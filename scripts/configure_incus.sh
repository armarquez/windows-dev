#!/bin/bash
set -euo pipefail

echo "=== Configuring Incus Server ==="

# Wait for Incus daemon and handle first-time setup
echo "Checking Incus daemon status..."
max_attempts=30
attempt=1
ready=false

while [ $attempt -le $max_attempts ]; do
    # Run waitready with a timeout and capture output. The command may fail.
    if output=$(incus admin waitready --timeout=5 2>&1); then
        # If the command succeeds, we're ready.
        echo "Incus daemon is ready."
        ready=true
        break
    else
        # If the command fails, check if it's because it needs initialization.
        if echo "$output" | grep -q "you should also run: incus admin init"; then
            echo "First-time setup detected, proceeding with initialization..."
            ready=true
            break
        fi
    fi
    
    echo "Waiting for Incus daemon (attempt $attempt/$max_attempts)..."
    sleep 2
    ((attempt++))
done

if [ "$ready" = false ]; then
    echo "Error: Incus daemon failed to become ready after $max_attempts attempts"
    echo "Last output from incus admin waitready:"
    echo "$output"
    exit 1
fi

NEEDS_INIT=false
if ! incus storage show default >/dev/null 2>&1 || [ "$(incus storage show default | grep '^driver:' | awk '{print $2}')" != "btrfs" ]; then
    NEEDS_INIT=true
fi

if ! incus network show incusbr0 >/dev/null 2>&1; then
    NEEDS_INIT=true
fi

if ! incus profile show ci >/dev/null 2>&1; then
    NEEDS_INIT=true
fi

if [ "$NEEDS_INIT" = "true" ]; then
    echo "Incus configuration is incomplete or incorrect. Wiping existing config and re-initializing."

    # Clean up potential leftovers from previous failed runs
    incus profile device remove default root --project default >/dev/null 2>&1 || true
    incus storage delete default >/dev/null 2>&1 || true
    incus network delete incusbr0 >/dev/null 2>&1 || true
    incus profile delete ci >/dev/null 2>&1 || true

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
- name: default
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
- name: ci
  description: "Profile optimized for CI/CD workloads"
  config:
    limits.cpu: "2"
    limits.memory: 2GiB
    security.nesting: "true"
    security.privileged: "false"
  devices:
    eth0:
      name: eth0
      network: incusbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
cluster: null
EOF
else
    echo "Incus is already configured. Skipping initialization."
fi

# Ensure the incusbr0 network exists, as init can sometimes fail to create it
if ! incus network show incusbr0 >/dev/null 2>&1; then
  echo "Network incusbr0 not found. Creating it now."
  incus network create incusbr0 ipv4.address=10.0.10.1/24 ipv4.nat=true ipv6.address=none
fi

# Verify Incus is properly configured
echo "Verifying Incus configuration..."
incus network list
incus storage list
incus profile list

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

# Set default token file path (can be overridden by environment variable)
TOKEN_FILE="${TOKEN_FILE:-/vagrant/secrets/incus-server-wsl-client.token}"

# Create secrets directory if it doesn't exist
mkdir -p "$(dirname "$TOKEN_FILE")"

if echo "$TOKEN_OUTPUT" | grep -q "token:"; then
    # Extract token - get everything after "token:" line
    TOKEN=$(echo "$TOKEN_OUTPUT" | awk '/token:/{getline; print}')
    echo "Debug: Extracted token:"
    echo "$TOKEN"
    
    # Save token with explicit echo
    echo "$TOKEN" > "$TOKEN_FILE"
    
    # Verify file contents
    echo "Debug: Token file contents:"
    cat "$TOKEN_FILE"
    
    if [ -s "$TOKEN_FILE" ]; then
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
    echo "$TOKEN" > "$TOKEN_FILE"
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
echo "  incus remote add incus-vm <SERVER_IP> --token $(cat $TOKEN_FILE)"