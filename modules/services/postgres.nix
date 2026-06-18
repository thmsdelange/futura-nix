{
  flake.modules.nixos.postgres = 
  { config, hostConfig, ... }:
  let
    inherit (config.hostSpec.impermanence) backup;
  in
  {
    ### TODO: guard with if postgres is used!
    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      location = "${backup}/postgresql";
      startAt = "*-*-* 03:00:00";
      compression = "zstd";
    };
  };
}