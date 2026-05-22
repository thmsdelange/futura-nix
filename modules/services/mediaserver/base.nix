{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      ### TODO: handle this ugly-ass block better across all submodules where it is required
      hostName = hostConfig.name;
      inherit (config.hostSpec) hasSecrets;
      sopsRoot = builtins.toString inputs.futura-secrets;

      inherit (config.hostSpec.impermanence) dontBackupStorage dontBackup;
      hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    in
    {
      imports = [
        inputs.nixflix.nixosModules.default
        "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/recyclarr.nix"
      ];

      disabledModules = [
        "services/misc/recyclarr.nix"
      ];

      services.recyclarr.package = pkgs.unstable.recyclarr;

      sops.secrets = lib.mkIf hasSecrets {
        "wg-confs/airvpn-ch" = {
          sopsFile = "${sopsRoot}/sops/shared.yaml";
        };
        "services/radarr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/sonarr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      nixflix = {
        enable = true;
        mediaUsers = [ "thms" ];
        downloadsDir = lib.mkIf hasPersistDir "${dontBackupStorage}/mediaserver/downloads";
        mediaDir = lib.mkIf hasPersistDir "${dontBackupStorage}/mediaserver/media";
        stateDir = lib.mkIf hasPersistDir "${dontBackup}/mediaserver/.state";

        theme = {
          enable = true;
          name = "catppuccin-mocha";
        };

        vpn = {
          enable = true;
          wgConfFile = config.sops.secrets."wg-confs/airvpn-ch".path;
          accessibleFrom = [ "10.10.10.0/24" ];
        };

        postgres.enable = true;

        recyclarr = {
          enable = true;
          cleanupUnmanagedProfiles = {
            enable = true;
            managedProfiles = [
              "HD Bluray + WEB"
              "UHD Bluray + WEB"
              "WEB-1080p (Alternative)"
              "WEB-2160p (Alternative)"
              "[Anime] Remux-1080p"
            ];
          };
          config = {
            radarr.radarr = {
              base_url = "http://127.0.0.1:7878";
              api_key._secret = config.sops.secrets."services/radarr/api-key".path;
              quality_definition.type = "movie";
              media_management.propers_and_repacks = "do_not_prefer";

              quality_profiles = [
                {
                  trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
                  reset_unmatched_scores.enabled = true;
                }
                {
                  trash_id = "64fb5f9858489bdac2af690e27c8f42f"; # UHD Bluray + WEB
                  reset_unmatched_scores.enabled = true;
                }
              ];

              custom_format_groups.add = [
                {
                  trash_id = "f8bf8eab4617f12dfdbd16303d8da245"; # [Optional] Golden Rule HD
                  select_all = false;
                  select = [ "839bea857ed2c0a8e084f3cbdbd65ecb" ]; # x265 (no HDR/DV)
                  assign_scores_to = [
                    { trash_id = "d1d67249d3890e49bc12e275d989a7e9"; }
                  ];
                }
                {
                  trash_id = "ff204bbcecdd487d1cefcefdbf0c278d"; # [Optional] Golden Rule UHD
                  select_all = false;
                  select = [ "839bea857ed2c0a8e084f3cbdbd65ecb" ]; # x265 (no HDR/DV)
                  assign_scores_to = [
                    { trash_id = "64fb5f9858489bdac2af690e27c8f42f"; }
                  ];
                }
              ];
            };

            sonarr.sonarr = {
              base_url = "http://127.0.0.1:8989";
              api_key._secret = config.sops.secrets."services/sonarr/api-key".path;
              quality_definition.type = "series";

              quality_profiles = [
                {
                  trash_id = "9d142234e45d6143785ac55f5a9e8dc9"; # WEB-1080p (Alternative)
                  reset_unmatched_scores.enabled = true;
                }
                {
                  trash_id = "dfa5eaae7894077ad6449169b6eb03e0"; # WEB-2160p (Alternative)
                  reset_unmatched_scores.enabled = true;
                }
              ];

              custom_formats = [
                {
                  trash_ids = [
                    "85c61753df5da1fb2aab6f2a47426b09" # BR-DISK
                  ];
                  assign_scores_to = [
                    { name = "WEB-1080p (Alternative)"; score = -10000; }
                    { name = "WEB-2160p (Alternative)"; score = -10000; }
                  ];
                }
              ];

              custom_format_groups.add = [
                {
                  trash_id = "158188097a58d7687dee647e04af0da3"; # [Optional] Golden Rule HD
                  select_all = false;
                  select = [ "9b64dff695c2115facf1b6ea59c9bd07" ]; # x265 (no HDR/DV)
                  assign_scores_to = [
                    { trash_id = "9d142234e45d6143785ac55f5a9e8dc9"; }
                  ];
                }
                {
                  trash_id = "e3f37512790f00d0e89e54fe5e790d1c"; # [Optional] Golden Rule UHD
                  select_all = false;
                  select = [ "9b64dff695c2115facf1b6ea59c9bd07" ]; # x265 (no HDR/DV)
                  assign_scores_to = [
                    { trash_id = "dfa5eaae7894077ad6449169b6eb03e0"; }
                  ];
                }
              ];
            };
          };
        };
      };

      environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
        hideMounts = true;
        directories = [
          "/var/lib/recyclarr"
        ];
      };
    };
}