# TODO: this is a bit much, find a more sane default config
{
  flake.modules.homeManager.dev =
    { config, lib, ... }:
    let
      inherit (config.hostSpec) isWork;
      adminUser = builtins.head (builtins.attrNames (lib.filterAttrs (_: u: u.isAdmin) config.hostSpec.users));
      gitUserName = config.hostSpec.users.${adminUser}.name;
      gitUserEmail = if !isWork then config.hostSpec.users.${adminUser}.email.user else config.hostSpec.users.${adminUser}.email.work;
    in
    {
      programs = {
        git = {
          enable = true;
          settings = {
            user = {
              name = gitUserName;
              email = gitUserEmail;
            };
            
            # TODO: add signing later
            # signing = {
            #   signByDefault = true;
            #   key = adminUser.key;
            # };
            # commit = {
            #   gpgsign = true;
            # };

            core.pager = "delta";
            pager = {
              diff = "delta";
              log = "delta";
              reflog = "delta";
              show = "delta";
            };
            interactive.diffFilter = "delta --color-only";
            delta = {
              # UX
              hyperlinks = true;
              navigate = true;
              line-numbers = true;
              side-by-side = false;
              detect-dark-light = true;
              # Readability
              true-color = "auto";
              syntax-theme = "GitHub";
              whitespace-error-style = "22 reverse";
              # Noise
              hunk-header-style = "syntax";
              line-numbers-left-style = "dim";
              line-numbers-right-style = "dim";
              line-numbers-minus-style = "red";
              line-numbers-plus-style = "green";
            };
          };
        };

        delta = {
          enable = true;
        };

        lazygit = {
          enable = true;
          # settings = {
          #   git.overrideGpg = true;
          # };
        };
      };
    };
}
