{ config, pkgs, ... }:

let
  secrets = (import ../secrets) { inherit pkgs; };
  ffpkgs = (import ../pkgs/default.nix) { };
in

{
  imports = [
    ../modules/default.nix
    ../modules/gateway.nix
  ];

  hardware.enableAllFirmware = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "uhci_hcd" "usbhid" "usb_storage" "sd_mod" "sr_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/d0ca21c6-f0b7-46a2-8e48-572156dabd44";
      fsType = "btrfs";
    };

  nix.maxJobs = 4;

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  freifunk.gateway = {
    enable = true;
    externalInterface = "eno2";
    ip4Interfaces = [ "tun0" "eno2" ];
    ip6Interface = "eno2";
    networkingLocalCommands = ''
      ip rule add from 195.30.94.49/32 lookup 5
      ip route replace default via 195.30.94.30 table 5
      ip route replace 195.30.94.48/28 dev eno1 table 5
      ip route replace 195.30.94.24/29 dev eno2 table 5
    '';
    graphite = secrets.stats.bpletza;
    segments = {
      ffmuc = {
        baseMacAddress = "80:00:03:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.80.32.13"; prefixLength = 19; } ];
          ip6 = [
            { address = "fdef:ffc0:4fff::13"; prefixLength = 64; }
            { address = "fdef:ffc0:4fff::130"; prefixLength = 64; }
            { address = "fdef:ffc0:4fff::131"; prefixLength = 64; }
            { address = "2001:608:a01:2::13"; prefixLength = 64; }
          ];
        };
        dhcpRanges = [ "10.80.34.0,10.80.53.255,255.255.224.0,1h" ];
        ra.prefixes = [ "2001:608:a01:2::/64" ];
        ra.rdnss = [ "2001:608:a01:2::13" ];
        fastdConfigs = let
          secret = secrets.fastd.gw03.secret;
          listenAddresses = [ "195.30.94.27" "[2001:608:a01::1]" ];
        in {
          backbone = {
            inherit secret listenAddresses;
            listenPort = 9999;
            mtu = 1426;
          };
          mesh0 = {
            inherit secret listenAddresses;
            listenPort = 10000;
            mtu = 1426;
          };
          mesh1 = {
            inherit secret listenAddresses;
            listenPort = 10099;
            mtu = 1426;
          };
          mesh2 = {
            inherit secret listenAddresses;
            listenPort = 10001;
            mtu = 1280;
          };
          mesh3 = {
            inherit secret listenAddresses;
            listenPort = 10098;
            mtu = 1280;
          };
        };
        portBalancings = [
          { from = 10000; to = 10099; }
          { from = 10001; to = 10098; }
        ];
      };
      welcome = {
        baseMacAddress = "80:ff:02:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.80.64.12"; prefixLength = 19; } ];
          ip6 = [
            { address = "fdef:ffc0:4fff:1::12"; prefixLength = 64; }
            { address = "2001:608:a01:3::12"; prefixLength = 64; }
          ];
        };
        dhcpRanges = [ "10.80.68.0,10.80.90.255,255.255.224.0,1h" ];
        ra.prefixes = [ "2001:608:a01:3::/64" ];
        ra.rdnss = [ "2001:608:a01:3::12" ];
        fastdConfigs = let
          secret = secrets.fastd.gwf02.secret;
          listenAddresses = [ "195.30.94.27" "[2001:608:a01::1]" ];

        in {
          mesh0 = {
            inherit secret listenAddresses;
            listenPort = 11000;
            mtu = 1426;
          };
          mesh1 = {
            inherit secret listenAddresses;
            listenPort = 11099;
            mtu = 1426;
          };
          mesh2 = {
            inherit secret listenAddresses;
            listenPort = 11001;
            mtu = 1280;
          };
          mesh3 = {
            inherit secret listenAddresses;
            listenPort = 11098;
            mtu = 1280;
          };
        };
        portBalancings = [
          { from = 11000; to = 11099; }
          { from = 11001; to = 11098; }
        ];
      };
      umland = {
        baseMacAddress = "80:01:02:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.80.96.12"; prefixLength = 19; } ];
          ip6 = [
            { address = "fdef:ffc0:4fff:2::12"; prefixLength = 64; }
            { address = "2001:608:a01:4::12"; prefixLength = 64; }
          ];
        };
        dhcpRanges = [ "10.80.98.0,10.80.111.255,255.255.224.0,1h" ];
        ra.prefixes = [ "2001:608:a01:4::/64" ];
        ra.rdnss = [ "2001:608:a01:4::12" ];
        fastdConfigs = let
          secret = secrets.fastd.gwu02.secret;
          listenAddresses = [ "195.30.94.27" "[2001:608:a01::1]" ];
        in {
          mesh0 = {
            inherit secret listenAddresses;
            listenPort = 10011;
            mtu = 1426;
          };
          mesh1 = {
            inherit secret listenAddresses;
            listenPort = 10089;
            mtu = 1426;
          };
          mesh3 = {
            inherit secret listenAddresses;
            listenPort = 10015;
            mtu = 1280;
          };
          mesh4 = {
            inherit secret listenAddresses;
            listenPort = 10085;
            mtu = 1280;
          };
        };
        portBalancings = [
          { from = 10011; to = 10089; }
          { from = 10015; to = 10085; }
        ];
      };
     };
  };

  networking = {
    hostName = "isartor";
    interfaces.eno2 = {
      ip4 = [ { address = "195.30.94.27"; prefixLength = 29; } ];
      ip6 = [ { address = "2001:608:a01::1"; prefixLength = 64; } ];
    };
    interfaces.eno1 = {
      ip4 = [ { address = "195.30.94.49"; prefixLength = 28; } ];
      ip6 = [ { address = "2001:608:a01:1::2"; prefixLength = 64; } ];
    };

    defaultGateway = "195.30.94.30";
    defaultGateway6 = "2001:608:a01::ffff";

    firewall.allowedTCPPorts = [ 80 443 ];
    firewall.allowedUDPPorts = [ 123 10100 ];
    firewall.extraCommands = ''
      ip6tables -I nixos-fw 3 -i fastd-babel -m pkttype --pkt-type multicast -j nixos-fw-accept
      ip46tables -I FORWARD 1 -i br-+ -o dn42-+ -j ACCEPT
      ip46tables -I FORWARD 1 -i dn42-+ -o br-+ -j ACCEPT
      ip46tables -I FORWARD 1 -i dn42-+ -o dn42-+ -j ACCEPT
    '';
  };

   environment.systemPackages = with pkgs; [
     tinc_pre babeld
   ];

  systemd.services = {
    fastd-babel = {
      description = "fastd tunneling daemon for babel";
      wantedBy = [ "network.target" "multi-user.target" ];
      after = [ "network.target" ];
      preStart = ''
        mkdir -p /run/fastd
        rm -f /run/fastd/babel.sock
        chown nobody:nogroup /run/fastd
      '';
      serviceConfig = {
        ExecStart = ''
          ${ffpkgs.fastd}/bin/fastd -c ${pkgs.writeText "fastd-babel.conf" ''
            user "nobody";
            group "nogroup";
            status socket "/run/fastd/babel.sock";
            log level verbose;
            mode tap;
            interface "fastd-babel";
            mtu 1280;
            bind 195.30.94.27:10100;
            bind [2001:608:a01::1]:10100;
            method "salsa2012+umac";
            method "null";
            on verify "true";
            on up "${pkgs.iproute}/bin/ip link set fastd-babel up; ${pkgs.iproute}/bin/ip addr add 2001:608:a01:bfff::1/64 dev fastd-babel";
            secret "${secrets.fastd.gw03.secret}";
          ''}
        '';
      };
    };
    babeld = let
      babeldConf = pkgs.writeText "babeld.conf" ''
        redistribute ip 2001:608:a01::/64 le 127 deny
        redistribute ip ::/0 le 0 proto 3 metric 128
        redistribute ip 2001:608:a01::/48 le 127 metric 128
        redistribute ip fdef:ffc0:4fff::/48 le 127 metric 128

        # only redistribute nets matching the filters above
        redistribute local deny
        redistribute deny

        # Don't accept default routes
        in ip 0.0.0.0/32 le 0 deny
        in ip ::/128 le 0 deny
      '';
      in {
        description = "Babel routing daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "fastd-babel.service" ];
        serviceConfig = {
          ExecStart =
            "${pkgs.babeld}/bin/babeld -c ${babeldConf} fastd-babel";
        };
      };
  };

  services.dhcpd =
    { enable = true;
      interfaces = [ "fastd-babel" ];
      extraFlags = "-6";
      configFile = pkgs.writeText "dhpcd.conf" ''
        authoritative;
        log-facility local1;
        default-lease-time 600;
        max-lease-time 7200;

        #option dhcp-renewal-time 3600;
        #option dhcp-rebinding-time 7200;

        option dhcp6.name-servers 2001:608:a01:bfff::1;

        subnet6 2001:608:a01:b000::/52 {
          range6 2001:608:a01:b000:f000:: 2001:608:a01:bfff:ffff::;
          prefix6 2001:608:a01:b000:: 2001:608:a01:bffe:: / 64;
        }

        #subnet6 fe80::/64 {
        #}
      '';
    };

  services.chrony =
    { extraConfig = ''
        bindaddress fdef:ffc0:4fff::3
        bindaddress fdef:ffc0:4fff::131
        bindaddress 10.80.32.13
        allow 10.80/16
        allow fdef:ffc0:4fff::/48
        allow 2001:608:a01::/48
      '';
    };


  services.bird =
    { enable = true;
      config = ''
protocol device {
  scan time 10;
}

router id 10.80.32.13;

define OWNAS = 65080;
define OWNIP = 10.80.32.13;

table v4direct;
table v4vpn;

function is_self_net() {
  return net ~ [
    10.80.0.0/16+
  ];
}

include "${../static/bird_filter_dn42.conf}";

roa table dn42_roa {
  include "${../static/bird_roa_dn42.conf}";
};

protocol kernel {
  scan time 20;
  device routes;
  import none;
  export filter {
    krt_prefsrc = OWNIP;
    accept;
  };
}

protocol kernel kernel5 {
  table v4direct;
  scan time 20;
  device routes;
  import none;
  kernel table 5;
  export filter {
    krt_prefsrc = OWNIP;
    accept;
  };
}

protocol kernel kernel42 {
  table v4vpn;
  scan time 20;
  device routes;
  import none;
  kernel table 42;
  export filter {
    krt_prefsrc = OWNIP;
    accept;
  };
}

protocol pipe pipe5 {
  peer table v4direct;
  import none;
  export all;
};

protocol pipe pipe42 {
  peer table v4vpn;
  import none;
  export all;
};

protocol static {
  route 10.80.32.0/19 via "br-ffmuc";
  route 10.80.64.0/19 via "br-welcome";
  route 10.80.96.0/19 via "br-umland";
}

template bgp dnpeers {
  local as OWNAS;
  path metric 1;
  missing lladdr ignore;
  import keep filtered;
  import filter {
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_INVALID) then {
       print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
       reject;
    }
    if is_valid_network() && !is_self_net() then {
      accept;
    }
    reject;
  };
  export filter {
    if is_valid_network() then {
      accept;
    }
    reject;
  };
  route limit 10000;
}

