# Twinpines

Hosted on a raspberry pi 3b+, the architecture of this host differs a bit from the other hosts. For example, it cannot be deployed using nixos-anywhere because [I can't get it to boot from usb](https://discourse.nixos.org/t/rpi3-with-uefi/60225/18), leaving only the option of installing an iso on the sd card (at least, to my limited knowledge). So, the steps to install this host differ a bit from the rest:

1. [Download](https://hydra.nixos.org/job/nixos/unstable/nixos.sd_image.aarch64-linux) the minimal aarch64 installer iso and burn it on the sd card

```
unzstd nixos-image-sd-card-26.05pre948083.0182a3613243-aarch64-linux.img.zst
sudo dd if=nixos-image-sd-card-26.05pre948083.0182a3613243-aarch64-linux.img of=/dev/mmcblk0 bs=10MB oflag=dsync status=progress
```

2. Boot the pi into the installer and set the user (nixos) and root passwords to a simple password so we can ssh in later to deploy our config

```
mkpasswd
sudo -i
mkpasswd
```

3. Check that you can ssh into the pi

```
ssh root@nixos
```

4. Generate hardware configuration using [facter](https://github.com/nix-community/nixos-facter)

```
ssh root@nixos \
  'nix run --option experimental-features "nix-command flakes" nixpkgs#nixos-facter -- -o facter.json'
scp root@nixos:/root/facter.json modules/hosts/twinpines/facter.json
```

also get the nixos hardware config so we can easily update our config with the filesystems

```
ssh root@nixos \
  'nixos-generate-confg'
scp root@nixos:/etc/nixos/hardware-configuration.nix modules/hosts/twinpines
```

Now the filesystems in `modules/hosts/twinpines/default.nix` can be set.

3. Create host and user keys, and update the secrets with this, and copy over to the pi.
   For the host:

```
ssh-keygen -t ed25519 -f "$temp/ssh_host_ed25519_key" -C "thms"@"twinpines" -N ""
chmod 600 $temp/ssh_host_ed25519_key
just sops-setup-host-age-key "thms" "twinpines" "$temp/ssh_host_ed25519_key.pub"
```

For the user:

```
ssh-keygen -t ed25519 -f "$temp/id_ed25519" -C "thms"@"twinpines" -N ""
chmod 600 $temp/id_ed25519
just sops-setup-user-age-key "thms" "twinpines" "$temp/id_ed25519.pub"
```

Rekey, commit and push newly encrypted secrets:

```
just rekey
git add -A && (git commit -nm "chore: rekey" || true) && git push
```

Update the flake inputs with the updated secrets

```
cd ../futura-nix && nix flake update
```

And lastly copy over the created keys and destroy the temp directory

```
scp $temp/ssh_host_ed25519_key* root@nixos:/etc/ssh/
ssh root@nixos 'mkdir -p /home/thms/.ssh'
scp $temp/id_ed25519* root@nixos:/home/thms/.ssh/
ssh root@nixos 'chown -R 1000:100 /home/thms'
```

The pi now has the ssh keys which will later be used to decrypt the secrets.

5. Deploy the configuration, make sure to build locally, not on the pi

```
deploy ......
```
