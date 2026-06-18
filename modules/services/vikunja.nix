{
  flake.modules.nixos.vikunja = 
  { inputs, hostConfig, config, pkgs, lib, ... }:
  let
    vkPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.vikunja or 3456);

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
    subdomain = "todo";

    inherit (config.hostSpec.impermanence) backup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
  in
	{
    sops.secrets = lib.mkIf hasSecrets {
      "services/vikunja/pocket-id-client-id" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
      "services/vikunja/pocket-id-client-secret" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
		};

    sops.templates."vk-env" = lib.mkIf hasSecrets {
      content = ''
        VIKUNJA_AUTH_LOCAL_ENABLED=false
        VIKUNJA_AUTH_OPENID_ENABLED=true
        VIKUNJA_AUTH_OPENID_PROVIDERS_POCKETID_AUTHURL=https://id.${domain}
        VIKUNJA_AUTH_OPENID_PROVIDERS_POCKETID_CLIENTID=${config.sops.placeholder."services/vikunja/pocket-id-client-id"}
        VIKUNJA_AUTH_OPENID_PROVIDERS_POCKETID_CLIENTSECRET=${config.sops.placeholder."services/vikunja/pocket-id-client-secret"}
        VIKUNJA_AUTH_OPENID_PROVIDERS_POCKETID_NAME=PocketID
        VIKUNJA_AUTH_OPENID_PROVIDERS_POCKETID_SCOPE=openid profile email
        VIKUNJA_MAILER_ENABLED=true
        VIKUNJA_MAILER_HOST=${config.sops.placeholder."smtp/host"}
        VIKUNJA_MAILER_PORT=${config.sops.placeholder."smtp/port"}
        VIKUNJA_MAILER_AUTHTYPE=StartTLS
        VIKUNJA_MAILER_USERNAME=${config.sops.placeholder."smtp/user"}
        VIKUNJA_MAILER_PASSWORD=${config.sops.placeholder."smtp/password"}
        VIKUNJA_MAILER_FROMEMAIL=todo@${domain}
      '';
    };

    services.vikunja = {
      enable = true;
      package = pkgs.unstable.vikunja;
      frontendScheme = "http";
      frontendHostname = hostName;
      # address = "127.0.0.1";
      port = vkPort;
      environmentFiles = lib.mkIf hasSecrets [ config.sops.templates."vk-env".path ];
      settings = {
        service = {
          enableregistration = false;
        };
      };
    };

    environment.persistence."${backup}" = lib.mkIf hasPersistDir {
      hideMounts = true;
      directories = [
        "/var/lib/private/vikunja"
      ];
    };

    services.caddy.virtualHosts."${subdomain}.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString vkPort}
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
	};
}
