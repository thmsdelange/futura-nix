{
  flake.modules.nixos.gaggimate = 
  { hostConfig, config, pkgs, lib, ... }:
  let
    gmPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.gaggimate or 8080);

    ### TODO: handle this ugly-ass block better across all submodules where it is required
    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    networkingSecrets = config.hostSpec.networking or {};
    hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
    subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
    hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
    host = if hostInSecrets then subnet.hosts.${hostName} else null;
    domain = networkingSecrets.domain;
    subdomain = "caffeine";
  in
	{

    hostSpec.services.caddy.pocketIdApplications."gaggimate" = { inherit subdomain; };
    services.caddy.virtualHosts."${subdomain}.${domain}" = {
      extraConfig = ''
        @auth {
          path /caddy-security/*
        }

        route @auth {
          authenticate with gaggimate_portal
        }

        route /* {
          authorize with gaggimate_policy
          reverse_proxy 10.10.10.10:${builtins.toString gmPort}
        }
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
	};
}
