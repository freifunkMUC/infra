{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> { inherit system; };

  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = rec {
    libuecc = callPackage ./pkgs/libuecc { };

    ecdsautils = callPackage ./pkgs/ecdsautils { };

    fastd = callPackage ./pkgs/fastd { };

    fastd-fpletz = callPackage ./pkgs/fastd/fpletz.nix { };
  };
in
self

