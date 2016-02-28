{ config, pkgs, ... }:

let
  secrets = (import ../secrets);
in
{
  imports = [
    ../modules/default.nix
    ../modules/smartos-kvm.nix
  ];

  fileSystems."/".fsType = "ext4";

  networking = {
    dhcpcd = {
      denyInterfaces = [ "tinc.backbone" ];
    };
    firewall = {
      enable = false;
    };
    hostName = "stachus";
    interfaces.enp0s3 = {
      ip6 = [
        { address = "2001:608:a01:1::2"; prefixLength = 64; }
      ];
    };
    defaultGateway6 = "2001:608:a01:1::1";
   };

   environment.systemPackages = with pkgs; [
     tinc_pre babeld
   ];

  services = {
    tinc.networks = {
      backbone = {
        package = pkgs.tinc_pre;
        interfaceType = "tap";
        extraConfig = ''
          Mode = switch
          ExperimentalProtocol = yes
        '';
      };
    };
    collectd = {
      enable = true;
      package = pkgs.collectdMinimal;
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

        <Plugin interface>
          Interface "lo"
          IgnoreSelected true
        </Plugin>

        <Plugin write_graphite>
          <Node "${secrets.stats.bpletza.host}">
            Host "${secrets.stats.bpletza.host}"
            Port "${toString secrets.stats.bpletza.port}"
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

  systemd.services = {
    babeld = let
      babeldConf = pkgs.writeText "babeld.conf" ''
        redistribute ip ::/0 le 0 proto 3 metric 128
        redistribute ip 2001:608:a01::/48 le 127 metric 128
        redistribute local deny
        redistribute deny
        in ip 0.0.0.0/32 le 0 deny
        in ip ::/128 le 0 deny
      '';
      in {
        description = "Babel routing daemon";
        wantedBy = [ "network.target" "multi-user.target" ];
        after = [ "tinc.backbone" ];
        serviceConfig = {
          ExecStart =
            "${pkgs.babeld}/bin/babeld -c ${babeldConf} tinc.backbone";
        };
      };
  };
}

