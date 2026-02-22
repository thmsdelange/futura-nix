{
  flake.modules.nixos.virtualisation = {
    # the following configuration is added only when building VM with build-vm
    # for use with `nixos-rebuild build-vm`
    virtualisation.vmVariant = {
      virtualisation = {
        memorySize = 8192;
        cores = 4;
        graphics = false;
      };
    };
  };
}
