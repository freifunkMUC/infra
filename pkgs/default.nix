{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> { inherit system; };

  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = rec {
    libuecc = callPackage ./libuecc { };

    ecdsautils = callPackage ./ecdsautils { };

    fastd = callPackage ./fastd { };
  };

in self
