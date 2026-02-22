topLevel:
let
  inherit (topLevel) lib;

  disksOptions = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "enable custom disk configuration using disko";
    };
    amReinstalling = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "am I reinstalling and want to save the storage pool + keep /persist/save unused so I can restore data";
    };
    # systemd-boot = lib.mkOption {
    #   type = lib.types.bool;
    #   default = false;
    # };
    initrd-ssh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      ethernetDrivers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          ethernet drivers to load: (run "lspci -v | grep -iA8 'network\|ethernet'")
        '';
      };
    };
    zfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      hostID = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      root = {
        luks-encrypt = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        zfs-encrypt = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        disk1 = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "device name";
        };
        disk2 = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "device name";
        };
        reservation = lib.mkOption {
          type = lib.types.str;
          default = "20GiB";
          description = "zfs reservation";
        };
        mirror = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "mirror the zfs pool";
        };
        impermanenceRoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "wipe the root directory on boot";
        };
      };
      storage = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        luks-encrypt = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        zfs-encrypt = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        disks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "device names";
        };
        reservation = lib.mkOption {
          type = lib.types.str;
          default = "20GiB";
          description = "zfs reservation";
        };
        mirror = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "mirror the zfs pool";
        };
      };
    };
  };
in
{
  flake.modules.nixos.hostSpec =
    { config, lib, ... }:
    {
      options.hostSpec.disks = disksOptions;
    };

  flake.modules.homeManager.hostSpec =
    { config, lib, ... }:
    {
      options.hostSpec.disks = disksOptions;
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
