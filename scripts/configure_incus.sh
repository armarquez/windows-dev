#!/bin/bash
set -euo pipefail

echo "=== Configuring Incus Server ==="

# Ensure PATH includes snap binaries
export PATH="/snap/bin:$PATH"

# Wait for Incus daemon to be ready
echo "Waiting for Incus daemon to be ready..."
timeout=60
counter=0
while ! incus info &>/dev/null && [ $counter -lt $timeout ]; do
    echo "Waiting for Incus daemon... ($counter/$timeout)"
    sleep 2
    ((counter++))
done

if [ $counter -eq $timeout ]; then
    echo "Timeout waiting for Incus daemon to start"
    exit 1
fi

# Initialize Incus with preseed configuration
echo "Initializing Incus with preseed configuration..."
cat << EOF | incus admin init --preseed
config:
  core.https_address: "0.0.0.0:8443"
  core.trust_password: "incus-server-password"
networks:
- config:
    ipv4.address: 10.0.10.1/24
    ipv4.nat: "true"
    ipv6.address: none
  description: "Default Incus bridge"
  name: incusbr0
  type: bridge
storage_pools:
- config:
    size: 50GiB
  description: "Default storage pool"
  name: default
  driver: btrfs
profiles:
- config: {}
  description: "Default Incus profile"
  devices:
    eth0:
      name: eth0
      network: incusbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
cluster: null
EOF

# Verify Incus is properly configured
echo "Verifying Incus configuration..."
incus network list
incus storage list
incus profile list

# Create a test profile for CI/CD workloads
echo "Creating CI profile for testing workloads..."
incus profile create ci 2>/dev/null || echo "CI profile already exists"

incus profile edit ci << EOF
config:
  limits.cpu: "2"
  limits.memory: 2GiB
  security.nesting: "true"
  security.privileged: "false"
description: "Profile optimized for CI/CD workloads"
devices:
  eth0:
    name: eth0
    network: incusbr0
    type: nic
  root:
    path: /
    pool: default
    type: disk
name: ci
EOF

# Download some useful base images for testing
echo "Downloading base images for CI/CD..."
incus image copy images:debian/12 local: --alias debian12 &
incus image copy images:ubuntu/22.04 local: --alias ubuntu2204 &

# Wait for image downloads (run in background)
wait

# Create client certificate directory
echo "Setting up client certificates..."
mkdir -p /home/vagrant/.config/incus

# Generate client certificate for WSL connection
incus config trust add --name "wsl-client" || echo "WSL client certificate may already exist"

# Show server info
echo "Incus server configuration complete!"
echo "Server info:"
incus info

echo "Available images:"
incus image list

echo "Network configuration:"
incus network show incusbr0

echo "=== Incus server is ready for connections ==="
echo "Connection details:"
echo "  - Server IP: 192.168.56.10"
echo "  - API Port: 8443"
echo "  - Trust password: incus-server-password"
echo ""
echo "To connect from WSL, run:"
echo "  incus remote add incus-vm 192.168.56.10 --password incus-server-password"