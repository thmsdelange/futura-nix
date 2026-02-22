{ lib, ... }:
{
  flake.modules.nixos.core = {
    boot = {
      # initrd.systemd.enable = true;
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          # we use Git for version control, so we don't need to keep too many generations.
          configurationLimit = lib.mkDefault 3;
          # pick the highest resolution for systemd-boot's console.
          consoleMode = lib.mkDefault "max";
        };
      };
    };
  };
}
