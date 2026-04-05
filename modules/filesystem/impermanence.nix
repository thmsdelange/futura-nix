{ inputs, ... }:
{
  # imports = [ inputs.impermanence.nixosModules.impermanence ]; # breaks

  flake.modules.nixos.core =
    {
      config,
      lib,
      ...
    }:
    let
      hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
      inherit (config.hostSpec.impermanence) dontBackup;
    in
    {
      config = {
        # TODO: put in context
        environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
          directories = [
            "/var/lib/systemd"
            "/var/lib/nixos"
            "/var/log" # where journald dumps logs
          ];
          files = [
            "/etc/machine-id" # ensures logs are retained after reboot
          ];
        };
        # can't get this to work without infinte recursion error, FIXME
        # environment.persistence = lib.mkIf (!hasPersistDir) (lib.mkForce { });
      };
    };

  flake.modules.homeManager.core =
    {
      config,
      lib,
      ...
    }:
    let
      hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;
    in
    {
      config = {
        home.persistence = lib.mkIf (!hasPersistDir) (lib.mkForce { });
      };
    };
}
