{
  flake.modules.nixos.dns-server = 
  { config, hostConfig, inputs, ... }:
  let
    aghPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.adguardhome or 3003);
    ubPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.unbound or 5335);
    userName = (config.hostSpec.services.adguardhome.${hostConfig.name}.user or "admin");
    password = (config.hostSpec.services.adguardhome.${hostConfig.name}.passwd or null);  # this immediately locks you out if you don't have the correct htpasswd setup, see: https://github.com/AdguardTeam/AdGuardHome/wiki/Configuration#password-reset
  in
  {
    services.adguardhome = {
      enable = true;
      # mutableSettings = false; # declare all settings in this config rather than in the web UI
      # You can select any ip and port, just make sure to open firewalls where needed
      # host = "127.0.0.1";
      host = "0.0.0.0";
      port = aghPort;
      settings = {
        users = [{
          name = userName;
          password = password;
        }];
        dns = {
          port = 53;
          upstream_dns = [
            # Example config with quad9
            # "9.9.9.9#dns.quad9.net"
            # "149.112.112.112#dns.quad9.net"
            # Uncomment the following to use a local DNS service (e.g. Unbound)
            # Additionally replace the address & port as needed
            "127.0.0.1:${toString ubPort}"
          ];
          bootstrap_dns = [
            "9.9.9.10"
            "149.112.112.10"
            "2620:fe::10"
            "2620:fe::fe:10"
          ];
          dhcp = {
            enabled = false;
          };
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;

          parental_enabled = false;  # Parental control-based DNS requests filtering.
          safe_search = {
            enabled = false;  # Enforcing "Safe search" option for search engines, when possible.
          };
          rewrites = [
            { domain = "twinpines"; answer = "10.10.10.2"; }
            { domain = "adguard.deloreanserver.nl"; answer = "10.10.10.2"; } # TODO: rewrite services to point to tailscale later
            { domain = "home.deloreanserver.nl"; answer = "10.10.10.2"; } # TODO: rewrite services to point to tailscale later
          ];
        };
        filters = map(url: { enabled = true; url = url; }) [
          "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/general/filter_24_1Hosts_Lite/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/other/filter_7_SmartTVBlocklist/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_8_Dutch/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_6_German/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_18_Annoyances_Cookies/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_19_Annoyances_Popups/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_21_Annoyances_Other/filter.txt"
        ];
      theme = "dark";
      };
    };

    ### open aghPort to view the web UI without a reverse proxy (so delete later)
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 aghPort ];
  };
}
