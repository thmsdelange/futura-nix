{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      lPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.lidarr or 8686);

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
      subdomain = "music";
    in
    {
      sops.secrets = {
        "services/lidarr/password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/lidarr/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      nixflix.lidarr = {
        enable = true;
        package = pkgs.unstable.lidarr;
        subdomain = subdomain;

        config = {
          apiKey._secret = config.sops.secrets."services/lidarr/api-key".path;
          hostConfig.username = "localadmin";
          hostConfig.password._secret = config.sops.secrets."services/lidarr/password".path;
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
          reverse_proxy 127.0.0.1:${builtins.toString lPort}
        '';
      };
      hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
    };
}