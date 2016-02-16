{
  network.description = "ffmuc network";

  gw03 = { config, pkgs, ... }:
    {
      deployment = {
        targetEnv = "none";
        targetHost = "195.30.94.49";
      };

      require = [ ./hosts/gw03.nix ];
    };
}

