{ onlySystem ? true, extraModules ? [] }:

let

  lib = import <nixpkgs/lib>;
  nixos = import <nixpkgs/nixos>;

  buildEnv = conf: (nixos {
    inherit extraModules;
    configuration = conf;
  });
  buildTarget = c: let build = buildEnv c; in
    if onlySystem then build.system else build.vm;

  hosts = import ./hosts;

in

lib.mapAttrs (k: v: buildTarget v) hosts