{
  flake.modules.nixos.core = 
  {
    config,
    lib,
    pkgs,
    ...
  }:
  let
    cfg = config.hostSpec.networking.ssh;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    # hostsCfg = config.inventory.hosts;  #TODO: make this work (yomaq)
    # # Generate host entries
    # regularHostEntries = lib.mapAttrs (hostname: hostConfig: {
    #     hostNames = [ hostname ];
    #     publicKey = hostConfig.publicKey.host;
    # }) (lib.filterAttrs (hostname: hostConfig: hostConfig.publicKey.host != "") hostsCfg);
    # # Generate initrd host entries
    # initrdHostEntries = lib.mapAttrs' (
    #     hostname: hostConfig:
    #     lib.nameValuePair "${hostname}-initrd" {
    #     hostNames = [ "${hostname}-initrd" ];
    #     publicKey = hostConfig.publicKey.initrd;
    #     }
    # ) (lib.filterAttrs (hostname: hostConfig: hostConfig.publicKey.initrd != "") hostsCfg);
    # # Merge
    # allHostEntries = regularHostEntries // initrdHostEntries;
  in
  {
    config = lib.mkIf cfg.enable {
      # programs.ssh.knownHosts = allHostEntries;
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          # agent forwarding management
          # remove stale sockets
          StreamLocalBindUnlink = "yes";
          # # Allow forwarding ports to everywhere
          # GatewayPorts = "clientspecified";
        };

        hostKeys = [
          {
            path = "${lib.optionalString hasPersistDir "/persist"}/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
    };
  };

  flake.modules.homeManager.core =
  { config, lib, ... }:
  let
    cfg = config.hostSpec.networking.ssh;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    inherit (config.hostSpec.impermanence) dontBackup;
  in
  {
    config = lib.mkIf cfg.enable {
      # programs.ssh.identities = [
      #   {
      #     privateKeyFile = "~/.ssh/id_ed25519";
      #     publicKeyFile  = "~/.ssh/id_ed25519.pub";
      #   }
      # ];
      home.persistence."${dontBackup}".directories = [ ".ssh" ];
    };
  };
  
  # FIXME: add optionally
  # lib.mkIf hasPersistDir {
  #   home.persistence."/persist".directories = [ ".ssh" ];
  # };
}
