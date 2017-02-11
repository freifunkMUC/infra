{ config, pkgs, ... }:

let
  secrets = (import ../secrets) { inherit pkgs; };
  ffpkgs = (import ../pkgs/default.nix) { };
in

{
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ../modules/default.nix
    ../modules/physical.nix
  ];

  boot.initrd.availableKernelModules = [ "ehci_pci" "megaraid_sas" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelParams = [ "console=ttyS0,115200" ];

  fileSystems."/" =
    { device = "tank/root";
      fsType = "zfs";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/1c7157b2-a418-41ff-af03-9875c72fd712"; }
      { device = "/dev/disk/by-uuid/f9b7e1b3-a32a-4cd6-9a03-0669ad6b8be7"; }
    ];

  nix.maxJobs = 4;

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/sda" "/dev/sdb" ];

  networking.hostId = "109271e3";
  networking.hostName = "sendlingertor";

  networking.useDHCP = false;
  networking.interfaces.eno1 = {
    ip4 = [
      { address = "195.30.94.28"; prefixLength = 29; }
    ];
    ip6 = [
      { address = "2001:608:a01::3"; prefixLength = 64; }
    ];
  };
  networking.defaultGateway = "195.30.94.30";
  networking.defaultGateway6 = "2001:608:a01::ffff";
  networking.nameservers = [ "2001:608:a01::53" ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = rec {
    enable = true;
    appendHttpConfig = ''
      proxy_cache_path /var/spool/nginx/cache-ffmuc-data keys_zone=isartor:32m inactive=2m;
      proxy_cache_path /var/spool/nginx/cache-osm keys_zone=osm:512m inactive=7d;
      proxy_cache_path /var/spool/nginx/cache-osmhot keys_zone=osmhot:2048m inactive=7d;
      proxy_cache_lock on;
      proxy_cache_lock_age 10s;

      upstream osm {
        server a.tile.openstreetmap.org;
        #server b.tile.openstreetmap.org;
        keepalive 8;
      }

      upstream osmhot {
        server a.tile.openstreetmap.fr;
        #server b.tile.openstreetmap.fr;
        keepalive 4;
      }
    '';
    virtualHosts = {
      "sendlingertor.ffmuc.net" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/.metrics/node/" = {
            proxyPass = "http://[::1]:9100/";
          };
        };
      };
      "prometheus.ffmuc.net" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            proxyPass = "http://[::1]:9090";
          };
          "/alertmanager" = {
            proxyPass = "http://[::1]:9093";
          };
        };
        basicAuth = { "foo" = "bar"; };
      };
      "stats.ffmuc.net" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://[::1]:3000";
      };
      "map.ffmuc.net" = {
        serverAliases = [ "map.freifunk-muenchen.de" ];
        forceSSL = true;
        enableACME = true;
        locations."/".root = "/srv/www/map.ffmuc.net";
        locations."/data" = {
          proxyPass = "https://isartor/hopglass/data/";
          extraConfig = ''
            proxy_set_header Host isartor.ffmuc.net;
            proxy_cache isartor;
            proxy_cache_valid 1m;
            expires 1m;
          '';
        };
      };
      "data.ffmuc.net" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = virtualHosts."map.ffmuc.net".locations."/data";
      };
    } // (pkgs.lib.genAttrs [
        "a.tiles.map.ffmuc.net"
        "b.tiles.map.ffmuc.net"
        "c.tiles.map.ffmuc.net"
      ] (name: {
        forceSSL = true;
        enableACME = true;
        locations."/osm/".extraConfig = ''
          proxy_set_header Host a.tile.openstreetmap.org;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_pass http://osm/;
          proxy_cache osm;
          proxy_cache_valid 7d;
          expires 1d;
        '';
        locations."/osmhot/".extraConfig = ''
          proxy_set_header Host a.tile.openstreetmap.fr;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_pass http://osmhot/hot/;
          proxy_cache osmhot;
          proxy_cache_valid 7d;
          expires 1d;
        '';
      }));
  };

  services.grafana = {
    enable = true;
    addr = "[::1]";
    domain = "stats.ffmuc.net";
    rootUrl = "https://stats.ffmuc.net/";
    auth.anonymous = {
      enable = true;
      org_name = "ffmuc";
    };
  };

  services.prometheus =
    { enable = true;
      alertmanagerURL = [ "http://localhost:9093/alertmanager" ];
      rules = [
        ''
          ALERT node_down
          IF up == 0
          FOR 2m
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description = "{{$labels.alias}} has been down for more than 2 minutes"
          }

          ALERT systemd_service_failed
          IF node_systemd_unit_state{state="failed"} == 1
          FOR 30s
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description = "{{$labels.alias}} failed to start service {{$labels.name}}"
          }

          ALERT filesystem_full_90percent
          IF sort(node_filesystem_free{device!="ramfs"} < node_filesystem_size{device!="ramfs"} * 0.1) / 1024^3
          FOR 5m
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description = "{{$labels.alias}} device {{$labels.device}} on {{$labels.mountpoint}} got less than 10% space left on its filesystem"
          }

          ALERT filesystem_full_in_4h
          IF predict_linear(node_filesystem_free{device!="ramfs"}[1h], 4*3600) <= 0
          FOR 5m
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description = "{{$labels.alias}} device {{$labels.device}} on {{$labels.mountpoint}} is running out of space of in ~4 hours"
          }

          ALERT filedescriptors_full_in_3h
          IF predict_linear(node_filefd_allocated[1h], 3*3600) >= node_filefd_maximum
          FOR 20m
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description = "{{$labels.alias}} is running out of available file descriptors in ~3 hours"
          }

          ALERT load1_90percent
          IF node_load1 / on(alias) count(node_cpu{mode="system"}) by (alias) >= 0.9
          FOR 10m
          LABELS {
            severity="normal"
          }
          ANNOTATIONS {
            description = "{{$labels.alias}} is running with over 90% normalized load1 for at least 10 minutes"
          }

          ALERT cpu_util_90percent
          IF 100 - (avg by (alias) (irate(node_cpu{mode="idle"}[5m])) * 100) >= 90
          FOR 10m
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description = "{{$labels.alias}} is running with total CPU utilization over 90% for at least 10 minutes"
          }

          ALERT memory_using_90percent
          IF node_memory_MemFree + node_memory_Buffers + node_memory_Cached < node_memory_MemTotal * 0.1
          FOR 10m
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description="{{$labels.alias}} is using at least 90% of its memory for at least 10 minutes"
          }

          ALERT swap_using_50percent
          IF node_memory_SwapTotal - (node_memory_SwapFree + node_memory_SwapCached) > node_memory_SwapTotal * 0.5
          FOR 10m
          LABELS {
            severity="page"
          }
          ANNOTATIONS {
            description="{{$labels.alias}} is using more than 50% of its swap space for at least 10 minutes"
          }
        ''
      ];
      extraFlags = [ "-web.external-url=https://sendlingertor.ffmuc.net/prometheus/" ];
      scrapeConfigs = [
        { job_name = "hopglass";
          scrape_interval = "60s";
          metrics_path = "/hopglass/data/metrics";
          static_configs = [
            { targets = [ "isartor.ffmuc.net" ];
              labels = { };
            }
          ];
        }
        { job_name = "node";
          scrape_interval = "10s";
          metrics_path = "/.metrics/node/metrics";
          static_configs = [
            { targets = [ "sendlingertor.ffmuc.net" ];
              labels = { alias = "sendlingertor.ffmuc.net"; };
            }
            { targets = [ "isartor.ffmuc.net" ];
              labels = { alias = "isartor.ffmuc.net"; };
            }
          ];
        }
       ];
      alertmanager = {
        enable = true;
        listenAddress = "0.0.0.0";
        webExternalUrl = "https://prometheus.ffmuc.net/alertmanager/";
        configuration = {
          global = {
            smtp_smarthost = "localhost";
            smtp_from = "alertmanager@ffmuc.net";
          };
          route = {
            group_by = [ "alertname" "alias" ];
            group_wait = "5s";
            group_interval = "1m";
            repeat_interval = "1h";
            receiver = "noc";
          };
          receivers = [
            { name = "noc";
              slack_configs = [
                { send_resolved = true;
                  api_url = "https://chat.ffmuc.net/hooks/a6m51uq4e3gw9nht399cbxfdww";
                  channel = "NOC-Monitoring";
                  title = ''
                    [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .GroupLabels.SortedPairs.Values | join " " }}
                  '';
                  text = "{{ .CommonAnnotations.description }}";
                }
              ];
            }
          ];
        };
      };
    };

}
