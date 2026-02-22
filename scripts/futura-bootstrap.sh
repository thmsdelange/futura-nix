#!/usr/bin/env bash
set -euo pipefail

# Helpers library
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/sops-helpers.sh"
# source "$(dirname "$0")/sops-helpers.sh"
# source "$(command -v sops-helpers)"
# source "${SOPS_HELPERS}/sops-helpers.sh"

# User variables
target_hostname=""
target_destination=""
target_user=${BOOTSTRAP_USER-$(whoami)} # Set BOOTSTRAP_ defaults in your shell.nix
ssh_port=${BOOTSTRAP_SSH_PORT-22}
ssh_key=${BOOTSTRAP_SSH_KEY-}
persist_dir=""
# luks_passphrase="passphrase"
# luks_secondary_drive_labels=""
# nix_src_path="" # path relative to /home/${target_user} where nix-config and nix-secrets are written in the users home
# git_root=$(git rev-parse --show-toplevel)
# nix_secrets_dir=${NIX_SECRETS_DIR:-"${git_root}"/../nix-secrets}

# Create a temp directory for generated host keys
temp=$(mktemp -d)

# Cleanup temporary directory on exit
function cleanup() {
	rm -rf "$temp"
}
trap cleanup exit

# Usage function
function help_and_exit() {
	echo
	echo "Remotely installs NixOS on a target machine using this nix-config."
	echo
	echo "USAGE: $0 -n <target_hostname> -d <target_destination> -u <target_user> -k <ssh_key> [OPTIONS]"
	echo
	echo "ARGS:"
	echo "  -n <target_hostname>                    specify target_hostname of the target host to deploy the nixos config on."
	echo "  -d <target_destination>                 specify ip or domain to the target host."
    echo "  -u <target_user>                        specify user to use for the installation."
	echo "  -k <ssh_key>                            specify the full path to the ssh_key you'll use for remote access to the"
	echo "                                          target during install process."
	echo "                                          Example: -k /home/${target_user}/.ssh/my_ssh_key"
	echo
	echo "OPTIONS:"
	echo "  -u <target_user>                        specify target_user with sudo access. nix-config will be cloned to their home."
	echo "                                          Default='${target_user}'."
	echo "  --port <ssh_port>                       specify the ssh port to use for remote access. Default=${ssh_port}."
	echo '  --luks-secondary-drive-labels <drives>  specify the luks device names (as declared with "disko.devices.disk.*.content.luks.name" in host/common/disks/*.nix) separated by commas.'
	echo '                                          Example: --luks-secondary-drive-labels "cryptprimary,cryptextra"'
	echo "  --impermanence                          Use this flag if the target machine has impermanence enabled. WARNING: Assumes /persist path."
	echo "  --debug                                 Enable debug mode."
	echo "  -h | --help                             Print this help."
	exit 0
}

# Handle command-line arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	-n)
		shift
		target_hostname=$1
		;;
	-d)
		shift
		target_destination=$1
		;;
	-u)
		shift
		target_user=$1
		;;
	-k)
		shift
		ssh_key=$1
		# ;;
	# --luks-secondary-drive-labels)
	# 	shift
	# 	luks_secondary_drive_labels=$1
		;;
	--port)
		shift
		ssh_port=$1
		;;
	--temp-override)
		shift
		temp=$1
		;;
	--impermanence)
		persist_dir="/persist"
		;;
	--debug)
		set -x
		;;
	-h | --help) help_and_exit ;;
	*)
		red "ERROR: Invalid option detected."
		help_and_exit
		;;
	esac
	shift
done

if [ -z "$target_hostname" ] || [ -z "$target_destination" ] || [ -z "$target_user" ] || [ -z "$ssh_key" ]; then
	red "ERROR: -n, -d, -u, and -k are all required"
	echo
	help_and_exit
fi

# SSH commands
# ssh_cmd="ssh \
#         -oControlPath=none \
#         -oport=${ssh_port} \
#         -oForwardAgent=yes \
#         -oStrictHostKeyChecking=no \
#         -oUserKnownHostsFile=/dev/null \
#         -i $ssh_key \
#         -t $target_user@$target_destination"
# shellcheck disable=SC2001
# ssh_root_cmd=$(echo "$ssh_cmd" | sed "s|${target_user}@|root@|") # uses @ in the sed switch to avoid it triggering on the $ssh_key value
# scp_cmd="scp -oControlPath=none -oport=${ssh_port} -oStrictHostKeyChecking=no -i $ssh_key"

# git_root=$(git rev-parse --show-toplevel)


# Clear the known keys, since they should be newly generated for the iso
green "Wiping known_hosts of $target_destination"
sed -i "/$target_hostname/d; /$target_destination/d" ~/.ssh/known_hosts

green "Installing NixOS on remote host $target_hostname at $target_destination"

###
# nixos-anywhere extra-files generation
###
green "Preparing a new ssh_host_ed25519_key pair for $target_hostname."
# Create the directory where sshd expects to find the host keys
install -d -m755 "$temp/$persist_dir/etc/ssh"

# Generate host ssh key pair without a passphrase
ssh-keygen -t ed25519 -f "$temp/$persist_dir/etc/ssh/ssh_host_ed25519_key" -C "$target_user"@"$target_hostname" -N ""

# Set the correct permissions so sshd will accept the key
chmod 600 "$temp/$persist_dir/etc/ssh/ssh_host_ed25519_key"

