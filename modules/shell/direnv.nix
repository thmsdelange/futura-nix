{
  flake.modules.homeManager.shell = {
    programs.direnv = {
      enable = true;
      config = {
        global = {
          hide_env_diff = true;
        };
      };
      nix-direnv.enable = true;
      # one of these could be necessary to silence direnv:
      silent = true;
    };
    # or even
    home.sessionVariables = {
      DIRENV_LOG_FORMAT = "";
    };
  };
}
