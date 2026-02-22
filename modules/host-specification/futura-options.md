# Host specification

Greatly inspired by hyperparabolic's [this module](https://github.com/hyperparabolic/nix-config/tree/main/modules/this) and EmergentMind's [hostSpec options](https://github.com/EmergentMind/nix-config/blob/dev/modules/common/host-spec.nix)

> HostSpec should be used for more fine-grained control over the configuration, not to determine what is enabled and what not. A great example is the primary user, which can be configured in hostSpec. This way the primary user module can stay generic.