# Setting up sops with the host key
sops_setup_host_age_key "$target_user" "$target_hostname" "$temp/$persist_dir/etc/ssh/ssh_host_ed25519_key.pub"


green "Preparing a new id_ed25519 key pair for $target_user."
# Create the directory where sshd expects to find the host keys
install -d -m755 "$temp/home/$target_user/.ssh"

# Generate host ssh key pair without a passphrase
ssh-keygen -t ed25519 -f "$temp/home/$target_user/.ssh/id_ed25519" -C "$target_user"@"$target_hostname" -N ""

# Set the correct permissions so sshd will accept the key
# chown "$target_user":"users" -R $temp/home/$target_user/.ssh
chmod 600 "$temp/home/$target_user/.ssh/id_ed25519"

# Setting up sops with the user key
sops_setup_user_age_key "$target_user" "$target_hostname" "$temp/home/$target_user/.ssh/id_ed25519.pub"

# Rekey-ing
cd ../futura-secrets
find sops/ -name '*.yaml' -exec sh -c '
  for f; do
    echo "updating keys in $f"
    sops updatekeys -y "$f"; 
  done
' sh {} +

# Pushing to secrets repo
git add -A && (git commit -nm "chore: rekey" || true) && git push

# Updating flake input
cd ../futura-nix
nix flake update


# green "Adding ssh host fingerprint at $target_destination to ~/.ssh/known_hosts"
# # This will fail if we already know the host, but that's fine
# ssh-keyscan -p "$ssh_port" "$target_destination" | grep -v '^#' >>~/.ssh/known_hosts || true

###
# nixos-anywhere installation
###
# cd nixos-installer
# when using luks, disko expects a passphrase on /tmp/disko-password, so we set it for now and will update the passphrase later
# if no_or_yes "Manually set luks encryption passphrase? (Default: \"$luks_passphrase\")"; then
# 	blue "Enter your luks encryption passphrase:"
# 	read -rs luks_passphrase
# 	$ssh_root_cmd "/bin/sh -c 'echo $luks_passphrase > /tmp/disko-password'"
# else
# 	green "Using '$luks_passphrase' as the luks encryption passphrase. Change after installation."
# 	$ssh_root_cmd "/bin/sh -c 'echo $luks_passphrase > /tmp/disko-password'"
# fi
# # this will run if luks_secondary_drive_labels cli argument was set, regardless of whether the luks_passphrase is default or not
# if [ -n "${luks_secondary_drive_labels}" ]; then
# 	luks_setup_secondary_drive_decryption
# fi

# # If you are rebuilding a machine without any hardware changes, this is likely unneeded or even possibly disruptive
# if no_or_yes "Generate a new hardware config for this host? Yes if your nix-config doesn't have an entry for this host."; then
# 	green "Generating hardware-configuration.nix on $target_hostname and adding it to the local nix-config."
# 	$ssh_root_cmd "--generate-hardware-config nixos-facter modules/hosts/$target_hostname/facter.json"
# 	generated_hardware_config=1
# fi

# nixos_anywhere_cmd = /bin/sh nix run github:nix-community/nixos-anywhere -- \
#         --ssh-port "$ssh_port" \
#         --post-kexec-ssh-port "$ssh_port" \
#         --extra-files "$temp" \
#         --flake .#"$target_hostname" \
#         --target-host "$target_user"@"$target_destination"

# if no_or_yes "Generate a new hardware config for this host? Yes if your nix-config doesn't have an entry for this host (using facter)."; then
#     nixos_anywhere_cmd += --generate-hardware-config nixos-facter modules/hosts/continuum/facter.json
# fi

# SHELL=${nixos_anywhere_cmd}

# Base nixos-anywhere command as an array
nixos_anywhere_cmd=(
    nix run github:nix-community/nixos-anywhere -- \
    --ssh-port "$ssh_port" \
    --post-kexec-ssh-port "$ssh_port" \
    --extra-files "$temp" \
    --flake .#"$target_hostname" \
    --target-host "$target_user"@"$target_destination"
)

# Append flag if user confirms
if no_or_yes "Generate a new hardware config for this host? Yes if your nix-config doesn't have an entry for this host (using facter)."; then
    nixos_anywhere_cmd+=(--generate-hardware-config "nixos-facter" "modules/hosts/$target_hostname/facter.json")
fi

# Print command
echo "The nixos-anywhere command to run is:"
printf ' %q' "${nixos_anywhere_cmd[@]}"
echo

# Confirm before execution
if no_or_yes "Install using this command?"; then
    "${nixos_anywhere_cmd[@]}"
else
    echo "Installation execution cancelled."
fi


# # if ! yes_or_no "Has your system restarted and are you ready to continue? (no exits)"; then
# # 	exit 0
# # fi

# green "Adding $target_destination's ssh host fingerprint to ~/.ssh/known_hosts"
# ssh-keyscan -p "$ssh_port" "$target_destination" | grep -v '^#' >>~/.ssh/known_hosts || true

# if [ -n "$persist_dir" ]; then
# 	$ssh_root_cmd "cp /etc/machine-id $persist_dir/etc/machine-id || true"
# 	$ssh_root_cmd "cp -R /etc/ssh/ $persist_dir/etc/ssh/ || true"
# fi
# cd - >/dev/null
