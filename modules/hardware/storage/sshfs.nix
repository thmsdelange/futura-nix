{ pkgs, ... }:
{
  flake.modules.nixos.sshfs = {
    environment.systemPackages = with pkgs; [ sshfs ];
    # fileSystems."/home/thomas/snellius" = {
    #   device = "tdlange@snellius.surf.nl:/home/tdlange/";
    #   fsType = "fuse.sshfs";
    #   options = [
    #     "identityfile=/home/thomas/.ssh/id_ed25519"
    #     "idmap=user"
    #     "x-systemd.automount" # mount the filesystem automatically on first access
    #     "allow_other" # don't restrict access to only the user which `mount`s it (because that's probably systemd who mounts it, not you)
    #     "user" # allow manual `mount`ing, as ordinary user.
    #     "_netdev"
    #     "ServerAliveCountMax=3"
    #     "ServerAliveInterval=30"
    #     "uid=thomas"
    #     "gid=users"
    #     "reconnect"
    #   ];
    # };
    # boot.supportedFilesystems."fuse.sshfs" = true;
  };
}
