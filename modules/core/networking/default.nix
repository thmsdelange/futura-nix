# TODO: pull in soft secrets from futura-secrets declaring network stuff
{
  flake.modules.nixos.core =
    { hostConfig, ... }:
    {
      networking = {
        hostName = hostConfig.name;

        # networkmanager = {
        #   enable = true;
        # };

        # useDHCP = true;
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
