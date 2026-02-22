{
  flake.modules.nixos.core = {
    services.dbus.implementation = "broker";
  };
}
