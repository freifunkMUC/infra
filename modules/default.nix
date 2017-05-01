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
        kernelPackages = pkgs.linuxPackages_4_10;
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
