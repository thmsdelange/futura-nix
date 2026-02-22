{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.host-twinpines = {
    imports =
      with config.flake.modules.nixos;
      [
        # Modules
        core
        # virtualisation
        # bluetooth
        # desktop
        # displaylink
        # dev
        # education
        # fwupd
        # games
        # lora
        # sound
        # vpn

        # Users
        # root
        user-primary
      ]
      # Specific Home-Manager modules
      ++ [
        {
          home-manager.users.thms = { # TODO: can this be made variable as well?
            imports = with config.flake.modules.homeManager; [
              core
              # desktop
              # dev
              # email
              # messaging
              user-primary
              # games
              shell
              # work
            ];
          };
        }
      ];

    # I would like to make this stuff a bit cleaner. Would be nice if this can be a TODO(hostSpec) option (stable|unstable|master)
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
      networking.ssh.enable = true;
      users.primary = {
        username = "thms";
        name = "Thomas de Lange";
        email = "thomas-delange@hotmail.com";
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAo9HJGB/8Qan1n62aR7cqci6CXm/z25DtLfAuaISTbB thomas@PC-THOMAS"
        ];
      };
    };

    facter.reportPath = ./facter.json;
  };
}
