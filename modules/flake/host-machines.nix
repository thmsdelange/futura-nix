{
  inputs,
  lib,
  config,
  withSystem,
  ...
}:
let
  prefix = "host-";
  hostModules = lib.filterAttrs (name: _: lib.hasPrefix prefix name) config.flake.modules.nixos;

  # Evaluate only hostSpec for each host to extract zfs info
  getHostSpec = name: module:
    let
      eval = inputs.nixpkgs.lib.evalModules {
        modules = [
          module
          config.flake.modules.nixos.hostSpec
          { _module.check = false; }
        ];
        specialArgs = {
          inherit inputs;
          pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
          lib = inputs.nixpkgs.lib;
          hostConfig.name = lib.removePrefix prefix name;
        };
      };
    in
      eval.config.hostSpec;

  syncoidClients = lib.attrValues (
    lib.filterAttrs (name: c: c.hasZfs && c.tailip != null) ( # note that hosts without a tailip defined are filtered out!
      lib.mapAttrs (name: module:
        let
          hostName = lib.removePrefix prefix name;
          spec = getHostSpec name module; 
        in {
          inherit hostName;
          tailip = spec.networking.host.tailip;
          sshPort = spec.networking.ports.${hostName}.tcp.ssh or 22;
          hasZfs = spec.disks.zfs.enable;
          hasStorage = spec.disks.zfs.storage.enable;
          hasNvme = spec.disks.zfs.nvme.enable;
        }
      ) hostModules
    )
  );
in
{
  flake.nixosConfigurations = lib.pipe hostModules [
    (lib.mapAttrs' (
      name: module:
      let
        hostSystem = (getHostSpec name module).system;  # read per-host
        specialArgs = {
          inherit inputs syncoidClients;
          hostConfig.name = lib.removePrefix prefix name;
        };
      in
      {
        name = lib.removePrefix prefix name;
        value = withSystem hostSystem ({ pkgs, ... }:
          inputs.nixpkgs.lib.nixosSystem {
            inherit specialArgs;
            modules = [
              module
              inputs.home-manager.nixosModules.home-manager
              inputs.impermanence.nixosModules.impermanence
              inputs.disko.nixosModules.disko
              config.flake.modules.nixos.hostSpec
              { nixpkgs.pkgs = pkgs; }
              {
                home-manager = {
                  extraSpecialArgs = specialArgs;
                  sharedModules = [
                    config.flake.modules.homeManager.hostSpec
                  ];
                };
              }
              ({ config, ... }: {
                home-manager.sharedModules = [
                  { hostSpec = config.hostSpec; }
                ];
              })
            ];
          }
        );
      }
    ))
  ];
}