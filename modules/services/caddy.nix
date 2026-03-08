{
  flake.modules.nixos.dns-server = 
  { hostConfig, lib, inputs, pkgs, config, ... }:
  let
    caddyWithPlugins = pkgs.caddy.withPlugins {
      plugins = [ 
        "github.com/caddy-dns/cloudflare@v0.2.3"
      ];
      hash = "sha256-bL1cpMvDogD/pdVxGA8CAMEXazWpFDBiGBxG83SmXLA=";
    };
    sopsRoot = builtins.toString inputs.futura-secrets;

    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    networkingSecrets = config.hostSpec.networking or {};
    hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
    subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
    hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
    host = if hostInSecrets then subnet.hosts.${hostName} else null;
    domain = networkingSecrets.domain;

    inherit (config.hostSpec.impermanence) dontBackup;
    adminUser = builtins.head (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
  in
  {
    sops.secrets = {
      "tokens/cloudflare-api-token" = {
        sopsFile = "${sopsRoot}/sops/shared.yaml";
      };
    };

    services.caddy = {
      enable = true;
      package = caddyWithPlugins;
      environmentFile = config.sops.secrets."tokens/cloudflare-api-token".path; # {CLOUDFLARE_API_TOKEN}
      # email = config.hostSpec.users.${adminUser}.email.user; # this breaks stuff because the caddy module can't really merge this with globalConfig. It seems that email doesn't have to be set if we use cloudflare for dns challenge certs

      globalConfig = ''
        acme_dns cloudflare {$CLOUDFLARE_API_TOKEN}
      '';

      ### TODO: block everything outside local network and tailnet and add this to all services exposed by caddy
      # extraConfig = ''
      #   (ts_host) {
      #     bind {TAILNET_IP}

      #     @blocked not remote_ip 100.64.0.0/10
      #     respond @blocked "Unauthorized" 403
      #   }
      # '';
    };

    networking.firewall.allowedTCPPorts = [ 443 ];

    environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
      hideMounts = true;
      directories = [ 
        "/var/lib/caddy"
        "/var/log/caddy"
      ];
    };
  };
}
