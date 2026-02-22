{
  inputs,
  ...
}:
{
  flake = {
    # TODO(hostSpec)
    # TODO: setup a primary user
    

    modules.nixos.user-primary = 
    {
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.hostSpec.users.primary;
      inherit (config.hostSpec) hasNoSecrets;
    in
    {
      users.users."${cfg.username}" = {
        description = cfg.name;
        isNormalUser = true;
        createHome = true;
        extraGroups = [
          "audio"
          "dialout" # Or else: Permission denied: ‘/dev/ttyUSB0’
          "input"
          "networkmanager"
          "sound"
          "tty"
          "wheel"
        ];
        openssh.authorizedKeys.keys = cfg.authorizedKeys;
        # Set a password to a fallback password if sops is not configured
        hashedPassword = if hasNoSecrets then "$y$j9T$Ac.m5IZ6ku/nrqK9K9kBi1$lRHp3Xg4Vk7Ly/VAiv5d839VlwDRNt2w9ACMMKe8kR2" else null;
        hashedPasswordFile = if hasNoSecrets then null else "sops";
      };

      nix.settings.trusted-users = [ cfg.username ];
    };

    modules.homeManager.user-primary = 
      { config, ... }:
      {
        # Remove this part if no access to the private repository.
        imports = [
          (if inputs ? infra-private then inputs.infra-private.homeModules."${config.hostSpec.users.primary.username}" else { })
        ];

        #   home.file = {
        #     ".face" = {
        #       source = ../../../files/home/"${cfg.username}"/.face;
        #       recursive = true;
        #     };
        #     ".face.icon" = {
        #       source = ../../../files/home/"${cfg.username}"/.face;
        #       recursive = true;
        #     };
        #     # Credits to https://store.kde.org/p/1272202
        #     "Pictures/Backgrounds/" = {
        #       source = ../../../files/home/"${cfg.username}"/Pictures/Backgrounds;
        #       recursive = true;
        #     };
        #   };
      };
  };
}
