{
  flake.modules.nixos.hermes-agent = 
  { config, lib, hostConfig, inputs, pkgs, user, ... }:
  let
    sgPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.signal-cli or 8818);

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

		# TODO remove after version is bumped to 0.14.5 in nixpkgs
		signal-cli-patched = pkgs.signal-cli.overrideAttrs (old: rec {
			version = "0.14.5";
			src = pkgs.fetchurl {
				url = "https://github.com/AsamK/signal-cli/releases/download/v${version}/signal-cli-${version}.tar.gz";
				hash = "sha256-YtOOv+85iNePQ35zKBg7de5UnRETguZsGvcNPr0816c=";
			};
		});
		signalCliDaemon = pkgs.writeShellScript "hermes-signal-cli-daemon" ''
			set -euo pipefail

			if [ -z "''${SIGNAL_ACCOUNT:-}" ]; then
				echo "SIGNAL_ACCOUNT is not set" >&2
				exit 1
			fi

			exec ${signal-cli-patched}/bin/signal-cli \
				--config /var/lib/hermes-signal-cli \
				--account "$SIGNAL_ACCOUNT" \
				daemon \
				--http 127.0.0.1:${builtins.toString sgPort} \
				--ignore-stories \
				--no-receive-stdout
		'';
	in
	{
		environment.systemPackages = [ 
			signal-cli-patched
			pkgs.jdk17
		];

		sops.secrets = {
      "services/signal-cli/env" = {
        sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        owner = adminUser;
        group = "hermes";
        mode = "0440";
      };
    };

		### hermes needs a signal cli daemon that is always running (at least if we want to use it for messaging)
		### Linking: doas -u hermes env TERM=$TERM COLORTERM=$COLORTERM LANG=$LANG XDG_DATA_HOME=/var/lib/hermes-signal-cli signal-cli --config /var/lib/hermes-signal-cli link -n "HermesAgent"
		systemd.services = {
			hermes-signal-cli = {
				description = "Signal CLI daemon for Hermes Agent";
				wantedBy = [ "multi-user.target" ];
				wants = [ "network-online.target" ];
				after = [ "network-online.target" ];

				serviceConfig = {
					User = adminUser;
					Group = "hermes";
					EnvironmentFile = config.sops.secrets."services/signal-cli/env".path;
					StateDirectory = "hermes-signal-cli";
					StateDirectoryMode = "0700";
					ExecStart = signalCliDaemon;
					Restart = "on-failure";
					RestartSec = "10s";
				};
			};

			### be sure that hermes only starts after signal-cli is up
			hermes-agent = {
				wants = [ "hermes-signal-cli.service" ];
				after = [ "hermes-signal-cli.service" ];
			};
		};

		services.hermes-agent.settings.signal.gateway_restart_notification = false;

		environment.persistence."${backup}" = lib.mkIf hasPersistDir {
      directories = [
        {
          directory = "/var/lib/hermes-signal-cli";
          user = adminUser;
          group = "hermes";
          mode = "0700";
        }
      ];
    };
	};
}