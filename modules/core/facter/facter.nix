{ inputs, ... }:
{
  flake.modules.nixos.core =
    { pkgs, ... }:
    {
      imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
      facter.detected.dhcp.enable = false;

      environment.systemPackages = [
        pkgs.nixos-facter
      ];
    };
}
