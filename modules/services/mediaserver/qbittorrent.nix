{
  flake.modules.nixos.mediaserver =
    { config, inputs, lib, hostConfig, pkgs, ... }:
    let
      qbPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.qbittorrent or 8282);

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
      subdomain = "torr";

      inherit (config.hostSpec.impermanence) dontBackupStorage dontBackup;
      hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    in
    {
      sops.secrets = {
        "services/qbittorrent/password" = {
          sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
        };
      };

      nixflix.torrentClients.qbittorrent = {
        enable = true;
        subdomain = subdomain;
        # port = qbPort;
        password._secret = config.sops.secrets."services/qbittorrent/password".path;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            Session = {
              AddTorrentStopped = false;
              Port = 45500;
              QueueingSystemEnabled = true;
              SSL.Port = 32380;

              # required for port forwarding from a VPN
              ReannounceWhenAddressChanged = true;
            };
          };
          Preferences = {
            WebUI = {
              Username = "marty";
              Password_PBKDF2 = "@ByteArray(FmMGrZ4uqnjBeGCkDjVZhQ==:hvenxuwv+BOVIJT+GH+xZ++8omXl/TL7JODltRFse9LtnlSzdpr7xgkxUJomGUPjZpBbRu54N0FzW4ZFg17S1Q==)";
            };
            General.Locale = "en";
          };
        };
      };

      environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
        hideMounts = true;
        directories = [
          "/var/lib/qBittorrent"
        ];
      };

      services.caddy.virtualHosts."${subdomain}.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${builtins.toString qbPort}
        '';
      };
      hostSpec.services.adguardhome.splitHorizonSubdomains = [ subdomain ];
    };
}