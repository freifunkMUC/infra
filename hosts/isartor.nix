{ config, pkgs, ... }:

let
  secrets = (import ../secrets) { inherit pkgs; };
  ffpkgs = (import ../pkgs/default.nix) { };
in

{
  imports = [
    ../modules/default.nix
    ../modules/physical.nix
    ../modules/gateway.nix
  ];

  hardware.enableAllFirmware = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "uhci_hcd" "usbhid" "usb_storage" "sd_mod" "sr_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ jool ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/d0ca21c6-f0b7-46a2-8e48-572156dabd44";
      fsType = "btrfs";
    };

  nix.maxJobs = 4;

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  containers.unbound-dns64 = {
    autoStart = true;
    privateNetwork = false;
    config = { ... }: {
      services.unbound =
        { enable = true;
          allowedAccess = [ "::1" "127.0.0.1" "::/0" "0.0.0.0/0" ];
          interfaces = [ "2001:608:a01:bfff::1" ];
          extraConfig = ''
            server:
              port: 53
              num-threads: 8
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
              log-queries: no
              module-config: "dns64 validator iterator"
              dns64-prefix: 2001:608:a01:0:64:ff9b::/96  # transfer-netz von space

            include: ${ffpkgs.icvpn-bird}/unbound.conf
          '';
        };
      };
  };


  freifunk.gateway = {
    enable = true;
    externalInterface = "eno2";
    ip4Interfaces = [ "tun0" "eno2" ];
    ip6Interface = "eno2";
    networkingLocalCommands = ''
      ip rule del priority 30 || true
      ip rule add priority 30 from 195.30.94.49/32 lookup 5
      ip route replace default via 195.30.94.30 table 5
      ip route replace 195.30.94.48/28 via 195.30.94.26 table 5
      ip route replace 195.30.94.24/29 dev eno2 table 5
      ip route replace 195.30.94.48/28 via 195.30.94.26 table 42
      ip route replace 195.30.94.24/29 dev eno2 table 42

      ${pkgs.ethtool}/bin/ethtool --offload eno2 gro off
      ${pkgs.kmod}/bin/modprobe jool pool6=2001:608:a01:0:64:ff9b::/96
    '';
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
        ra.rdnss = [ "2001:608:a01::53" ];
        meshInterfaces = [ "ffmuc-mesh" ];
        fastdConfigs = let
          secret = secrets.fastd.gw03.secret;
          listenAddresses = [ "195.30.94.27" "[2001:608:a01::1]" ];
          cpuaffinity = "1-2";
        in {
          backbone = {
            inherit secret listenAddresses;
            listenPort = 9999;
            mtu = 1426;
            cpuaffinity = "0";
          };
          mesh0 = {
            inherit secret listenAddresses;
            listenPort = 10000;
            mtu = 1426;
            cpuaffinity = "2";
          };
          mesh1 = {
            inherit secret listenAddresses;
            listenPort = 10099;
            mtu = 1426;
            cpuaffinity = "2";
          };
          mesh2 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 10001;
            mtu = 1280;
          };
          mesh3 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 10098;
            mtu = 1280;
          };
        };
        portBalancings = [
          { from = 10000; to1 = 10000; to2 = 10099; }
          { from = 10001; to1 = 10001; to2 = 10098; }
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
        ra.rdnss = [ "2001:608:a01::53" ];
        meshInterfaces = [ "welcome-mesh" ];
        fastdConfigs = let
          secret = secrets.fastd.gwf02.secret;
          listenAddresses = [ "195.30.94.27" "[2001:608:a01::1]" ];
          cpuaffinity = "2";
        in {
          mesh0 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 11000;
            mtu = 1426;
          };
          mesh1 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 11099;
            mtu = 1426;
          };
          mesh2 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 11001;
            mtu = 1280;
          };
          mesh3 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 11098;
            mtu = 1280;
          };
        };
        portBalancings = [
          { from = 11000; to1 = 11000; to2 = 11099; }
          { from = 11001; to1 = 11001; to2 = 11098; }
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
        ra.rdnss = [ "2001:608:a01::53" ];
        meshInterfaces = [ "umland-mesh" ];
        fastdConfigs = let
          secret = secrets.fastd.gwu02.secret;
          listenAddresses = [ "195.30.94.27" "[2001:608:a01::1]" ];
          cpuaffinity = "2-3";
        in {
          mesh0 = {
            inherit secret listenAddresses;
            listenPort = 10011;
            mtu = 1426;
            cpuaffinity = "2";
          };
          mesh1 = {
            inherit secret listenAddresses;
            listenPort = 10089;
            mtu = 1426;
            cpuaffinity = "2";
          };
          mesh3 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 10015;
            mtu = 1280;
          };
          mesh4 = {
            inherit secret listenAddresses cpuaffinity;
            listenPort = 10085;
            mtu = 1280;
          };
        };
        portBalancings = [
          { from = 10011; to1 = 10011; to2 = 10089; }
          { from = 10015; to1 = 10015; to2 = 10085; }
        ];
      };
     };
  };

  networking = {
    hostName = "isartor";
    interfaces.eno2 = {
      ip4 = [ { address = "195.30.94.27"; prefixLength = 29; } ];
      ip6 = [
        { address = "2001:608:a01::1"; prefixLength = 64; }
        { address = "2001:608:a01::53"; prefixLength = 64; }
      ];
    };
    interfaces.vlan-service = {
      ip4 = [ { address = "195.30.94.49"; prefixLength = 28; } ];
      ip6 = [ { address = "2001:608:a01:1::2"; prefixLength = 64; } ];
    };
    interfaces."tinc.icvpn" = {
      ip4 = [ { address = "10.207.1.80"; prefixLength = 16; } ];
      ip6 = [ { address = "fec0::a:cf:1:80"; prefixLength = 96; } ];
    };

    vlans = {
      vlan-service = {
        id = 4;
        interface = "eno1";
      };
      ffmuc-mesh = {
        id = 10;
        interface = "eno1";
      };
      welcome-mesh = {
        id = 11;
        interface = "eno1";
      };
      umland-mesh = {
        id = 12;
        interface = "eno1";
      };
    };

    defaultGateway = "195.30.94.30";
    defaultGateway6 = "2001:608:a01::ffff";
    nameservers = [ "2001:608:a01::53" ];

    firewall.allowedTCPPorts = [ 80 443 655 ];
    firewall.allowedUDPPorts = [ 123 10100 655 42000 42001 42002 42003 42004 42005 547 ];
    firewall.extraCommands = ''
      ip6tables -I nixos-fw 3 -i fastd-babel -m pkttype --pkt-type multicast -j nixos-fw-accept
      ip46tables -I FORWARD 1 -i br-+ -o tinc.icvpn -j ACCEPT
      ip46tables -I FORWARD 1 -i tinc.icvpn -o br-+ -j ACCEPT
      ip46tables -I FORWARD 1 -i br-+ -o dn42-+ -j ACCEPT
      ip46tables -I FORWARD 1 -i dn42-+ -o br-+ -j ACCEPT
      ip46tables -I FORWARD 1 -i tinc.icvpn -o dn42-+ -j ACCEPT
      ip46tables -I FORWARD 1 -i dn42-+ -o tinc.icvpn -j ACCEPT
      ip46tables -I FORWARD 1 -i dn42-+ -o dn42-+ -j ACCEPT

      # main dns recursor and cache for infrastructure
      ip6tables -I nixos-fw 3 -s 2001:608:a01::/48 -d 2001:608:a01::53 -p udp --dport 53 -j nixos-fw-accept
      ip6tables -I nixos-fw 3 -s 2001:608:a01::/48 -d 2001:608:a01::53 -p tcp --dport 53 -j nixos-fw-accept

      # hopglass
      ip6tables -I nixos-fw 3 -i br-+ -p udp --dport 45123 -j nixos-fw-accept

      # bogus node with ffhh firmware
      ip6tables -I nixos-fw 1 -s fe80::62e3:27ff:feee:213e/128 -i br-ffmuc -j DROP
    '';
  };

   environment.systemPackages = with pkgs; [
     tinc_pre babeld jool-cli
   ];

  systemd.services = {
    hopglass-server = {
      description = "hopglass server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      preStart = ''
        mkdir -p /var/lib/hopglass-server
        chown -R nobody:nogroup /var/lib/hopglass-server

        cat << EOF > /var/lib/hopglass-server/config.json
        {
          "receiver": {
            "receivers": [
              { "module": "announced",
                "config": {
                  "target": { "ip": "ff02::2:1001" },
                  "port": 45123,
                  "interval": {
                    "statistics": 60,
                    "nodeinfo": 300
                  }
                }
              }
            ],
            "ifaces": [
              "br-ffmuc",
              "br-umland",
              "br-welcome",
              "fastd-babel"
            ],
            "storage": {
              "file": "./raw.json"
            },
            "purge": {
              "maxAge": 14
            }
          },
          "provider": {
            "offlineTime": 600
          },
          "webserver": {
            "ip": "::1",
            "port": 4000
          }
        }
        EOF
      '';
      serviceConfig = {
        User = "nobody";
        Group = "nogroup";
        WorkingDirectory = "/var/lib/hopglass-server";
        PermissionsStartOnly = true;
        ExecStart = "${ffpkgs.hopglass-server.package}/lib/node_modules/hopglass-server/hopglass-server.js";
        CPUAffinity = "0";
      };
    };

    openvpn-airvpn.serviceConfig.CPUAffinity = "0";

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
        in ip 0.0.0.0/0 le 0 deny
        in ip ::/0 le 0 deny
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

    kea-dhcp6 = let
      keaConf = pkgs.writeText "kea6.json" ''
        {
          "Dhcp6":
            {
              "control-socket": {
                "socket-type": "unix",
                "socket-name": "/run/kea-dhcp6.socket"
              },

              "interfaces-config": {
                "interfaces": [ "br-ffmuc", "br-umland", "br-welcome" ]
              },

              "option-data": [
                { "name": "dns-servers",
                  "data": "2001:608:a01::53"
                },
                { "name": "domain-search",
                  "data": "ffmuc.net"
                },
                { "name": "sntp-servers",
                  "data": "fdef:ffc0:4fff::131"
                }
              ],

              "lease-database": { "type": "memfile" }
            },

          "Logging": {
            "loggers": [ {
              "name": "kea-dhcp6",
              "output_options": [
                { "output": "stdout" }
              ],
              "severity": "INFO"
            } ]
          }
        }
      '';
      in {
        description = "Kea DHCPv6 daemon";
        wantedBy = [ "multi-user.target" ];
        preStart = ''
          mkdir -p /var/run/kea /var/kea
        '';
        serviceConfig = {
          RestartSec = "5s";
          ExecStart = "${pkgs.kea}/bin/kea-dhcp6 -c ${keaConf}";
        };
      };
  };

  services.dhcpd6 =
    { enable = true;
      interfaces = [ "fastd-babel" ];
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

  services.tinc.networks.icvpn = {
    name = "muenchen1";
    interfaceType = "tap";
    extraConfig = ''
      Mode = switch
      ExperimentalProtocol = no
      ConnectTo = berlin2
      ConnectTo = darmstadt4
      ConnectTo = luebeck2
      ConnectTo = trier1
      ConnectTo = hamburg03
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

roa table dn42_roa {
  include "${../static/bird_roa_dn42.conf}";
  include "${ffpkgs.icvpn-bird}/roa4";
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

protocol direct {
  interface "br-*";
}

template bgp dnpeers {
  local as OWNAS;
  path metric 1;
  missing lladdr ignore;
  import keep filtered;
  import filter {
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_INVALID) then {
      print "[", proto, "] ROA check invalid for ", net, " ASN ", bgp_path.last;
      reject;
    }
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_UNKNOWN) then {
      print "[", proto, "] ROA check unknown for ", net, " ASN ", bgp_path.last;
      reject;
    }
    if !is_self_net() then {
      accept;
    }
    print "[", proto, "] rejected invalid route ", net, " ASN ", bgp_path.last;
    reject;
  };
  export filter {
    #if is_valid_network() then {
      accept;
    #}
    #reject;
  };
  route limit 10000;
}

template bgp icpeers from dnpeers {
  import filter {
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_INVALID) then {
      print "[", proto, "] ROA check invalid for ", net, " ASN ", bgp_path.last;
      reject;
    }
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_UNKNOWN) then {
      print "[", proto, "] ROA check unknown for ", net, " ASN ", bgp_path.last;
      reject;
    }
    gw = from;
    if !is_self_net() then {
      accept;
    }
    print "[", proto, "] rejected invalid route ", net, " ASN ", bgp_path.last;
    reject;
  };
}

