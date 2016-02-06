{ pkgs, ... }:
{
  time.timeZone = "UTC";

  boot =
    { kernel.sysctl."net.ipv6.conf.default.autoconf" = 0;
      kernel.sysctl."net.ipv6.conf.all.autoconf" = 0;
      tmpOnTmpfs = true;
      kernelPackages = pkgs.linuxPackages_latest;
    };

  networking.firewall.allowPing = true;
  networking.wireless.enable = false;

  services =
    { atd.enable = false;
      nscd.enable = false;
      udisks2.enable = false;
      haveged.enable = true;

      ntp.enable = false;
      chrony =
        { enable = true;
          servers =
            [ "0.de.pool.ntp.org"
              "1.de.pool.ntp.org"
            ];
        };

      openssh =
        { enable = true;
          hostKeys =
            [ { type = "ed25519";
                path = "/etc/ssh/ssh_host_ed25519_key";
                bits = 256;
              }
              { type = "rsa";
                path = "/etc/ssh/ssh_host_rsa_key";
                bits = 2048;
              }
            ];
        };
    };

  security =
    { polkit.enable = false;
      rngd.enable = false;
    };

  i18n =
    { consoleKeyMap = "us";
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [ "en_US.UTF-8/UTF-8" ];
    };

  nix =
    { extraOptions =
        ''
          auto-optimise-store = true
        '';
    };
}
