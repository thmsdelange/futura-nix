# TODO: explicit import lib functions
{
  inputs,
  ...
}:
{
  flake = {
    modules.nixos.core = 
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      inherit (config.hostSpec) hasSecrets;
      secretsRepo = builtins.toString inputs.futura-secrets;
      groupExist = config: groups: lib.filter (group: lib.hasAttr group config.users.groups) groups;

      users = config.hostSpec.users;
      adminUsers = lib.filterAttrs (_: u: u.isAdmin) users;

      # _check = let
      #   nUsers = builtins.length (builtins.attrNames users);
      #   nAdmins = builtins.length (builtins.attrNames adminUsers);
      # in
      #   if nUsers == 0 then throw "hostSpec.users: At least one system user must be specified"
      #   else if nAdmins == 0 then throw "hostSpec.users: At least one user must be marked as isAdmin = true"
      #   else if nAdmins > 1 then throw "hostSpec.users: No more than 1 user can be marked as isAdmin = true"
      #   else true;

      adminUser = builtins.head (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
    in
    {
      sops.secrets = lib.mkIf hasSecrets (
        lib.foldl' (acc: name:
          let
            sopsFile = "${secretsRepo}/secrets/users/${name}.yaml"; 
          in
          acc // {
            "users/${name}/passwd" = { 
              inherit sopsFile; 
              key = "passwd"; 
              neededForUsers = true; 
            };
            "users/${name}/id_ed25519" = { 
              inherit sopsFile; 
              key = "id_ed25519"; 
              owner = name; 
              group = "users"; 
              mode = "0600"; 
              path = "/home/${name}/.ssh/id_ed25519"; 
            };
            "users/${name}/id_ed25519_pub" = { 
              inherit sopsFile; 
              key = "id_ed25519_pub"; 
              owner = name; 
              group = "users"; 
              mode = "0644"; 
              path = "/home/${name}/.ssh/id_ed25519.pub";
            };
          }
        ) {} (builtins.attrNames config.hostSpec.users)
      );
        
      ### setting user
      users.mutableUsers = lib.mkDefault false;

      users.users = lib.mapAttrs (name: user:
        {
          description = user.name;
          createHome = true;
          home = "/home/${name}";
          # shell = "/run/current-system/sw/bin/${shell}"; # TODO
          uid = lib.mkDefault 1000;
          isNormalUser = lib.mkDefault true;

          extraGroups =
            (if user.isAdmin then [ "wheel" ] else [])
            ++ [ "nix" ]
            ++ groupExist config [
              "audio"
              "dialout" # Or else: Permission denied: ‘/dev/ttyUSB0’
              "input"
              "networkmanager"
              "sound"
              "tty"
              "wheel"
            ];

          ### setting initial throwaway password as well so we don't get locked out
          initialHashedPassword = lib.mkIf (!hasSecrets) (lib.mkDefault "$6$ZF1sMTVT9As8zING$51//RbVLuUiy/f35.KrPFP7NZjJGKgcv7uKwsIvr07hnSOCmKeHOZ9IwYQVM3ZH3FE3pmOunN3wY04npawroI1");
          hashedPasswordFile = lib.mkIf hasSecrets config.sops.secrets."users/${name}/passwd".path;
          openssh.authorizedKeys.keyFiles = (if hasSecrets then [ 
            config.sops.secrets."users/${name}/id_ed25519_pub".path 
          ] else []) ++ (if builtins.length user.authorizedKeys > 0 then user.authorizedKeys else []);
        }
      ) config.hostSpec.users
      // {
        ### setting up the root user
        root = {
          shell = pkgs.bashInteractive;
          initialHashedPassword = lib.mkIf (!hasSecrets) (lib.mkDefault "$6$U5.vI.2kBVm2eXQ3$nVdYX55elWyFo2v6RHy.e.HXBXDWfaMN/iVLHysBAgdSgTPygTOqPr47k8rVLMNsdIeR4Yb7MkUcpQVEHf0VL0");
          hashedPasswordFile = lib.mkIf hasSecrets config.sops.secrets."users/${adminUser}/passwd".path;
          hashedPassword = null;
          initialPassword = null;
          password = null;
        };
      };

      ### trusting the admin user
      nix.settings.trusted-users = map (k: k) (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
    };

    modules.homeManager.core = 
      { config, ... }:
      {
        #   home.file = {
        #     ".face" = {
        #       source = ../../../files/home/"${cfg.username}"/.face;
        #       recursive = true;
        #     };
        #     ".face.icon" = {
        #       source = ../../../files/home/"${cfg.username}"/.face;
        #       recursive = true;
        #     };
        #     # Credits to https://store.kde.org/p/1272202
        #     "Pictures/Backgrounds/" = {
        #       source = ../../../files/home/"${cfg.username}"/Pictures/Backgrounds;
        #       recursive = true;
        #     };
        #   };
      };
  };
}