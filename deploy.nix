{
  network.description = "ffmuc network";

  isartor = { config, pkgs, ... }:
    {
      deployment = {
        targetEnv = "none";
        targetHost = "isartor.ffmuc.net";
      };

      require = [ ./hosts/isartor.nix ];
    };

  stachus = { ... }:
    {
      deployment = {
        targetEnv = "none";
        targetHost = "195.30.94.61";
      };

      require = [ ./hosts/stachus.nix ];
    };
}

