{
  flake.modules.nixos.core = 
  {
    config,
    lib,
    pkgs,
    hostConfig,
    ...
  }:
  let
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    sshPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.ssh or 22);
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
    config = {
      # programs.ssh.knownHosts = allHostEntries;
      services.openssh = {
        enable = true;
        allowSFTP = true;
        openFirewall = true;
        ports = [ sshPort ];
        settings = {
          PermitRootLogin = "no";
          AuthenticationMethods = "publickey";
          PubkeyAuthentication = "yes";
          PasswordAuthentication = false;
          PermitEmptyPasswords = false;
          PermitTunnel = false;
          UseDns = false;
          ChallengeResponseAuthentication = "no";
          KbdInteractiveAuthentication = false;
          X11Forwarding = config.services.xserver.enable;
          MaxAuthTries = 3;
          MaxSessions = 2;
          TCPKeepAlive = false;
          AllowTcpForwarding = false;
          AllowAgentForwarding = false;
          LogLevel = "VERBOSE";

          KexAlgorithms = [
            "curve25519-sha256@libssh.org"
            "ecdh-sha2-nistp521"
            "ecdh-sha2-nistp384"
            "ecdh-sha2-nistp256"
            "diffie-hellman-group-exchange-sha256"
          ];
          Ciphers = [
            "chacha20-poly1305@openssh.com"
            "aes256-gcm@openssh.com"
            "aes128-gcm@openssh.com"
            "aes256-ctr"
            "aes192-ctr"
            "aes128-ctr"
          ];
          Macs = [
            "hmac-sha2-512-etm@openssh.com"
            "hmac-sha2-256-etm@openssh.com"
            "umac-128-etm@openssh.com"
            "hmac-sha2-512"
            "hmac-sha2-256"
            "umac-128@openssh.com"
          ];

          # kick out inactive sessions
          ClientAliveCountMax = 5;
          ClientAliveInterval = 60;
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
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    inherit (config.hostSpec.impermanence) dontBackup;
  in
  {
    config = {
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
