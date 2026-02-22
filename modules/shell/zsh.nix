{
  flake.modules.nixos.shell = 
  {
    programs.zsh = {
      enable = true; # Enable zsh as the default shell
      enableCompletion = true; # Enable command completion
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      interactiveShellInit =
        ""; # Extra commands to run at interactive shell initialization

      loginShellInit = ""; # Extra commands to run at login shell initialization

      promptInit = ""; # Extra commands to run at prompt initialization

      # # TODO: migrate my theme here
      # ohMyZsh = {
      #   enable = true; # Enable Oh My Zsh
      #   plugins = [ "fzf" ]; # Oh My Zsh plugins
      #   # theme = "fino"; # Oh My Zsh theme
      #   # custom = ""; # Custom Oh My Zsh configuration
      # };
    };
  };

  flake.modules.nixos.user-primary = 
    { pkgs, config, ... }:
    {
      users.users."${config.hostSpec.users.primary.username}" = {
        shell = pkgs.zsh;
        ignoreShellProgramCheck = true;
      };
    };
  
  flake.modules.homeManager.shell = 
  {
    config,
    lib,
    pkgs,
    ...
  }:
  {
    programs.fzf.enable = true;
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      # envExtra = [ "TERM=$TERM" ];

      oh-my-zsh = {
        enable = true;
        plugins = [ "fzf" ];
      };

      plugins = [
        # is this first block needed and why does it point to share?
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
          src = lib.cleanSource ./p10k-config;
          file = "p10k.zsh";
        }
      ];

      history = {
        size = 10000;
        # path = "${config.xdg.dataHome}/zsh/history";
        path = "/home/thms/.config/zsh/history"; # TODO: move to relevant persist dir
      };

      shellAliases = {
        sudo = "doas";
        # ls = "lsd";
        # ll = "lsd -l";
        # la = "lsd -lah --group-dirs first";
      };
    };
  };
}