protocol bgp fpletz from dnpeers {
  neighbor 172.23.214.1 as 4242420235;
};

protocol bgp jomat from dnpeers {
  neighbor 172.23.216.242 as 64773;
};

protocol bgp chaossbg from dnpeers {
  neighbor 172.23.171.30 as 4242421420;
};

protocol bgp AS4242421340 from dnpeers {
  neighbor 172.20.176.1 as 4242421340;
};

protocol bgp AS4242420330 from dnpeers {
  neighbor 172.20.182.1 as 4242420330;
};
      '';
    };

  services.bird6 =
    { enable = true;
      config = ''
protocol device {
  scan time 10;
}

router id 10.80.0.13;

define OWNAS = 65080;
define OWNIP = fdef:ffc0:4fff::13;

function is_self_net() {
  return net ~ [
    fdef:ffc0:4fff::/48+,
    2001:608:a01::/48+
  ];
}

include "${../static/bird6_filter_dn42.conf}";

roa table dn42_roa {
  include "${../static/bird6_roa_dn42.conf}";
};

protocol kernel {
  scan time 20;
  device routes;
  import none;
  export filter {
    krt_prefsrc = OWNIP;
    accept;
  };
}

protocol static {
  route fdef:ffc0:4fff:0::/64 via "br-ffmuc";
  route 2001:608:a01:2::/64 via "br-ffmuc";
  route fdef:ffc0:4fff:1::/64 via "br-welcome";
  route 2001:608:a01:3::/64 via "br-welcome";
  route fdef:ffc0:4fff:2::/64 via "br-umland";
  route 2001:608:a01:4::/64 via "br-umland";
}

template bgp dnpeers {
  local as OWNAS;
  path metric 1;
  missing lladdr ignore;
  import keep filtered;
  import filter {
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_INVALID) then {
       print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
       reject;
    }
    if is_valid_network() && !is_self_net() then {
      accept;
    }
    reject;
  };
  export filter {
    if is_valid_network() then {
      accept;
    }
    reject;
  };
  route limit 10000;
}

