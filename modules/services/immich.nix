{
  flake.modules.nixos.immich = 
  { hostConfig, config, pkgs, lib, ... }:
  let
    imPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.immich or 2283);

    ### TODO: handle this ugly-ass block better across all submodules where it is required
    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    networkingSecrets = config.hostSpec.networking or {};
    hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
    subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
    hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
    host = if hostInSecrets then subnet.hosts.${hostName} else null;
    domain = networkingSecrets.domain;
    subdomain = "photos";

    inherit (config.hostSpec.impermanence) backupStorage dontBackup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
  in
	{
    services.immich = {
      enable = true;
      port = imPort;
      host = "127.0.0.1";
      # mediaLocation = ${if hasPersistDir then "${backupStorage}/immich" else "/mnt/immich"};
      settings.server.externalDomain = "https://photos.${domain}";
      environment = {
        IMMICH_LOG_LEVEL = "verbose";
      };
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
	};
}
