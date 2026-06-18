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
        lib.optional thisHasNvme "zfast/persistSave";
    in
    {
      config = lib.mkMerge [
        (lib.mkIf thisHasZfs {
          services.syncoid.enable = true;
          users.users.syncoid.shell = pkgs.bash;

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

        ### remote backup pulling from backup server over tailscale
        (lib.mkIf (thisHasZfs && cfg.isBackupServer) {
          services.syncoid = {
            interval = "daily";
            commonArgs = [ 
              "--no-sync-snap"
            ];
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
              ++ lib.optional (thisHasNvme && !thisHasStorage) {
                "${thisHost}NvmeSave" = {
                  source = "zfast/persistSave";
                  target = "zstorage/backups/${thisHost}-nvme";
                  recvOptions = "c";
                };
              }
              ++ lib.concatMap (c:
                [
                  {
                    "${c.hostName}Save" = {
                      source = "syncoid@${c.tailip}:zroot/persistSave";
                      target = "zstorage/backups/${c.hostName}";
                      recvOptions = "c";
                      extraArgs = [
                        "-o" "StrictHostKeyChecking=no"
                        "-o" "UserKnownHostsFile=/dev/null"
                      ];
                    };
                  }
                ]
                ++ lib.optional c.hasStorage {
                  "${c.hostName}StorageSave" = {
                    source = "syncoid@${c.tailip}:zstorage/persistSave";
                    target = "zstorage/backups/${c.hostName}-storage";
                    recvOptions = "c";
                    extraArgs = [
                      "-o" "StrictHostKeyChecking=no"
                      "-o" "UserKnownHostsFile=/dev/null"
                    ];
                  };
                }
                ++ lib.optional c.hasNvme {
                  "${c.hostName}NvmeSave" = {
                    source = "syncoid@${c.tailip}:zfast/persistSave";
                    target = "zstorage/backups/${c.hostName}-nvme";
                    recvOptions = "c";
                    extraArgs = [
                      "-o" "StrictHostKeyChecking=no"
                      "-o" "UserKnownHostsFile=/dev/null"
                    ];
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
            ### only when fast does not backup to storage (which is then backed up to remote)
            ++ lib.optional (thisHasNvme && !thisHasStorage) {
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
              ### only when fast does not backup to storage (which is then backed up to remote)
              ++ lib.optional (c.hasNvme && !c.hasStorage) {
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

          # A service that runs after all syncoid jobs complete and shuts down
          systemd.services.backup-and-shutdown = {
            description = "Run syncoid backups then shut down";
            after = [ "network-online.target" "tailscaled.service" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "backup-and-shutdown" ''
                echo "=== Starting backup run $(date) ==="
                
                failed=0
                for service in ${lib.concatStringsSep " " (lib.mapAttrsToList (name: _: "syncoid-${name}.service") config.services.syncoid.commands)}; do
                  echo "Starting $service..."
                  systemctl start "$service"
                  if systemctl is-failed "$service"; then
                    echo "FAILED: $service"
                    failed=1
                  else
                    echo "OK: $service"
                  fi
                done

                echo "=== Backup run complete $(date) ==="
                
                if [ $failed -eq 1 ]; then
                  echo "Some backups failed, check journalctl"
                fi

                echo "Shutting down..."
                systemctl poweroff
              '';
              RemainAfterExit = false;
            };
            wantedBy = [ "multi-user.target" ];
          };
        })

        ### local backup from fast to storage
        (lib.mkIf (thisHasNvme && thisHasStorage && !cfg.isBackupServer) {
          services.syncoid = {
            interval = "*:15";
            commonArgs = [ "--no-sync-snap" ];
            commands = {
              "${thisHost}NvmeSave" = {
                source = "zfast/persistSave";
                target = "zstorage/backups/${thisHost}-nvme";
                recvOptions = "c";
              };
            };
          };
          services.sanoid.datasets."zstorage/backups/${thisHost}-nvme" = {
            autosnap = false;
            autoprune = true;
            hourly = 24;
            daily = 30;
            monthly = 0;
            yearly = 0;
          };
        })
      ];
    };
}
