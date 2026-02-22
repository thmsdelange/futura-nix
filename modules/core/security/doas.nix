{
  config,
  lib,
  ...
}:
{
  flake.modules.nixos.core =
    { config, ... }:
    {
      # Disable sudo
      security.sudo.enable = false;

      # Enable and configure `doas`.
      security.doas = {
        enable = true;
        # TODO: restrict this to only the stuff needed for nixos-anywhere
        extraRules = [
          {
            runAs = "root";
            # cmd = "*";             # allow all commands
            users = [ "${config.hostSpec.users.primary.username}" ]; # TODO: how do I expands this work for all users? i.e. get a list of all users
            noPass = true; # nopass
            # keepEnv = true;        # optional, preserves environment
          }
        ];
        # extraRules = [
        #   {
        #     runAs = "root";
        #     cmd = "nixos-rebuild";
        #     # users = [ "${config.hostSpec.users.primary.username}" ];  
        #     users = lib.mapAttrsToList (_: u: u.username) (
        #       lib.filterAttrs (_: u: u ? username) config.hostSpec.users
        #     );
        #     noPass = true;
        #     keepEnv = true;
        #   }
        # ];
      };
      # Add an alias to the shell for backward-compat and convenience.
      environment.shellAliases = {
        sudo = "doas";
      };
    };
}
