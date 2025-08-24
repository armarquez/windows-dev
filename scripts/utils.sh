#!/bin/bash
# Utility functions for provisioning scripts

# Function to detect the target user based on environment
get_target_user() {
    local target_user=""
    
    if id vagrant >/dev/null 2>&1; then
        target_user="vagrant"
    elif [ -n "${ANSIBLE_USER:-}" ]; then
        target_user="$ANSIBLE_USER"
    elif [ -n "$SUDO_USER" ]; then
        target_user="$SUDO_USER"
    else
        # Fallback to the user who invoked sudo
        target_user=$(who am i | awk '{print $1}' 2>/dev/null || echo "root")
    fi
    
    echo "$target_user"
}

# Function to get the home directory for the target user
get_target_user_home() {
    local target_user="${1:-$(get_target_user)}"
    
    if [ "$target_user" = "root" ]; then
        echo "/root"
    else
        echo "/home/$target_user"
    fi
}

# Function to determine the appropriate token file path
get_token_file_path() {
    local target_user="${1:-$(get_target_user)}"
    local default_filename="${2:-incus-server-wsl-client.token}"
    
    # For Vagrant VMs, use /vagrant/secrets, for remote servers use user's home directory
    if [ -d "/vagrant/secrets" ]; then
        echo "/vagrant/secrets/$default_filename"
    else
        echo "$(get_target_user_home "$target_user")/$default_filename"
    fi
}