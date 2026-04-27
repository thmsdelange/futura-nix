{
  flake.modules.nixos.core = 
  { config, lib, ... }:
  {
    config = lib.mkIf config.hostSpec.hasZfs {
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
        // lib.optionalAttrs (config.hostSpec.hasZfsStorage && !config.hostSpec.disks.amReinstalling) {
          "zstorage/storage".useTemplate = [ "default" ];
          "zstorage/persistSave".useTemplate = [ "default" ];
        };
      };
    };
  };
}
