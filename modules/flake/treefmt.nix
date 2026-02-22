{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      treefmt.config = {
        projectRootFile = "flake.nix";
        flakeCheck = false; # TODO: flip to true when I'm brave and want to format my nix
        programs = {
          nixfmt.enable = true;
        };
      };
    };
}
