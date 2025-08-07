#!/bin/bash
set -euo pipefail

echo "=== Starting system bootstrap ==="

# Update package lists
echo "Updating package lists..."
apt-get update

# Install essential packages
echo "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    unzip \
    git \
    vim \
    htop \
    tree \
    jq \
    rsync \
    net-tools \
    dnsutils \
    bridge-utils \
    iptables \
    ebtables \
    dnsmasq-base

# Install Python for Ansible compatibility
echo "Installing Python and pip..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev

# Create symlink for python if it doesn't exist
if ! command -v python &> /dev/null; then
    ln -s /usr/bin/python3 /usr/local/bin/python
fi

# Upgrade pip
python3 -m pip install --upgrade pip

# Install Ansible (useful for the CI environment)
echo "Installing Ansible..."
python3 -m pip install ansible ansible-core

# Configure kernel modules for containerization
echo "Configuring kernel modules..."
modprobe overlay
modprobe br_netfilter
modprobe nf_nat
modprobe ip_tables
modprobe ip6_tables
modprobe netfilter_xt_comment

# Make kernel modules persistent
cat >> /etc/modules-load.d/incus.conf << EOF
overlay
br_netfilter
nf_nat
ip_tables
ip6_tables
netfilter_xt_comment
EOF

# Configure sysctl for containerization
echo "Configuring sysctl parameters..."
cat >> /etc/sysctl.d/99-incus.conf << EOF
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
net.core.bpf_jit_limit = 3000000000
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

# Configure subuid and subgid for unprivileged containers
echo "Configuring subuid/subgid..."
echo "vagrant:1000000:1000000000" >> /etc/subuid
echo "vagrant:1000000:1000000000" >> /etc/subgid

# Add vagrant user to necessary groups
usermod -aG sudo vagrant

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
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "=== Bootstrap completed successfully ==="