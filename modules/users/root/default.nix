{
  flake.modules.nixos.user-root =
    { config, lib, ... }:
    {
      users.users.root = {
        openssh.authorizedKeys.keys = config.hostSpec.users.root.authorizedKeys;
        # # Set a password to as fallback if sops is not working
        # initialHashedPassword = "$y$j9T$Ac.m5IZ6ku/nrqK9K9kBi1$lRHp3Xg4Vk7Ly/VAiv5d839VlwDRNt2w9ACMMKe8kR2";
        # # initialPassword is higher priority, so sops secrets are not required (for example on iso)
        # TODO: decide if a root password is really needed or if it suffices to always elevate the privileges of the primary user
        # TODO: if root password needed, where do we store it in sops (and who has access)?
        hashedPasswordFile = lib.mkForce null;
      };
    };
}
