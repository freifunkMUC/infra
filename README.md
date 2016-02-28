# Freifunk München Infrastructure

These are the [NixOS](https://nixos.org) configurations for the main Freifunk München infrastructure.

## Machine configurations

Machines are defined in the `hosts` directory. There is a NixOps deployment available in `deploy.nix`.

You can easily bring up a test gateway locally using qemu with:

    nix-build .
    result/bin/run-testgw-vm

Please ensure you're on the latest unstable or 16.03 nixpkgs channel.

## Packages

Currently packaged:

 * libuecc
 * ecdsautils
 * fastd

You can install packages locally for instance like this:

    nix-env -f pkgs -iA fastd
