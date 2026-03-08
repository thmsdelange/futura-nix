{
  flake.modules.nixos.tailscale = 
	{ hostConfig, config, lib, pkgs, inputs, ... }:
	let
		cfg = config.hostSpec.services.tailscale;
		hostName = hostConfig.name;
		hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
		inherit (config.hostSpec.impermanence) dontBackup;
		inherit (config.hostSpec) hasSecrets;
		sopsRoot = builtins.toString inputs.futura-secrets;
	in
	{
		sops.secrets = lib.mkIf hasSecrets {
			"services/tailscale/ts-auth-key" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
		};

		services.tailscale = {
			enable = true;
			package = pkgs.tailscale; # FIXME: can't get unstable to work now: pkgs.unstable.tailscale;
			authKeyFile = if hasSecrets then config.sops.secrets."services/tailscale/ts-auth-key".path else cfg.authKeyFile; # TODO: only needed for bootstrap?
			extraUpFlags = cfg.extraUpFlags;
			useRoutingFeatures = cfg.useRoutingFeatures;
			# permitCertUid = "caddy";
		};

		environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
			hideMounts = true;
			directories = [ "/var/lib/tailscale" ];
		};
	};
}



