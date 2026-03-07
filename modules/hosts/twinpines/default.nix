{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.host-twinpines = 
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

    # I would like to make this stuff a bit cleaner. Would be nice if this can be a TODO(hostSpec) option (stable|unstable|master)
    # nixpkgs = {
    #   overlays = [
    #     (final: _prev: {
    #       stable = import inputs.nixpkgs-stable {
    #         inherit (final) config system;
    #       };
    #     })
    #   ];
    # };

    # TODO: hostSpec option boot.systemd/rpi
    boot.loader = {
      grub.enable = false;
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
      generic-extlinux-compatible.enable = true;
    };
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_rpi3;

    hostSpec = {
      hasSecrets = true;
      networking.ssh.enable = true;
      users = {
        thms = {
          isAdmin = true;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAo9HJGB/8Qan1n62aR7cqci6CXm/z25DtLfAuaISTbB thomas@PC-THOMAS"
          ];
        };
      };
    };

    facter.reportPath = ./facter.json;
    fileSystems."/" =
      { device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
        fsType = "ext4";
      };

    swapDevices = [
      { device = "/swapfile"; size = 1024; }
    ];
  };
}
