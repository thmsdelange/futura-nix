### Networking

I messed up the networking config, which I found out when I rebooted [twinpines](https://github.com/thmsdelange/nix-futura/tree/main/modules/hosts/twinpines/TWINPINES.md) and it suddenly became inaccessible. When I connected twinpines to my monitor I could verify that it did not have an ip address anymore, whoops! After countless rolled back nixos-generations, I (actually, smarter people than I am told me) managed to find a way to make it at least temporatily accessible again, on the pi connected to a keyboard and monitor:

```
sudo ip addr add <ip>/24 dev <interface>
sudo ip link set <interface> up
```

confirm with:

```
ip a
```

> This is why deploy-rs is such amazing software, it has a core feature [magic rollback](https://github.com/serokell/deploy-rs?tab=readme-ov-file#magic-rollback) made to prevent these issues: it rolls back when it senses that the host becomes unreachable after applying the configuration to the remote. A feature my stubborn ass circumvented by using `--magic-rollback="false"`. At a first glace, this seemed fine, so I didn't see the issue to not use it to push my configuration (that otherwise gave an annoying error, meh!). It turned out that the issue only occurred after a reboot... _Although it showed no error on a new networking configuration which it happily applied, and then failed after a reboot as well. So all in all: it's mainly my networking skills to blame_

So now let's find out what happened. I can ssh into the system again and grab some logs:

```
mrt 07 09:52:56 nixos systemd-timesyncd[488]: Network configuration changed, trying to establish connection.
mrt 07 09:52:57 nixos systemd[1]: Reached target Preparation for Network.
mrt 07 09:52:57 nixos network-addresses-<interface>-start[804]: adding address <ip>... done
mrt 07 09:52:57 nixos systemd[1]: Starting Networking Setup...
mrt 07 09:52:58 nixos network-setup-start[876]: Cannot find device "<interface>"
mrt 07 09:52:58 nixos systemd[1]: network-setup.service: Main process exited, code=exited, status=1/FAILURE
mrt 07 09:52:58 nixos systemd[1]: network-setup.service: Failed with result 'exit-code'.
mrt 07 09:52:58 nixos systemd[1]: Failed to start Networking Setup.
```

Okay, it can't find the interface. Weird. Turns out I mixed some incompatible networking approaches. Right now, I fully moved to networkd to handle my networking configuration (instead of setting countless nixos options zip-tied together).
