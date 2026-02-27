{
  inputs,
  ...
}:
let
  sopsRoot = builtins.toString inputs.futura-secrets;
  sopsFolder = builtins.toString inputs.futura-secrets + "/sops";
in
{
  # hosts level sops
  flake.modules.nixos.core =
    { config, pkgs, ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      sops = {
        defaultSopsFile = "${sopsRoot}/secrets/shared.yaml";
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        gnupg.sshKeyPaths = [ ];
      };

      sops.secrets = {
        # NOTE: This entry is duplicated in home sops and here because nix.nix can't
        # directly check for sops usage due to recursion in some situations
        # formatted as extra-access-tokens = github.com=<PAT token>
        "tokens/nix-access-tokens" = {
          sopsFile = "${sopsFolder}/shared.yaml";
        };
      };

      environment.systemPackages = with pkgs; [
      	age
      	sops
      	ssh-to-age
      ];
    };

  # user-level sops
  flake.modules.homeManager.core =
    { config, lib, ... }:
    let
      adminUser = builtins.head (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
    in
    {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
      ];

      sops = {
        defaultSopsFile = "${sopsRoot}/secrets/users/${adminUser}.yaml";
        age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
        gnupg.sshKeyPaths = [ ];
      };

      sops.secrets = {
        # "password" = {
        #   sopsFile = "${sopsRoot}/secrets/users/${config.hostSpec.users.primary.username}.yaml";
        #   neededForUsers = true;
        # };

        # NOTE: This entry is duplicated in home sops and here because nix.nix can't
        # directly check for sops usage due to recursion in some situations
        # formatted as extra-access-tokens = github.com=<PAT token>
        "tokens/nix-access-tokens" = {
          sopsFile = "${sopsFolder}/shared.yaml";
        };
      };
    };
}
