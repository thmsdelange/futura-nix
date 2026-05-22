{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      sePort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.seerr or 5055);

      ### TODO: handle this ugly-ass block better across all submodules where it is required
      hostName = hostConfig.name;
      inherit (config.hostSpec) hasSecrets;
      sopsRoot = builtins.toString inputs.futura-secrets;
      networkingSecrets = config.hostSpec.networking or {};
      hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
      subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
      hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
      host = if hostInSecrets then subnet.hosts.${hostName} else null;
      domain = networkingSecrets.domain;
      subdomain = "request";
    in
    {
      sops.secrets = {
        "services/seerr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/radarr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/sonarr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/sonarr-anime/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      nixflix.seerr = {
        enable = true;
        package = pkgs.unstable.seerr;
        subdomain = subdomain;
        apiKey._secret = config.sops.secrets."services/seerr/api-key".path;
        jellyfin.adminUsername = "localadmin";
        settings.users = {
          defaultPermissions = 32;
          localLogin = false;
        };
        radarr = {
          "1080p" = {
            apiKey._secret = config.sops.secrets."services/radarr/api-key".path;
            activeProfileName = "HD Bluray + WEB";
            isDefault = true;
            is4k = false;
          };
          "4K" = {
            apiKey._secret = config.sops.secrets."services/radarr/api-key".path;
            activeProfileName = "UHD Bluray + WEB";
            isDefault = false;
            is4k = true;
          };
        };
        sonarr = {
          "1080p" = {
            apiKey._secret = config.sops.secrets."services/sonarr/api-key".path;
            activeProfileName = "WEB-1080p (Alternative)";
            isDefault = true;
            is4k = false;
          };
          "4K" = {
            apiKey._secret = config.sops.secrets."services/sonarr/api-key".path;
            activeProfileName = "WEB-2160p (Alternative)";
            isDefault = false;
            is4k = true;
          };
          "Sonarr Anime" = {
            hostname = config.nixflix.sonarr-anime.connectionAddress;
            port = config.nixflix.sonarr-anime.config.hostConfig.port;
            apiKey._secret = config.sops.secrets."services/sonarr-anime/api-key".path;

            activeProfileName = "[Anime] Remux-1080p";
            activeDirectory = builtins.head config.nixflix.sonarr-anime.mediaDirs;

            activeAnimeProfileName = "[Anime] Remux-1080p";
            activeAnimeDirectory = builtins.head config.nixflix.sonarr-anime.mediaDirs;

            seriesType = "standard";
            animeSeriesType = "anime";

            isDefault = false;
            is4k = false;
          };
        };
      };

      systemd.services.seerr-setup = {
        after = [ "jellyfin.service" ];
        requires = [ "jellyfin.service" ];
        preStart = ''
          echo "Waiting for Jellyfin to be ready..."
          for i in $(seq 1 60); do
            if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:8096/health >/dev/null 2>&1; then
              echo "Jellyfin is ready"
              break
            fi
            sleep 2
          done
        '';
      };

      services.caddy.virtualHosts."${subdomain}.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${builtins.toString sePort}
        '';
      };
      hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
    };
}