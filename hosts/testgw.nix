{ config, pkgs, ... }:

{
  imports = [
    ../modules/default.nix
    ../modules/gateway.nix
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];

  boot.loader.grub.devices = [ "/dev/vda" ];

  networking = {
    hostName = "testgw";
    dhcpcd.allowInterfaces = [ "eth0" ];
  };

  fileSystems."/".device = "/dev/vda1";

  freifunk.gateway = {
    enable = true;
    externalInterface = "eth0";
    ip4Interfaces = [ "tun0" "eth0" ];
    ip6Interface = "eth0";
    segments = {
      ffmuc = {
        baseMacAddress = "80:00:01:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.80.0.11"; prefixLength = 19; } ];
          ip6 = [ { address = "fdef:ffc0:4fff::11"; prefixLength = 64; } ];
        };
        dhcpRanges = [ "10.80.1.0,10.80.7.255,255.255.224.0,1h" ];
        fastdConfigs = {
          backbone = {
            listenAddresses = [ "any" ];
            listenPort = 9999;
            mtu = 1428;
            # fastd public: cc702a59de69623c2bb759a3c9dcac19c24e3ca597387b8463f8d130a6f640c0
            secret = "f026925227659628400350407340eef4e155d0db1fd85d41c9f86764cba91c6a";
          };
        };
        portBalancings = [
          { from = 10000; to1 = 10099; to2 = 10098; }
          { from = 10001; to1 = 10097; to2 = 10096; }
        ];
      };
      ffoo = {
        baseMacAddress = "42:00:01:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.81.0.1"; prefixLength = 16; } ];
          ip6 = [ { address = "fdef::1"; prefixLength = 64; } ];
        };
        dhcpRanges = [ "10.81.1.0,10.81.31.255,255.255.0.0,1h" ];
        ra.prefixes = [ "fdef::/64" ];
        ra.rdnss = [ "fdef::1" ];
        fastdConfigs = {
          backbone = {
            listenAddresses = [ "any" ];
            listenPort = 9998;
            mtu = 1428;
            # fastd public: cc702a59de69623c2bb759a3c9dcac19c24e3ca597387b8463f8d130a6f640c0
            secret = "f026925227659628400350407340eef4e155d0db1fd85d41c9f86764cba91c6a";
          };
        };
        portBalancings = [
          { from = 10010; to1 = 10089; to2 = 10088; }
        ];
      };
    };
  };
}
