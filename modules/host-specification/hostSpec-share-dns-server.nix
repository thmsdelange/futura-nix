### shares split horizon subdomains across dns servers
topLevel: {
  flake.modules.nixos.share-split-horizon =
    { lib, ... }:
    {
      hostSpec.services.adguardhome.sharedSplitHorizonSubdomains = 
        lib.concatMap (nixosConfig: 
          let
            networkingSecrets = nixosConfig.config.hostSpec.networking or {};
            hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
            subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
            hostName = nixosConfig.config.networking.hostName;
            hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
            host = if hostInSecrets then subnet.hosts.${hostName} else null;
          in
          lib.optionals (host != null) (
            map (sub: {
              subdomain = sub;
              ip = host.ip;
              tailip = host.tailip;
            }) nixosConfig.config.hostSpec.services.adguardhome.splitHorizonSubdomains
          )
        ) (lib.attrValues topLevel.config.flake.nixosConfigurations);
    };
}