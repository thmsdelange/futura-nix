{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      sPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.sonarr or 8989);

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
      subdomain = "tv";
    in
    {
      sops.secrets = {
        "services/sonarr/password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/sonarr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      nixflix.sonarr = {
        enable = true;
        package = pkgs.unstable.sonarr;
        subdomain = subdomain;

        config = {
          apiKey._secret = config.sops.secrets."services/sonarr/api-key".path;
          hostConfig.username = "localadmin";
          hostConfig.password._secret = config.sops.secrets."services/sonarr/password".path;
          delayProfiles = [
            {
              enableUsenet = true;
              enableTorrent = true;
              preferredProtocol = "usenet";
              usenetDelay = 0;
              torrentDelay = 0;
              bypassIfHighestQuality = true;
              bypassIfAboveCustomFormatScore = false;
              minimumCustomFormatScore = 0;
              order = 2147483647;
              tags = [ ];
              id = 1;
            }
          ];
        };
      };

      services.caddy.virtualHosts."${subdomain}.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${builtins.toString sPort}
        '';
      };
      hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
    };
}