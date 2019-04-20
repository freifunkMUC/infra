{ config, lib, pkgs, ... }:

with lib;

let
  ffpkgs = (import ../pkgs/default.nix) { };

  cfg = config.freifunk.gateway;

  mapSegments = f: mapAttrsToList f cfg.segments;
  concatSegments = f: concatStrings (mapSegments f);

  genMacAddr = base: prefix: "${prefix}:${base}";

  mkFastd = { interface, mtu, bind, secret, mac, segment, cpuaffinity }:
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
          --mtu ${toString mtu} \
          ${concatMapStrings (b: ''
            --bind '${b}' \'') bind}
          --method salsa2012+umac \
          --on-up '${pkgs.iproute}/bin/ip link set "${interface}" ${lib.optionalString (mac != null) "address ${mac}"} up; ${pkgs.batctl}/bin/batctl -m bat-${segment} if add "${interface}"; systemctl start bat-${segment}-netdev.service;' \
          --on-verify "true" \
          --config ${pkgs.writeText "fastd-mesh-${segment}" ''
            secret "${secret}";
          ''} \
          --config-peer ${pkgs.writeText "some-peer" ''
            key "2242fe7fff1def15233a364487545e57c3c69e1b624d97bd5d72359b9851cb6e";
            float yes;
          ''}
      '';

      serviceConfig.CPUAffinity = cpuaffinity;
    };

in

