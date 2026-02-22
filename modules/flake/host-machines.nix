{
  inputs,
  lib,
  config,
  ...
}:
let
  prefix = "host-";
in
{
  flake.nixosConfigurations = lib.pipe config.flake.modules.nixos [
    (lib.filterAttrs (name: _: lib.hasPrefix prefix name))
    (lib.mapAttrs' (
      name: module:
      let
        specialArgs = {
          inherit inputs;
          hostConfig = {
            name = lib.removePrefix prefix name;
          };
        };
      in
      {
        name = lib.removePrefix prefix name;
        value = inputs.nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [
            module
            inputs.home-manager.nixosModules.home-manager
            inputs.impermanence.nixosModules.impermanence # TODO: import this in a more relevant context
            inputs.disko.nixosModules.disko # TODO: import this in a more relevant context
            config.flake.modules.nixos.hostSpec # import hostSpec for every host
            # config.flake.modules.nixos.hostSpec-share-home # import hostSpec-share-home for every host
            {
              home-manager = {
                extraSpecialArgs = specialArgs;
                sharedModules = [
                  config.flake.modules.homeManager.hostSpec # import hostSpec for every home
                ];
              };
            }
          ];
        };
      }
    ))
  ];
}
