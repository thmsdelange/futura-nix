{ inputs, ... }:
{
  flake.modules.nixos.core =
    { config, ... }:
    {
      users.motdFile = "/etc/motd";
      environment.etc.motd.text = ''
        =========== Futura NixOS config ===========
        NixOS release: ${config.system.nixos.release}
        Nixpkgs revision: ${inputs.nixpkgs.rev}
      ''; # TODO: add self.rev again
    };
}
