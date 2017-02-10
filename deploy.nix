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

  stachus = { config, pkgs, ... }:
    {
      deployment = {
        targetEnv = "none";
        targetHost = "83.133.179.119";
      };

      require = [ ./hosts/stachus.nix ];
    };
}

