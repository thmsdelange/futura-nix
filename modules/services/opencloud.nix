{
  flake.modules.nixos.opencloud = 
  { inputs, hostConfig, config, pkgs, lib, ... }:
  let
    ocPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.opencloud or 9200);
    rcPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.radicale or 5232);
    
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
  in
	{
    sops.secrets = lib.mkIf hasSecrets {
			"services/opencloud/initial-admin-passwd" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
      "services/opencloud/pocket-id-client-id" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
      # "services/opencloud/pocket-id-client-secret" = {
			# 	sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			# };
		};

    # Render a single env file that systemd will load, combining all static
    # config with the runtime secrets. The opencloud service user needs to
    # be able to read this.
    sops.templates."oc-env" = lib.mkIf hasSecrets {
      owner = "opencloud";
      content = ''
        PROXY_TLS=false
        OC_INSECURE=true
        # discard opencloud oidc
        OC_EXCLUDE_RUN_SERVICES=idp
        OC_OIDC_ISSUER=https://id.${domain}
        # OC_BASE_DATA_PATH=${if hasPersistDir then "${backupStorage}/opencloud" else "/mnt/opencloud"};
        PROXY_USER_OIDC_CLAIM=preferred_username
        PROXY_USER_CS3_CLAIM=username
        GRAPH_USERNAME_MATCH=none
        PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD=none
        GRAPH_ASSIGN_DEFAULT_USER_ROLE=false
        WEB_OIDC_CLIENT_ID=${config.sops.placeholder."services/opencloud/pocket-id-client-id"}
        INITIAL_ADMIN_PASSWORD=${config.sops.placeholder."services/opencloud/initial-admin-passwd"}
        SMTP_HOST=${config.sops.placeholder."smtp/host"}
        SMTP_PORT=${config.sops.placeholder."smtp/port"}
        SMTP_SENDER=admin@${domain}
        SMTP_USERNAME=${config.sops.placeholder."smtp/user"}
        SMTP_PASSWORD=${config.sops.placeholder."smtp/password"}
        SMTP_TRANSPORT_ENCRYPTION=StartTLS
        SMTP_INSECURE=false
        SMTP_AUTHENTICATION=auto
      '';
    };

    environment.etc."opencloud/csp.yaml".text = ''
      directives:
        child-src:
          - "'self'"
        connect-src:
          - "'self'"
          - 'blob:'
          - 'https://raw.githubusercontent.com/opencloud-eu/awesome-apps/'
          - 'https://id.${domain}/'
        default-src:
          - "'none'"
        font-src:
          - "'self'"
        frame-ancestors:
          - "'self'"
        frame-src:
          - "'self'"
          - 'blob:'
        img-src:
          - "'self'"
          - 'data:'
          - 'blob:'
          - 'https://raw.githubusercontent.com/opencloud-eu/awesome-apps/'
        manifest-src:
          - "'self'"
        media-src:
          - "'self'"
        object-src:
          - "'self'"
          - 'blob:'
        script-src:
          - "'self'"
          - "'unsafe-inline'"
          - "'unsafe-eval'"
          - 'https://id.${domain}/'
        style-src:
          - "'self'"
          - "'unsafe-inline'"
    '';

    services.opencloud = {
      enable = true;
      package = pkgs.unstable.opencloud;
      url = "https://ocloud.${domain}";
      address = "127.0.0.1";
      port = ocPort;
      environmentFile = lib.mkIf hasSecrets config.sops.templates."oc-env".path;
      environment = lib.mkIf (!hasSecrets) {
        PROXY_TLS = "false";
        OC_INSECURE = "true";
        INITIAL_ADMIN_PASSWORD = "super-secret-password";
      };
      settings = {
        proxy = {
          csp_config_file_location = "/etc/opencloud/csp.yaml";
          auto_provision_accounts = true;
          oidc = {
            rewrite_well_known = true;
          };
          role_assignment = {
            driver = "oidc";
            oidc_role_mapper = {
              role_claim = "opencloudRole";
              role_mapping = [
                {
                  role_name = "admin";
                  claim_value = "opencloudAdmin";
                }
                {
                  role_name = "user";
                  claim_value = "opencloudUser";
                }
              ];
            };
          };
          ### Radicale proxy
          additional_policies = [
            {
              name = "default";
              routes = [
                {
                  endpoint = "/caldav/";
                  backend = "http://127.0.0.1:${builtins.toString rcPort}";
                  remote_user_header = "X-Remote-User";
                  skip_x_access_token = true;
                  additional_headers = [{"X-Script-Name" = "/caldav";}];
                }
                {
                  endpoint = "/.well-known/caldav";
                  backend = "http://127.0.0.1:${builtins.toString rcPort}";
                  remote_user_header = "X-Remote-User";
                  skip_x_access_token = true;
                  additional_headers = [{"X-Script-Name" = "/caldav";}];
                }
                {
                  endpoint = "/carddav/";
                  backend = "http://127.0.0.1:${builtins.toString rcPort}";
                  remote_user_header = "X-Remote-User";
                  skip_x_access_token = true;
                  additional_headers = [{"X-Script-Name" = "/carddav";}];
                }
                {
                  endpoint = "/.well-known/carddav";
                  backend = "http://127.0.0.1:${builtins.toString rcPort}";
                  remote_user_header = "X-Remote-User";
                  skip_x_access_token = true;
                  additional_headers = [{"X-Script-Name" = "/carddav";}];
                }
              ];
            }
          ];
        };
        web = {
          web = {
            config = {
              oidc = {
                scope = "openid profile email opencloud_roles";
              };
            };
          };
        };
      };
    };

    ### Radicale setup
    services.radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [ "127.0.0.1:${builtins.toString rcPort}" ];
          ssl = false; # disable SSL, only use when behind reverse proxy
        };
        auth = {
          type = "http_x_remote_user"; # disable authentication, and use the username that OpenCloud provides
        };
        web = {
          type = "none";
        };
        storage = {
          filesystem_folder = "/var/lib/radicale/collections";
          predefined_collections = builtins.toJSON {
            def-addressbook = {
              "D:displayname" = "OpenCloud Address Book";
              tag = "VADDRESSBOOK";
            };
            def-calendar = {
              "C:supported-calendar-component-set" = "VEVENT,VJOURNAL,VTODO";
              "D:displayname" = "OpenCloud Calendar";
              tag = "VCALENDAR";
            };
          };
        };
        logging = {
          level = "debug"; # optional, enable debug logging
          bad_put_request_content = true; # only if level=debug
          request_header_on_debug = true; # only if level=debug
          request_content_on_debug = true; # only if level=debug
          response_content_on_debug = true; # only if level=debug
        };
      };
    };

    environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
      hideMounts = true;
      directories = [ 
        # "/var/lib/opencloud"
        "/var/lib/radicale"
      ];
    };
    # systemd.tmpfiles.rules = lib.mkIf hasPersistDir [
    #   "d /var/lib/private 0700 root root -"
    # ];

    systemd.services.opencloud.restartTriggers = [
      config.environment.etc."opencloud/csp.yaml".source
      config.sops.templates."oc-env".path
    ];

    services.caddy.virtualHosts."ocloud.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString ocPort}
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ "ocloud" ];
	};
}
