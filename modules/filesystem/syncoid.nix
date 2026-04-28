topLevel:
{
  flake.modules.nixos.core =
    { config, lib, pkgs, syncoidClients, ... }:
    let
      cfg = config.hostSpec.services.syncoid;
      thisHost = config.networking.hostName;
      thisHasZfs = config.hostSpec.disks.zfs.enable;
      thisHasStorage = config.hostSpec.disks.zfs.storage.enable;
      thisHasNvme = config.hostSpec.disks.zfs.nvme.enable;
      clients = lib.filter (c: c.hostName != thisHost) syncoidClients;
      rootDatasets =
        lib.optional thisHasZfs "zroot/persistSave"
        ++ cfg.extraDatasets;
      storageDatasets =
        lib.optional thisHasStorage "zstorage/persistSave";
      nvmeDatasets =
        lib.optional thisHasStorage "zfast/persistSave";
    in
    {
      config = lib.mkMerge [
        (lib.mkIf thisHasZfs {
          services.syncoid.enable = true;

          systemd.services = lib.mkMerge (
            map (dataset: {
              "syncoid-zfs-allow-${lib.replaceStrings [ "/" ] [ "-" ] dataset}" = {
                serviceConfig.ExecStart = "${lib.getExe pkgs.zfs} allow -u syncoid bookmark,snapshot,send,hold ${dataset}";
                wantedBy = [ "multi-user.target" ];
              };
            }) rootDatasets
          );
        })

        (lib.mkIf thisHasStorage {
          systemd.services = lib.mkMerge (
            map (dataset: {
              "syncoid-zfs-allow-${lib.replaceStrings [ "/" ] [ "-" ] dataset}" = {
                serviceConfig.ExecStart = "${lib.getExe pkgs.zfs} allow -u syncoid bookmark,snapshot,send,hold ${dataset}";
                wantedBy = [ "multi-user.target" ];
              };
            }) storageDatasets
          );
        })

        (lib.mkIf thisHasNvme {
          systemd.services = lib.mkMerge (
            map (dataset: {
              "syncoid-zfs-allow-${lib.replaceStrings [ "/" ] [ "-" ] dataset}" = {
                serviceConfig.ExecStart = "${lib.getExe pkgs.zfs} allow -u syncoid bookmark,snapshot,send,hold ${dataset}";
                wantedBy = [ "multi-user.target" ];
              };
            }) nvmeDatasets
          );
        })

        (lib.mkIf (thisHasZfs && cfg.isBackupServer) {
          services.syncoid = {
            interval = "daily";
            commonArgs = [ "--no-sync-snap" ];
            commands = lib.mkMerge (
              [
                {
                  "${thisHost}Save" = {
                    source = "zroot/persistSave";
                    target = "zstorage/backups/${thisHost}";
                    recvOptions = "c";
                  };
                }
              ]
              ++ lib.optional thisHasStorage {
                "${thisHost}StorageSave" = {
                  source = "zstorage/persistSave";
                  target = "zstorage/backups/${thisHost}-storage";
                  recvOptions = "c";
                };
              }
              ++ lib.optional thisHasNvme {
                "${thisHost}NvmeSave" = {
                  source = "fast/persistSave";
                  target = "zstorage/backups/${thisHost}-nvme";
                  recvOptions = "c";
                };
              }
              ++ lib.concatMap (c:
                [
                  {
                    "${c.hostName}Save" = {
                      source = "syncoid@${c.hostName}:zroot/persistSave";
                      target = "zstorage/backups/${c.hostName}";
                      recvOptions = "c";
                    };
                  }
                ]
                ++ lib.optional c.hasStorage {
                  "${c.hostName}StorageSave" = {
                    source = "syncoid@${c.hostName}:zstorage/persistSave";
                    target = "zstorage/backups/${c.hostName}-storage";
                    recvOptions = "c";
                  };
                }
                ++ lib.optional c.hasNvme {
                  "${c.hostName}NvmeSave" = {
                    source = "syncoid@${c.hostName}:zfast/persistSave";
                    target = "zstorage/backups/${c.hostName}-nvme";
                    recvOptions = "c";
                  };
                }
              ) clients
            );
          };

          services.sanoid = lib.mkMerge (
            [
              {
                datasets."zstorage/backups/${thisHost}" = {
                  autosnap = false;
                  autoprune = true;
                  hourly = 24;
                  daily = 30;
                  monthly = 0;
                  yearly = 0;
                };
              }
            ]
            ++ lib.optional thisHasStorage {
              datasets."zstorage/backups/${thisHost}-storage" = {
                autosnap = false;
                autoprune = true;
                hourly = 24;
                daily = 30;
                monthly = 0;
                yearly = 0;
              };
            }
            ++ lib.optional thisHasNvme {
              datasets."zstorage/backups/${thisHost}-nvme" = {
                autosnap = false;
                autoprune = true;
                hourly = 24;
                daily = 30;
                monthly = 0;
                yearly = 0;
              };
            }
            ++ lib.concatMap (c:
              [
                {
                  datasets."zstorage/backups/${c.hostName}" = {
                    autosnap = false;
                    autoprune = true;
                    hourly = 24;
                    daily = 90;
                    monthly = 0;
                    yearly = 1;
                  };
                }
              ]
              ++ lib.optional c.hasStorage {
                datasets."zstorage/backups/${c.hostName}-storage" = {
                  autosnap = false;
                  autoprune = true;
                  hourly = 24;
                  daily = 90;
                  monthly = 0;
                  yearly = 1;
                };
              }
              ++ lib.optional c.hasNvme {
                datasets."zstorage/backups/${c.hostName}-nvme" = {
                  autosnap = false;
                  autoprune = true;
                  hourly = 24;
                  daily = 90;
                  monthly = 0;
                  yearly = 1;
                };
              }
            ) clients
          );
        })
      ];
    };
}
