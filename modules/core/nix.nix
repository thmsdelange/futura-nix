{
  flake.modules.nixos.core =
    { pkgs, config, ... }:
    let
      inherit (config.hostSpec.impermanence) dontBackup;
    in
    {
      nix = {
        # See https://discourse.nixos.org/t/24-05-add-flake-to-nix-path/46310/9
        # See https://hachyderm.io/@leftpaddotpy/112539055867932912
        channel.enable = false;
        nixPath = [ "nixpkgs=${pkgs.path}" ];

        # From https://jackson.dev/post/nix-reasonable-defaults/
        # Access token prevents github rate limiting if you have to nix flake update a bunch
        extraOptions = ''
          connect-timeout = 5
          log-lines = 50
          min-free = 128000000
          max-free = 1000000000
          fallback = true
          ${if config ? sops then "!include ${config.sops.secrets."tokens/nix-access-tokens".path}" else ""}
        '';
        # Access token prevents github rate limiting if you have to nix flake update a bunch
        # extraOptions =
        #   if config ? "sops" then "!include ${config.sops.secrets."tokens/nix-access-tokens".path}" else "";
        optimise.automatic = true;
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };
        settings = {
          trusted-users = [
            "root"
          ];
          auto-optimise-store = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          warn-dirty = false;
          tarball-ttl = 60 * 60 * 24;
        };
      };
      environment.persistence."${dontBackup}".directories = [ "/root/.local/share/nix" ];
      # FIXME:
      # mkIf (hasPersistDir) { environment.persistence."/persist".directories = ["/root/.local/share/nix"]; };
    };
}
