{
  flake.modules.homeManager.shell =
  { pkgs, ... }: 
  {
    home.packages = with pkgs; [
      zip
      unzip
      wget
    ];
  };
}
