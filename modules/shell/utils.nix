{
  flake.modules.homeManager.shell =
  { pkgs, config, hostConfig, inputs, lib, ... }: 
  let
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

    inherit (config.hostSpec.impermanence) backupStorage dontBackup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    adminUser = builtins.head (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
  in
  {
    home.packages = with pkgs; [
      zip
      unzip
      wget
      jq
      rclone
    ];

    home.persistence."${dontBackup}".directories = lib.mkIf hasPersistDir [ ".config/rclone" ];
  };
}
