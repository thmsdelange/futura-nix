{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.host-jigowatt = 
  { pkgs, lib, inputs, ... }:
  {
    imports =
      with config.flake.modules.nixos;
      [
        inputs.autoaspm.nixosModules.default
        # Modules
        core
        shell

        tailscale
        hermes-agent
      ]
      # Specific Home-Manager modules
      ++ [
        {
          home-manager.users.thms = { # TODO: can this be made variable as well?
            imports = with config.flake.modules.homeManager; [
              core
              shell
              dev
            ];
          };
        }
      ];

    ### can't get hermes to work with doas because hermes expects sudo
    security.sudo.enable = lib.mkForce true;
    
    ### in pursuit of 2W
    powerManagement.powertop.enable = true;
    powerManagement.cpuFreqGovernor = "powersave";
    boot.kernelParams = [
      "pcie_aspm=force"
      "pcie_aspm.policy=powersupersave"
      # "pcie_port_pm=force"
      "i915.enable_dc=2"
      "i915.enable_fbc=1"
    ];
    services.autoaspm.enable = true;

    hostSpec = {
      isServer = true;
      hasSecrets = true;
      networking.wifi = true;
      disks = {
        zfs = {
          enable = true;
          hostID = "06544d2d";
          root = {
            disk1 = "sda";
            reservation = "10G";
            impermanenceRoot = true;
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
