{ nixpkgs ? <nixpkgs>, onlySystem ? true, extraModules ? [] }:

let

  nixos = import "${nixpkgs}/nixos";

  buildEnv = conf: (nixos {
    configuration = conf;
  });
  buildTarget = m: let build = buildEnv (buildConf m); in
    if onlySystem then build.system else build.vm;

  buildConf = module: { ... }:
    {
      imports = [ module ] ++ extraModules;
    };

in

{
  testgw = buildTarget ./hosts/testgw.nix;
}
