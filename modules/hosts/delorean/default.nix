{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.host-delorean = 
  { pkgs, lib, ... }:
  {
    imports =
      with config.flake.modules.nixos;
      [
        # Modules
        core
        shell

        # Services
        dns-server
        share-split-horizon
        pocket-id
        tailscale
        opencloud
        scrutiny
        gaggimate
        # dashboard
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
      hasSecrets = true;
      hasZfs = true;
      hasZfsStorage = false;
      disks = {
        zfs = {
          hostID = "501eb87a";
          root = {
            disk1 = "sda";
            reservation = "10G";
            impermanenceRoot = true;
          };
          # storage = {
          #   disks = [ "vdb" "vdc" ];
          #   reservation = "10G";
          #   mirror = true;
          # };
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
        tailscale = {
          extraUpFlags = [
            "--ssh=true"
            "--reset=true"
            "--accept-dns=true"
          ];
          useRoutingFeatures = "server";
        };
      };
    };

    facter.reportPath = ./facter.json;
  };
}
