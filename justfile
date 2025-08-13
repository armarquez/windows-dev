default:
    @just --list

VM_NAME := "incus-server-vm"
VM_IP := "192.168.56.10"
REMOTE_NAME := "incus-vm"
TOKEN_FILE := "./secrets/incus-server-wsl-client.token"

VAGRANT := '"/mnt/c/Program Files/Vagrant/bin/vagrant.exe"'
VBOXMANAGE := '"/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"'

check-secrets:
    @if [ ! -d "secrets" ]; then \
        echo "Creating secrets directory..."; \
        mkdir secrets; \
    fi

up: check-secrets
    @echo "🚀 Creating and provisioning Incus server VM..."
    {{VAGRANT}} up
    @echo "✅ Incus server VM is ready! You can now setup the Incus client."

down:
    @echo "🔥 Destroying Incus server VM..."
    {{VAGRANT}} destroy -f

halt:
    @echo "🛑 Halting Incus server VM..."
    {{VAGRANT}} halt

restart:
    @echo "🔄 Restarting Incus server VM..."
    {{VAGRANT}} reload

ssh:
    @echo "🔐 Connecting to Incus server VM..."
    {{VAGRANT}} ssh

status:
    @echo "📊 Incus server VM Status:"
    {{VAGRANT}} status
    @echo ""
    @echo "📊 VirtualBox Status:"
    {{VBOXMANAGE}} list runningvms | grep "{{VM_NAME}}" || echo "VM is not running"

provision: check-secrets
    @echo "⚙️  Re-provisioning Incus server VM..."
    {{VAGRANT}} provision

setup-client:
    ./scripts/setup_client.sh "{{VM_IP}}" "{{REMOTE_NAME}}" "{{TOKEN_FILE}}"

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

clean-test:
    @echo "🧹 Cleaning up test containers..."
    @if incus list | grep -q "test-container"; then incus delete test-container --force; echo "Test container removed"; fi
    @if ! incus list | grep -q "test-container"; then echo "No test container found"; fi

logs:
    @echo "📋 Showing Incus server VM logs..."
    {{VAGRANT}} ssh -c "journalctl -u snap.incus.daemon -f --no-pager" || echo "Failed to get logs"

health-check:
    @echo "🏥 Performing health check..."
    @echo "1. Incus server VM Status:"
    @{{VBOXMANAGE}} list runningvms | grep "{{VM_NAME}}" || echo "❌ Incus server VM is not running"
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

network-info:
    @echo "🌐 Network Information:"
    @echo "Incus server VM IP: {{VM_IP}}"
    @echo "Incus API Port: 8443"
    @echo "SSH Port: 2222 (forwarded)"
    @echo ""
    @echo "Connection command for manual setup:"
    @echo "incus remote add {{REMOTE_NAME}} {{VM_IP}} --token $(cat {{TOKEN_FILE}})"

full-setup:
    @echo "🚀 Starting full Incus development environment setup..."
    just up
    @echo "⏳ Waiting 30 seconds for services to stabilize..."
    @sleep 30
    @echo "🔧 Setting up client (run this part from WSL)..."
    @echo "Run the following command from WSL:"
    @echo "just setup-client"

backup:
    @echo "💾 Creating Incus server VM snapshot..."
    {{VBOXMANAGE}} snapshot "{{VM_NAME}}" take "backup-$(date +%Y%m%d-%H%M%S)" --description "Automated backup"

list-snapshots:
    @echo "📸 Incus server VM Snapshots:"
    {{VBOXMANAGE}} snapshot "{{VM_NAME}}" list

resources:
    @echo "📊 Incus server VM Resource Usage:"
    {{VAGRANT}} ssh -c "top -bn1 | head -20"
    @echo ""
    {{VAGRANT}} ssh -c "df -h"
    @echo ""
    {{VAGRANT}} ssh -c "free -h"

ports:
    @echo "🔌 Port Forwarding Information:"
    @echo "SSH: localhost:2222 -> {{VM_IP}}:22"
    @echo "Incus API: localhost:8443 -> {{VM_IP}}:8443"
    @echo ""
    @echo "Direct access (if on same network):"
    @echo "SSH: ssh vagrant@{{VM_IP}}"
    @echo "Incus API: https://{{VM_IP}}:8443"

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
