# TODO's

## Phase 1: get familiar with [dendritic config]()

- [x] 1.1 Dendritic-specific config

  - [x] Setup flake and minimal install with vm
  - [x] Define host as an aspect
  - [x] Define workstation as an aspect
  - [x] Define work as an aspect?
  - [x] Define user as an aspect

- [ ] 1.2 define system core

  - [x] networking
  - [x] ssh
  - [x] keys
  - [ ] git including github access token
  - [ ] think about removing everything with initrd-ssh

- [ ] 1.3 Migrate basic tools to config
  - [x] shell
  - [ ] dev
  - [ ] editors

## Phase 2: setup futura-secrets as a flake input

- [x] 2.1 Import futura-secrets private repo in flake
- [x] 2.2 Automate generation of host/user keys
- [ ] setup sops
  - [x] host-level and home level sops
  - [ ] test with sending keys over to vm
    - [ ] decrypt example key --> this does not work because the remote doesn't have the secret file, however when it is deployed from a remote it can decrypt the secrets it needs now!
    - [ ] see if necessary to make zpools like etcssh
      - [x] works with zpool!
      - [ ] check without making a zpool
      - [ ] make home persist
- [ ] 2.3 Use secrets for sensitive stuff
  - [ ] user password
  - [ ] networking configuration
  - [ ] tokens

Probably also here (requires changes in networking and ssh modules amongst others):

- [ ] Manage ssh keys in config
- [ ] Setup tailscale in config

## Phase 3: setup declarative disk paritioning with [disko](https://github.com/nix-community/disko)

- [ ] 3.1 disko setup
  - [x] flake input
  - [x] zfs module
  - [x] zfs disks
  - [x] zfs disks for storage
  - [x] zfs test mirror on new VM
  - [ ] syncoid sanoid
- [x] 3.2 facter setup

## Phase 4: Migrate DE and apps

Configure one by one

- [ ] shell
  - [ ] bottom
  - [ ] btop
  - [ ] direnv
  - [ ] lsd
  - [ ] nix-your-shell
  - [ ] ripgrep
  - [ ] utils
  - [ ] yazi (fix warnings)
  - [ ] zoxide
  - [ ] zsh
    - [x] fix default shell in user janky-ness
    - [ ] make working config a but more polished
    - [ ] fix kitty term: [long-term fix](https://blog.rei.my.id/posts/7/how-to-fix-xterm-kitty-unknown-terminal-type-in-ssh/) (see what I did there)
- [ ] desktop environment
  - [ ] experiment with [Dank Material Shell](https://danklinux.com/) and niri
  - [ ] research possibility to have multiple DE's configured (for switching to un-broken configs on work pc)

## Phase 5: QoL deployement stuff

- [ ] Add pre commit checks
- [ ] Add CI automated updates
- [x] Make an iso host that can create an installer image with `just iso`
  - [x] iso has keys, user, minimal setup
- [ ] [Automatic updating](https://blog.gothuey.dev/2025/nixos-auto-upgrade/) with CI/CD stuff

## Phase 6: Homelab

- [ ] 6.1 setup delorean host
- [ ] 6.2 setup tailnet
- [ ] 6.3 setup services
  - [ ] Add each service to dashboard
