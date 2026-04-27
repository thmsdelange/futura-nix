topLevel:
{
  flake.modules.nixos.core =
    { config, lib, pkgs, syncoidClients, ... }:
    let
      cfg = config.hostSpec.services.syncoid;
      thisHost = config.networking.hostName;
      thisHasZfs = config.hostSpec.hasZfs;
      thisHasStorage = config.hostSpec.hasZfsStorage;
      clients = lib.filter (c: c.hostName != thisHost) syncoidClients;
      rootDatasets =
        lib.optional thisHasZfs "zroot/persistSave"
        ++ cfg.extraDatasets;
      storageDatasets =
        lib.optional thisHasStorage "zstorage/persistSave";
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
            ) clients
          );
        })
      ];
    };
}

# topLevel:
# {
#   flake.modules.nixos.core =
#     { config, lib, pkgs, syncoidClients, ... }:
#     let
#       cfg = config.hostSpec.services.syncoid;
#       thisHost = config.networking.hostName;
#       thisHasZfs = config.hostSpec.hasZfs;
#       thisHasStorage = config.hostSpec.hasZfsStorage;
#       clients = lib.filter (c: c.hostName != thisHost) syncoidClients;
#       datasets = lib.optional thisHasZfs "zroot/persistSave"
#         ++ lib.optional thisHasStorage "zstorage/persistSave"
#         ++ cfg.extraDatasets;
#     in
#     {
#       config = lib.mkMerge [
#         (lib.mkIf (thisHasZfs) {
#           services.syncoid.enable = lib.mkIf thisHasZfs true;
#           # users.users.syncoid.shell = lib.mkIf thisHasZfs pkgs.bash;
          
#           systemd.services = lib.mkIf thisHasZfs (
#             lib.mkMerge (
#               map (dataset: {
#                 "syncoid-zfs-allow-${lib.replaceStrings [ "/" ] [ "-" ] dataset}" = {
#                   serviceConfig.ExecStart = "${lib.getExe pkgs.zfs} allow -u syncoid bookmark,snapshot,send,hold ${dataset}";
#                   wantedBy = [ "multi-user.target" ];
#                 };
#               }) datasets
#             )
#           );
#         })
#         (lib.mkIf thisHasStorage {
#           systemd.services."syncoid-zfs-allow-zstorage-persistSave" = {
#             serviceConfig.ExecStart = "${lib.getExe pkgs.zfs} allow -u syncoid bookmark,snapshot,send,hold zstorage/persistSave";
#             wantedBy = [ "multi-user.target" ];
#           };
#         })

#         (lib.mkIf (thisHasZfs && cfg.isBackupServer) {
#           services.syncoid = {
#             interval = "daily";
#             commonArgs = [ "--no-sync-snap" ];
#             commands = lib.mkMerge (
#               [
#                 {
#                   "${thisHost}Save" = {
#                     source = "zroot/persistSave";
#                     target = "zstorage/backups/${thisHost}";
#                     recvOptions = "c";
#                   };
#                 }
#               ]
#               ++ lib.optional thisHasStorage {
#                 "${thisHost}StorageSave" = {
#                   source = "zstorage/persistSave";
#                   target = "zstorage/backups/${thisHost}-storage";
#                   recvOptions = "c";
#                 };
#               }
#               ++ lib.concatMap (c:
#                 [
#                   {
#                     "${c.hostName}Save" = {
#                       source = "syncoid@${c.hostName}:zroot/persistSave";
#                       target = "zstorage/backups/${c.hostName}";
#                       recvOptions = "c";
#                     };
#                   }
#                 ]
#                 ++ lib.optional c.hasStorage {
#                   "${c.hostName}StorageSave" = {
#                     source = "syncoid@${c.hostName}:zstorage/persistSave";
#                     target = "zstorage/backups/${c.hostName}-storage";
#                     recvOptions = "c";
#                   };
#                 }
#               ) clients
#             );
#           };
#         })

#         {
#           services.sanoid = lib.mkIf (thisHasZfs && cfg.isBackupServer) (
#             lib.mkMerge (
#               [
#                 {
#                   datasets."zstorage/backups/${thisHost}" = {
#                     autosnap = false;
#                     autoprune = true;
#                     hourly = 24;
#                     daily = 30;
#                     monthly = 0;
#                     yearly = 0;
#                   };
#                 }
#               ]
#               ++ lib.optional thisHasStorage {
#                 datasets."zstorage/backups/${thisHost}-storage" = {
#                   autosnap = false;
#                   autoprune = true;
#                   hourly = 24;
#                   daily = 30;
#                   monthly = 0;
#                   yearly = 0;
#                 };
#               }
#               ++ lib.concatMap (c:
#                 [
#                   {
#                     datasets."zstorage/backups/${c.hostName}" = {
#                       autosnap = false;
#                       autoprune = true;
#                       hourly = 24;
#                       daily = 90;
#                       monthly = 0;
#                       yearly = 1;
#                     };
#                   }
#                 ]
#                 ++ lib.optional c.hasStorage {
#                   datasets."zstorage/backups/${c.hostName}-storage" = {
#                     autosnap = false;
#                     autoprune = true;
#                     hourly = 24;
#                     daily = 90;
#                     monthly = 0;
#                     yearly = 1;
#                   };
#                 }
#               ) clients
#             )
#           );

#           # systemd.services = lib.mkIf (thisHasZfs && cfg.isBackupServer) (
#           #   lib.mkMerge (
#           #     map (hostName: {
#           #       "syncoid-${hostName}Save" = {
#           #         onSuccess = [ "syncoid-success-${hostName}.service" ];
#           #         onFailure = [ "syncoid-fail-${hostName}.service" ];
#           #       };
#           #       "syncoid-success-${hostName}" = {
#           #         script = ''
#           #           ${lib.getExe pkgs.curl} -X POST \
#           #             ${config.yomaq.gatus.url}/api/v1/endpoints/backup_${hostName}/external\?success\=true\&error\= \
#           #             -H 'Authorization: Bearer ${hostName}'
#           #         '';
#           #       };
#           #       "syncoid-fail-${hostName}" = {
#           #         script = ''
#           #           ${lib.getExe pkgs.curl} -X POST \
#           #             ${config.yomaq.gatus.url}/api/v1/endpoints/backup_${hostName}/external\?success\=false\&error\= \
#           #             -H 'Authorization: Bearer ${hostName}'
#           #         '';
#           #       };
#           #     }) clients
#           #   )
#           # );
#         }
#       ];
#     };
# }
