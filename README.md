# The ever-evolving NixOS configuration

My personal (hence highly-opiniated) NixOS configuration structured with a [dendritic pattern](https://github.com/mightyiam/dendritic), hosting my personal infrastructure. The dendritic pattern makes every file a flake-parts module, and pairing it with [vic/import-tree](https://github.com/vic/import-tree) makes it a super flexible setup; I can shuffle files around without breaking all the glue-code that's normally required. Host configurations rely on importing flake modules (e.g. `core`) and setting more fine-grained `hostSpec` settings, see [continuum](https://github.com/thmsdelange/nix-futura/tree/main/modules/hosts/continuum/default.nix) as an example of a host configuration.

- disko
- zfs
- impermanence

## [TODO's](docs/TODO.md)

## Secrets

Using [sops-nix](https://github.com/Mic92/sops-nix) with the secrets hosted in a private repository and pulled into the config as a flake input. Largely inspired by [EmergentMind's guide](https://unmovedcentre.com/posts/secrets-management/). An example of a private secrets repository can be found [here](https://github.com/EmergentMind/nix-secrets-reference/tree/complex).

- Host secrets are decrypted using an age key derived from the host ssh key `/etc/ssh/ssh_host_ed25519_key`
- User secrets are decrypted using an age key derived from the user ssh key `~/.ssh/id_ed25519`
- Shared secrets can be accessed by all hosts

## Acknowledgements

Inspiration and insights was found in

- [EmergentMind/nix-config](https://github.com/EmergentMind/nix-config)
- [yomaq/nix-config](https://github.com/yomaq/nix-config)
- [drupol/infra](https://github.com/drupol/infra)
- [hyperparabolic/nix-config](https://github.com/hyperparabolic/nix-config)
- [adamarbour/nix-alchemy](https://github.com/adamarbour/nix-alchemy)
