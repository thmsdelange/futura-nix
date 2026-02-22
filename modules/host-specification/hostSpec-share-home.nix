topLevel: {
  flake.modules.nixos.hostSpec-share-home =
    { ... }:
    {
      home-manager = {
        sharedModules = with topLevel.config.flake.modules.homeManager; [
          hostSpec
        ];
      };
    };
}
