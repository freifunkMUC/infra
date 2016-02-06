{ pkgs, ... }:

{

  imports =
    [ <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    ];

  boot.loader.grub =
    { enable = true;
      version = 2;
      device = "/dev/vda";
      timeout = 0;
    };

  fileSystems."/" =
    { device = "/dev/vda1";
      fsType = "ext4";
    };

}
