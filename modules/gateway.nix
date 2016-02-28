{ config, lib, pkgs, ... }:

with lib;

let
  ffpkgs = (import ../pkgs/default.nix) { };

  cfg = config.gateway;

  genMacAddr = prefix: "${prefix}:${cfg.baseMacAddress}";

  mkFastd = { interface, mtu, bind, secret, macPrefix }:
    {
      description = "fastd tunneling daemon for ${interface}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      script = ''
        mkdir -p /run/fastd
        rm -f /run/fastd/${interface}.sock
        chown nobody:nogroup /run/fastd

        exec ${ffpkgs.fastd}/bin/fastd \
          --status-socket /run/fastd/${interface}.sock \
          --user nobody \
          --group nogroup \
          --log-level verbose \
          --mode tap \
          --interface "${interface}" \
          --mtu ${mtu} \
          --bind ${bind} \
          --method salsa2012+umac \
          --on-up '${pkgs.iproute}/bin/ip link set "${interface}" address ${genMacAddr macPrefix} up; ${pkgs.batctl}/bin/batctl -m bat0 if add "${interface}"; systemctl start bat0-netdev.service;' \
          --on-verify "true" \
          --config ${pkgs.writeText "fastd-mesh-vpn" ''
            secret "${cfg.fastdSecret}";
          ''} \
          --config-peer ${pkgs.writeText "gw05" ''
            key "2242fe7fff1def15233a364487545e57c3c69e1b624d97bd5d72359b9851cb6e";
            float yes;
          ''}
      '';
    };

in

