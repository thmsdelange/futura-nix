{
  flake.modules.nixos.mealie = 
  { inputs, hostConfig, config, pkgs, lib, ... }:
  let
    mlPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.mealie or 9000);

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
    subdomain = "recipes";

    inherit (config.hostSpec.impermanence) backupStorage dontBackup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
  in
	{
    sops.secrets = lib.mkIf hasSecrets {
      "services/mealie/pocket-id-client-id" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
      "services/mealie/pocket-id-client-secret" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
		};

    sops.templates."ml-env" = lib.mkIf hasSecrets {
      # owner = 911;
      content = ''
        ALLOW_PASSWORD_LOGIN='false'
        ALLOW_SIGNUP='true'
        OIDC_AUTH_ENABLED=True
        OIDC_SIGNUP_ENABLED=True
        OIDC_CONFIGURATION_URL=https://id.${domain}/.well-known/openid-configuration
        OIDC_CLIENT_ID=${config.sops.placeholder."services/mealie/pocket-id-client-id"}
        OIDC_CLIENT_SECRET=${config.sops.placeholder."services/mealie/pocket-id-client-secret"}
        OIDC_USER_GROUP=family
        OIDC_ADMIN_GROUP=admin
        OIDC_AUTO_REDIRECT=true
        OIDC_PROVIDER_NAME=PocketID
      '';
    };

    services.mealie = {
      enable = true;
      package = pkgs.unstable.mealie;
      port = mlPort;
      listenAddress = "127.0.0.1";
      settings = {
        TZ = "Europe/Amsterdam";
        BASE_URL = "https://${subdomain}.${domain}";
      };
      credentialsFile = lib.mkIf hasSecrets config.sops.templates."ml-env".path;
    };

    environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
      hideMounts = true;
      directories = [
        "/var/lib/private/mealie"
      ];
    };

    services.caddy.virtualHosts."${subdomain}.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString mlPort}
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
	};
}
