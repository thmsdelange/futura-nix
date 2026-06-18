{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.host-delorean = 
  { pkgs, lib, ... }:
  {
    imports =
      with config.flake.modules.nixos;
      [
        # Modules
        core
        shell

        # Services
        dns-server
        share-split-horizon
        pocket-id
        tailscale
        opencloud
        immich
        scrutiny
        gaggimate
        mealie
        vikunja
        searx
        mediaserver
        postgres
        # dashboard
      ]
      # Specific Home-Manager modules
      ++ [
        {
          home-manager.users.thms = { # TODO: can this be made variable as well?
            imports = with config.flake.modules.homeManager; [
              core
              shell
            ];
          };
        }
      ];

    ### delorean has OOM issues, so requires systemd-oom tuning
    services.earlyoom = {
      enable = true;
      freeMemThreshold = 5;   # kill when <5% RAM free
      freeSwapThreshold = 2;  # kill when <2% swap free
    };
    systemd.timers.nix-gc.timerConfig = {
      OnCalendar = lib.mkForce "03:35";
      RandomizedDelaySec = lib.mkForce "10min";
    };
    systemd.services.nix-gc.serviceConfig.MemoryMax = "512M";
    systemd.services.immich-server.serviceConfig.MemoryMax = "2G";
    systemd.services.opencloud.serviceConfig.MemoryMax = "1G";
    systemd.services.postgresql.serviceConfig.MemoryMax = "1G";
    systemd.services.radarr.serviceConfig.MemoryMax = "400M";
    systemd.services.sonarr.serviceConfig.MemoryMax = "400M";
    systemd.services.sonarr-anime.serviceConfig.MemoryMax = "400M";
    systemd.services.prowlarr.serviceConfig.MemoryMax = "300M";
    systemd.services.lidarr.serviceConfig.MemoryMax = "300M";
    systemd.services.jellyfin.serviceConfig.MemoryMax = "800M";
    systemd.timers.scrutiny-collector.timerConfig = {
      OnCalendar = lib.mkForce "02:15";
    };
    systemd.services.scrutiny-collector.serviceConfig.MemoryMax = "256M";
    boot.crashDump.enable = true;
    systemd.settings.Manager.RuntimeWatchdogSec = "30s";
    systemd.settings.Manager.RebootWatchdogSec = "1min";
    # boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
    boot.kernelParams = [
      "nmi_watchdog=panic"
      "softlockup_panic=1"
      "hardlockup_panic=1"
    ];


    hostSpec = {
      isServer = true;
      hasSecrets = true;
      disks = {
        zfs = {
          enable = true;
          hostID = "501eb87a";
          root = {
            disk1 = "sda";
            reservation = "10G";
            impermanenceRoot = true;
          };
          storage = {
            enable = true;
            disks = [ "sdb" ];
            reservation = "10G";
          };
          nvme = {
            enable = true;
            disks = [ "nvme0n1" ];
            reservation = "10G";
            swap = false;
          };
        };
      };
      users = {
        thms = {
          isAdmin = true;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAo9HJGB/8Qan1n62aR7cqci6CXm/z25DtLfAuaISTbB thomas@PC-THOMAS"
          ];
        };
      };
      services = {
        tailscale = {
          extraUpFlags = [
            "--ssh=true"
            "--reset=true"
          ];
          useRoutingFeatures = "server";
        };
      };
    };

    facter.reportPath = ./facter.json;
  };
}
