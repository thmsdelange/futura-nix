## Phase 0: discover bootstrapping workflow

0. minimal iso with auth ssh keys user, etc.
1. disk declaration with disko
2. secrets management with sops

- [ ] creation of keys, rules, etc.

> Mental model: consider a limited amount of devices (personal laptop + work laptop) to be the "control plane" from which other systems are managed:
>
> - before bootstrapping, necessary keys are generated on the control plane (in a temp dir) and the secrets repo is updated with them
> - while bootstrapping, these keys will be copied over to the target host such that it can decrypt the secrets (critial note: decryption is at run time)
>   This way, the need to manage secrets on multiple hosts is eliminated, as well as the problem of the catch-22: needing another secret key to authenticate the private secrets repo: **a better solution is to use a yubikey for this, since this will only need to happen on the "control plane" hosts that I carry around with me anyways**

Bootstrapping steps (add numbering later since it will shift anyways)

- generate iso

```
nix build .#nixosConfigurations.iso.config.system.build.isoImage
```

- boot target machine into iso

  - verify ssh access working

- setup secrets

  - generate host ssh key on local machine (in a temp dir)
  - generate user age key on local machine (in a temp dir)
  - update secrets with these keys
  - later copy over these files with nixos-anywhere such that the new host can decrypt them
  - add dev age key that I can backup in my password manager

  0. if master key does not exist yet:
     0.1. generate age master key:
     0.2. add to .sops.yaml
     0.3. re-encrypt
  1. generate host ssh key:
  2. base host age key on host ssh key: temp
  3. add to .sops.yaml: `sops-add-shared-creation-rules HOST` and `sops-add-host-creation-rules HOST`
  4. generate user ssh key: id_ed...
  5. base user age key on user ssh key: temp
  6. add to .sops.yaml: `sops-add-host-creation-rules USER HOST`
  7. optionally: add all creation rules at once: `sops-add-all-creation-rules USER HOST`
  8. re-encrypt secrets with new keys
  9. supply these two ssh keys in nixos-anywhere command

- get info of target machine using `host-info IP`

  - change disk layout
  - change ...

- remote install

```
nix run github:nix-community/nixos-anywhere -- -f '.#{{HOST}}' --target-host {{USER}}@{{IP}} --generate-hardware-config nixos-facter modules/hosts/{{HOST}}/facter.json
```
