{ config, pkgs, ... }:

{
  imports = [
    ../modules/default.nix
    ../modules/gateway.nix
  ];

  gateway = {
    baseMacAddress = "80:00:01:23:42";
    bridgeInterface = {
      ip4 = [ { address = "10.80.0.11"; prefixLength = 19; } ];
      ip6 = [ { address = "fdef:ffc0:4fff::11"; prefixLength = 64; } ];
    };
    dhcpRanges = [ "10.80.1.0,10.80.7.255,255.255.224.0,1h" ];
    # fastd public: cc702a59de69623c2bb759a3c9dcac19c24e3ca597387b8463f8d130a6f640c0
    fastdSecret = "f026925227659628400350407340eef4e155d0db1fd85d41c9f86764cba91c6a";
    graphite = { host = "localhost"; port = 2003; };
  };

  networking = {
    hostName = "testgw";
  };

  users.extraUsers.root.password = "";
}