{
  options = {
    freifunk.gateway = {
      enable = mkEnableOption "Freifunk Gateway Config";

      isRouter = mkOption {
        type = types.bool;
        default = true;
      };

      externalInterface = mkOption {
        type = types.str;
        description = "External Interface";
        example = "eth0";
      };

      ip4Interfaces = mkOption {
        type = types.listOf types.str;
        description = "Interfaces to route IPv4 to";
        example = "tun0";
      };

      ip6Interface = mkOption {
        type = types.str;
        description = "Interface to route IPv6 to";
        example = "eth1";
      };

      networkingLocalCommands = mkOption {
        type = types.lines;
        description = "Commands to add to networking.localCommands";
        default = "";
      };

      segments = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            baseMacAddress = mkOption {
              type = types.str;
              description = "Base MAC address without first byte";
              example = "80:00:01:23:42";
            };

            bridgeInterface = mkOption {
              type = types.attrs;
              description = "Interface config for main bridge";
              example = {
                ip4 = [ { address = "10.80.0.11"; prefixLength = 19; } ];
                ip6 = [ { address = "fdef:ffc0:4fff::11"; prefixLength = 64; } ];
              };
            };

            dhcpRanges = mkOption {
              type = types.listOf types.str;
              description = "List of DHCP ranges in dnsmasq format";
              example = [ "10.80.1.0,10.80.7.255,255.255.224.0,1h" ];
            };

            portBalancings = mkOption {
              type = types.listOf types.attrs;
              description = "Simple port balancing mappings";
              default = [];
            };

            ra.prefixes = mkOption {
              type = types.listOf types.str;
              default = [];
            };

            ra.rdnss = mkOption {
              type = types.listOf types.str;
              default = [];
            };

            meshInterfaces = mkOption {
              type = types.listOf types.str;
              default = [];
            };

            fastdConfigs = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  listenAddresses = mkOption {
                    type = types.listOf types.str;
                    default = [ "any" ];
                  };
                  listenPort = mkOption {
                    type = types.int;
                    default = 10000;
                  };
                  mac = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                  };
                  secret = mkOption {
                    type = types.str;
                    description = "Secret key for fastd";
                    example = "180dcd09cd9e40f18b202d0a5c5c2d174fbb7758defc0a60bc649016c74c4d42";
                  };
                  mtu = mkOption {
                    type = types.int;
                    default = 1280;
                  };
                  cpuaffinity = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                  };
                };
              });
              description = "Configuration for fastd daemons";
            };
          };
        });
        description = "Freifunk Segments configuration";
      };

    };
  };

  config = mkIf cfg.enable {

    boot =
      { extraModulePackages = with config.boot.kernelPackages;
          [ batman_adv netatop ];
        kernelModules = [ "batman_adv" ];
        tmpOnTmpfs = true;
        kernel.sysctl =
          { "fs.file-max" = 100000;
            "vm.swappiness" = 10;
            "net.core.default_qdisc" = "fq_codel";
            "net.ipv4.ip_forward" = 1;
            "net.ipv6.conf.all.forwarding" = 1;
            "net.ipv6.conf.all.use_tempaddr" = 0;
            "net.ipv6.conf.default.use_tempaddr" = 0;
            "net.ipv4.conf.default.rp_filter" = 0;
            "net.ipv4.conf.all.rp_filter" = 0;
            # Increase Linux autotuning TCP buffer limits
            "net.core.rmem_max" = 33554432;
            "net.core.wmem_max" = 33554432;
            "net.core.rmem_default" = 33554432;
            "net.core.wmem_default" = 33554432;
            "net.core.optmem_max" = 1048576;
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
            "net.ipv4.neigh.default.gc_thresh1" = 20000;
            "net.ipv4.neigh.default.gc_thresh2" = 25000;
            "net.ipv4.neigh.default.gc_thresh3" = 30000;
            "net.ipv6.neigh.default.gc_thresh1" = 20000;
            "net.ipv6.neigh.default.gc_thresh2" = 25000;
            "net.ipv6.neigh.default.gc_thresh3" = 30000;
            "net.ipv6.route.gc_thresh" = 30000;
            # Disable TCP slow start on idle connections
            "net.ipv4.tcp_slow_start_after_idle" = 0;
            # Disable source routing and redirects
            "net.ipv4.conf.all.send_redirects" = 0;
            "net.ipv4.conf.all.accept_redirects" = 0;
            "net.ipv6.conf.all.accept_redirects" = 0;
            "net.ipv4.conf.all.accept_source_route" = 0;
            "net.ipv6.conf.all.accept_source_route" = 0;
            # Log martian packets
            "net.ipv4.conf.all.log_martians" = 0;
            # Decrease connection tracking timeouts
            "net.netfilter.nf_conntrack_generic_timeout" = 300;
            "net.netfilter.nf_conntrack_expect_max" = 8192;
            "net.netfilter.nf_conntrack_tcp_max_retrans" = 2;
            "net.netfilter.nf_conntrack_tcp_timeout_close" = 5;
            "net.netfilter.nf_conntrack_tcp_timeout_close_wait" = 15;
            "net.netfilter.nf_conntrack_tcp_timeout_established" = 600;
            "net.netfilter.nf_conntrack_tcp_timeout_fin_wait" = 30;
            "net.netfilter.nf_conntrack_tcp_timeout_last_ack" = 15;
            "net.netfilter.nf_conntrack_tcp_timeout_max_retrans" = 300;
            "net.netfilter.nf_conntrack_tcp_timeout_syn_recv" = 15;
            "net.netfilter.nf_conntrack_tcp_timeout_syn_sent" = 30;
            "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 30;
            "net.netfilter.nf_conntrack_tcp_timeout_unacknowledged" = 60;
            "net.netfilter.nf_conntrack_udp_timeout" = 20;
            "net.netfilter.nf_conntrack_udp_timeout_stream" = 180;
            "net.netfilter.nf_conntrack_max" = 500000;
          };
      };

    networking =
      { firewall = {
          allowedTCPPorts = [ 5201 69 ];
          allowedUDPPorts = [ 69 ];
          checkReversePath = false;
          logRefusedConnections = false;
          extraCommands = ''
            ip46tables -F FORWARD
            ip46tables -P FORWARD DROP

            ${concatSegments (name: scfg: concatStrings (mapAttrsToList (name: fcfg: ''
              iptables -I nixos-fw 3 -i ${cfg.externalInterface} -p udp \! -s 195.30.94.25/29 --dport ${toString fcfg.listenPort} -j nixos-fw-accept
              ip6tables -I nixos-fw 3 -i ${cfg.externalInterface} -p udp \! -s 2001:608:a01::/48 --dport ${toString fcfg.listenPort} -j nixos-fw-accept
            '') scfg.fastdConfigs))}

            iptables -t nat -F PREROUTING
            iptables -t nat -F POSTROUTING
            ip46tables -t mangle -F POSTROUTING

            ${concatSegments (name: scfg: concatStrings (map ({ from, to1, to2, to3 ? to1, to4 ? to2 }: ''
              iptables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0xc&0x3=0x0" -j REDIRECT --to-ports ${toString to1}
              iptables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0xc&0x3=0x1" -j REDIRECT --to-ports ${toString to2}
              iptables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0xc&0x3=0x2" -j REDIRECT --to-ports ${toString to3}
              iptables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0xc&0x3=0x3" -j REDIRECT --to-ports ${toString to4}
              ip6tables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0x14&0x3=0x0" -j REDIRECT --to-ports ${toString to1}
              ip6tables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0x14&0x3=0x1" -j REDIRECT --to-ports ${toString to2}
              ip6tables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0x14&0x3=0x2" -j REDIRECT --to-ports ${toString to3}
              ip6tables -t nat -A PREROUTING -i ${cfg.externalInterface} -p udp -m udp --dport ${toString from} -m u32 --u32 "0x14&0x3=0x3" -j REDIRECT --to-ports ${toString to4}
            '') scfg.portBalancings))}

          '' + (optionalString cfg.isRouter ''

            iptables -t mangle -F PREROUTING

            ${concatSegments (name: scfg: ''
              iptables -I nixos-fw 3 -i br-${name} -p udp --dport 67:68 --sport 67:68 -j nixos-fw-accept
              ip46tables -I nixos-fw 3 -i br-${name} -p udp --dport 53 -j nixos-fw-accept
              ip46tables -I nixos-fw 3 -i br-${name} -p tcp --dport 53 -j nixos-fw-accept

              iptables -A PREROUTING -t mangle -i br-${name} -p icmp --icmp-type echo-request -j MARK --set-mark 5
              ${concatMapStrings (port: ''
                iptables -A PREROUTING -t mangle -i br-${name} -p udp --dport ${toString port} -j MARK --set-mark 5
                iptables -A PREROUTING -t mangle -i br-${name} -p tcp --dport ${toString port} -j MARK --set-mark 5
              '') [ 80 443 8080 8443 9090 143 993 110 587 5222 5269 53 655 1149 123 4500 1293 500 5060 5061 4569 3478 22 2223 ]}
            '')}

            ip46tables -A FORWARD -i br-+ -o br-+ -j ACCEPT
            ${concatSegments (name: scfg: ''
              ip6tables -A FORWARD -i br-${name} -o ${cfg.ip6Interface} -j ACCEPT
              ip6tables -A FORWARD -i ${cfg.ip6Interface} -o br-${name} -j ACCEPT
            '' + (concatMapStrings (if4: ''
              iptables -A FORWARD -i br-${name} -o ${if4} -j ACCEPT
              iptables -A FORWARD -i ${if4} -o br-${name} -j ACCEPT
            '') cfg.ip4Interfaces))}
            iptables -A FORWARD -j REJECT --reject-with icmp-admin-prohibited
            ip6tables -A FORWARD -j REJECT --reject-with icmp6-adm-prohibited

            ${concatMapStrings (if4: ''
              iptables -t nat -A POSTROUTING -o ${if4} -j MASQUERADE
              iptables -t mangle -A POSTROUTING -o ${if4} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1200
            '') cfg.ip4Interfaces}
          '');
        };
        bridges = fold (a: b: a // b) {} (mapSegments (name: scfg: {
          "br-${name}" = {
            interfaces = [];
          };
        }));
        interfaces = fold (a: b: a // b) {} (mapSegments (name: scfg: {
          "br-${name}" = {
            macAddress = genMacAddr scfg.baseMacAddress "f6";
          } // scfg.bridgeInterface;
        }));
        dhcpcd.allowInterfaces = [ ];
        localCommands = ''
          set -x
        '' + (optionalString cfg.isRouter ''
            ip route replace unreachable default metric 100 table 42
            ${concatSegments (name: scfg: ''
              ip rule add iif br-${name} lookup 42
              ip rule add iif br-${name} fwmark 5 lookup 5
            '')}
        '') + ''
          ${cfg.networkingLocalCommands}

          ip route replace unreachable 10/8
          ip route replace unreachable 10/8 table 5
          ip route replace unreachable 10/8 table 42
          ip route replace unreachable 172.16/12
          ip route replace unreachable 172.16/12 table 5
          ip route replace unreachable 172.16/12 table 42
          ip route replace unreachable 192.168/16
          ip route replace unreachable 192.168/16 table 5
          ip route replace unreachable 192.168/16 table 42
        '';
      };

    systemd.services = fold (a: b: a // b) {} (
      mapSegments (name: scfg: {
        "bat-${name}-netdev" = {
          description = "batman interface bat-${name}";
          #wantedBy = [ "multi-user.target" ];
          after = [ "network-interfaces.target" ];
          #requires = [ "br-${name}-netdev.service" ];

          serviceConfig.Type = "oneshot";
          path = with pkgs; [ iproute batctl ];
          script = ''
            ${optionalString cfg.isRouter ''
              batctl -m bat-${name} gw server 1000000/1000000
            ''}
            batctl -m bat-${name} it 10000
            ip link set bat-${name} down
            ip link set bat-${name} address ${genMacAddr scfg.baseMacAddress "fa"}
            ip link set bat-${name} up
            ip link set br-${name} down
            ip link set bat-${name} master br-${name}
            ip link set br-${name} up
            ${concatStrings (flip map scfg.meshInterfaces (mif: ''
              batctl -m bat-${name} if add ${mif}
            ''))}
            systemctl restart network-addresses-br-${name}.service
            systemctl start alfred-${name}.service batadv-vis-${name}.service
          '';
        };
        "alfred-${name}" = {
          description = "Alfred daemon for ${name}";
          after = [ "network.target" ];

          script = ''
            sleep 2
            exec ${pkgs.alfred}/bin/alfred -i br-${name} -b bat-${name} -u /run/alfred-${name}.sock
          '';
        };
        "batadv-vis-${name}" = {
          description = "batadv-vis daemon for ${name}";
          after = [ "alfred-${name}.service" ];
          requires = [ "alfred-${name}.service" ];

          script = "exec ${pkgs.alfred}/bin/batadv-vis -s -i bat-${name} -u /run/alfred-${name}.sock";
        };
      } // (fold (a: b: a // b) {} (mapAttrsToList (interface: fcfg: {
        "fastd-${name}-${interface}" = mkFastd {
          inherit (fcfg) secret mac mtu cpuaffinity;
          bind = map (addr: "${addr}:${toString fcfg.listenPort}") fcfg.listenAddresses;
          interface = "${name}-${interface}";
          segment = name;
        };
      }) scfg.fastdConfigs))
    ))
    //
    {
      iperf = {
        description = "iperf daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig.ExecStart = "${pkgs.iperf}/bin/iperf -s -p 5201";
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
        bmon
      ];

    services = mkIf cfg.isRouter
      { dnsmasq =
          { enable = true;
            resolveLocalQueries = false;
            extraConfig = ''
              bind-interfaces
              interface=lo
              ${concatSegments (name: scfg: ''
                interface=br-${name}
              '')}
              port = 0
              log-async = 100
              dhcp-option=6,10.80.32.13

              dhcp-ignore-names
              dhcp-lease-max=40960
              ${concatSegments (name: scfg: concatMapStrings (range: ''
                dhcp-range=${range}
              '') scfg.dhcpRanges)}

              no-hosts
              dns-forward-max=1024
              cache-size=0
              no-negcache
              no-resolv
              server=2001:608:a01::53

              enable-tftp
              dhcp-authoritative
              tftp-root=/var/lib/tftp
              tftp-secure
              dhcp-match=set:ipxe,175
              dhcp-boot=tag:!ipxe,undionly.kpxe
            '';
          };
        unbound =
          { enable = true;
            allowedAccess = [ "::1" "127.0.0.1" "::/0" "0.0.0.0/0" ];
            interfaces = [ "10.80.32.13" "2001:608:a01::53" ];
            extraConfig = ''
              server:
                port: 53
                #interface-automatic: yes
                so-reuseport: yes
                num-threads: 8
                outgoing-range: 8192
                num-queries-per-thread: 4096
                prefer-ip6: yes

                msg-cache-slabs: 8
                rrset-cache-slabs: 8
                infra-cache-slabs: 8
                key-cache-slabs: 8

                # more cache memory, rrset=msg*2
                rrset-cache-size: 512m
                msg-cache-size: 256m

                # Larger socket buffer
                so-rcvbuf: 4m
                so-sndbuf: 4m

                cache-min-ttl: 60
                cache-max-ttl: 86400
                cache-max-negative-ttl: 30
                qname-minimisation: yes
                prefetch: yes
                hide-version: yes
                log-queries: no

                statistics-interval: 0
                extended-statistics: yes
                statistics-cumulative: no

                local-data-ptr: "2001:608:a01:2::13 isartor.ffmuc.net"
                local-data-ptr: "10.80.32.13 isartor.ffmuc.net"
                local-data-ptr: "2001:608:a01::31 ipv6.space.ffmuc.net"

                local-zone: "1.0.a.0.8.0.6.0.1.0.0.2.ip6.arpa" nodefault
                local-zone: "f.f.f.4.0.c.f.f.f.e.d.f.ip6.arpa" nodefault

              forward-zone:
                name: "1.0.a.0.8.0.6.0.1.0.0.2.ip6.arpa"
                forward-addr: 2001:608:a01::54

              forward-zone:
                name: "f.f.f.4.0.c.f.f.f.e.d.f.ip6.arpa"
                forward-addr: 2001:608:a01::54

              remote-control:
                control-enable: yes
                control-use-cert: no

              include: ${ffpkgs.icvpn-bird}/unbound.conf
            '';
          };
        radvd = let
          config = concatSegments (name: scfg:
            lib.optionalString (scfg.ra.prefixes != []) ''
              interface br-${name} {
                AdvSendAdvert on;
                AdvManagedFlag off;
                AdvOtherConfigFlag on;
                MaxRtrAdvInterval 60;

                ${concatStrings (map (prefix: ''
                  prefix ${prefix} {
                    AdvValidLifetime 600;
                    AdvPreferredLifetime 300;
                  };
                '') scfg.ra.prefixes)}

                ${concatStrings (map (dns: ''
                      RDNSS ${dns} {
                        AdvRDNSSLifetime 600;
                      };
                '') scfg.ra.rdnss)}
              };
          '');
          in
          { enable = (config != "");
            inherit config;
          };
      };
    };
}
