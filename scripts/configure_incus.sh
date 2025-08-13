#!/bin/bash
set -euo pipefail

echo "=== Configuring Incus Server ==="

# Wait for Incus daemon and handle first-time setup
echo "Checking Incus daemon status..."
max_attempts=30
attempt=1
while ! incus admin waitready 2>/dev/null; do
    if [ $attempt -gt $max_attempts ]; then
        echo "Error: Incus daemon failed to become ready after $max_attempts attempts"
        exit 1
    fi
    
    # Check if this is first-time setup
    if incus admin waitready 2>&1 | grep -q "you should also run: incus admin init"; then
        echo "First-time setup detected, proceeding with initialization..."
        break
    fi
    
    echo "Waiting for Incus daemon (attempt $attempt/$max_attempts)..."
    sleep 2
    ((attempt++))
done

# Initialize Incus with preseed configuration
echo "Initializing Incus with preseed configuration..."
cat << EOF | incus admin init --preseed
config:
  core.https_address: "0.0.0.0:8443"
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
if ! incus profile show ci >/dev/null 2>&1; then
    echo "Creating CI profile..."
    incus profile create ci
fi

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

# Generate and save client certificate token
echo "Generating WSL client certificate..."
TOKEN_OUTPUT=$(incus config trust add wsl-client 2>&1 || true)

# Debug: Show full token output
echo "Debug: Raw token output:"
echo "$TOKEN_OUTPUT"

# Create secrets directory if it doesn't exist
mkdir -p /vagrant/secrets

if echo "$TOKEN_OUTPUT" | grep -q "token:"; then
    # Extract token - get everything after "token:" line
    TOKEN=$(echo "$TOKEN_OUTPUT" | awk '/token:/{getline; print}')
    echo "Debug: Extracted token:"
    echo "$TOKEN"
    
    # Save token with explicit echo
    echo "$TOKEN" > /vagrant/secrets/incus-server-wsl-client.token
    
    # Verify file contents
    echo "Debug: Token file contents:"
    cat /vagrant/secrets/incus-server-wsl-client.token
    
    if [ -s /vagrant/secrets/incus-server-wsl-client.token ]; then
        echo "✅ Token saved successfully"
    else
        echo "❌ Token file is empty after writing"
        exit 1
    fi
elif echo "$TOKEN_OUTPUT" | grep -q "already exists"; then
    echo "⚠️  Certificate already exists - removing and regenerating"
    incus config trust remove wsl-client
    # Retry token generation
    TOKEN_OUTPUT=$(incus config trust add wsl-client 2>&1)
    TOKEN=$(echo "$TOKEN_OUTPUT" | awk '/token:/{getline; print}')
    echo "$TOKEN" > /vagrant/secrets/incus-server-wsl-client.token
else
    echo "❌ Failed to generate token"
    echo "Error output: $TOKEN_OUTPUT"
    exit 1
fi

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
echo ""
echo "To connect from WSL, run:"
echo "  incus remote add incus-vm 192.168.56.10 --token $(cat /vagrant/secrets/incus-server-wsl-client.token)"