protocol bgp dn42_fpletz from dnpeers {
  neighbor 172.23.214.1 as 4242420235;
};

protocol bgp dn42_jomat from dnpeers {
  neighbor 172.23.216.242 as 64773;
};

protocol bgp dn42_chaossbg from dnpeers {
  neighbor 172.23.171.30 as 4242421420;
};

protocol bgp AS4242421340 from dnpeers {
  neighbor 172.20.176.1 as 4242421340;
};

#protocol bgp AS4242420330 from dnpeers {
#  neighbor 172.20.182.1 as 4242420330;
#};

protocol bgp dn42_twink0r from dnpeers {
  neighbor 172.20.11.1 as 4242421339;
}

protocol bgp dn42_fbnw from dnpeers {
  neighbor 172.22.78.30 as 4242423955;
}

protocol bgp dn42_w0h from dnpeers {
  neighbor 172.22.232.1 as 4242420013;
}

include "${ffpkgs.icvpn-bird}/peers4";
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

roa table dn42_roa {
  include "${../static/bird6_roa_dn42.conf}";
  include "${ffpkgs.icvpn-bird}/roa6";
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

protocol direct {
  interface "br-*";
}

template bgp dnpeers {
  local as OWNAS;
  path metric 1;
  missing lladdr ignore;
  import keep filtered;
  import filter {
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_INVALID) then {
       print "[", proto, "] ROA check invalid for ", net, " ASN ", bgp_path.last;
       reject;
    }
    if (roa_check(dn42_roa, net, bgp_path.last) = ROA_UNKNOWN) then {
      print "[", proto, "] ROA check unknown for ", net, " ASN ", bgp_path.last;
      reject;
    }
    if !is_self_net() then {
      accept;
    }
    print "[", proto, "] rejected invalid route ", net, " ASN ", bgp_path.last;
    reject;
  };
  export filter {
    #if is_valid_network() then {
      accept;
    #}
    #reject;
  };
  route limit 10000;
}