protocol bgp fpletz from dnpeers {
  neighbor fe80::1 % 'dn42-fpletz' as 4242420235;
};

protocol bgp jomat from dnpeers {
  neighbor fe80::1 % 'dn42-jomat' as 64773;
};

protocol bgp chaossbg from dnpeers {
  neighbor fe80::1 % 'dn42-chaossbg' as 4242421420;
};
      '';
    };

  services.quicktun = {
    "dn42-fpletz" = {
      protocol = "nacltai";
      tunMode = 1;
      remoteAddress = "2a01:4f8:161:23c1::2";
      localAddress = "2001:608:a01::1";
      localPort = 42000;
      remotePort = 42000;
      privateKey = "e7160476fd327cce3016b3f63cae875f808ad0b6c4d31b73641e1e1f881b8a0c"; # b35fb729e209fe5a077d74695da3ecfe577d9168d88b1a47b68580bcb4441937
      publicKey = "53cc53f3a6719314615e1e7fc303134db3e912c419f0587aab1fb6c35e94ef5b";
      upScript = ''
        ${pkgs.iproute}/bin/ip addr replace 10.80.32.13 peer 172.23.214.1 dev dn42-fpletz
        ${pkgs.iproute}/bin/ip addr replace fe80::2/64 dev dn42-fpletz
        ${pkgs.iproute}/bin/ip link set dn42-fpletz up
      '';
    };
    "dn42-jomat" = {
      protocol = "nacltai";
      tunMode = 1;
      remoteAddress = "2a02:180:a:62:ffff:ffff:ffff:fffb";
      localAddress = "2001:608:a01::1";
      localPort = 42001;
      remotePort = 42001;
      privateKey = "73bda6ec1d8cb10f2e2ff14ce8a3bec5c555cbb9905ffd30abb457580b1b478e"; # 3f46ac44ac4f0014c0a942879ad42b7a1bf40abbb2fa5a3f27a2a9ca364c9331
      publicKey = "9692bf40e029fa39368f03b0c3348605c20cd1acc74a4d3643ce219e7e39c00c";
      upScript = ''
        ${pkgs.iproute}/bin/ip addr replace 10.80.32.13 peer 172.23.216.242 dev dn42-jomat
        ${pkgs.iproute}/bin/ip addr replace fe80::2/64 dev dn42-jomat
        ${pkgs.iproute}/bin/ip link set dn42-jomat up
      '';
    };
    "dn42-chaossbg" = {
      protocol = "nacltai";
      tunMode = 1;
      remoteAddress = "2a02:180:1:1::517:f77";
      localAddress = "2001:608:a01::1";
      localPort = 42002;
      remotePort = 42002;
      privateKey = "86cfd964fc2768f4c178272514b4126a582fea1340f9ea1dc07ae2e598af6473"; # c4ba473e7454475f95c4b4d7b6b2c75c54376ad2eb96cb296b6b602b3b4d816b
      publicKey = "8def7bdbfb32d4efb47c4adca8a0bce477207a4d07a222333f5a63ffffbd2053";
      upScript = ''
        ${pkgs.iproute}/bin/ip addr replace 10.80.32.13 peer 172.23.171.30 dev dn42-chaossbg
        ${pkgs.iproute}/bin/ip addr replace fe80::2/64 dev dn42-chaossbg
        ${pkgs.iproute}/bin/ip link set dn42-chaossbg up
      '';
    };
  };

  services.openvpn.servers.airvpn = secrets.openvpn.airvpn;
  services.openvpn.servers.dn42-ffm-ixp = secrets.openvpn.dn42-ffm-ixp;
  services.openvpn.servers.dn42-ixp-nl-zuid = secrets.openvpn.dn42-ixp-nl-zuid;

  services.nginx =
    { enable = true;
      virtualHosts = let
        firmware = {
          root = "/srv/firmware.ffmuc.net";
          extraConfig = ''
            autoindex on;
            access_log syslog:server=unix:/dev/log;
          '';
        };
      in {
        "_" = firmware;
        "firmware.ffmuc.net" = firmware // {
          enableSSL = true;
          enableACME = true;
        };
      };
    };

  users.extraUsers.root.password = secrets.rootPassword;
}

