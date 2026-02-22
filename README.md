# The ever-evolving NixOS configuration

My personal (hence highly-opiniated) NixOS configuration structured with a [dendritic pattern](https://github.com/mightyiam/dendritic), hosting my personal infrastructure. The dendritic pattern makes every file a flake-parts module, and pairing it with [vic/import-tree](https://github.com/vic/import-tree) makes it a super flexible setup; I can shuffle files around without breaking all the glue-code that's normally required. Host configurations rely on importing flake modules (e.g. `core`) and setting more fine-grained `hostSpec` settings, see [continuum](https://github.com/thmsdelange/nix-futura/tree/main/modules/hosts/continuum/default.nix) as an example of a host configuration.

- disko
- zfs
- impermanence

## [TODO's](docs/TODO.md)

## Secrets

- sops-nix
- private futura-nix flake input

## Acknowledgements

Inspiration and insights was found in

- [EmergentMind/nix-config](https://github.com/EmergentMind/nix-config)
- [yomaq/nix-config](https://github.com/yomaq/nix-config)
- [drupol/infra](https://github.com/drupol/infra)
- [hyperparabolic/nix-config](https://github.com/hyperparabolic/nix-config)
- [adamarbour/nix-alchemy](https://github.com/adamarbour/nix-alchemy)