{
  options = {
    gateway.baseMacAddress = mkOption {
      type = types.str;
      description = "Base MAC address without first byte";
      example = "80:00:01:23:42";
    };

    gateway.bridgeInterface = mkOption {
      type = types.attrs;
      description = "Interface config for main bridge";
      example = {
        ip4 = [ { address = "10.80.0.11"; prefixLength = 19; } ];
        ip6 = [ { address = "fdef:ffc0:4fff::11"; prefixLength = 64; } ];
      };
    };

    gateway.dhcpRanges = mkOption {
      type = types.listOf types.str;
      description = "List of DHCP ranges in dnsmasq format";
      example = [ "10.80.1.0,10.80.7.255,255.255.224.0,1h" ];
    };

    gateway.fastdSecret = mkOption {
      type = types.str;
      description = "Secret key for fastd";
      example = "180dcd09cd9e40f18b202d0a5c5c2d174fbb7758defc0a60bc649016c74c4d42";
    };

    gateway.graphite.host = mkOption {
      type = types.str;
      description = "Graphite hostname to deliver stats to";
      example = "stats.example.com";
    };

    gateway.graphite.port = mkOption {
      type = types.int;
      description = "Graphite TCP port to deliver stats to";
      example = 2003;
    };

  };

  config = {

    boot =
      { extraModulePackages = with config.boot.kernelPackages;
          [ batman_adv netatop ];
        kernelModules = [ "batman_adv" ];
        tmpOnTmpfs = true;
        kernel.sysctl =
          { "kernel.panic" = 1;
            "fs.file-max" = 100000;
            "vm.swappiness" = 10;
            "net.core.default_qdisc" = "fq_codel";
            "net.ipv4.ip_forward" = 1;
            "net.ipv6.conf.all.forwarding" = 1;
            "net.ipv6.conf.all.use_tempaddr" = 0;
            "net.ipv6.conf.default.use_tempaddr" = 0;
            "net.ipv4.conf.default.rp_filter" = 2;
            "net.ipv4.conf.all.rp_filter" = 2;
            # Increase Linux autotuning TCP buffer limits
            # Set max to 16MB for 1GE
            "net.core.rmem_max" = 16777216;
            "net.core.wmem_max" = 16777216;
            "net.core.rmem_default" = 16777216;
            "net.core.wmem_default" = 16777216;
            "net.core.optmem_max" = 40960;
            "net.ipv4.tcp_rmem" = "4096 87380 16777216";
            "net.ipv4.tcp_wmem" = "4096 65536 16777216";
            # Make room for more TIME_WAIT sockets due to more clients,
            # and allow them to be reused if we run out of sockets
            # Also increase the max packet backlog
            "net.core.netdev_max_backlog" = 50000;
            "net.ipv4.tcp_max_syn_backlog" = 30000;
            "net.ipv4.tcp_max_tw_buckets" = 2000000;
            "net.ipv4.tcp_tw_reuse" = 1;
            "net.ipv4.tcp_fin_timeout" = 10;
            # Increase garbage collection thresholds for neighbor tables
            "net.ipv4.neigh.default.gc_thresh1" = 2048;
            "net.ipv4.neigh.default.gc_thresh2" = 5120;
            "net.ipv4.neigh.default.gc_thresh3" = 10240;
            "net.ipv6.neigh.default.gc_thresh1" = 2048;
            "net.ipv6.neigh.default.gc_thresh2" = 5120;
            "net.ipv6.neigh.default.gc_thresh3" = 10240;
            "net.ipv6.route.gc_thresh" = 10240;
            # Disable TCP slow start on idle connections
            "net.ipv4.tcp_slow_start_after_idle" = 0;
            # Disable source routing and redirects
            "net.ipv4.conf.all.send_redirects" = 0;
            "net.ipv4.conf.all.accept_redirects" = 0;
            "net.ipv6.conf.all.accept_redirects" = 0;
            "net.ipv4.conf.all.accept_source_route" = 0;
            "net.ipv6.conf.all.accept_source_route" = 0;
            # Log martian packets
            "net.ipv4.conf.all.log_martians" = 1;
            # Decrease connection tracking timeouts
            "net.netfilter.nf_conntrack_tcp_timeout_established" = 43200;
          };
      };

    networking =
      { firewall = {
          allowedTCPPorts = [ 22 5201 ];
          checkReversePath = false;
          extraCommands = ''
            iptables -I nixos-fw 3 -i br0 -p udp --dport 67:68 --sport 67:68 -j nixos-fw-accept
            ip46tables -I nixos-fw 3 -i br0 -p udp --dport 53 -j nixos-fw-accept
            ip46tables -I nixos-fw 3 -i br0 -p tcp --dport 53 -j nixos-fw-accept
            ip46tables -I nixos-fw 3 -i enp0s3 -p udp --dport 10000 -j nixos-fw-accept
            ip46tables -I nixos-fw 3 -i enp0s3 -p udp --dport 10001 -j nixos-fw-accept
            ip46tables -I nixos-fw 3 -i enp0s3 -p udp --dport 10098 -j nixos-fw-accept
            ip46tables -I nixos-fw 3 -i enp0s3 -p udp --dport 10099 -j nixos-fw-accept
            ip46tables -I nixos-fw 3 -i enp0s3 -p udp --dport 9999 -j nixos-fw-accept

            ip46tables -F FORWARD
            ip46tables -P FORWARD DROP
            iptables -A FORWARD -i br0 -o tun0 -j ACCEPT
            iptables -A FORWARD -i tun0 -o br0 -j ACCEPT
            iptables -A FORWARD -j REJECT --reject-with icmp-net-prohibited

            iptables -t nat -F POSTROUTING
            iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
            ip46tables -t nat -A PREROUTING -i enp0s3 -p udp -m udp --dport 10000 -m u32 --u32 "0xc&0x1=0x1" -j REDIRECT --to-ports 10099
            ip46tables -t nat -A PREROUTING -i enp0s3 -p udp -m udp --dport 10001 -m u32 --u32 "0xc&0x1=0x1" -j REDIRECT --to-ports 10098

            ip46tables -t mangle -F POSTROUTING
            ip46tables -t mangle -A POSTROUTING -o tun0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1200
          '';
        };
        dhcpcd.allowInterfaces = [ "enp0s3" "eth0" ];
        bridges = {
          br0 = {
            interfaces = [];
          };
        };
        interfaces= {
          br0 = {
            macAddress = genMacAddr "f6";
          } // cfg.bridgeInterface;
        };
        localCommands = ''
          ip route replace unreachable default metric 100 table 42
          ip rule add iif br0 lookup 42
        '';
      };

    systemd.services = {
      iperf = {
        description = "iperf daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig.ExecStart = "${pkgs.iperf}/bin/iperf -s -p 5201";
      };
      "bat0-netdev" = {
        description = "batman interface bat0";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        #after = [ "br0-netdev.service" ];
        #requires = [ "br0-netdev.service" ];

        serviceConfig.Type = "oneshot";

        path = with pkgs; [ iproute batctl ];

        script = ''
          batctl -m bat0 gw server 1000000/1000000
          batctl -m bat0 it 10000
          ip link set bat0 down
          ip link set bat0 address ${genMacAddr "fa"}
          ip link set bat0 up
          ip link set bat0 master br0
        '';
      };
      alfred = {
        description = "Alfred daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        requires = [ "bat0-netdev.service" ];

        script = "exec ${pkgs.alfred}/bin/alfred -i bat0 -b bat0 -u /run/alfred.sock";
      };
      "batadv-vis" = {
        description = "batadv-vis daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "alfred.service" ];
        requires = [ "alfred.service" ];

        script = "exec ${pkgs.alfred}/bin/batadv-vis -i bat0 /run/alfred.sock -s";
      };
      fastd-mesh0 = mkFastd {
        interface = "mesh-vpn0";
        mtu = "1426";
        bind = "any:10000";
        macPrefix = "f2";
        secret = cfg.fastdSecret;
      };
      fastd-mesh1 = mkFastd {
        interface = "mesh-vpn1";
        mtu = "1426";
        bind = "any:10099";
        macPrefix = "f6";
        secret = cfg.fastdSecret;
      };
      fastd-mesh0-1280 = mkFastd {
        interface = "mesh-vpn0-1280";
        mtu = "1280";
        bind = "any:10001";
        macPrefix = "e2";
        secret = cfg.fastdSecret;
      };
      fastd-mesh1-1280 = mkFastd {
        interface = "mesh-vpn1-1280";
        mtu = "1280";
        bind = "any:10098";
        macPrefix = "e6";
        secret = cfg.fastdSecret;
      };
      fastd-backbone = mkFastd {
        interface = "backbone-vpn";
        mtu = "1426";
        bind = "any:9999";
        macPrefix = "f4";
        secret = cfg.fastdSecret;
      };
    };

    environment.systemPackages = with pkgs;
      [ vim
        wget
        tcpdump
        htop
        batctl
        alfred
        ffpkgs.ecdsautils
        ffpkgs.fastd
        atop
        bridge-utils
        strace
        socat
        jq
        jnettop
        tmux
        mtr
        iperf
      ];

    services =
      { dnsmasq =
          { enable = true;
            extraConfig = ''
              bind-interfaces
              interface=lo
              interface=br0
              dhcp-lease-max=40960
              ${concatMapStrings (range: ''
                dhcp-range=${range}
              '') cfg.dhcpRanges}
              cache-size=0
              no-negcache
              no-resolv
              server=::1#54
            '';
          };
        unbound =
          { enable = true;
            allowedAccess = [ "::1" "127.0.0.1" ];
            extraConfig = ''
              server:
                port: 54
                num-threads: 2
                msg-cache-size: 16M
                msg-cache-slabs: 8
                num-queries-per-thread: 2048
                rrset-cache-size: 16M
                rrset-cache-slabs: 8
                cache-min-ttl: 10
                cache-max-ttl: 86400
                cache-max-negative-ttl: 600
                qname-minimisation: yes
                prefetch: yes
                hide-version: yes
                log-queries: yes
            '';
          };
        collectd =
          { enable = true;
            extraConfig = ''
              FQDNLookup true
              Interval 30

              LoadPlugin conntrack
              LoadPlugin cpu
              LoadPlugin df
              LoadPlugin disk
              LoadPlugin dns
              LoadPlugin entropy
              LoadPlugin interface
              LoadPlugin load
              LoadPlugin memory
              LoadPlugin processes
              LoadPlugin swap
              LoadPlugin users
              LoadPlugin write_graphite

              <Plugin df>
                FSType rootfs
                FSType sysfs
                FSType proc
                FSType devtmpfs
                FSType devpts
                FSType tmpfs
                FSType fusectl
                FSType cgroup
                IgnoreSelected true
              </Plugin>

              <Plugin dns>
                Interface "br0"
              </Plugin>

              <Plugin interface>
                Interface "lo"
                IgnoreSelected true
              </Plugin>

              <Plugin write_graphite>
                <Node "${cfg.graphite.host}">
                  Host "${cfg.graphite.host}"
                  Port "${toString cfg.graphite.port}"
                  Protocol "tcp"
                  LogSendErrors true
                  Prefix "servers."
                  StoreRates true
                  AlwaysAppendDS false
                  SeparateInstances false
                  EscapeCharacter "_"
                </Node>
              </Plugin>
            '';
          };
      };
  };
}
