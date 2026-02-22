{
  inputs,
  ...
}:
{
  imports = [
    inputs.make-shell.flakeModules.default
  ];

  flake.modules.nixos.core = {
    programs = {
      nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = "--keep 2";
        };
      };
    };
  };

  perSystem =
    { pkgs, ... }:
    let
      # host-info = pkgs.writeShellApplication {
      #   name = "host-info";
      #   text = builtins.readFile ../../scripts/host-info.sh;
      # };
      # sops-helpers = pkgs.writeShellApplication {
      #   name = "sops-helpers";
      #   text = builtins.readFile ../../scripts/sops-helpers.sh;
      # };
      # futura-secrets-dir = ../../futura-secrets;
      # futura-install = pkgs.writeShellApplication {
      #   name = "futura-install";
      #   runtimeInputs = [ sops-helpers ];
      #   text = ''
      #     #!/usr/bin/env bash
      #     set -euo pipefail

      #     SECRETS_DIR=${futura-secrets-dir}

      #     ${builtins.readFile ../../scripts/sops-helpers.sh}

      #     ${builtins.readFile ../../scripts/futura-install.sh}
      #   '';
      # };
    in
    {
      make-shells.default = {
        # buildInputs = checks.pre-commit-check.enabledPackages;
        nativeBuildInputs = with pkgs; [
          # add any packages you want available in the shell when accessing the parent directory.
          # These will be installed regardless of what was installed specific for the host or home configs
          nix
          home-manager
          nh
          git
          just
          pre-commit
          deadnix
          sops
          yq-go # jq for yaml, used for build scripts
          ripgrep # used in sops scripts
          bats # for bash testing
          age # for bootstrap script
          ssh-to-age # for bootstrap script
          nix-search-tv # move this to the package
          fzf
          # host-info
          # sops-helpers
          # futura-install
        ];
        env = {
          NIX_CONFIG = "extra-experimental-features = nix-command flakes";
          BOOTSTRAP_USER = "hiro";
          BOOTSTRAP_SSH_PORT = "22";
          BOOTSTRAP_SSH_KEY = "~/.ssh/id_manu";
        };
        shellHook = ''
          # ---------- Aliases ---------- TODO: fix this, not working
          alias ns="nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history"

          # ---------- UI ----------
          bold=$(tput bold 2>/dev/null || true)
          green=$(tput setaf 2 2>/dev/null || true)
          yellow=$(tput setaf 3 2>/dev/null || true)
          blue=$(tput setaf 4 2>/dev/null || true)
          reset=$(tput sgr0 2>/dev/null || true)

          header() { echo -e "\n$bold$blue==> $1$reset"; }
          ok()     { echo -e "$green✔$reset $1"; }
          warn()   { echo -e "$yellow⚠$reset  $1"; }

          header "futura-nix admin shell"

          # ---------- Context ----------
          if git rev-parse --show-toplevel >/dev/null 2>&1; then
            REPO_ROOT=$(git rev-parse --show-toplevel)
            ok "Repo: $(basename "$REPO_ROOT")"
          else
            warn "Not inside a git repository"
          fi

          if [[ -f flake.nix ]]; then
            ok "Flake: detected"
          else
            warn "No flake.nix in current directory"
          fi

          # ---------- Nix config visibility ----------
          header "Nix config"
          echo "$NIX_CONFIG" | sed 's/^/  /'

          echo -e "\nEnvironment ready.$reset\n"
        '';
      };
    };
}
