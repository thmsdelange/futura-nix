{
  flake.modules.nixos.core =
    { hostConfig, ... }:
    {
      networking = {
        hostName = hostConfig.name;

        # networkmanager = {
        #   enable = true;
        # };

        # useDHCP = true; # was set to false, TODO: configure static ip. This worked in iso because lib.mkDefault wase used to force useDHCP = true when the installer was included
      };

      systemd = {
        services.NetworkManager-wait-online.enable = false;
        network.wait-online.enable = false;
      };

      # services.resolved = {
      #   enable = true;
      # };
    };
}
