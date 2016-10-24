{ pkgs, lib, ... }:

{
  config = {

    time.timeZone = "UTC";

    boot =
      { kernel.sysctl."net.ipv6.conf.default.autoconf" = 0;
        kernel.sysctl."net.ipv6.conf.all.autoconf" = 0;
        tmpOnTmpfs = true;
        kernelPackages = pkgs.linuxPackages_4_8;
        loader.grub.splashImage = null;
        loader.grub.version = lib.mkDefault 2;
      };

    networking.domain = lib.mkDefault "ffmuc.net";
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
          { recommendedOptimisation = true;
            recommendedTlsSettings = true;
            recommendedGzipSettings = true;
            recommendedProxySettings = true;
          };
      };

    environment.systemPackages = with pkgs;
      [ vim htop git ethtool python3 perf-tools unzip
        tcpdump iptables jnettop iotop nmap rsync
        rxvt_unicode.terminfo
      ];

    programs.bash.enableCompletion = true;

    hardware.pulseaudio.enable = false;

    fonts.fontconfig.enable = false;

    security =
      { polkit.enable = false;
        rngd.enable = false;
      };

    users.mutableUsers = false;
    users.extraUsers.root.password = lib.mkDefault "";
    users.extraUsers.root.openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK20Lv3TggAXcctelNGBxjcQeMB4AqGZ1tDCzY19xBUV fpletz"
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5PD0xVViVQd5qgE2E4iC8ZWLIg8rmhz1Zb7NJgcA/uwvLTsc1aNW5c16qVWQot37EMHTeh1emr6C0oqNXSOsLWlOfcIHuV/QlVFhxiFZjCv/MWenb2US0mS9po7OS1v+zDAfotb2uUf2MPuaOEcnzToCUu4fa2Guh6YqislWfdFJRbA6rHZtWR48t1cJjhYI5KuF4Y2ef3yMDohTBXcA+oy8rKEfrCJuUaxzqlJPzKRsu1i0mooOvIehBUxAecmRBruBnamTf2NYestshazVkFKnUFf9gk25t6dVuT4UiMjBZdT6lqlbyW+RUtJTa6t65oUj4WfSp9Qt5GS172Ko0w== ruebezahl"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD2BA27CHT85uegdPaocOV9YyiKNiVOGm6eU3oaJmuEFp0hpAbjn7pvvNpT6oAXmV06V0Kj7TpKzHrfjWs+kkOnM0LgBAbcPMsJMG/oNCJL9T1JQgBxefJ3ZcSKbPRlutJ6y5hwxFI5dn4DP6OyDfiSvjTEyyRiaa70jbkmixSKZckO5DgvbxEo3lUplZt9zQECZEePkBodTNTT79DWXfbvmLOzdrXG8ekZIjvEvvdDO+3Aj74ca5KOVGgaJSBMNX5DOYI+r9K/oz7E+NFuwORDghXSYmodrC5JMBBuUdhIc0S+pksNZHYYguYUGXaleIXQ10lGBRBSJ6uPdNLFYel3 fadenb@taytay"
      ];

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
        gc =
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

    nixpkgs.config = {
      packageOverrides = pkgs: {
        collectd = pkgs.collectd.override {
          jdk = null;
          libdbi = null;
          cyrus_sasl = null;
          libmodbus = null;
          libnotify = null;
          gdk_pixbuf = null;
          libsigrok = null;
          libvirt = null;
          rabbitmq-c = null;
          riemann = null;
          rrdtool = null;
          varnish = null;
          yajl = null;
        };
      };
    };
  };
}
