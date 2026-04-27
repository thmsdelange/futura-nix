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
    lib.filterAttrs (name: c: c.hasZfs) (
      lib.mapAttrs (name: module:
        let spec = getHostSpec name module; in {
          hostName = lib.removePrefix prefix name;
          hasZfs = spec.hasZfs;
          hasStorage = spec.hasZfsStorage;
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
        specialArgs = {
          inherit inputs;
          inherit syncoidClients;
          hostConfig.name = lib.removePrefix prefix name;
        };
      in
      {
        name = lib.removePrefix prefix name;
        value = withSystem "x86_64-linux" ({ pkgs, ... }:
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