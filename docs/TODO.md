# TODO's

## Get familiar with [dendritic config]()

- [x] Dendritic-specific config

  - [x] Setup flake and minimal install with vm
  - [x] Define host as an aspect
  - [x] Define workstation as an aspect
  - [x] Define work as an aspect?
  - [x] Define user as an aspect

- [ ] Define system core

  - [x] networking
  - [x] ssh
  - [x] keys
  - [ ] git including github access token

## Setup futura-secrets

- [x] Import futura-secrets private repo in flake
- [x] Automate generation of host/user keys
- [ ] setup sops
  - [x] host-level and home level sops
  - [x] test with sending keys over to vm
    - [x] decrypt example key --> this does not work because the remote doesn't have the secret file, however when it is deployed from a remote it can decrypt the secrets it needs now!
    - [x] see if necessary to make zpools like etcssh
      - [x] works with zpool!
      - [x] check without making a zpool
- [ ] rewrite secrets structure: host has users password and ssh keys
  - [ ] setup creating user secret side
  - [ ] setup creating user config side

Probably also here (requires changes in networking and ssh modules amongst others):

- [ ] Manage ssh keys in config (see above)
- [ ] Setup tailscale in config

## Setup declarative disk paritioning with [disko](https://github.com/nix-community/disko)

- [ ] disko setup
  - [x] flake input
  - [x] zfs module
  - [x] zfs disks
  - [x] zfs disks for storage
  - [x] zfs test mirror on new VM
  - [ ] syncoid sanoid
- [x] facter setup

## Migrate DE and apps

Configure one by one

- [ ] Migrate basic tools to config
  - [x] shell
  - [ ] dev
  - [ ] editors
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

## Deployement stuff

- [ ] Add pre commit checks
- [x] Make an iso host that can create an installer image with `just iso`
  - [x] iso has keys, user, minimal setup
- [ ] [Automatic updating](https://blog.gothuey.dev/2025/nixos-auto-upgrade/) with CI/CD stuff

## Homelab

- [ ] setup delorean host
- [ ] setup tailnet
- [ ] setup services
  - [ ] Add each service to dashboard
