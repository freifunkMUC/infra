(import ./release.nix {
  onlySystem = false;
  extraModules = [ ./modules/qemu-test.nix ];
}).testgw
