{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> { inherit system; };

  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = rec {
    ecdsautils = callPackage ./ecdsautils { };

    fastd = callPackage ./fastd { };

    hopglass-server = callPackage ./hopglass-server { };

    icvpn-bird = callPackage ./icvpn-bird { };

    libuecc = callPackage ./libuecc { };
  };

in self
