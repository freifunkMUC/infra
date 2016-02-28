{ pkgs, lib, ... }:

{
  imports =
    [ <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    ];

  config = {
    boot.loader.grub =
      { enable = true;
        version = 2;
        device = "/dev/vda";
        timeout = 3;
      };

    fileSystems."/" =
      { device = "/dev/vg0/nixos";
        fsType = lib.mkDefault "xfs";
      };
  };
}
