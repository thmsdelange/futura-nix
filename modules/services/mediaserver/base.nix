{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, nixpkgs, ... }:
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
      ];
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

      nixpkgs.overlays = [
        (final: prev: {
          recyclarr = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.recyclarr;
        })
      ];

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
            # managedProfiles = [
            #   "[SQP] SQP-1 (1080p)"
            #   "[SQP] SQP-1 (2160p)"
            #   "WEB-1080p (Alternative)"
            #   "WEB-2160p (Alternative)"
            #   "[Anime] Remux-1080p"
            # ];
          };
          config = {
            # sonarr.sonarr = {
            #   base_url = "http://127.0.0.1:8989";
            #   api_key._secret = config.sops.secrets."services/sonarr/api-key".path;
            #   quality_definition.type = "series";
            #   quality_profiles = [{
            #     trash_id = "dfa5eaae7894077ad6449169b6eb03e0"; # WEB-2160p (Alternative)
            #     reset_unmatched_scores.enabled = true;
            #   }];
            #   custom_format_groups.add = [{
            #     trash_id = "e3f37512790f00d0e89e54fe5e790d1c"; # [Required] Golden Rule UHD
            #     select = [ "9b64dff695c2115facf1b6ea59c9bd07" ]; # x265 (no HDR/DV)
            #   }];
            # };
            # radarr.radarr = {
            #   base_url = "http://127.0.0.1:7878";
            #   api_key._secret = config.sops.secrets."services/radarr/api-key".path;
            #   quality_definition.type = "movie";
            #   media_management.propers_and_repacks = "do_not_prefer";
            # };
            # radarr.radarr = {
            #   quality_profiles = lib.mkForce [
            #     {
            #       trash_id = "0896c29d74de619df168d23b98104b22"; # [SQP] SQP-1 (1080p)
            #       reset_unmatched_scores.enabled = true;
            #     }
            #     {
            #       trash_id = "5128baeb2b081b72126bc8482b2a86a0"; # [SQP] SQP-1 (2160p)
            #       reset_unmatched_scores.enabled = true;
            #     }
            #   ];
            #   custom_formats = [
            #     {
            #       trash_ids = [
            #         "9c11cd3f07101cdba90a2d81cf0e56b4" # BR-DISK
            #         "9965a052eb87b0d10313b1cea89eb451" # Raw-HD
            #       ];
            #       assign_scores_to = [
            #         { name = "[SQP] SQP-1 (1080p)"; score = -10000; }
            #         { name = "[SQP] SQP-1 (2160p)"; score = -10000; }
            #       ];
            #     }
            #   ];
            # };
            # sonarr.sonarr = {
            #   quality_profiles = [
            #     {
            #       trash_id = "9d142234e45d6143785ac55f5a9e8dc9"; # WEB-1080p (Alternative)
            #       reset_unmatched_scores.enabled = true;
            #     }
            #     {
            #       trash_id = "dfa5eaae7894077ad6449169b6eb03e0"; # WEB-2160p (Alternative)
            #       reset_unmatched_scores.enabled = true;
            #     }
            #   ];
            #   custom_formats = [
            #     {
            #       trash_ids = [
            #         "9c11cd3f07101cdba90a2d81cf0e56b4" # BR-DISK
            #         "9965a052eb87b0d10313b1cea89eb451" # Raw-HD
            #       ];
            #       assign_scores_to = [
            #         { name = "WEB-1080p (Alternative)"; score = -10000; }
            #         { name = "WEB-2160p (Alternative)"; score = -10000; }
            #       ];
            #     }
            #   ];
            # };
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