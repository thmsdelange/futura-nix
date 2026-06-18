{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.host-outatime = 
  { pkgs, lib, ... }:
  {
    imports =
      with config.flake.modules.nixos;
      [
        # Modules
        core
        shell

        tailscale
      ]
      # Specific Home-Manager modules
      ++ [
        {
          home-manager.users.thms = { # TODO: can this be made variable as well?
            imports = with config.flake.modules.homeManager; [
              core
              shell
            ];
          };
        }
      ];

    hostSpec = {
      isServer = true;
      hasSecrets = true;
      legacyBoot = true;
      disks = {
        zfs = {
          enable = true;
          hostID = "686330f8";
          root = {
            disk1 = "sda";
            reservation = "10G";
            impermanenceRoot = false; # NOTE: must be false to avoid clash between initrd.systemd and rollback!
          };
          storage = {
          enable = true;
            disks = [ "sdb" "sdc" ];
            reservation = "10G";
            mirror = true;
          };
        };
      };
      users = {
        thms = {
          isAdmin = true;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAo9HJGB/8Qan1n62aR7cqci6CXm/z25DtLfAuaISTbB thomas@PC-THOMAS"
          ];
        };
      };
      services = {
        syncoid = {
          isBackupServer = true;
        };
        tailscale = {
          extraUpFlags = [
            "--ssh=true"
            "--reset=true"
          ];
          useRoutingFeatures = "server";
        };
      };
    };

    facter.reportPath = ./facter.json;
  };
}
