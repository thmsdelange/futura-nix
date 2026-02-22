{ config, inputs, ... }:
{
  flake.modules.homeManager.host-iso = { ... }: { };
  flake.modules.nixos.host-iso =
    {
      lib,
      pkgs,
      ...
    }:
    let
      futura-install = pkgs.writeShellApplication {
        name = "futura-install";
        text = builtins.readFile ../../../scripts/futura-install.sh;
      };
    in
    {
      imports =
        with config.flake.modules.nixos;
        [
          "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          core
          user-primary
        ]
        # Specific Home-Manager modules
        ++ [
          {
            home-manager.users.thms = {
              imports = with config.flake.modules.homeManager; [
                core
                host-iso
                user-primary
                shell
              ];
            };
          }
        ];

      nixpkgs = {
        overlays = [
          (final: _prev: {
            master = import inputs.nixpkgs-master {
              inherit (final) config system;
            };
          })
        ];
      };

      hostSpec = {
        users.primary = {
          username = "thms";
          name = "Thomas de Lange";
          email = "thomas-delange@hotmail.com";
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAo9HJGB/8Qan1n62aR7cqci6CXm/z25DtLfAuaISTbB thomas@PC-THOMAS"
          ];
        };
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

      boot.initrd.systemd.emergencyAccess = true; # Don't need to enter password in emergency mode
      
      boot.kernelParams = [
        "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
        "systemd.show_status=true"
        #"systemd.log_level=debug"
        "systemd.log_target=console"
        "systemd.journald.forward_to_console=1"
      ];

      fileSystems."/boot".options = [ "umask=0077" ]; # Removes permissions and security warnings.

      isoImage = {
        makeEfiBootable = true;
        makeUsbBootable = true;
        squashfsCompression = "zstd -Xcompression-level 3";
      };

      systemd = {
        services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
        targets = {
          sleep.enable = false;
          suspend.enable = false;
          hibernate.enable = false;
          hybrid-sleep.enable = false;
        };
      };

      # services = {
      #   qemuGuest.enable = true;
      #   openssh = {
      #     enable = true;
      #     ports = [ 22 ];
      #     settings.PermitRootLogin = "yes";
      #     authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
      #   };
      # };

      services.getty.autologinUser = lib.mkForce "thms";

      environment.systemPackages = with pkgs; [
        futura-install

        nix
        home-manager
        nh
        git
        just
        pre-commit
        deadnix
        sops
        yq-go # jq for yaml, used for build scripts
        bats # for bash testing
        age # for bootstrap script
        ssh-to-age # for bootstrap script

        wget
        curl
        rsync
      ];
    };
}
