#!/bin/bash
set -euo pipefail

echo "=== Installing Incus ==="

# Check if running on Debian/Ubuntu
if ! command -v lsb_release &> /dev/null || [[ "$(lsb_release -si)" != "Debian" && "$(lsb_release -si)" != "Ubuntu" ]]; then
    echo "This script is designed for Debian/Ubuntu systems"
    exit 1
fi

# Install dependencies
echo "Installing Incus dependencies..."
apt-get update
apt-get install -y \
    snapd \
    zfsutils-linux \
    thin-provisioning-tools \
    lvm2

# Enable and start snapd
systemctl enable snapd
systemctl start snapd

# Wait for snapd to be ready
echo "Waiting for snapd to initialize..."
sleep 10

# Install Incus via snap
echo "Installing Incus via snap..."
snap install incus --channel=latest/stable

# Wait for Incus to be installed
echo "Waiting for Incus installation to complete..."
sleep 15

# Add vagrant user to incus group (created by snap)
usermod -aG incus vagrant

# Create incus-admin group and add vagrant user
groupadd -f incus-admin
usermod -aG incus-admin vagrant

# Ensure snap binaries are in PATH
echo 'export PATH="/snap/bin:$PATH"' >> /home/vagrant/.bashrc
echo 'export PATH="/snap/bin:$PATH"' >> /root/.bashrc

# Create symlinks for easier access
ln -sf /snap/bin/incus /usr/local/bin/incus
ln -sf /snap/bin/incusd /usr/local/bin/incusd

# Configure AppArmor for Incus (if AppArmor is installed)
if command -v aa-status &> /dev/null; then
    echo "Configuring AppArmor for Incus..."
    # AppArmor profiles are handled by the snap
fi

# Verify installation
echo "Verifying Incus installation..."
if /snap/bin/incus version; then
    echo "Incus installed successfully!"
else
    echo "Incus installation verification failed"
    exit 1
fi

echo "=== Incus installation completed ==="