template bgp icpeers from dnpeers { }

protocol bgp dn42_fpletz from dnpeers {
  neighbor fe80::1 % 'dn42-fpletz' as 4242420235;
};

protocol bgp dn42_jomat from dnpeers {
  neighbor fe80::1 % 'dn42-jomat' as 64773;
};

protocol bgp dn42_chaossbg from dnpeers {
  neighbor fe80::1 % 'dn42-chaossbg' as 4242421420;
};

protocol bgp dn42_twink0r from dnpeers {
  neighbor fe80::1 % 'dn42-twink0r' as 4242421339;
}

protocol bgp dn42_fbnw from dnpeers {
  neighbor fe80::2 % 'dn42-fbnw' as 4242423955;
}

protocol bgp dn42_w0h from dnpeers {
  neighbor fe80::7fc9 % 'dn42-w0h' as 4242420013;
}

include "${ffpkgs.icvpn-bird}/peers6";
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
      privateKey = secrets.quicktun.fpletz;
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
      privateKey = secrets.quicktun.jomat;
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
      privateKey = secrets.quicktun.chaossbg;
      publicKey = "8def7bdbfb32d4efb47c4adca8a0bce477207a4d07a222333f5a63ffffbd2053";
      upScript = ''
        ${pkgs.iproute}/bin/ip addr replace 10.80.32.13 peer 172.23.171.30 dev dn42-chaossbg
        ${pkgs.iproute}/bin/ip addr replace fe80::2/64 dev dn42-chaossbg
        ${pkgs.iproute}/bin/ip link set dn42-chaossbg up
      '';
    };
  };

  services.openvpn.servers.airvpn = secrets.openvpn.airvpn;
  #services.openvpn.servers.dn42-ffm-ixp = secrets.openvpn.dn42-ffm-ixp;
  #services.openvpn.servers.dn42-ixp-nl-zuid = secrets.openvpn.dn42-ixp-nl-zuid;
  services.openvpn.servers.dn42-twink0r = secrets.openvpn.dn42-twink0r;
  services.openvpn.servers.dn42-fbnw = secrets.openvpn.dn42-fbnw;
  services.openvpn.servers.dn42-w0h = secrets.openvpn.dn42-w0h;

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
        "isartor.ffmuc.net" = {
          forceSSL = true;
          enableACME = true;
          root = "/srv/isartor.ffmuc.net";
          locations = {
            "/hopglass/data/" = {
              proxyPass = "http://[::1]:4000/";
            };
            "/.metrics/node/" = {
              proxyPass = "http://[::1]:9100/";
            };
          };
        };
      };
    };

  users.extraUsers.root.password = secrets.rootPassword;
}

