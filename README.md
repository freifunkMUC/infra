# Freifunk München Infrastructure

# REPO DEPRECATED AND NO LONGER MAINTAINED

These are the [NixOS](https://nixos.org) configurations for the
infrastructure of Freifunk München.

## Machine configurations

Machines are defined in the `hosts` directory. The production NixOps
deployment is available in `deploy.nix`.

You can easily bring up a test gateway locally using `qemu` with:

    make
    ./result/bin/run-testgw-vm

This will use [mayflower/nixpkgs](https://github.com/mayflower/nixpkgs)
which the production deployment also uses. The main reason for this is
that there are some security enhancements not yet present on upstream
NixOS. It it regularly updated.

All configs should also work with the latest upstream master/17.03 but
is not actively tested against it.

## Secrets

Some configuration options like private keys or vpn configs have to be
private. These are available in a separate repository where the admins
have access.

You can use the folder `secrets-template` as a starting point for your
own `secrets` folder.

## Packages

Currently packaged:

 * libuecc
 * ecdsautils
 * fastd

You can install packages locally for instance like this:

    nix-env -f pkgs -iA fastd
