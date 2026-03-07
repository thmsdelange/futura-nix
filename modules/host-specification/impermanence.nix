# TODO: merge with modules/host-specification/disks.nix
topLevel:
let
  inherit (topLevel) lib;

  impermanenceOptions = {
    enable = lib.mkEnableOption {
      type = lib.types.bool;
      default = false;
      description = "Enable impermanence for persistence directories below";
    };
    backup = lib.mkOption {
      type = lib.types.str;
      default = "/persist/save";
      description = "The persistent directory to backup";
    };
    backupStorage = lib.mkOption {
      type = lib.types.str;
      default = "/storage/save";
      description = "The persistent directory to backup";
    };
    dontBackup = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "The persistent directory to not backup";
    };
  };
in
{
  flake.modules.nixos.hostSpec =
    { config, lib, ... }:
    {
      options.hostSpec.impermanence = impermanenceOptions;

      config.hostSpec.impermanence = lib.mkIf (config.hostSpec.disks.amReinstalling) {
        backup = "/tmp";
        backupStorage = "/tmp";
      };
    };

  flake.modules.homeManager.hostSpec =
    { config, lib, ... }:
    {
      options.hostSpec.impermanence = impermanenceOptions;

      # not sure if I should also add this to the home-manager options
      config.hostSpec.impermanence = lib.mkIf (config.hostSpec.disks.amReinstalling) {
        backup = "/tmp";
        backupStorage = "/tmp";
      };
    };

  # I think I have this covered by doing this in modules/flake/host-machines.nix by importing hostSpec under sharedModules
  # flake.modules.nixos.hostSpec-share-home =
  #   { config, ... }:
  #   {
  #     config = {
  #       home-manager = {
  #         sharedModules = [
  #           {
  #             hostSpec.impermanence = config.hostSpec.impermanence;
  #           }
  #         ];
  #       };
  #     };
  #   };
}
