{
  flake.modules.nixos.postgres = 
  { config, hostConfig, ... }:
  {
    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      location = "/persist/save/postgresql";
      startAt = "*-*-* 03:00:00";
      compression = "zstd";
    };
  };
}