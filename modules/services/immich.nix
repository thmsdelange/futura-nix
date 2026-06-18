{
  flake.modules.nixos.immich = 
  { hostConfig, config, pkgs, lib, inputs, ... }:
  let
    imPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.immich or 2283);

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
    subdomain = "photos";

    inherit (config.hostSpec.impermanence) backupStorage dontBackup backupFast dontBackupFast;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    hasNvme = config.hostSpec.disks.zfs.nvme.enable;
  in
	{
    sops.secrets = lib.mkIf hasSecrets {
      "services/immich/pocket-id-client-id" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
      "services/immich/pocket-id-client-secret" = {
				sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
			};
		};

    users.users.immich.extraGroups = [ "video" "render" ];
    hardware.graphics.enable = true;
    systemd.services.immich-server.serviceConfig.DeviceAllow = [ "/dev/dri/renderD128" ];
    environment.systemPackages = with pkgs; [ immich-cli ];

    services.immich = {
      enable = true;
      package = pkgs.unstable.immich;
      port = imPort;
      host = "127.0.0.1";
      mediaLocation = if hasPersistDir then (if hasNvme then "${backupFast}/immich/upload" else "${backupStorage}/immich/upload") else "/mnt/immich";
      database = {
        enable = true;
        createDB = true;
      };
      redis.enable = true;

      settings = {
        backup = {
          database = {
            cronExpression = "0 02 * * *";
            enabled = true;
            keepLastAmount = 14;
          };
        };

        ffmpeg = {
          accel = "vaapi";
          preferredHwDevice = "/dev/dri/renderD128";  
          accelDecode = true;
          acceptedAudioCodecs = [
            "aac"
            "mp3"
            "opus"
          ];
          acceptedContainers = [
            "mov"
            "ogg"
            "webm"
          ];
          acceptedVideoCodecs = [ "h264" ];
          bframes = -1;
          cqMode = "auto";
          crf = 23;
          gopSize = 0;
          maxBitrate = "0";
          preset = "default";
          refs = 0;
          targetAudioCodec = "aac";
          targetResolution = "original";
          targetVideoCodec = "h264";
          temporalAQ = false;
          threads = 0;
          tonemap = "hable";
          transcode = "required";
          twoPass = false;
        };

        image = {
          colorspace = "p3";
          extractEmbedded = false;
          fullsize = {
            enabled = false;
            format = "jpeg";
            quality = 80;
          };
          preview = {
            format = "jpeg";
            quality = 80;
            size = 1440;
          };
          thumbnail = {
            format = "webp";
            quality = 80;
            size = 250;
          };
        };

        job = {
          backgroundTask = {
            concurrency = 5;
          };
          faceDetection = {
            concurrency = 2;
          };
          library = {
            concurrency = 5;
          };
          metadataExtraction = {
            concurrency = 5;
          };
          migration = {
            concurrency = 5;
          };
          notifications = {
            concurrency = 5;
          };
          ocr = {
            concurrency = 1;
          };
          search = {
            concurrency = 5;
          };
          sidecar = {
            concurrency = 5;
          };
          smartSearch = {
            concurrency = 2;
          };
          thumbnailGeneration = {
            concurrency = 3;
          };
          videoConversion = {
            concurrency = 1;
          };
        };

        library = {
          scan = {
            cronExpression = "0 0 * * *";
            enabled = true;
          };
          watch = {
            enabled = false;
          };
        };

        logging = {
          enabled = true;
          level = "log";
        };

        machineLearning = {
          availabilityChecks = {
            enabled = true;
            interval = 30000;
            timeout = 2000;
          };
          clip = {
            enabled = true;
            modelName = "ViT-B-32__openai";
          };
          duplicateDetection = {
            enabled = true;
            maxDistance = 0.01;
          };
          enabled = true;
          facialRecognition = {
            enabled = true;
            maxDistance = 0.5;
            minFaces = 3;
            minScore = 0.7;
            modelName = "buffalo_l";
          };
          ocr = {
            enabled = true;
            maxResolution = 736;
            minDetectionScore = 0.5;
            minRecognitionScore = 0.8;
            modelName = "PP-OCRv5_mobile";
          };
          urls = [ "http://127.0.0.1:3003" ];
        };

        map = {
          darkStyle = "https://tiles.immich.cloud/v1/style/dark.json";
          enabled = true;
          lightStyle = "https://tiles.immich.cloud/v1/style/light.json";
        };

        metadata = {
          faces = {
            import = false;
          };
        };

        newVersionCheck = {
          enabled = true;
        };

        nightlyTasks = {
          clusterNewFaces = true;
          databaseCleanup = true;
          generateMemories = true;
          missingThumbnails = true;
          startTime = "00:00";
          syncQuotaUsage = true;
        };

        notifications = {
          smtp = {
            enabled = false;
            from = "";
            replyTo = "";
            transport = {
              host = "";
              ignoreCert = false;
              password = "";
              port = 587;
              secure = false;
              username = "";
            };
          };
        };

        oauth = {
          enabled = true;
          autoLaunch = true;
          autoRegister = true;
          buttonText = "Login with OAuth";
          clientId._secret = config.sops.secrets."services/immich/pocket-id-client-id".path;
          clientSecret._secret = config.sops.secrets."services/immich/pocket-id-client-secret".path;
          defaultStorageQuota = null;
          issuerUrl = "https://id.${domain}";
          mobileOverrideEnabled = false;
          mobileRedirectUri = "";
          profileSigningAlgorithm = "none";
          roleClaim = "immich_role";
          scope = "openid email profile";
          signingAlgorithm = "RS256";
          storageLabelClaim = "preferred_username";
          storageQuotaClaim = "immich_quota";
          timeout = 30000;
          tokenEndpointAuthMethod = "client_secret_post";
        };

        passwordLogin = {
          enabled = false;
        };

        reverseGeocoding = {
          enabled = true;
        };

        server = {
          externalDomain = "https://photos.${domain}";
          loginPageMessage = "";
          publicUsers = false;
        };

        storageTemplate = {
          enabled = true;
          hashVerificationEnabled = true;
          template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
        };

        templates = {
          email = {
            albumInviteTemplate = "";
            albumUpdateTemplate = "";
            welcomeTemplate = "";
          };
        };

        theme = {
          customCss = "";
        };

        trash = {
          days = 30;
          enabled = true;
        };

        user = {
          deleteDelay = 7;
        };
      };
    };

    ### we don't backup postgres here, but instead use modules/services/postgres.nix
    environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
      directories = [ 
        "/var/lib/postgresql"
      ];
    };

    services.caddy.virtualHosts."${subdomain}.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString imPort}
      '';
    };
    hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
	};
}