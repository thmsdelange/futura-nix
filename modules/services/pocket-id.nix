{
  flake.modules.nixos.pocket-id = 
  { inputs, hostConfig, config, pkgs, lib, ... }:
  let
    pidPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.pocket-id or 1411);
    
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

    inherit (config.hostSpec.impermanence) dontBackup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
  in
	{
    sops.secrets = lib.mkIf hasSecrets {
			"services/pocket-id/encryption-key" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
		};

    sops.templates."pid-env" = lib.mkIf hasSecrets {
      content = ''
        ENCRYPTION_KEY=${config.sops.placeholder."services/pocket-id/encryption-key"}
        ### The below was not picked up:
        EMAIL_ONE_TIME_ACCESS_AS_ADMIN_ENABLED=true
        EMAIL_VERIFICATION_ENABLED=true
        SMTP_HOST=${config.sops.placeholder."smtp/host"}
        SMTP_PORT=${config.sops.placeholder."smtp/port"}
        SMTP_FROM=admin@${domain}
        SMTP_USER=${config.sops.placeholder."smtp/user"}
        SMTP_PASSWORD=${config.sops.placeholder."smtp/password"}
        SMTP_TLS=StartTLS
      '';
    };

    services.pocket-id = {
      enable = true;
      package = pkgs.unstable.pocket-id;
      settings = {
        PORT = pidPort;
        HOST = "127.0.0.1";
        APP_URL="https://id.${domain}";
        EMAILS_VERIFIED=false;
        TRUST_PROXY=true;
        ANALYTICS_DISABLED=true;
        DISABLE_RATE_LIMITING=true;
      };
      environmentFile = if hasSecrets then config.sops.templates."pid-env".path else "/dev/null";
    };

    environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
      hideMounts = true;
      directories = [ 
        "/var/lib/pocket-id"
      ];
    };
    systemd.tmpfiles.rules = lib.mkIf hasPersistDir [
      "d /var/lib/pocket-id 0750 pocket-id pocket-id -"
    ];

    services.caddy.virtualHosts."id.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString pidPort}
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ "id" ];
	};
}
