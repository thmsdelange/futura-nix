{
  flake.modules.homeManager.shell = {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y"; # needed for: evaluation warning: The default value of `programs.yazi.shellWrapperName` has changed from `yy` to `y`.
      settings = {
        open = {
          rules = [
            {
              mime = "application/pdf";
              use = "pdf";
            }
          ];
        };
        opener = {
          pdf = [
            {
              run = "zathura \"$@\"";
              orphan = true;
              for = "unix";
            }
          ];
        };
      };
    };
  };
}
