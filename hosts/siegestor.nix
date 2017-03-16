{ config, lib, pkgs, ... }:

let
  secrets = (import ../secrets) { inherit pkgs; };
in
{
  imports = [
    ../modules/default.nix
    ../modules/physical.nix
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.devices = [ "/dev/disk/by-id/scsi-3600508e00000000046d5bc3c9035cb0f" ];

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "mptsas" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" "sg" ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/6d2e635b-3d4f-44ab-9f7b-93519ebbeba5";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/8EB6-736E";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/40ad9f64-4f8b-4e36-a8c2-7c38b856b4b5"; }
    ];

  nix.maxJobs = lib.mkDefault 24;
  nix.extraOptions = ''
    build-cores = 24
  '';

  networking = {
    hostName = "siegestor";

    firewall.allowedTCPPorts = [ 80 443 ];

    useDHCP = true;
    dhcpcd.allowInterfaces = [ "vlan-foo-uplink" ];

    interfaces.vlan-transfer = {
      ip4 = [ { address = "195.30.94.29"; prefixLength = 29; } ];
      ip6 = [
        { address = "2001:608:a01::29"; prefixLength = 64; }
      ];
    };

    defaultGateway.address = "195.30.94.30";
    defaultGateway.metric = 512;
    defaultGateway6.address = "2001:608:a01::ffff";
    defaultGateway6.metric = 2048;
    nameservers = [ "2001:608:a01::53" ];

    bonds.bond0 = {
      interfaces = [
        "eno1" "eno2" "eno3" "eno4"
        "enp4s0f0" "enp4s0f1" "enp5s0f0" "enp5s0f1"
      ];
      mode = "802.3ad";
      lacp_rate = "fast";
      miimon = 100;
      xmit_hash_policy = "layer3+4";
    };

    vlans = {
      vlan-mgmt = {
        id = 2;
        interface = "bond0";
      };
      vlan-transfer = {
        id = 3;
        interface = "bond0";
      };
      vlan-service = {
        id = 4;
        interface = "bond0";
      };
      vlan-foo-uplink = {
        id = 420;
        interface = "bond0";
      };
    };
  };

  services.smartd.devices = [
    { device = "/dev/sg0"; }
    { device = "/dev/sg1"; }
  ];

  services.nginx = {
    enable = true;
    virtualHosts = {
      "siegestor.ffmuc.net" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/.metrics/node/" = {
            proxyPass = "http://[::1]:9100/";
          };
        };
      };
    };
  };

  users.extraUsers.root.password = secrets.rootPassword;
}

