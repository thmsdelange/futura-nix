{
  flake.modules.nixos.core = 
  { config, lib, ... }:
  let
    hasZfs = config.hostSpec.disks.zfs.enable;
    hasZfsStorage = config.hostSpec.disks.zfs.storage.enable;
    hasZfsNvme = config.hostSpec.disks.zfs.nvme.enable;
  in
  {
    config = lib.mkIf hasZfs {
      services.sanoid = {
        enable = true;
        templates = {
          default = {
            autosnap = true;
            autoprune = true;
            hourly = 24;
            daily = 30;
            monthly = 0;
            yearly = 0;
          };
        };
        datasets = {
          "zroot/persist".useTemplate = [ "default" ];
          "zroot/persistSave".useTemplate = [ "default" ];
        }
        // lib.optionalAttrs (hasZfsStorage && !config.hostSpec.disks.amReinstalling) {
          "zstorage/storage".useTemplate = [ "default" ];
          "zstorage/persistSave".useTemplate = [ "default" ];
        }
        // lib.optionalAttrs (hasZfsNvme && !config.hostSpec.disks.amReinstalling) {
          "zfast/fast".useTemplate = [ "default" ];
          "zfast/persistSave".useTemplate = [ "default" ];
        };
      };
    };
  };
}
