#!/usr/bin/env bash
set -eo pipefail

### UX helpers

function red() {
	echo -e "\x1B[31m[!] $1 \x1B[0m"
	if [ -n "${2-}" ]; then
		echo -e "\x1B[31m[!] $($2) \x1B[0m"
	fi
}

function green() {
	echo -e "\x1B[32m[+] $1 \x1B[0m"
	if [ -n "${2-}" ]; then
		echo -e "\x1B[32m[+] $($2) \x1B[0m"
	fi
}

function blue() {
	echo -e "\x1B[34m[*] $1 \x1B[0m"
	if [ -n "${2-}" ]; then
		echo -e "\x1B[34m[*] $($2) \x1B[0m"
	fi
}

function yellow() {
	echo -e "\x1B[33m[*] $1 \x1B[0m"
	if [ -n "${2-}" ]; then
		echo -e "\x1B[33m[*] $($2) \x1B[0m"
	fi
}

# Ask yes or no, with yes being the default
function yes_or_no() {
	echo -en "\x1B[34m[?] $* [y/n] (default: y): \x1B[0m"
	while true; do
		read -rp "" yn
		yn=${yn:-y}
		case $yn in
		[Yy]*) return 0 ;;
		[Nn]*) return 1 ;;
		esac
	done
}

# Ask yes or no, with no being the default
function no_or_yes() {
	echo -en "\x1B[34m[?] $* [y/n] (default: n): \x1B[0m"
	while true; do
		read -rp "" yn
		yn=${yn:-n}
		case $yn in
		[Yy]*) return 0 ;;
		[Nn]*) return 1 ;;
		esac
	done
}

### SOPS helpers
nix_secrets_dir=${NIX_SECRETS_DIR:-"$(dirname "${BASH_SOURCE[0]}")/../../futura-secrets"}
SOPS_FILE="${nix_secrets_dir}/.sops.yaml"

# Updates the .sops.yaml file with a new host or user age key.
function sops_update_age_key() {
	field="$1"
	keyname="$2"
	key="$3"

	if [ ! "$field" == "hosts" ] && [ ! "$field" == "users" ] && [ ! "$field" == "master" ]; then
		red "Invalid field passed to sops_update_age_key. Must be either 'hosts', 'users' or 'master'."
		exit 1
	fi

	if [[ -n $(yq ".keys.${field}[] | select(anchor == \"$keyname\")" "${SOPS_FILE}") ]]; then
		green "Updating existing ${keyname} key"
		yq -i "(.keys.${field}[] | select(anchor == \"$keyname\")) = \"$key\"" "$SOPS_FILE"
	else
		green "Adding new ${keyname} key"
		yq -i ".keys.$field += [\"$key\"] | .keys.${field}[-1] anchor = \"$keyname\"" "$SOPS_FILE"
	fi
}

# Adds the host to the shared.yaml creation rules
function sops_add_shared_creation_rules() {
	h="\"$1\""    # quoted hostname for yaml

	shared_selector='.creation_rules[] | select(.path_regex == "shared\.yaml$")'
	if [[ -n $(yq "$shared_selector" "${SOPS_FILE}") ]]; then
		echo "BEFORE"
		cat "${SOPS_FILE}"
		if [[ -z $(yq "$shared_selector.key_groups[].age[] | select(alias == $h)" "${SOPS_FILE}") ]]; then
			green "Adding $h to shared.yaml rule"
			# NOTE: Split on purpose to avoid weird file corruption
			yq -i "($shared_selector).key_groups[].age += [$h]" "$SOPS_FILE"
			yq -i "($shared_selector).key_groups[].age[-1] alias = $h" "$SOPS_FILE"	# this line only adds the alias (*) to the key above
		fi
	else
		red "shared.yaml rule not found"
	fi
}


