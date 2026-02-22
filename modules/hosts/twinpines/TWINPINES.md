# Twinpines

Hosted on a raspberry pi 3b+, the architecture of this host differs a bit from the other hosts. For example, it cannot be deployed using nixos-anywhere because [I can't get it to boot from usb](https://discourse.nixos.org/t/rpi3-with-uefi/60225/18), leaving only the option of installing an iso on the sd card (at least, to my limited knowledge). So, the steps to install this host differ a bit from the rest:

1. Download the minimal aarch64 installer iso and burn it on the sd card

```
sudo dd if=<image> of=/dev/mmcblk0 bs=10MB oflag=dsync status=progress
```

2. Boot the pi into the installer and set the user (nixos) and root passwords to a simple password so we can ssh in later to deploy our config

```
mkpasswd
sudo -i
mkpasswd
```

3. Generate host and user ssh keys and set the correct permissions

```
ssh-keygen

mkdir -p /home/<USER>/.ssh
chmod 600?
```

4. Derive the age keys from them, add them to the `.sops.yaml` and add creation rules (on the local device, not on the pi)
   Adding the host and user keys to the `.sops.yaml`

```
cat /home/<USER>/.ssh/id_ed25519.pub | ssh-to-age
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

Adding them to `.sops.yaml`

```
just sops-update-user-age-key <USER> twinpines <USER_KEY>:
just sops-update-host-age-key twinpines <HOST_KEY>
```

Adding the user to the user creation rules and twinpines to the shared creation rules

```
just sops-add-user-creation-rules <USER> twinpines:
just sops-add-shared-creation-rules twinpines
```

5. Deploy the configuration, make sure to build locally, not on the pi

```
deploy ......
```
