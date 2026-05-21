{
  inputs,
  ...
}:
{
  systems = import inputs.systems ++ [ "aarch64-linux" ];
}
