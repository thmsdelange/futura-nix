{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.host-twinpines = 
  { pkgs, lib, inputs, ... }:
  {
    imports =
      with config.flake.modules.nixos;
      [
        inputs.nixos-hardware.nixosModules.raspberry-pi-3
        # Modules
        core
        shell

        # Services
        dns-server
        share-split-horizon
        tailscale
        dashboard
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

    # Couldn't write '33' to 'vm/mmap_rnd_bits': Invalid argument
    boot.kernel.sysctl = {
      "vm.mmap_rnd_bits" = 24;
    };

    hostSpec = {
      system = "aarch64-linux";
      isServer = true;
      hasSecrets = true;
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
          ];
          useRoutingFeatures = "server";
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
