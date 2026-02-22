# git is core no matter what but additional settings may could be added made in e.g. flake.modules.<...>.dev
{
  flake.modules.homeManager.core = 
    {
      pkgs,
      ...
    }:
    {
      programs.git = {
        enable = true;
        package = pkgs.gitFull;

        ignores = [
          ".csvignore"
          # nixgi
          "*.drv"
          "result"
          # python
          "*.py?"
          "__pycache__/"
          ".venv/"
          # direnv
          ".direnv"
        ];
      };
    };
}