#!/bin/bash
set -euo pipefail

echo "=== Installing Incus ==="

# Check if running on Debian 12
if command -v lsb_release &> /dev/null; then
    DISTRO=$(lsb_release -si)
    VERSION=$(lsb_release -sr)
    if [[ "$DISTRO" == "Debian" && "$VERSION" == 12* ]]; then
        echo "Debian 12 detected."
    else
        echo "This script requires Debian 12."
        exit 1
    fi
else
    echo "lsb_release not found. Cannot determine distribution."
    exit 1
fi

# Download and verify Zabbly repository key
echo "Verifying Zabbly repository key..."
EXPECTED_FINGERPRINT="4EFC 5906 96CB 15B8 7C73 A3AD 82CC 8797 C838 DCFD"
ACTUAL_FINGERPRINT=$(wget -q -O - https://pkgs.zabbly.com/key.asc | gpg --show-keys --fingerprint | grep "^      " | tr -d ' ')

if [ "$ACTUAL_FINGERPRINT" = "$(echo $EXPECTED_FINGERPRINT | tr -d ' ')" ]; then
    echo "Key fingerprint verified successfully"
else
    echo "Key fingerprint verification failed!"
    echo "Expected: $EXPECTED_FINGERPRINT"
    echo "Actual  : $ACTUAL_FINGERPRINT"
    exit 1
fi

# Add Zabbly repository key
mkdir -p /etc/apt/keyrings
wget -O /etc/apt/keyrings/zabbly.asc https://pkgs.zabbly.com/key.asc

# Add Zabbly repository
sh -c 'cat <<EOF > /etc/apt/sources.list.d/zabbly-incus-lts-6.0.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/lts-6.0
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc

EOF'

# Update package list
apt-get update

# Install Incus
apt-get install -y \
    incus \
    btrfs-progs

# Wait for Incus to be installed
echo "Waiting for Incus installation to complete..."
sleep 15

# Add vagrant user to incus group (created by snap)
usermod -aG incus vagrant

# Create incus-admin group and add vagrant user
groupadd -f incus-admin
usermod -aG incus-admin vagrant

# Verify installation
echo "Verifying Incus installation..."
if incus version; then
    echo "Incus installed successfully!"
else
    echo "Incus installation verification failed"
    exit 1
fi

echo "=== Incus installation completed ==="
