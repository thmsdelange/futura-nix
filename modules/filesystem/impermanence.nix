{ inputs, ... }:
{
  # imports = [ inputs.impermanence.nixosModules.impermanence ];

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
        environment.persistence."${dontBackup}".directories = [
          "/var/lib/systemd"
          "/var/lib/nixos"
          "/var/log" # where journald dumps logs
        ];
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
