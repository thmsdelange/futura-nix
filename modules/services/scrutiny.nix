{
  flake.modules.nixos.scrutiny = 
  { inputs, hostConfig, config, pkgs, lib, ... }:
  let
    scrPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.scrutiny or 8080);
    
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
    services.scrutiny = {
      enable = true;
      settings = {
        web.listen = {
          basepath = ""; #"https://disks.${domain}";
          host = "127.0.0.1";
          port = scrPort;
        };
      };
    };

    environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
      hideMounts = true;
      directories = [ 
        # "/var/lib/scrutiny"
      ];
    };
    # systemd.tmpfiles.rules = lib.mkIf hasPersistDir [
    #   "d /var/lib/pocket-id 0750 pocket-id pocket-id -"
    # ];

    hostSpec.services.caddy.pocketIdApplications."scrutiny" = { subdomain = "disks"; };
    services.caddy.virtualHosts."disks.${domain}" = {
      extraConfig = ''
        @auth {
          path /caddy-security/*
        }

        route @auth {
          authenticate with scrutiny_portal
        }

        route /* {
          authorize with scrutiny_policy
          reverse_proxy 127.0.0.1:${builtins.toString scrPort}
        }
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ "disks" ];
	};
}
