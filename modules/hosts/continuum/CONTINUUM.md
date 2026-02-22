# Continuum host

Test vm

### Fix for unable to import zpool after deployment

It's super silly, but the VM is [just a bit particular](https://discourse.nixos.org/t/zfs-with-disko-faluire-to-import-zfs-pool/61988/6) about which disk uuid's it expects, see fix in `modules/filesystem/disks.nix`:

```
zfs = {
    devNodes = if config.hostSpec.isVM # see: https://discourse.nixos.org/t/zfs-with-disko-faluire-to-import-zfs-pool/61988/6
    then "/dev/disk/by-uuid"
    else "/dev/disk/by-id/";
    forceImportAll = true;
    requestEncryptionCredentials = true;
};
```
