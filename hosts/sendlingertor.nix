{ config, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ../modules/default.nix
  ];

  boot.initrd.availableKernelModules = [ "ehci_pci" "megaraid_sas" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelParams = [ "console=ttyS0,115200" ];

  fileSystems."/" =
    { device = "tank/root";
      fsType = "zfs";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/1c7157b2-a418-41ff-af03-9875c72fd712"; }
      { device = "/dev/disk/by-uuid/f9b7e1b3-a32a-4cd6-9a03-0669ad6b8be7"; }
    ];

  nix.maxJobs = 4;

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/sda" "/dev/sdb" ];

  networking.hostId = "109271e3";
  networking.hostName = "sendlingertor";

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    virtualHosts = {
      "sendlingertor.ffmuc.net" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/.metrics/node/" = {
            proxyPass = "http://[::1]:9100/";
          };
          "/prometheus" = {
            proxyPass = "http://[::1]:9090";
          };
        };
      };
    };
  };

  services.prometheus =
    { enable = true;
      extraFlags = [ "-web.external-url=https://sendlingertor.ffmuc.net/prometheus" ];
      scrapeConfigs = [
        { job_name = "hopglass";
          scrape_interval = "60s";
          metrics_path = "/hopglass/data/metrics";
          static_configs = [
            { targets = [
                "isartor.ffmuc.net"
              ];
              labels = { };
            }
          ];
        }
        { job_name = "node";
          scrape_interval = "10s";
          metrics_path = "/.metrics/node/metrics";
          static_configs = [
            { targets = [
                "sendlingertor.ffmuc.net"
              ];
              labels = { alias = "sendlingertor.ffmuc.net"; };
            }
            { targets = [
                "isartor.ffmuc.net"
              ];
              labels = { alias = "isartor.ffmuc.net"; };
            }
          ];
        }
       ];
      nodeExporter = {
        enable = true;
        enabledCollectors = [
          "conntrack"
          "diskstats"
          "entropy"
          "filefd"
          "filesystem"
          "loadavg"
          "interrupts"
          "meminfo"
          "netdev"
          "netstat"
          "sockstat"
          "stat"
          "time"
          "uname"
          "vmstat"
        ];
        port = 9100;
      };
    };

}
