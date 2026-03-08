{
  flake.modules.nixos.dns-server = 
  { config, lib, hostConfig, inputs, ... }:
  let
    aghPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.adguardhome or 3003);
    ubPort = (config.hostSpec.networking.ports.${hostConfig.name}.tcp.unbound or 5335);
    userName = (config.hostSpec.services.adguardhome.${hostConfig.name}.user or "admin");
    password = (config.hostSpec.services.adguardhome.${hostConfig.name}.passwd or null);  # this immediately locks you out if you don't have the correct htpasswd setup, see: https://github.com/AdguardTeam/AdGuardHome/wiki/Configuration#password-reset
    
    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    networkingSecrets = config.hostSpec.networking or {};
    hasPrimarySubnet = builtins.hasAttr "subnets" networkingSecrets && builtins.hasAttr "primary" networkingSecrets.subnets;
    subnet = if hasPrimarySubnet then networkingSecrets.subnets.primary else null;
    hostInSecrets = hasPrimarySubnet && builtins.hasAttr hostName subnet.hosts;
    host = if hostInSecrets then subnet.hosts.${hostName} else null;
    domain = networkingSecrets.domain;
    hasPersistDir = config.hostSpec.disks.zfs.root.impermanenceRoot;

    inherit (config.hostSpec.impermanence) dontBackup;
  in
  {
    # Let adguardhome manage DNS, disabling systemd-resolved entirely
    networking.resolvconf = {
      enable = false;  # Don't manage /etc/resolv.conf via resolved
    };
    systemd.services.systemd-resolved.enable = false;

    # Ensure /etc/resolv.conf points somewhere sensible
    environment.etc."resolv.conf".text = lib.mkForce ''
      nameserver 127.0.0.1
    '';
    
    services.adguardhome = {
      enable = true;
      # mutableSettings = false; # declare all settings in this config rather than in the web UI
      # You can select any ip and port, just make sure to open firewalls where needed
      host = "127.0.0.1";
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
          rewrites =
            (lib.optionals hasSecrets [ #TODO: add these for other hosts as well (not sure how yet)
              { enabled = true; domain = hostName; answer = host.ip; }
            ])
            ++ [
              # unconditional entries can safely go here later
              # { domain = "example.internal"; answer = "192.168.1.10"; }
            ];
        };
        ### user rules to enable split-horizon dns. See this wonderful explanation why: https://burakberk.dev/split-horizon-dns-on-adguard-one-domain-two-networks-two-ip-addresses/
        user_rules = [ #TODO: programatically add these in their context (e.g. when adding a service to caddy)
          "||adguard.${domain}^$dnsrewrite=NOERROR;A;${host.ip},client=${subnet.ip}/${toString subnet.prefixLength}"
          "||adguard.${domain}^$dnsrewrite=NOERROR;A;${host.tailip},client=100.0.0.0/8"
          "||home.${domain}^$dnsrewrite=NOERROR;A;${host.ip},client=${subnet.ip}/${toString subnet.prefixLength}"
          "||home.${domain}^$dnsrewrite=NOERROR;A;${host.tailip},client=100.0.0.0/8"
        ];
        filters = map(url: { enabled = true; url = url; }) [
          "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/general/filter_24_1Hosts_Lite/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/other/filter_7_SmartTVBlocklist/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_8_Dutch/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_6_German/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_18_Annoyances_Cookies/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_19_Annoyances_Popups/filter.txt"
          "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/refs/heads/master/filters/filter_21_Annoyances_Other/filter.txt"
        ];
        querylog = {
          enabled = false;
          file_enabled = false;
        };
      theme = "dark"; # important ;)
      };
    };

    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];

    environment.persistence."${dontBackup}" = lib.mkIf hasPersistDir {
      directories = [ "/var/lib/AdGuardHome" ];
    };

    services.caddy.virtualHosts."adguard.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString aghPort}
      '';
    };
  };
}
