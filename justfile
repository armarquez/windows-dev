# Incus Server Management Justfile
# Run with: just <command>

# Default recipe - show available commands
default:
    @just --list

# Variables
VM_NAME := "incus-server-vm"
VM_IP := "192.168.56.10"
INCUS_PASSWORD := "incus-server-password"
REMOTE_NAME := "incus-vm"

# Vagrant command - use full path to ensure it's found (quoted for spaces)
VAGRANT := '"/mnt/c/Program Files/Vagrant/bin/vagrant.exe"'

# Create and provision the Incus server VM
up:
    @echo "🚀 Creating and provisioning Incus server VM..."
    {{VAGRANT}} up
    @echo "✅ Incus server VM is ready! You can now setup the Incus client."

# Destroy the Incus server VM
down:
    @echo "🔥 Destroying Incus server VM..."
    {{VAGRANT}} destroy -f

# Restart the Incus server VM
restart:
    @echo "🔄 Restarting Incus server VM..."
    {{VAGRANT}} reload

# SSH into the Incus server VM
ssh:
    @echo "🔐 Connecting to Incus server VM..."
    {{VAGRANT}} ssh

# Show Incus server VM status
status:
    @echo "📊 Incus server VM Status:"
    {{VAGRANT}} status
    @echo ""
    @echo "📊 VirtualBox Status:"
    VBoxManage list runningvms | grep "{{VM_NAME}}" || echo "VM is not running"

# Provision only (useful for updates)
provision:
    @echo "⚙️  Re-provisioning Incus server VM..."
    {{VAGRANT}} provision

# Setup Incus client in WSL (run this from WSL)
setup-client:
    @echo "🔧 Setting up Incus client in WSL..."
    @echo "Installing Incus client..."
    @if ! command -v incus >/dev/null 2>&1; then \
        echo "Installing Incus via apt..."; \
        sudo apt install -y incus qemu-system ; \
    else \
        echo "Incus client already installed"; \
    fi
    @echo "Adding Incus remote server..."
    @if ! incus remote list | grep -q "{{REMOTE_NAME}}"; then \
        echo "Adding remote server..."; \
        incus remote add {{REMOTE_NAME}} {{VM_IP}} --password {{INCUS_PASSWORD}} --accept-certificate; \
    else \
        echo "Remote server already configured"; \
    fi
    @echo "Setting default remote..."
    incus remote set-default {{REMOTE_NAME}}
    @echo "✅ Incus client setup complete!"

# Test the connection from WSL client
test-connection:
    @echo "🧪 Testing Incus client connection..."
    @echo "Server info:"
    incus info
    @echo ""
    @echo "Available images:"
    incus image list
    @echo ""
    @echo "Network status:"
    incus network list

# Create a test container for validation
test-container:
    @echo "🧪 Creating test container..."
    @if ! incus list | grep -q "test-container"; then \
        incus launch ubuntu2204 test-container --profile ci; \
        sleep 5; \
        incus exec test-container -- apt update; \
        incus exec test-container -- apt install -y curl; \
    else \
        echo "Test container already exists"; \
    fi
    @echo "Container status:"
    incus list test-container
    @echo ""
    @echo "Testing container connectivity:"
    incus exec test-container -- curl -s https://httpbin.org/ip || echo "Network test failed"

# Clean up test containers
clean-test:
    @echo "🧹 Cleaning up test containers..."
    @if incus list | grep -q "test-container"; then \
        incus delete test-container --force; \
        echo "Test container removed"; \
    else \
        echo "No test container found"; \
    fi

# Show logs from the Incus server VM
logs:
    @echo "📋 Showing Incus server VM logs..."
    {{VAGRANT}} ssh -c "journalctl -u snap.incus.daemon -f --no-pager" || echo "Failed to get logs"

# Quick health check
health-check:
    @echo "🏥 Performing health check..."
    @echo "1. Incus server VM Status:"
    @{{VAGRANT}} status | grep "{{VM_NAME}}"
    @echo ""
    @echo "2. Incus server VM Network Connectivity:"
    @ping -c 2 {{VM_IP}} >/dev/null 2>&1 && echo "✅ Incus server VM is reachable" || echo "❌ Incus server VM is not reachable"
    @echo ""
    @echo "3. Incus API Connectivity:"
    @timeout 5 bash -c "</dev/tcp/{{VM_IP}}/8443" >/dev/null 2>&1 && echo "✅ Incus API is reachable" || echo "❌ Incus API is not reachable"
    @if command -v incus >/dev/null 2>&1; then \
        echo ""; \
        echo "4. Incus Client Status:"; \
        incus remote list | grep "{{REMOTE_NAME}}" >/dev/null 2>&1 && echo "✅ Remote server configured" || echo "❌ Remote server not configured"; \
    fi

# Get Incus server VM network information
network-info:
    @echo "🌐 Network Information:"
    @echo "Incus server VM IP: {{VM_IP}}"
    @echo "Incus API Port: 8443"
    @echo "SSH Port: 2222 (forwarded)"
    @echo ""
    @echo "Connection command for manual setup:"
    @echo "incus remote add {{REMOTE_NAME}} {{VM_IP}} --password {{INCUS_PASSWORD}}"

# Full setup - create Incus server VM and configure client
full-setup:
    @echo "🚀 Starting full Incus development environment setup..."
    just up
    @echo "⏳ Waiting 30 seconds for services to stabilize..."
    @sleep 30
    @echo "🔧 Setting up client (run this part from WSL)..."
    @echo "Run the following command from WSL:"
    @echo "just setup-client"

# Backup Incus server VM state (snapshot)
backup:
    @echo "💾 Creating Incus server VM snapshot..."
    VBoxManage snapshot "{{VM_NAME}}" take "backup-$(date +%Y%m%d-%H%M%S)" --description "Automated backup"

# List Incus server VM snapshots
list-snapshots:
    @echo "📸 Incus server VM Snapshots:"
    VBoxManage snapshot "{{VM_NAME}}" list

# Show Incus server VM resource usage
resources:
    @echo "📊 Incus server VM Resource Usage:"
    {{VAGRANT}} ssh -c "top -bn1 | head -20"
    @echo ""
    {{VAGRANT}} ssh -c "df -h"
    @echo ""
    {{VAGRANT}} ssh -c "free -h"

# Port forwarding information
ports:
    @echo "🔌 Port Forwarding Information:"
    @echo "SSH: localhost:2222 -> {{VM_IP}}:22"
    @echo "Incus API: localhost:8443 -> {{VM_IP}}:8443"
    @echo ""
    @echo "Direct access (if on same network):"
    @echo "SSH: ssh vagrant@{{VM_IP}}"
    @echo "Incus API: https://{{VM_IP}}:8443"

# Debug environment variables and paths
debug-env:
    @echo "🔍 Environment Debug Information:"
    @echo "PATH: $PATH"
    @echo "VAGRANT variable: {{VAGRANT}}"
    @echo "Vagrant executable test:"
    @{{VAGRANT}} --version || echo "Vagrant command failed"
    @echo "Shell: $SHELL"
    @echo "Current directory: $(pwd)"
    @echo "Testing vagrant up dry-run:"
    @{{VAGRANT}} up --help | head -2 || echo "Vagrant up command failed"