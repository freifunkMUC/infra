{ pkgs, lib, ... }:

{
  config = {

    time.timeZone = "UTC";

    boot =
      { kernel.sysctl =
          { "net.ipv6.conf.default.autoconf" = 0;
            "net.ipv6.conf.all.autoconf" = 0;
            "vm.overcommit_memory" = 1;
            "kernel.panic" = 1;
          };
        tmpOnTmpfs = true;
        kernelPackages = pkgs.linuxPackages_4_11;
        loader =
          { timeout = lib.mkDefault 1;
            grub.splashImage = null;
            grub.version = lib.mkDefault 2;
          };
      };

    networking =
      { domain = lib.mkDefault "ffmuc.net";
        firewall.allowPing = true;
        wireless.enable = lib.mkDefault false;
      };

    services =
      { atd.enable = false;
        nscd.enable = false;
        udisks2.enable = false;

        haveged.enable = lib.mkDefault true;

        ntp.enable = false;
        timesyncd.enable = false;
        chrony =
          { enable = true;
            servers =
              [ "0.de.pool.ntp.org"
                "1.de.pool.ntp.org"
                "2.de.pool.ntp.org"
                "3.de.pool.ntp.org"
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

        fail2ban.enable = true;

        journald.extraConfig =
          ''
            MaxFileSec=1day
            MaxRetentionSec=1week
          '';

        nginx =
          { package = pkgs.nginxMainline;
            recommendedOptimisation = true;
            recommendedTlsSettings = true;
            recommendedGzipSettings = true;
            recommendedProxySettings = true;
          };

        prometheus.nodeExporter =
          { enable = true;
            enabledCollectors =
              [ "conntrack"
                "diskstats"
                "entropy"
                "filefd"
                "filesystem"
                "loadavg"
                "interrupts"
                "meminfo"
                "netdev"
                "netstat"
                "sockstat"
                "stat"
                "time"
                "uname"
                "vmstat"
                "systemd"
                "logind"
              ];
            port = 9100;
          };
    };

    environment.systemPackages = with pkgs;
      [ vim htop git ethtool python3 perf-tools unzip traceroute
        tcpdump iptables jnettop iotop nmap rsync dstat wget
        rxvt_unicode.terminfo f2fs-tools strace mtr lsof tmux
        screen pciutils dnsutils
      ];

    programs.bash.enableCompletion = true;

    hardware.pulseaudio.enable = false;

    fonts.fontconfig.enable = false;

    security =
      { polkit.enable = false;
        rngd.enable = lib.mkDefault false;
      };

    users.mutableUsers = false;
    users.extraUsers.root.password = lib.mkDefault "";
    users.extraUsers.root.openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK20Lv3TggAXcctelNGBxjcQeMB4AqGZ1tDCzY19xBUV fpletz"
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5PD0xVViVQd5qgE2E4iC8ZWLIg8rmhz1Zb7NJgcA/uwvLTsc1aNW5c16qVWQot37EMHTeh1emr6C0oqNXSOsLWlOfcIHuV/QlVFhxiFZjCv/MWenb2US0mS9po7OS1v+zDAfotb2uUf2MPuaOEcnzToCUu4fa2Guh6YqislWfdFJRbA6rHZtWR48t1cJjhYI5KuF4Y2ef3yMDohTBXcA+oy8rKEfrCJuUaxzqlJPzKRsu1i0mooOvIehBUxAecmRBruBnamTf2NYestshazVkFKnUFf9gk25t6dVuT4UiMjBZdT6lqlbyW+RUtJTa6t65oUj4WfSp9Qt5GS172Ko0w== ruebezahl"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8t+oNAichactROH7TkbzkY7X4rb/+uu2ZdczFw8ash7JJD7bayH/RbSQ4yMae0jByU4ZMj+WyUDwX01FRXId4qkDSI9ggYF6DIsjDw01Xe+CXkihbdgMGTgDfKj11VJag8ADebl6Iw19kUxjqGFDvA7dfOSLfV8yZ4QdUF4MZ4tzSN15Uq/zWE6rz88MbfMDfZgyf30iJ8/FUisSkOFlST7PeKdZEoTFerJMgSXwaJU/MWhn6NJmVt0Yeg8wUr0JgfsS9q77NGmrXz+taeRLfq9L1AdsA95o2kyldLDwzc22ONq5yv47ipSvhQxcAt1E4NNiO4/SzwN/C3k44U8T3 Luke6@SpaceNet"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8GeD2forY/XcRoXgwd8FB+SABLM5HZ3TOPWSykKf6EbLp3HExLycqHmQcv8a/T6/jI0pWVtEmJzot26L0APUDVMIeEQKoAh+OMJQ1XU7N3Q9T85YwPSNXOcyrtBg86vOz7rKM4RTO+CDI7DfQ+l/2CSRV0djTt49XpGnF4bmKtZ5KkLwQGtktf5ZlNROj5NOjwzIFxRrxGkQFX+KpIAu9j6Lw43iIsLO1+TO8BfS050JLPAtU+3KIC+Y9sYCSGb3kehx9wRVBYL6fLcpRK7X+Y65+zfxT7ZTBpGOOT/oM6IHl3bYfgWGjRDcwkHlezzzFl8g+cbNSCF7d9KXsga4B MatthiasKesler@krombel"
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAvLqxeheXIbcmqJzxju4MU00JpDH9MTprNWP9qEG66oJZ1C5ONjGWqxurdhoujvEUhIGBCu4WpSs1aHEVv4KvQmGyXmVt+/GeSiLJIOPPrCwUhYvHfQXmEdY/qOl9RnBWp0qvl6pLv84Py549w+h3DKuwS5WmD1tNo9lJSIRcxmiBdzvpIhn2uAIsyBgXn6DnC7fyaZmsSrrrw82gDmOWlzeb6KNundgV8d04glwToM9d2V4A16g1FJt2Lta8EvK4TgNA+BkizadO5JcQ5Lf+aaN2dUk685a4V+yht9o6wjssnXl820mEIDkLTJf2qe4owSg87lGD52lhzQHWcjvEVQ== Raffaello Brecht@virtual"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXV8SNB8SR05F3xZcNrVeBcvUcd2COnmvU2BXvYmpr6qUnF+rtjn16ap7x2brimiHSp5gwvS1Ntkl5JAsDETTR44yTDEqMrJi9SGKTcDvsnCxcLLTgUjeIKdboPGnslaT8NM1Y1rct9j5XBGq5ITZIL/TU77YXz+co/MT9mVBc3jmdeUIRP08rqjbrsBaJ90khaoyx7axhaymrxCvg8FVe4oMDqXjEAq3AWoltvtHsgXVnEOj50KLyLydwVI4gJfH44Y/sMbBIQaNHF2oKBsmvnMecQcsnOhx337L5TqLJOBWbGm+YQcbQZIHSqRke3v+a511A6ZTwJnB+76YVXkI1 AnnikaWickert@awlnx"
        "ssh-dss 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 pkoerner"
      ];

    i18n =
      { consoleKeyMap = "us";
        defaultLocale = "en_US.UTF-8";
        supportedLocales = [ "en_US.UTF-8/UTF-8" ];
      };

    sound.enable = false;

    nix =
      { gc =
          { automatic = true;
            options = "--delete-older-than 2d";
          };
        binaryCaches =
          [ "https://hydra.mayflower.de/"
          ];
        binaryCachePublicKeys =
          [ "hydra.mayflower.de:9knPU2SJ2xyI0KTJjtUKOGUVdR2/3cOB4VNDQThcfaY="
          ];
      };
  };
}
