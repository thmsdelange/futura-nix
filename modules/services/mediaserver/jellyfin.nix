{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      inherit (inputs.nixflix.lib.jellyfinPlugins) fromRepo;

      jfPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.jellyfin or 8096);

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
      subdomain = "binge";

      inherit (config.hostSpec.impermanence) backupStorage dontBackup;
      hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
      adminUser = builtins.head (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
    in
    {
      sops.secrets = lib.mkIf hasSecrets {
        "services/jellyfin/admin-password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/jellyfin/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/jellyfin/pocket-id-client-id" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/jellyfin/pocket-id-client-secret" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/opensubtitles/api-key" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
        "services/opensubtitles/password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      ### hardware acceleration
      users.users.jellyfin.extraGroups = [ "video" "render" ];
      systemd.services.jellyfin.serviceConfig.DeviceAllow = [ "/dev/dri/renderD128 rw" ];
      hardware.graphics.enable = true;

      nixflix.jellyfin = {
        enable = true;
        package = pkgs.unstable.jellyfin;
        apiKey._secret = config.sops.secrets."services/jellyfin/api-key".path;
        # cacheDir = fast;
        subdomain = subdomain;
        network.enableRemoteAccess = true;
        branding = {
          loginDisclaimer = ''
            <form action="https://${subdomain}.${domain}/sso/OID/start/PocketID">
              <button class="raised block emby-button button-submit">
                Sign in with PocketID
              </button>
            </form>
          '';

          customCss = ''
            @import url('https://cdn.jsdelivr.net/gh/KartoffelChipss/NeutralFin@latest/theme/neutralfin-minified.css');

            a.raised.emby-button {
              padding: 0.9em 1em;
              color: inherit !important;
            }

            .disclaimerContainer {
              display: block;
            }
          '';
        };

        users = {
          localadmin = {
            mutable = false;
            policy.isAdministrator = true;
            password._secret = config.sops.secrets."services/jellyfin/admin-password".path;
          };
        };

        libraries =
          let
            subtitleSettings = {
              subtitleDownloadLanguages = [
                "eng"
                "dut"
                "ger"
              ];
              requirePerfectSubtitleMatch = true;
            };
          in
          {
            Shows = subtitleSettings;
            Anime = subtitleSettings;
            Movies = subtitleSettings;
            Music = lib.mkForce null;
          };

        ### hardware acceleration
        encoding = {
          hardwareAccelerationType = "qsv";

          hardwareDecodingCodecs = [
            "h264"
            "hevc"
            "mpeg2video"
            "vc1"
            "vp9"
            "vp8"
            "av1"
          ];
        };

        system = {
          serverName = "Binge - DeLorean";
          enableGroupingMoviesIntoCollections = true;
          pluginRepositories = {
            "Intro Skipper" = {
              url = "https://raw.githubusercontent.com/intro-skipper/manifest/d56c137ae182c04a894dd700c25b04c8d2eba855/10.11/manifest.json";
              hash = "sha256-ENwn7Ei3WU2REcxnFNwzF6NGFUcnH2kJ4E5TKbpcDII=";
            };
            "Jellyfin SSO" = {
              url = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/4ee785577e77b703f206c7a33f4123986d90f2c2/manifest.json";
              hash = "sha256-KeMfhBGoeeC3dW329sr1K0dnUaM35rYdAhr2y/o3vp4=";
            };
          };
          metadataPath = "${config.nixflix.stateDir}/jellyfin/metadata";
        };

        plugins = {
          subbuzz = {
            enable = true;

            config = {
              OpenSubApiKey._secret = config.sops.secrets."services/opensubtitles/api-key".path;
              OpenSubUserName = config.hostSpec.users.${adminUser}.email.user;
              OpenSubPassword._secret = config.sops.secrets."services/opensubtitles/password".path;
              EnableOpenSubtitles = true;
              EnableYifySubtitles = true;

              Cache.SubLifeInMinutes = "Always";
            };
          };

          "Subtitle Extract" = {
            enable = true;

            config.ExtractionDuringLibraryScan = true;
          };

          "Intro Skipper" = {
            package = fromRepo {
              version = "1.10.11.17";
              hash = "sha256-cfEnLqKeEGpQSth3NPjDnxCkgv2pePfgCXfVIOrYSiQ=";
            };
            config = {
              ExcludeSeries = "";
              AutoDetectIntros = true;
              AnalyzeSeasonZero = false;
              PreferChromaprint = false;
              CacheFingerprints = true;
              UseAlternativeBlackFrameAnalyzer = false;
              UpdateMediaSegments = true;
              RebuildMediaSegments = true;
              ScanIntroduction = true;
              ScanCredits = true;
              ScanRecap = true;
              ScanPreview = true;
              ScanCommercial = false;
              AnalysisPercent = "25";
              AnalysisLengthLimit = "10";
              FullLengthChapters = false;
              SkipFirstEpisode = false;
              SkipFirstEpisodeAnime = false;
              MinimumIntroDuration = "15";
              MaximumIntroDuration = "120";
              MinimumCreditsDuration = "15";
              MaximumCreditsDuration = "450";
              MaximumMovieCreditsDuration = "900";
              MinimumRecapDuration = "15";
              MaximumRecapDuration = "120";
              MinimumPreviewDuration = "15";
              MaximumPreviewDuration = "120";
              MinimumCommercialDuration = "15";
              MaximumCommercialDuration = "120";
              BlackFrameMinimumPercentage = "85";
              BlackFrameThreshold = "28";
              UseChapterMarkersBlackFrame = true;
              AdjustIntroBasedOnChapters = true;
              AdjustIntroBasedOnSilence = true;
              SnapToKeyframe = true;
              EndSnapThreshold = "2";
              AdjustWindowInward = "5";
              AdjustWindowOutward = "2";
              ChapterAnalyzerIntroductionPattern = "(^|\\s)(Intro|Introduction|OP|Opening)(?!\\sEnd)(\\s|$)";
              ChapterAnalyzerEndCreditsPattern = "(^|\\s)(Credits?|ED|Ending|Outro)(?!\\sEnd)(\\s|$)";
              ChapterAnalyzerPreviewPattern = "(^|\\s)(Preview|PV|Sneak\\s?Peek|Coming\\s?(Up|Soon)|Next\\s+(time|on|episode)|Extra|Teaser|Trailer)(?!\\sEnd)(\\s|:|$)";
              ChapterAnalyzerRecapPattern = "(^|\\s)(Re?cap|Sum{1,2}ary|Prev(ious(ly)?)?|(Last|Earlier)(\\s\\w+)?|Catch[ -]up)(?!\\sEnd)(\\s|:|$)";
              ChapterAnalyzerCommercialPattern = "(^|\\s)(Ad(vert(isement)?)?|Commercial)(?!\\sEnd)(\\s|$)";
              IntroEndOffset = "0";
              IntroStartOffset = "0";
              MaximumFingerprintPointDifferences = 6;
              MaximumTimeSkip = 3.5;
              InvertedIndexShift = 2;
              SilenceDetectionMaximumNoise = "-50";
              SilenceDetectionMinimumDuration = "0.33";
              MaxParallelism = "2";
              ProcessThreads = "0";
              ProcessPriority = "BelowNormal";
              UseFileTransformationPlugin = false;
              SkipbuttonHideDelay = "8";
              EnableMainMenu = true;
              FileTransformationPluginEnabled = false;
            };
          };

          "SSO Authentication" = {
            apiName = "SSO-Auth";
            package = fromRepo {
              version = "4.0.0.4";
              hash = "sha256-MJTyE6CeVLk7mlugauJ/F6bpi1kYwNtzNmQeH3+CFeQ=";
            };
            config = {
              SamlConfigs = { };
              OidConfigs = {
                PocketID = {
                  OidProviderName = "PocketID";
                  OidEndpoint = "https://id.${domain}";
                  OidClientId._secret = config.sops.secrets."services/jellyfin/pocket-id-client-id".path;
                  OidSecret._secret = config.sops.secrets."services/jellyfin/pocket-id-client-secret".path;
                  RoleClaim = "groups";
                  DefaultProvider = "Jellyfin.Server.Implementations.Users.DefaultAuthenticationProvider";
                  DefaultUsernameClaim = "preferred_username";
                  AvatarUrlFormat = "@{picture}";
                  SchemeOverride = "https";
                  PortOverride = null;
                  Enabled = true;
                  EnableAuthorization = true;
                  EnableAllFolders = true;
                  EnableFolderRoles = false;
                  EnableLiveTvRoles = false;
                  EnableLiveTv = false;
                  EnableLiveTvManagement = false;
                  DisableHttps = false;
                  DisablePushedAuthorization = false;
                  DoNotValidateEndpoints = false;
                  DoNotValidateIssuerName = false;
                  DoNotLoadProfile = false;
                  Roles = [
                    "family"
                    "admin"
                  ];
                  AdminRoles = [ "admin" ];
                  LiveTvRoles = [ ];
                  LiveTvManagementRoles = [ ];
                  OidScopes = [ "groups" ];
                  EnabledFolders = [ ];
                  FolderRoleMapping = [ ];
                };
              };
            };
          };
        };
      };

      environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
        hideMounts = true;
        directories = [
          "/var/cache/jellyfin"
        ];
      };
      systemd.tmpfiles.rules = [
        "d /var/cache/jellyfin 0700 146 146 -"
        "d /var/cache/jellyfin/transcodes 0700 146 146 -"
      ];

      services.caddy.virtualHosts."${subdomain}.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${builtins.toString jfPort}
        '';
      };
      hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
    };
}