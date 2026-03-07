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
    hasSecrets = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Used to indicate a host does have sops configured yet, as configurations without on secrets need extra care.
        It goes without saying that this is a temporary switch and as such sops should be configured prompty.
        '';
    };
    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Full name of the user";
          };
          email = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Named email addresses (work, personal, etc.)";
          };
          authorizedKeys = lib.mkOption {
            type = with lib.types; listOf str;
            default = [];
            description = "List of SSH authorized keys of the user";
          };
          isAdmin = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the user should be an admin";
          };
        };
      }));
      default = { };
      description = ''
        List of non-system users that should be declared for the host.
      '';
      # check = lib.mkCheck (users: 
      #   let
      #     adminUsers = lib.filterAttrs (_: u: u.isAdmin) users;
      #   in
      #     if builtins.length (builtins.attrNames users) == 0 then
      #       throw "hostSpec.users: At least one system user must be specified"
      #     else if builtins.length (builtins.attrNames adminUsers) == 0 then
      #       throw "hostSpec.users: At least one user must be marked as isAdmin = true"
      #     else true
      # );
    };
    # Networking (freeform — can take entire secrets structure)
    networking = lib.mkOption {
      type = lib.types.submodule ({ ... }: {
        freeformType = lib.types.attrsOf lib.types.anything;
        options = {}; # no fixed options, everything comes from secrets
      });
      default = {};
      description = "Host networking (subnets, hosts, ports, ssh, dns, etc.)";
    };
     # Services (freeform — can take entire secrets structure)
    services = lib.mkOption {
      type = lib.types.submodule ({ ... }: {
        freeformType = lib.types.attrsOf lib.types.anything;
        options = {}; # no fixed options, everything comes from secrets
      });
      default = {};
      description = "Services configuration (e.g. adguardghome, etc.)";
    };
  };
in
{
  flake.modules.nixos.hostSpec =
    { config, lib, inputs, ... }:
    {
      options.hostSpec = hostOptions;
      config.hostSpec = {
        inherit (inputs.futura-secrets)
          networking
          users
          services
          ;
      };
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
