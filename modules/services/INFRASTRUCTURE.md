# Infrastructure of services

- DNS server in tailscale is set to (tailscale) IP of [twinpines](https://github.com/thmsdelange/nix-futura/tree/main/modules/hosts/twinpines/TWINPINES.md) such that all DNS queries on the tailnet are resolved by the [adguardhome](https://github.com/thmsdelange/nix-futura/tree/main/modules/services/adguardhome.nix) instance.
- On the adguardhome instance a dns rewrite is placed that points my domain name \*.example.com to the internal ip of the twinpines host
- This, way, whether I'm on my local home network or on my tailscale network, all services that are exposed via caddy are accessible.
- Since I'm also hosting some stuff from my other (legacy servers) publicly, I can't use wildcard certs for the subdomains here, as it will throw a SSL error when navigating to one of these subdomains from my local network. Luckily, I like to be explicit anyway so defining the subdomains I will need certificates for is fine for me.

> I'm obviously not qualified to clearly explain the concept here. For a way better explanation of what I was trying to achieve, see [this](https://burakberk.dev/split-horizon-dns-on-adguard-one-domain-two-networks-two-ip-addresses/) article
