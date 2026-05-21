{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      sabPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.sabnzbd or 8080);

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
      subdomain = "sab";

      inherit (config.hostSpec.impermanence) dontBackupStorage dontBackup;
      hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    in
    {
      sops.secrets = {
        "services/sabnzbd/username" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/sabnzbd/password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/sabnzbd/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/sabnzbd/nzb-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/usenet/bulknews/username" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/usenet/bulknews/password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      nixflix.usenetClients.sabnzbd = {
        enable = true;
        package = pkgs.unstable.sabnzbd;
        subdomain = subdomain;

        settings = {
          misc = {
            port = sabPort;
            username._secret = config.sops.secrets."services/sabnzbd/username".path;
            password._secret = config.sops.secrets."services/sabnzbd/password".path;
            api_key._secret = config.sops.secrets."services/sabnzbd/api-key".path;
            nzb_key._secret = config.sops.secrets."services/sabnzbd/nzb-key".path;
          };
          servers = [
            {
              name = "Bulknews";
              host = "news.bulknews.eu";
              port = 443;
              username._secret = config.sops.secrets."services/usenet/bulknews/username".path;
              password._secret = config.sops.secrets."services/usenet/bulknews/password".path;
              connections = 20;
              ssl = true;
              priority = 0;
            }
          ];
        };
      };

      environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
        hideMounts = true;
        directories = [
          "/var/lib/sabnzbd"
        ];
      };

      services.caddy.virtualHosts."${subdomain}.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${builtins.toString sabPort}
        '';
      };
      hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
    };
}