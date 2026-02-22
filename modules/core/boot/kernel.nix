{
  flake.modules.nixos.core =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # get latest zfs compatible kernel
      latestZfsCompatibleLinuxPackages = lib.pipe pkgs.linuxKernel.packages [
        builtins.attrValues
        (builtins.filter (
          # fitler packages where
          kPkgs:
          # packages do not throw or assert errors
          (builtins.tryEval kPkgs).success
          # package is a kernel package
          && kPkgs ? kernel
          && kPkgs.kernel.pname == "linux"
          # zfs metadata indicates kernel version is compatible with zfs
          && !kPkgs.${pkgs.zfs.kernelModuleAttribute}.meta.broken
        ))
        # sort oldest -> newest
        (builtins.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)))
        # get last element (newest)
        lib.last
      ];
    in
    {
      config = {
        # boot.kernelPackages =
        #   if config.hostSpec.disks.zfs.enable
        #   then latestZfsCompatibleLinuxPackages
        #   else pkgs.linuxPackages_latest;
        boot.kernelPackages = latestZfsCompatibleLinuxPackages;
      };
    };
}
