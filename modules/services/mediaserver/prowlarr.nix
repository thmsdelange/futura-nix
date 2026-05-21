{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      plPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.prowlarr or 9696);

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
      subdomain = "indexers";
    in
    {
      sops.secrets = {
        "services/prowlarr/password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/prowlarr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/usenet/nzbgeek/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/usenet/ninjacentral/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      nixflix.prowlarr = {
        enable = true;
        package = pkgs.unstable.prowlarr;
        subdomain = subdomain;

        config = {
          apiKey._secret = config.sops.secrets."services/prowlarr/api-key".path;
          hostConfig.username = "localadmin";
          hostConfig.password._secret = config.sops.secrets."services/prowlarr/password".path;
          indexers = [
            # NZB Indexers
            # {
            #   enable = true;
            #   name = "DrunkenSlug";
            #   apiKey._secret = config.sops.secrets."indexer-api-keys/DrunkenSlug".path;
            # }
            # {
            #   enable = true;
            #   name = "NZBFinder";
            #   apiKey._secret = config.sops.secrets."indexer-api-keys/NZBFinder".path;
            # }
            {
              enable = false;
              name = "NinjaCentral";
              apiKey._secret = config.sops.secrets."services/usenet/ninjacentral/api-key".path;
            }
            {
              enable = false;
              name = "NZBgeek";
              apiKey._secret = config.sops.secrets."services/usenet/nzbgeek/api-key".path;
            }

            # Torrent indexers
            {
              enable = true;
              name = "Nyaa.si";
              baseUrl = "https://nyaa.si/";
              radarr_compatibility = true;
              sonarr_compatibility = true;
            }
            {
              enable = true;
              name = "YTS";
              baseUrl = "https://yts.bz/";
            }
            {
              enable = true;
              name = "The Pirate Bay";
              baseUrl = "https://thepiratebay.org/";
            }
            {
              enable = true;
              name = "LimeTorrents";
              baseUrl = "https://www.limetorrents.fun/";
            }
            {
              enable = false;
              name = "TorrentDownload";
              baseUrl = "https://www.torrentdownload.info/";
            }
            # {
            #   enable = false;
            #   name = "EZTV";
            #   baseUrl = "https://eztvx.to/";
            # }
            # {
            #   enable = false;
            #   name = "BitSearch";
            #   baseUrl = "http://bitsearch.to/";
            # }
          ];
        };
      };

      services.caddy.virtualHosts."${subdomain}.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${builtins.toString plPort}
        '';
      };
      hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
    };
}