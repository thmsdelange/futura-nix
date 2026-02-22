# TODO: merge with modules/host-specification/disks.nix
topLevel:
let
  inherit (topLevel) lib;

  hostOptions = {
    # Configuration Settings
    isVM = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a VM host";
    };
    isServer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a server host";
    };
    isWork = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a host that uses work resources";
    };
    isMobile = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a mobile host";
    };
    hasNoSecrets = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Used to indicate a host does not have sops configured yet, so configurations relying on this cannot be installed.
        It goes without saying that this is a temporary switch and as such sops should be configured prompty.
        '';
    };
    networking = {
      ssh = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
    };
    users = {
      primary = {
        username = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Username of the primary user";
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Full name of the primary user";
        };
        email = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Email of the primary user";
        };
        authorizedKeys = lib.mkOption {
          type = with lib.types; listOf str;
          default = [];
          description = "List of authorized SSH keys for the primary user";
        };
      };
    };
  };
in
{
  flake.modules.nixos.hostSpec =
    { config, lib, ... }:
    {
      options.hostSpec = hostOptions;
    };

  flake.modules.homeManager.hostSpec =
    { config, lib, ... }:
    {
      options.hostSpec = hostOptions;
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
