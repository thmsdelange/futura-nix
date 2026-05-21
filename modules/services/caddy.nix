{
  flake.modules.nixos.dns-server = 
  { hostConfig, lib, inputs, pkgs, config, ... }:
  let
    caddyWithPlugins = (pkgs.caddy.withPlugins {
      plugins = [ 
        "github.com/caddy-dns/cloudflare@v0.2.3"
        "github.com/greenpau/caddy-security@v1.1.56"
        # "pkg.jsn.cam/caddy-defender@v0.10.0"
      ];
      hash = "sha256-7e1QYP+DBIZ/izYPYrb9HGbC+AEPnx3z+T/GyADOAW0=";
    }).overrideAttrs
      (old: {
        # Patch token validation regex to accept cfut_/cfat_ tokens (>50 chars).
        # Upstream fix: github.com/caddy-dns/cloudflare/pull/123
        postPatch = (old.postPatch or "") + ''
          sed -i 's/{35,50}/{35,256}/' vendor/github.com/caddy-dns/cloudflare/cloudflare.go
        '';
      });
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
    sops.secrets = lib.mkIf hasSecrets (lib.mkMerge (
      [
        {
          "tokens/cloudflare-api-token" = {
            sopsFile = "${sopsRoot}/sops/shared.yaml";
          };
        }
      ]
      ++ lib.mapAttrsToList (name: app: {
        "services/${name}/pocket-id-client-id" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
          owner = config.services.caddy.user;
        };
        "services/${name}/pocket-id-client-secret" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
          owner = config.services.caddy.user;
        };
      }) config.hostSpec.services.caddy.pocketIdApplications
    ));

    sops.templates."caddyEnv" = lib.mkIf hasSecrets {
      owner = config.services.caddy.user;
      content = lib.concatStringsSep "\n" (
        [ "CLOUDFLARE_API_TOKEN=${config.sops.placeholder."tokens/cloudflare-api-token"}" ]
        ++ lib.concatMap (name: [
          "${lib.toUpper name}_POCKET_ID_CLIENT_ID=${config.sops.placeholder."services/${name}/pocket-id-client-id"}"
          "${lib.toUpper name}_POCKET_ID_CLIENT_SECRET=${config.sops.placeholder."services/${name}/pocket-id-client-secret"}"
        ]) (lib.attrNames config.hostSpec.services.caddy.pocketIdApplications)
      );
    };

    systemd.services.caddy = {
      after = [ "adguardhome.service" ];
      wants = [ "adguardhome.service" ];
    };

    services.caddy = {
      enable = true;
      package = caddyWithPlugins;
      enableReload = false;
      logFormat = lib.mkForce "level ERROR";
      environmentFile = config.sops.templates."caddyEnv".path;
      # email = config.hostSpec.users.${adminUser}.email.user; # this breaks stuff because the caddy module can't really merge this with globalConfig. It seems that email doesn't have to be set if we use cloudflare for dns challenge certs
      globalConfig = ''
        acme_dns cloudflare {$CLOUDFLARE_API_TOKEN}

        order authenticate before respond
        ${lib.optionalString (config.hostSpec.services.caddy.pocketIdApplications != { }) ''
          security {
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: app: ''
                oauth identity provider ${name} {
                  delay_start 3
                  realm ${name}
                  driver generic
                  client_id {${"$"}${lib.toUpper name}_POCKET_ID_CLIENT_ID}
                  client_secret {${"$"}${lib.toUpper name}_POCKET_ID_CLIENT_SECRET}
                  scopes openid email profile
                  base_auth_url https://id.${domain}
                  metadata_url https://id.${domain}/.well-known/openid-configuration
                }

                authentication portal ${name}_portal {
                  crypto default token lifetime 3600
                  enable identity provider ${name}
                  trust login redirect uri domain exact ${app.subdomain}.${domain} path prefix /
                  cookie insecure off
                  cookie domain ${app.subdomain}.${domain}
                  transform user {
                    match realm ${name}
                    action add role user
                  }
                }

                authorization policy ${name}_policy {
                  set auth url /caddy-security/oauth2/${name}
                  allow roles user
                  inject headers with claims
                }
              '') config.hostSpec.services.caddy.pocketIdApplications
            )}
          }
        ''}
      '';

      ### TODO: block everything outside local network and tailnet and add this to all services exposed by caddy
      # extraConfig = ''
      #   (ts_host) {
      #     bind {TAILNET_IP}

      #     @blocked not remote_ip 100.64.0.0/10
      #     respond @blocked "Unauthorized" 403
      #   }
      # '';

      # extraConfig = ''
      #   (blackholeCrawlers) {
      #     defender drop {
      #       ranges aliyun vpn aws deepseek githubcopilot gcloud azurepubliccloud openai mistral vultr digitalocean linode huawei
      #     }
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
