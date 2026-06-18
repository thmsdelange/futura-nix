{
  flake.modules.nixos.hermes-agent = 
  { config, lib, hostConfig, inputs, pkgs, user, ... }:
  let
    sgPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.signal-cli or 8818);
    hmPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.hermes-agent or 3248);

    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    sopsRoot = builtins.toString inputs.futura-secrets;
    networkingSecrets = config.hostSpec.networking or {};
    hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
    subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
    hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
    host = if hostInSecrets then subnet.hosts.${hostName} else null;
    domain = networkingSecrets.domain;

    inherit (config.hostSpec.impermanence) backup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;

    adminUser = builtins.head (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
  in
  {
    imports = [
      inputs.hermes-agent.nixosModules.default
    ];

		### read hermes env from sops secrets
		sops.secrets = {
      "services/hermes-agent/env" = {
        sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        owner = adminUser;
        group = "hermes";
        mode = "0440";
      };
    };

		### add user to the hermes group
		users.users.${adminUser}.extraGroups = [ "hermes" ];
		users.groups.hermes = { };

		### configure hermes agent service
		services.hermes-agent = {
			enable = true;
			user = adminUser;
      group = "hermes";
      createUser = false;  # user declared elsewhere; hermes group declared here
			environmentFiles = [ config.sops.secrets."services/hermes-agent/env".path ];
			# extraDependencyGroups = [
			# "anthropic"
			# "firecrawl"
			# ];
			addToSystemPackages = true;

			# environment = {
			# OBSIDIAN_VAULT_PATH = "/home/user/docs/notes";
			# };

			settings = {
				model = {
					provider = "deepseek";
					base_url = "https://api.deepseek.com";
					default = "deepseek-v4-flash";
				};

				# OAuth login required per-host: hermes auth add openai-codex
				fallback_model = {
					provider = "openai-codex";
					base_url = "https://chatgpt.com/backend-api/codex";
					default = "gpt-5.5";
				};

				# fallback_model = {
				# 	provider = "anthropic";
				# 	model = "claude-opus-4-7";
				# };

				# memory = {
				# 	memory_enable = true;
				# 	user_profile_enable = true;
				# 	provider = "hindsight";
				# };
			};
		};

		system.activationScripts = {
			# Shared-world auth can be touched by either user's interactive CLI or the
			# hermes system service. Keep existing auth files group-readable/writable so
			# the gateway can authenticate even if the CLI created/rewrote them.
			"hermes-shared-world-auth-permissions" = ''
			if [ -d /var/lib/hermes/.hermes ]; then
				chown ${adminUser}:hermes /var/lib/hermes /var/lib/hermes/.hermes 2>/dev/null || true
				chmod 2770 /var/lib/hermes /var/lib/hermes/.hermes 2>/dev/null || true
				for f in /var/lib/hermes/.hermes/auth.json /var/lib/hermes/.hermes/auth.lock; do
				if [ -e "$f" ]; then
						chgrp hermes "$f" 2>/dev/null || true
						chmod 0660 "$f" 2>/dev/null || true
				fi
				done
			fi
			'';

			# Skills in the shared Hermes home may be installed from packaged / Nix-store
			# sources with read-only modes (e.g. 0555 dirs and 0444 SKILL.md files).
			# Hermes' CLI and gateway both run as user in group hermes, so make the skill
			# tree group-writable while preserving executable bits on any helper scripts.
			"hermes-shared-world-skill-permissions" = ''
			if [ -d /var/lib/hermes/.hermes/skills ]; then
				chown -R ${adminUser}:hermes /var/lib/hermes/.hermes/skills 2>/dev/null || true
				find /var/lib/hermes/.hermes/skills -type d -exec chmod ug+rwx,o-rwx,g+s {} + 2>/dev/null || true
				find /var/lib/hermes/.hermes/skills -type f -exec chmod ug+rw,o-rwx {} + 2>/dev/null || true
			fi
			'';
		};

		### set permissions on /var/lib/hermes
		systemd.tmpfiles.rules = [
      "d /var/lib/hermes 2770 ${adminUser} hermes - -"
      "d /var/lib/hermes/.hermes 2770 ${adminUser} hermes - -"
    ];

		### configure hermes agent service settings
		systemd.services.hermes-agent.serviceConfig = {
			User = lib.mkForce adminUser;
			Group = "hermes";
			SupplementaryGroups = [
				"users"
				"hermes"
				];

			Environment = [
				"HERMES_HOME=/var/lib/hermes/.hermes"
				"HOME=${config.users.users.${adminUser}.home}"
				];

			ReadWritePaths = [
				"/var/lib/hermes"
				"${config.users.users.${adminUser}.home}"
			];

			TimeoutStopSec = "240s";
		};

		environment.persistence."${backup}" = lib.mkIf hasPersistDir {
      directories = [
				{ directory = "/var/lib/hermes"; user = adminUser; group = "hermes"; mode = "2770"; }
			];
    };
	};
}