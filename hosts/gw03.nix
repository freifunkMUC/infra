{ config, pkgs, ... }:

let
  secrets = (import ../secrets);
in

{
  imports = [
    ../modules/default.nix
    ../modules/smartos-kvm.nix
    ../modules/gateway.nix
  ];

  gateway = {
    baseMacAddress = "80:00:03:23:42";
    bridgeInterface = {
      ip4 = [ { address = "10.80.32.13"; prefixLength = 19; } ];
      ip6 = [ { address = "fdef:ffc0:4fff::13"; prefixLength = 64; } ];
    };
    dhcpRanges = [ "10.80.34.0,10.80.43.255,255.255.224.0,1h" ];
    fastdSecret = secrets.fastd.gw03.secret;
    graphite = secrets.stats.bpletza;
  };

  networking = {
    hostName = "gw03.ffmuc.net";
    interfaces.enp0s3 = {
      ip6 = [
        { address = "2001:608:a01:1:ffff::1"; prefixLength = 64; }
      ];
    };
    defaultGateway6 = "2001:608:a01:1::1";
  };

  services.openvpn.servers = secrets.openvpn;

  users.extraUsers.root.password = secrets.rootPassword;
}