# Adds the user and host to the user.yaml creation rules
function sops_add_user_creation_rules() {
	user="$1"                     # username for selector
	host="$2"                     # hostname for selector
	u="\"${user}_${host}\""       # quoted user_host for yaml
	# w="\"$(whoami)_$(hostname)\"" # quoted whoami_hostname for yaml
	# n="\"$(hostname)\""           # quoted hostname for yaml
	m="\"master\""           # quoted master for yaml

	# Add creation rule if it does not exist yet
	user_selector=".creation_rules[] | select(.path_regex | contains(\"${user}\.yaml\"))"
	if [[ -z $(yq "$user_selector" "$SOPS_FILE") ]]; then
		green "Adding new user file creation rule"
		yq -i ".creation_rules += {\"path_regex\": \"${user}\\.yaml$\", \"key_groups\": [{\"age\": [$m]}]}" "$SOPS_FILE"
		yq -i "($user_selector).key_groups[].age[-1] alias = $m" "$SOPS_FILE"
	fi

	user_selector=".creation_rules[] | select(.path_regex == \"${user}\.yaml$\")"
	if [[ -n $(yq "$user_selector" "${SOPS_FILE}") ]]; then
		if [[ -z $(yq "$user_selector.key_groups[].age[] | select(alias == $u)" "${SOPS_FILE}") ]]; then
			green "Adding $u to $user.yaml rule"
			# NOTE: Split on purpose to avoid weird file corruption
			yq -i "($user_selector).key_groups[].age += [$u]" "$SOPS_FILE"
			yq -i "($user_selector).key_groups[].age[-1] alias = $u" "$SOPS_FILE"
		fi
	else
		red "${user}.yaml rule not found"
	fi
}


# Adds the host to the host.yaml creation rules
# Adds the user and host to the user.yaml creation rules
function sops_add_host_creation_rules() {
	user="$1"                     # username for selector
	host="$2"                     # hostname for selector
	h="\"$2\""    				  # quoted hostname for yaml
	m="\"master\""           	  # quoted master for yaml

	# Add creation rule if it does not exist yet
	host_selector=".creation_rules[] | select(.path_regex | contains(\"${host}\.yaml\"))"
	if [[ -z $(yq "$host_selector" "$SOPS_FILE") ]]; then
		green "Adding new host file creation rule"
		yq -i ".creation_rules += {\"path_regex\": \"${host}\\.yaml$\", \"key_groups\": [{\"age\": [$m]}]}" "$SOPS_FILE"
		yq -i "($host_selector).key_groups[].age[-1] alias = $m" "$SOPS_FILE"
	fi

	host_selector=".creation_rules[] | select(.path_regex == \"${host}\.yaml$\")"
	if [[ -n $(yq "$host_selector" "${SOPS_FILE}") ]]; then
		if [[ -z $(yq "$host_selector.key_groups[].age[] | select(alias == $h)" "${SOPS_FILE}") ]]; then
			green "Adding $h to $host.yaml rule"
			# NOTE: Split on purpose to avoid weird file corruption
			yq -i "($host_selector).key_groups[].age += [$h]" "$SOPS_FILE"
			yq -i "($host_selector).key_groups[].age[-1] alias = $h" "$SOPS_FILE"
		fi
	else
		red "$host.yaml rule not found"
	fi
}


# Adds the host to the shared.yaml and host.yaml creation rules and the user to the user.yaml
function sops_add_all_creation_rules() {
	user="$1"
	host="$2"

	sops_add_shared_creation_rules "$host"
	sops_add_host_creation_rules "$host"
	sops_add_user_creation_rules "$user" "$host"
}


# Add a user age key to .sops.yaml and update creation rules
function sops_generate_user_age_key() {
    local target_user="$1"
    local target_hostname="$2"
    local ssh_key="$3"
    local key_name="${target_user}_${target_hostname}"

    # Convert SSH key to age
    local user_age_key
    user_age_key=$(cat "$ssh_key" | ssh-to-age)

    # Update SOPS keys
	green "Updating .sops.yaml with age key for ${key_name}"
    sops_update_age_key "users" "$key_name" "$user_age_key"
}

# Add a host age key to .sops.yaml and update creation rules
function sops_generate_host_age_key() {
    local target_user="$1"
    local target_hostname="$2"
    local ssh_key="$3"
    local key_name="${target_hostname}"

    # Convert SSH key to age
    local host_age_key
    host_age_key=$(cat "$ssh_key" | ssh-to-age)	# FIXME: this will not work when the permissions to "/etc/ssh/ssh_host_ed25519_key" are restricted

    # Update SOPS keys
	green "Updating .sops.yaml with age key for ${key_name}"
    sops_update_age_key "hosts" "$key_name" "$host_age_key"
}

