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

  sendlingertor = { config, pkgs, ... }:
    {
      deployment = {
        targetEnv = "none";
        targetHost = "sendlingertor.ffmuc.net";
      };

      require = [ ./hosts/sendlingertor.nix ];
    };

  siegestor = { config, pkgs, ... }:
    {
      deployment = {
        targetEnv = "none";
        targetHost = "siegestor.ffmuc.net";
      };

      require = [ ./hosts/siegestor.nix ];
    };
}

