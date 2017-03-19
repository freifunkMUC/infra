{ config, lib, pkgs, ... }:

let
  secrets = (import ../secrets) { inherit pkgs; };
in
{
  imports = [
    ../modules/default.nix
    ../modules/physical.nix
    ../modules/gateway.nix
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
      ffmuc-mesh = {
        id = 10;
        interface = "bond0";
      };
      welcome-mesh = {
        id = 11;
        interface = "bond0";
      };
      umland-mesh = {
        id = 12;
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

  freifunk.gateway = {
    enable = true;
    isRouter = false;
    externalInterface = "vlan-transfer";

    segments = {
      ffmuc = {
        baseMacAddress = "80:00:04:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.80.32.14"; prefixLength = 19; } ];
          ip6 = [
            { address = "fdef:ffc0:4fff::14"; prefixLength = 64; }
            { address = "2001:608:a01:2::14"; prefixLength = 64; }
          ];
        };
        meshInterfaces = [ "ffmuc-mesh" ];
        fastdConfigs = let
          secret = secrets.fastd.gw04.secret;
          listenAddresses = [ "195.30.94.29" "[2001:608:a01::29]" ];
        in {
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
        baseMacAddress = "80:ff:01:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.80.64.11"; prefixLength = 19; } ];
          ip6 = [
            { address = "fdef:ffc0:4fff:1::11"; prefixLength = 64; }
            { address = "2001:608:a01:3::11"; prefixLength = 64; }
          ];
        };
        meshInterfaces = [ "welcome-mesh" ];
        fastdConfigs = let
          secret = secrets.fastd.gwf01.secret;
          listenAddresses = [ "195.30.94.29" "[2001:608:a01::29]" ];
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
        baseMacAddress = "80:01:01:23:42";
        bridgeInterface = {
          ip4 = [ { address = "10.80.96.11"; prefixLength = 19; } ];
          ip6 = [
            { address = "fdef:ffc0:4fff:2::11"; prefixLength = 64; }
            { address = "2001:608:a01:4::11"; prefixLength = 64; }
          ];
        };
        meshInterfaces = [ "umland-mesh" ];
        fastdConfigs = let
          secret = secrets.fastd.gwu01.secret;
          listenAddresses = [ "195.30.94.29" "[2001:608:a01::29]" ];
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

  users.extraUsers.root.password = secrets.rootPassword;
}