function sops_setup_user_age_key() {
	local target_user="$1"
    local target_hostname="$2"
    local ssh_key="$3"
    local key_name="${target_user}_${target_hostname}"

	# always update the age key, also if it exists already (since it is derived from a ssh key)
	sops_generate_user_age_key "${target_user}" "${target_hostname}" "${ssh_key}"

	sops_add_user_creation_rules "$target_user" "$target_hostname"

	secret_file="${nix_secrets_dir}/sops/users/${target_user}.yaml"
	config="${nix_secrets_dir}/.sops.yaml"
	# If the secret file doesn't exist, creating it
	if [ ! -f "$secret_file" ]; then
		green "User secret file does not exist. Creating $secret_file"
		mkdir -p "$(dirname "$secret_file")"
		echo "{}" >"$secret_file"
		sops --config "$config" -e "$secret_file" >"$secret_file.enc"
		mv "$secret_file.enc" "$secret_file"
	fi
}

function sops_setup_host_age_key() {
    local target_user="$1"
    local target_hostname="$2"
	local ssh_key="$3"
    local key_name="${target_user}_${target_hostname}"

	# always update the age key, also if it exists already (since it is derived from a ssh key)
	sops_generate_host_age_key "${target_user}" "${target_hostname}" "${ssh_key}"

	sops_add_shared_creation_rules "$target_hostname"
	sops_add_host_creation_rules "$target_user" "$target_hostname"

    secret_file="${nix_secrets_dir}/sops/hosts/${target_hostname}.yaml"
	config="${nix_secrets_dir}/.sops.yaml"
	# If the secret file doesn't exist, creating it
	if [ ! -f "$secret_file" ]; then
		green "Host secret file does not exist. Creating $secret_file"
		mkdir -p "$(dirname "$secret_file")"
		echo "{}" >"$secret_file"
		sops --config "$config" -e "$secret_file" >"$secret_file.enc"
		mv "$secret_file.enc" "$secret_file"
	fi
}


# age_secret_key=""
# # Generate a user age key, update the .sops.yaml entries, and return the key in age_secret_key
# # args: user, hostname
# function sops_generate_user_age_key() {
# 	target_user="$1"
# 	target_hostname="$2"
# 	key_name="${target_user}_${target_hostname}"
# 	green "Age key does not exist. Generating."
# 	user_age_key=$(age-keygen)
# 	readarray -t entries <<<"$user_age_key"
# 	age_secret_key=${entries[2]}
# 	public_key=$(echo "${entries[1]}" | rg key: | cut -f2 -d: | xargs)
# 	green "Generated age key for ${key_name}"
# 	# Place the anchors into .sops.yaml so other commands can reference them
# 	sops_update_age_key "users" "$key_name" "$public_key"
# 	sops_add_all_creation_rules "${target_user}" "${target_hostname}"

# 	# "return" key so it can be used by caller
# 	export age_secret_key
# }

# function sops_setup_master_age_key() {
#     local key_name="master"

# 	# generating the master key and storing it in ~/.config/sops/age/keys.txt
# 	master_age_key=$(age-keygen -y ${HOME}/.config/sops/age/keys.txt)

#     # Update SOPS keys
# 	green "Updating .sops.yaml with master age key for ${key_name}"
#     sops_update_age_key "master" "$key_name" "$host_age_key"
# 	yellow "!!! Make sure to backup the private key stored in $($HOME/.config/sops/age/keys.txt) in a secure location !!!"
# }

function sops_setup_master_age_key() {
    local key_file="${HOME}/.config/sops/age/keys.txt"

    # Ensure directory exists
    mkdir -p "$(dirname "$key_file")"

    # If key already exists → exit
    if [ -f "$key_file" ]; then
        red "Master age key already exists at $key_file, not creating a new one"
	else
		master_age_key=$(age-keygen -o "${key_file}")
		green "Generated master age key in ${key_file}"
		yellow "!!! Back up this private key securely !!!"
    fi

	master_age_key=$(age-keygen -y "${key_file}")
	green "Read master age key from ${key_file}"
	
	# Place the anchors into .sops.yaml so other commands can reference them
	sops_update_age_key "master" "master" "$master_age_key"

	secret_file="${nix_secrets_dir}/sops/shared.yaml"
	config="${nix_secrets_dir}/.sops.yaml"
	# If the secret file doesn't exist, creating it
	if [ ! -f "$secret_file" ]; then
		green "Shared secret file does not exist. Creating $secret_file"
		mkdir -p "$(dirname "$secret_file")"
		echo "{}" >"$secret_file"
		sops --config "$config" -e "$secret_file" >"$secret_file.enc"
		mv "$secret_file.enc" "$secret_file"
	fi
}