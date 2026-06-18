{
  flake.modules.nixos.hermes-agent = 
  { config, lib, hostConfig, inputs, pkgs, user, ... }:
  let
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
		environment.systemPackages = [ 
			inputs.codex-cli-nix.packages.${pkgs.system}.default
		];
	};
}