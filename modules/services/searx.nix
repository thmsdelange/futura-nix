{
  flake.modules.nixos.searx = 
  { hostConfig, config, pkgs, lib, inputs, ... }:
  let
    sPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.searx or 8888);

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
    subdomain = "search";

    inherit (config.hostSpec.impermanence) backupStorage dontBackup;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
  in
	{
    sops.secrets = lib.mkIf hasSecrets {
      "services/searx/secret-key" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
		};

    services.searx = {
      enable = true;
      package = pkgs.unstable.searxng;
      redisCreateLocally = true;

      # UWSGI configuration
      # configureUwsgi = true;

      # uwsgiConfig = {
      #   socket = "/run/searx/searx.sock";
      #   http = ":8888";
      #   chmod-socket = "660";
      # };

      # Searx configuration
      settings = {
        # Instance settings
        general = {
          debug = false;
          instance_name = "DeLorean Search";
          donation_url = false;
          contact_url = false;
          privacypolicy_url = false;
          enable_metrics = false;
        };

        # User interface
        ui = {
          static_use_hash = true;
          default_locale = "en";
          query_in_title = true;
          infinite_scroll = false;
          center_alignment = true;
          default_theme = "simple";
          theme_args.simple_style = "dark";
          search_on_category_select = true;
          hotkeys = "vim";
        };

        # Search engine settings
        search = {
          safe_search = 1;
          autocomplete_min = 2;
          autocomplete = "duckduckgo";
          ban_time_on_fail = 5;
          max_ban_time_on_fail = 120;
        };

        # Server configuration
        server = {
          base_url = "https://${subdomain}.${domain}";
          port = sPort;
          bind_address = "127.0.0.1";
          secret_key = config.sops.secrets."services/searx/secret-key".path;
          # limiter = true;
          public_instance = false;
          image_proxy = true;
          method = "POST";
        };

        # Search engines
        # engines = lib.mapAttrsToList (name: value: { inherit name; } // value) {
        #   "duckduckgo".disabled = false;
        #   "brave".disabled = true;
        #   "bing".disabled = false;
        #   "mojeek".disabled = true;
        #   "mwmbl".disabled = false;
        #   "mwmbl".weight = 0.4;
        #   "qwant".disabled = true;
        #   "crowdview".disabled = false;
        #   "crowdview".weight = 0.5;
        #   "curlie".disabled = true;
        #   "ddg definitions".disabled = false;
        #   "ddg definitions".weight = 2;
        #   "wikibooks".disabled = false;
        #   "wikidata".disabled = false;
        #   "wikiquote".disabled = true;
        #   "wikisource".disabled = true;
        #   "wikispecies".disabled = false;
        #   "wikispecies".weight = 0.5;
        #   "wikiversity".disabled = false;
        #   "wikiversity".weight = 0.5;
        #   "wikivoyage".disabled = false;
        #   "wikivoyage".weight = 0.5;
        #   "currency".disabled = true;
        #   "dictzone".disabled = true;
        #   "lingva".disabled = true;
        #   "bing images".disabled = false;
        #   "brave.images".disabled = true;
        #   "duckduckgo images".disabled = true;
        #   "google images".disabled = false;
        #   "qwant images".disabled = true;
        #   "1x".disabled = true;
        #   "artic".disabled = false;
        #   "deviantart".disabled = false;
        #   "flickr".disabled = true;
        #   "imgur".disabled = false;
        #   "library of congress".disabled = false;
        #   "material icons".disabled = true;
        #   "material icons".weight = 0.2;
        #   "openverse".disabled = false;
        #   "pinterest".disabled = true;
        #   "svgrepo".disabled = false;
        #   "unsplash".disabled = false;
        #   "wallhaven".disabled = false;
        #   "wikicommons.images".disabled = false;
        #   "yacy images".disabled = true;
        #   "bing videos".disabled = false;
        #   "brave.videos".disabled = true;
        #   "duckduckgo videos".disabled = true;
        #   "google videos".disabled = false;
        #   "qwant videos".disabled = false;
        #   "dailymotion".disabled = true;
        #   "google play movies".disabled = true;
        #   "invidious".disabled = true;
        #   "odysee".disabled = true;
        #   "peertube".disabled = false;
        #   "piped".disabled = true;
        #   "rumble".disabled = false;
        #   "sepiasearch".disabled = false;
        #   "vimeo".disabled = true;
        #   "youtube".disabled = false;
        #   "brave.news".disabled = true;
        #   "google news".disabled = true;
        # };

        # # Outgoing requests
        # outgoing = {
        #   request_timeout = 3.0;
        #   max_request_timeout = 8.0;
        #   pool_connections = 100;
        #   pool_maxsize = 15;
        #   enable_http2 = true;
        # };

        # Enabled plugins
        enabled_plugins = [
          "Basic Calculator"
          "Hash plugin"
          "Tor check plugin"
          "Open Access DOI rewrite"
          "Hostnames plugin"
          "Unit converter plugin"
          "Tracker URL remover"
        ];

        # plugins = {
        #   searx.plugins.calculator.SXNGPlugin.active = true;
        # };
  #       searx.plugins.calculator.SXNGPlugin:
  #   active: true

  # searx.plugins.infinite_scroll.SXNGPlugin:
  #   active: false

  # searx.plugins.hash_plugin.SXNGPlugin:
  #   active: true

  # searx.plugins.self_info.SXNGPlugin:
  #   active: true

  # searx.plugins.tracker_url_remover.SXNGPlugin:
  #   active: true

  # searx.plugins.unit_converter.SXNGPlugin:
  #   active: true

  # searx.plugins.ahmia_filter.SXNGPlugin:
  #   active: true

  # searx.plugins.hostnames.SXNGPlugin:
  #   active: true

  # searx.plugins.oa_doi_rewrite.SXNGPlugin:
  #   active: false

  # searx.plugins.tor_check.SXNGPlugin:
  #   active: false
      };
    };

    # # Systemd configuration
    # systemd.services.nginx.serviceConfig.ProtectHome = false;

    # # User management
    # users.groups.searx.members = ["nginx"];

    # # Nginx configuration
    # services.nginx = {
    #   enable = true;
    #   recommendedGzipSettings = true;
    #   recommendedOptimisation = true;
    #   recommendedProxySettings = true;
    #   recommendedTlsSettings = true;
    #   virtualHosts = {
    #     "search.example.com" = {
    #       forceSSL = true;
    #       sslCertificate = "...";
    #       sslCertificateKey = "...";
    #       locations = {
    #         "/" = {
    #           extraConfig = ''
    #             uwsgi_pass unix:${config.services.searx.uwsgiConfig.socket};
    #           '';
    #         };
    #       };
    #     };
    #   };
    # };

    # environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
    #   directories = [ 
    #     "/var/lib/postgresql"
    #   ];
    # };

    services.caddy.virtualHosts."${subdomain}.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString sPort}
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
	};
}