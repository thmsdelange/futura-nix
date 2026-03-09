{
  flake.modules.nixos.dashboard = 
  { hostConfig, config, pkgs, ... }:
  let
    glPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.glance or 8080);

    ### TODO: handle this ugly-ass block better across all submodules where it is required
    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    networkingSecrets = config.hostSpec.networking or {};
    hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
    subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
    hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
    host = if hostInSecrets then subnet.hosts.${hostName} else null;
    domain = networkingSecrets.domain;
  in
	{
    services.glance = {
      enable = true;
      settings = {
        server = {
          host = "127.0.0.1";
          port = glPort;
          proxied = true;
        };
        pages = [
          {
            name = "Home";

            columns = [
              {
                size = "small";
                widgets = [
                  {
                    type = "calendar";
                    "first-day-of-week" = "monday";
                  }

                  {
                    type = "rss";
                    limit = 10;
                    "collapse-after" = 3;
                    cache = "12h";
                    feeds = [
                      {
                        url = "https://selfh.st/rss/";
                        title = "selfh.st";
                        limit = 4;
                      }
                      {
                        url = "https://ciechanow.ski/atom.xml";
                      }
                      {
                        url = "https://www.joshwcomeau.com/rss.xml";
                        title = "Josh Comeau";
                      }
                      {
                        url = "https://samwho.dev/rss.xml";
                      }
                      {
                        url = "https://ishadeed.com/feed.xml";
                        title = "Ahmad Shadeed";
                      }
                    ];
                  }

                  {
                    type = "twitch-channels";
                    channels = [
                      "theprimeagen"
                      "j_blow"
                      "giantwaffle"
                      "cohhcarnage"
                      "christitustech"
                      "EJ_SA"
                    ];
                  }
                ];
              }

              {
                size = "full";
                widgets = [
                  {
                    type = "group";
                    widgets = [
                      { type = "hacker-news"; }
                      { type = "lobsters"; }
                    ];
                  }

                  {
                    type = "videos";
                    channels = [
                      "UCXuqSBlHAE6Xw-yeJA0Tunw"
                      "UCR-DXc1voovS8nhAvccRZhg"
                      "UCsBjURrPoezykLs9EqgamOA"
                      "UCBJycsmduvYEL83R_U4JriQ"
                      "UCHnyfMqiRRG1u-2MsSQLbXA"
                    ];
                  }

                  {
                    type = "group";
                    widgets = [
                      {
                        type = "reddit";
                        subreddit = "technology";
                        "show-thumbnails" = true;
                      }
                      {
                        type = "reddit";
                        subreddit = "selfhosted";
                        "show-thumbnails" = true;
                      }
                    ];
                  }
                ];
              }

              {
                size = "small";
                widgets = [
                  {
                    type = "weather";
                    location = "London, United Kingdom";
                    units = "metric";
                    "hour-format" = "12h";
                  }

                  {
                    type = "markets";
                    markets = [
                      { symbol = "SPY"; name = "S&P 500"; }
                      { symbol = "BTC-USD"; name = "Bitcoin"; }
                      { symbol = "NVDA"; name = "NVIDIA"; }
                      { symbol = "AAPL"; name = "Apple"; }
                      { symbol = "MSFT"; name = "Microsoft"; }
                    ];
                  }

                  {
                    type = "releases";
                    cache = "1d";
                    repositories = [
                      "glanceapp/glance"
                      "go-gitea/gitea"
                      "immich-app/immich"
                      "syncthing/syncthing"
                    ];
                  }
                ];
              }
            ];
          }
        ];
      };
    };

		# environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
		# 	hideMounts = true;
		# 	directories = [ "/var/lib/tailscale" ];
		# };

    ### TODO: eventually move to root dir when I don't have other servers fighting for the root dir (DRA30)
    services.caddy.virtualHosts."home.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString glPort}
      '';
    };
	};
}



