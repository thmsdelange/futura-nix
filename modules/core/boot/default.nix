{
  flake.modules.nixos.core = 
  { lib, config, ... }:
  {
    boot = lib.mkMerge [
      (lib.mkIf (!config.hostSpec.legacyBoot) {
        loader = {
          efi.canTouchEfiVariables = true;
          systemd-boot = {
            enable = true;
            configurationLimit = lib.mkDefault 5;
            consoleMode = lib.mkDefault "max";
          };
        };
      })
      (lib.mkIf config.hostSpec.legacyBoot {
        loader = {
          efi.canTouchEfiVariables = lib.mkForce false;
          grub = {
            enable = true;
            devices = lib.mkForce [ "/dev/${config.hostSpec.disks.zfs.root.disk1}" ];
            efiSupport = lib.mkForce false;
            copyKernels = true; # copies kernel/initrd out of ZFS to /boot
          };
        };
        initrd.systemd.enable = true;
      })
    ];
  };
}