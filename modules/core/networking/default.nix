# Networking config which sets a static ip according to hostSpec (inherited from secrets) and disables ipv6
{
  flake.modules.nixos.core = 
  { hostConfig, config, lib, ... }:
  let
    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    networkingSecrets = config.hostSpec.networking or {};
    hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
    subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
    hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
    host = if hostInSecrets then subnet.hosts.${hostName} else null;
  in
  {
    # Apparently, @yomaq: 
    # Notion of "online" is a broken concept
    # https://github.com/systemd/systemd/blob/e1b45a756f71deac8c1aa9a008bd0dab47f64777/NEWS#L13
    systemd.services.NetworkManager-wait-online.enable = false;
    systemd.network.wait-online.enable = false;

    networking = {
      ### settings that are always set
      hostName = hostName;
      useNetworkd = lib.mkDefault true; # @yomaq: Use networkd instead of the pile of shell scripts
      enableIPv6 = false;

      firewall = {
        enable = true;
        # allowedTCPPorts = lib.mkForce [ ];
        # allowedUDPPorts = lib.mkForce [ ];
        allowPing = false;
      };

      networkmanager.enable = lib.mkIf (!config.hostSpec.isServer) true;
    };
    
    ### settings that are only set when properly defined in the secrets (disabling DHCP and setting static ip) 
    systemd.network = {
      networks."10-${hostName}" = lib.mkIf (hasSecrets && hostInSecrets) {
        matchConfig.Name = host.interface;
        address = [
          "${host.ip}/${toString subnet.prefixLength}"
        ];
        routes = [
          { Gateway = subnet.gateway; }
        ];
      };
    };
  };
}