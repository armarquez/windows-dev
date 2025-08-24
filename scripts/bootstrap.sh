#!/bin/bash
set -euo pipefail

# Utility functions
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

echo "=== Starting system bootstrap ==="

# Check if the OS is Ubuntu
if [[ "$(lsb_release -is)" == "Ubuntu" ]]; then
  echo "Ubuntu detected, performing package upgrade..."
  
  # Set non-interactive frontend
  export DEBIAN_FRONTEND=noninteractive
  
  # Update package lists
  echo "Updating package lists..."
  apt-get update
  
  # Upgrade all packages
  echo "Upgrading all packages..."
  apt-get dist-upgrade -y

  
else
  # Update package lists for other OS (Debian)
  echo "Updating package lists..."
  apt update
fi

# Install essential packages (common to both Ubuntu and Debian)
echo "Installing essential packages..."
apt install -y \
    curl \
    wget \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    net-tools \
    dnsutils \
    bridge-utils \
    iptables \
    ebtables \
    dnsmasq-base \
    zstd

# Install OS-specific packages
if [[ "$(lsb_release -is)" == "Ubuntu" ]]; then
    echo "Installing Ubuntu-specific packages..."
    apt install -y software-properties-common
fi

# Install KVM and other virtualization packages
echo "Installing KVM and other virtualization packages..."
apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager

# Install Python for Ansible compatibility
echo "Installing Python and pip..."
apt install -y \
    python3 \
    python3-pip

# Create symlink for python if it doesn't exist
if ! command -v python &> /dev/null; then
    ln -s /usr/bin/python3 /usr/local/bin/python
fi

# Install Ansible (useful for the CI environment)
echo "Installing Ansible..."
apt install -y ansible

# Install kernel headers
echo "Installing kernel headers..."
if [[ "$(lsb_release -is)" == "Debian" ]]; then
    apt-get install -y linux-headers-amd64
else
    apt-get install -y "linux-headers-$(uname -r)"
fi

# Configure kernel modules for containerization
echo "Configuring kernel modules..."
modprobe overlay
modprobe br_netfilter
modprobe nf_nat
modprobe ip_tables
modprobe ip6_tables
modprobe netfilter_xt_comment || true

# Make kernel modules persistent
cat > /etc/modules-load.d/incus.conf << EOF
overlay
br_netfilter
nf_nat
ip_tables
ip6_tables
netfilter_xt_comment
EOF

# Configure sysctl for containerization
echo "Configuring sysctl parameters..."
cat > /etc/sysctl.d/99-incus.conf << EOF
# Enable IP forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Bridge netfilter
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Increase limits for containers
fs.inotify.max_user_instances = 1048576
fs.inotify.max_user_watches = 1048576
fs.aio-max-nr = 1048576
kernel.dmesg_restrict = 1
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv6.neigh.default.gc_thresh3 = 8192
#net.core.bpf_jit_limit = 3000000000
kernel.keys.maxkeys = 2000
kernel.keys.maxbytes = 2000000
vm.max_map_count = 262144

# Increase network buffer sizes
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
EOF

# Apply sysctl changes
sysctl --system

# Get the target user using utility function
TARGET_USER=$(get_target_user)

echo "Configuring subuid/subgid for user: $TARGET_USER"
echo "$TARGET_USER:1000000:1000000000" >> /etc/subuid
echo "$TARGET_USER:1000000:1000000000" >> /etc/subgid

# Add user to necessary groups
usermod -aG sudo $TARGET_USER
usermod -aG libvirt $TARGET_USER
usermod -aG kvm $TARGET_USER

# Configure systemd for containers
echo "Configuring systemd..."
mkdir -p /etc/systemd/system/user@.service.d
cat > /etc/systemd/system/user@.service.d/delegate.conf << EOF
[Service]
Delegate=yes
EOF

systemctl daemon-reload

# Disable swap if enabled (recommended for containers)
swapoff -a
sed -i 's|/ swap |#&|' /etc/fstab

echo "=== Bootstrap completed successfully ==="
