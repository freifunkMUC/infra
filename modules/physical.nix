{ pkgs, ... }:

{
  config = {

    environment.systemPackages = with pkgs; [
      ipmitool lm_sensors smartmontools
    ];

    services.postfix =
      { enable = true;
        rootAlias = "fpletz@bpletza.de";
      };

    services.smartd =
      { enable = true;
        notifications =
          { test = true;
          };
      };

    services.irqbalance.enable = true;
    security.rngd.enable = true;

    powerManagement =
      { enable = true;
        cpuFreqGovernor = "ondemand";
      };

    hardware.firmware = with pkgs; [ firmwareLinuxNonfree ];

  };
}
