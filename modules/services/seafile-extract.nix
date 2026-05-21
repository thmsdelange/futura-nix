{
  flake.modules.nixos.seafile-extract =
  { inputs, hostConfig, config, pkgs, lib, ... }:
  let
    hostName = hostConfig.name;
    inherit (config.hostSpec) hasSecrets;
    sopsRoot = builtins.toString inputs.futura-secrets;
    domain = config.hostSpec.networking.domain;
  in
  {
    sops.secrets = lib.mkIf hasSecrets {
      "services/seafile/mysql-root-password" = {
        sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
      };
      "services/seafile/admin-user" = {
        sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
      };
      "services/seafile/admin-password" = {
        sopsFile = "${sopsRoot}/sops/hosts/${hostName}.yaml";
      };
    };

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers = {
      seafile-mysql = {
        image = "mariadb:10.11";
        environment = {
          MYSQL_LOG_CONSOLE = "true";
          MARIADB_AUTO_UPGRADE = "1";
        };
        environmentFiles = lib.mkIf hasSecrets [
          config.sops.templates."seafile-db-env".path
        ];
        volumes = [
          "/storage/save/seafile/db:/var/lib/mysql"
        ];
        extraOptions = [ "--network=seafile-net" "--ip=10.90.0.2" ];
      };

      seafile-memcached = {
        image = "memcached:1.6.18";
        cmd = [ "memcached" "-m" "256" ];
        extraOptions = [ "--network=seafile-net" "--ip=10.90.0.3" ];
      };

      seafile = {
        image = "seafileltd/seafile-mc:11.0.8";
        environment = {
          DB_HOST = "10.90.0.2";
          TIME_ZONE = "Europe/Amsterdam";
          NON_ROOT = "true";
          # SEAFILE_ADMIN_EMAIL = "admin@${domain}";
          # SEAFILE_ADMIN_PASSWORD = "changeme123";
        };
        environmentFiles = lib.mkIf hasSecrets [
          config.sops.templates."seafile-db-env".path
        ];
        volumes = [
          "/mnt/hot/data/seafile:/shared"
        ];
        ports = [
          "127.0.0.1:8090:80"
        ];
        dependsOn = [ "seafile-mysql" "seafile-memcached" ];
        extraOptions = [ "--network=seafile-net" "--ip=10.90.0.4" "--device=/dev/fuse" "--cap-add=SYS_ADMIN" "--security-opt=label=disable" ];
      };
    };

    sops.templates."seafile-db-env" = lib.mkIf hasSecrets {
      content = ''
        MYSQL_ROOT_PASSWORD=${config.sops.placeholder."services/seafile/mysql-root-password"}
        DB_ROOT_PASSWD=${config.sops.placeholder."services/seafile/mysql-root-password"}
        SEAFILE_ADMIN_EMAIL=${config.sops.placeholder."services/seafile/admin-user"}
        SEAFILE_ADMIN_PASSWORD=${config.sops.placeholder."services/seafile/admin-password"}
      '';
    };

    systemd.services.podman-seafile = {
      after = [ "podman-seafile-mysql.service" "podman-seafile-memcached.service" ];
      requires = [ "podman-seafile-mysql.service" "podman-seafile-memcached.service" ];
    };

    systemd.services.init-seafile-network = {
      description = "Create seafile podman network";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.podman}/bin/podman network exists seafile-net || \
        ${pkgs.podman}/bin/podman network create --disable-dns --subnet 10.90.0.0/24 seafile-net
      '';
    };
  };
}