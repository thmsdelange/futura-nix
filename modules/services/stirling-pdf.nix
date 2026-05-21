{
  flake.modules.nixos.stirling-pdf = 
  { inputs, hostConfig, config, pkgs, lib, ... }:
  let
    spPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.stirling-pdf or 8080);

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
    subdomain = "pdf";

    inherit (config.hostSpec.impermanence) backupStorage dontBackup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
  in
	{
    sops.secrets = lib.mkIf hasSecrets {
      "services/stirling-pdf/pocket-id-client-id" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
      "services/stirling-pdf/pocket-id-client-secret" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
		};

    sops.templates."sp-env" = lib.mkIf hasSecrets {
      # owner = 911;
      content = ''
        SECURITY_ENABLELOGIN=true
        SECURITY_LOGINMETHOD=all
        SECURITY_INITIALLOGIN_USERNAME=admin
        SECURITY_INITIALLOGIN_PASSWORD=yourSecurePassword123
        SECURITY_OAUTH2_ENABLED=true
        SECURITY_OAUTH2_ISSUER=https://id.${domain}
        SECURITY_OAUTH2_CLIENTID=${config.sops.placeholder."services/stirling-pdf/pocket-id-client-id"}
        SECURITY_OAUTH2_CLIENTSECRET=${config.sops.placeholder."services/stirling-pdf/pocket-id-client-secret"}
        SECURITY_OAUTH2_SCOPES=openid, profile, email
        SECURITY_OAUTH2_USEASUSERNAME=email
        SECURITY_OAUTH2_PROVIDER=PocketID
        SECURITY_OAUTH2_AUTOCREATEUSER=true
        SECURITY_OAUTH2_BLOCKREGISTRATION=false
      '';
    };

    services.stirling-pdf = {
      enable = true;
      package = pkgs.unstable.stirling-pdf;
      environment = {
        
      };
      environmentFiles = [ lib.mkIf hasSecrets config.sops.templates."sp-env".path ];
    };

    # environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
    #   hideMounts = true;
    #   directories = [
    #     "/var/lib/private/stirling-pdf"
    #   ];
    # };

    services.caddy.virtualHosts."${subdomain}.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString spPort}
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
	};
}
