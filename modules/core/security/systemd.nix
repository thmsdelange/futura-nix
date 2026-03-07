{
  config,
  lib,
  ...
}:
{
  flake.modules.nixos.core =
    { config, ... }:
    {
      # Ensure nixos is owned by root and homes are owned by the respective users. (taken from nix-alchemy)
      systemd.tmpfiles.rules = [
        "d /etc/nixos 0700 root root -"
        "Z /etc/nixos 0600 root root -"
      ] ++ map (u: "z /home/${u} 0700 ${u} users -") (builtins.attrNames config.hostSpec.users);
    };
}
