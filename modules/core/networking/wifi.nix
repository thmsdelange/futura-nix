# # Wifi config which sets a static ip according to hostSpec (inherited from secrets) and disables ipv6
# {
#   flake.modules.nixos.core = 
#   { hostConfig, config, lib, pkgs, ... }:
#   let
#     hostName = hostConfig.name;
#     inherit (config.hostSpec) hasSecrets;
#     networkingSecrets = config.hostSpec.networking or {};
#     hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
#     subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
#     hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
#     host = if hostInSecrets then subnet.hosts.${hostName} else null;
#   in
#   {
#     lib.mkIf !isServer ...
#   };
# }
{}