{ config, pkgs, ... }:

let
  ffpkgs = (import ./default.nix) { };
in

{
  require =
    [ ./minimal.nix
      ./libvirt.nix
    ];

  boot =
    { extraModulePackages = with config.boot.kernelPackages; [ batman_adv netatop ];
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
          "net.ipv4.conf.default.rp_filter" = 2;
          "net.ipv4.conf.all.rp_filter" = 2;
          # Increase Linux autotuning TCP buffer limits
          # Set max to 16MB for 1GE and 32M (33554432) or 54M (56623104) for 10GE
          # Don't set tcp_mem itself! Let the kernel scale it based on RAM.
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

        };
    };

  networking =
    { hostName = "gw01.ffmuc.bpletza.de";
      firewall = {
        allowedTCPPorts = [ 22 53 ];
        allowedUDPPorts = [ 53 10000 ];
      };
      bridges = {
        br0 = {
          interfaces = [];
        };
      };
      interfaces.br0 = {
        ip4 = [
          { address = "10.80.0.11"; prefixLength = 19; }
        ];
        ip6 = [
          { address = "fdef:ffc0:4fff::11"; prefixLength = 64; }
        ];
      };
    };

  systemd.services = {
    "bat0-netdev" = {
      description = "batman interface bat0";
      wantedBy = [ "network-interfaces.target" ];
      after = [ "br0-netdev.service" ];
      requires = [ "br0-netdev.service" ];

      path = with pkgs; [ iproute batctl ];

      script = ''
        ip link add dummy0 type dummy || true
        batctl -m bat0 if add dummy0
        batctl -m bat0 gw server 100000/100000
        batctl -m bat0 it 10000
        ip link set bat0 up
        ip link set bat0 master br0
      '';
    };
    alfred = {
      description = "Alfred daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "bat0-netdev.service" "network.target" ];
      requires = [ "bat0-netdev.service" ];

      script = "${pkgs.alfred}/bin/alfred -i bat0 -b bat0 -u /run/alfred.sock";
    };
    "batadv-vis" = {
      description = "batadv-vis daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "alfred.service" ];
      requires = [ "alfred.service" ];

      script = "${pkgs.alfred}/bin/batadv-vis -i bat0 /run/alfred.sock -s";
    };
    fastd = {
      description = "fastd tunneling daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      script = ''
        mkdir /run/fastd
        chown nobody:nogroup /run/fastd

        ${ffpkgs.fastd}/bin/fastd \
          --status-socket /run/fastd/mesh-vpn.sock \
          --user nobody \
          --group nogroup \
          --log-level verbose \
          --mode tap \
          --interface mesh-vpn \
          --mtu 1426 \
          --bind any:10000 \
          --method salsa2012+umac \
          --on-up '${pkgs.batctl}/bin/batctl -m bat0 if add $IFACE' \
          --on-verify "true" \
          --config ${pkgs.writeText "fastd-mesh-vpn" ''
            secret "f0f77b2da54873417e9e2a6ee6b1935da46ea17f6033baf4638cd1a81c150044";
          ''} \
          --config-peer ${pkgs.writeText "fastd-peer-gw04" ''
            key "2242fe7fff1def15233a364487545e57c3c69e1b624d97bd5d72359b9851cb6e";
            float no;
            remote "gw05.ffmuc.net" port 9999;
          ''}
      '';
    };
  };

  environment.systemPackages = with pkgs;
    [ vim
      tcpdump
      htop
      batctl
      alfred
      ffpkgs.ecdsautils
      ffpkgs.fastd
      atop
      bridge-utils
      strace
    ];

  services =
    { dnsmasq.enable = true;
    };

  hardware.pulseaudio.enable = false;

  users.extraUsers.root.password = "";

  #virtualisation.graphics = false;
}
