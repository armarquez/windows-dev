# Default recipe - show available commands
default:
    @just --list

VM_NAME := "incus-server-vm"
VM_IP := "192.168.56.10"
REMOTE_NAME := "incus-vm"
TOKEN_FILE := "./secrets/incus-server-wsl-client.token"

VAGRANT := "'/mnt/c/Program Files/Vagrant/bin/vagrant.exe'"
VBOXMANAGE := "'/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe'"

# Check if running in a WSL environment
is-wsl:
    @uname -r | grep -q "WSL"

# Check if secrets directory exists, if not create it
check-secrets:
    @if [ ! -d "secrets" ]; then \
        echo "Creating secrets directory..."; \
        mkdir secrets; \
    fi

# Create and provision the Incus server VM
up: check-secrets
    @echo "🚀 Creating and provisioning Incus server VM..."
    {{VAGRANT}} up --provision
    @echo "✅ Incus server VM is ready! You can now setup the Incus client."

# Destroy the Incus server VM
down:
    @just reset-client 'true'
    @echo "🔥 Destroying Incus server VM..."
    {{VAGRANT}} destroy -f

# Halt the Incus server VM
halt:
    @echo "🛑 Halting Incus server VM..."
    {{VAGRANT}} halt

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
    {{VAGRANT}} global-status
    @echo ""
    @echo "📊 VirtualBox Status:"
    {{VBOXMANAGE}} list runningvms | grep "{{VM_NAME}}" || echo "VM is not running"

# Provision only (useful for updates)
provision: check-secrets
    @echo "⚙️  Re-provisioning Incus server VM..."
    {{VAGRANT}} provision

# Setup Incus client in WSL (run this from WSL)
setup-client:
    ./scripts/setup_client.sh "{{VM_IP}}" "{{REMOTE_NAME}}" "{{TOKEN_FILE}}"

# Reset Incus client configuration
# Usage: just reset-client [clean_token]
#   clean_token: set to 'true' to delete the token file
reset-client clean_token="false":
    @echo "🔥 Resetting Incus client configuration..."
    @if incus remote list | grep -q "{{REMOTE_NAME}}"; then \
        current_remote=$(incus remote get-default); \
        if [ "$current_remote" = "{{REMOTE_NAME}}" ]; then \
            echo "Switching from default remote '{{REMOTE_NAME}}' to 'local'..."; \
            incus remote switch local; \
        fi; \
        incus remote remove {{REMOTE_NAME}}; \
        echo "✅ Remote '{{REMOTE_NAME}}' removed."; \
    else \
        echo "ℹ️ Remote '{{REMOTE_NAME}}' not found."; \
    fi
    @if [ "{{clean_token}}" = "true" ]; then \
        if [ -f "{{TOKEN_FILE}}" ]; then \
            rm -f "{{TOKEN_FILE}}"; \
            echo "✅ Token file '{{TOKEN_FILE}}' removed."; \
        else \
            echo "ℹ️ Token file '{{TOKEN_FILE}}' not found."; \
        fi; \
    else \
        echo "ℹ️ Skipping token file removal."; \
    fi


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

# --- Ansible Remote Provisioning ---

# Provision a remote server using Ansible
provision-remote:
    @echo "🚀 Provisioning remote server with Ansible..."
    ansible-playbook playbook.yml --ask-become-pass

# Setup Incus client for a provisioned remote server
setup-remote-client:
    @echo "🔧 Setting up Incus client for remote server..."
    ./scripts/setup_client.sh "$(grep -v '#' inventory.ini | awk '{print $1}')" "incus-remote" "{{TOKEN_FILE}}"

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
    @if incus list | grep -q "test-container"; then incus delete test-container --force; echo "Test container removed"; fi
    @if ! incus list | grep -q "test-container"; then echo "No test container found"; fi

# Show logs from the Incus server VM
logs:
    @echo "📋 Showing Incus server VM logs..."
    {{VAGRANT}} ssh -c "journalctl -u snap.incus.daemon -f --no-pager" || echo "Failed to get logs"

# Quick health check
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

# Get Incus server VM network information
network-info:
    @echo "🌐 Network Information:"
    @echo "Incus server VM IP: {{VM_IP}}"
    @echo "Incus API Port: 8443"
    @echo "SSH Port: 2222 (forwarded)"
    @echo ""
    @echo "Connection command for manual setup:"
    @echo "incus remote add {{REMOTE_NAME}} {{VM_IP}} --token $(cat {{TOKEN_FILE}})"

# Full setup - create Incus server VM and configure client
full-setup:
    @echo "🚀 Starting full Incus development environment setup..."
    just up
    @echo "⏳ Waiting 30 seconds for services to stabilize..."
    @sleep 30
    @if just --quiet is-wsl; then \
        echo "✅ Detected WSL environment, running client setup..."; \
        just setup-client; \
    else \
        echo "❌ Not in a WSL environment."; \
        echo "Please run the following command from your WSL terminal to complete the setup:"; \
        echo "just setup-client"; \
    fi

# Backup Incus server VM state (snapshot)
backup:
    @echo "💾 Creating Incus server VM snapshot..."
    {{VBOXMANAGE}} snapshot "{{VM_NAME}}" take "backup-$(date +%Y%m%d-%H%M%S)" --description "Automated backup"

# List Incus server VM snapshots
list-snapshots:
    @echo "📸 Incus server VM Snapshots:"
    {{VBOXMANAGE}} snapshot "{{VM_NAME}}" list

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

# --- Enhanced Remote Provisioning Commands ---

# Check if inventory is configured properly
check-inventory:
    @echo "🔍 Checking inventory configuration..."
    @if grep -q "your_server_ip" inventory.ini; then \
        echo "❌ Error: Please configure your server details in inventory.ini"; \
        echo "   Replace 'your_server_ip' and 'your_user' with actual values"; \
        exit 1; \
    fi
    @echo "✅ Inventory appears to be configured"
    @echo "📋 Current inventory:"
    @grep -v '^#' inventory.ini | grep -v '^ ' | head -5

# Test connection to remote server
test-remote-connection:
    @echo "🔗 Testing connection to remote server..."
    @if ! ansible incus_server -m ping; then \
        echo "❌ Cannot connect to remote server"; \
        echo "   Check your inventory.ini configuration"; \
        echo "   Ensure SSH keys are properly configured"; \
        exit 1; \
    fi
    @echo "✅ Remote server connection successful"

# Validate remote provisioning completed successfully
validate-remote-provision:
    @echo "🔍 Validating remote Incus server..."
    @if [ ! -f "{{TOKEN_FILE}}" ]; then \
        echo "❌ Token file not found: {{TOKEN_FILE}}"; \
        echo "   Remote provisioning may have failed"; \
        exit 1; \
    fi
    @echo "✅ Token file exists ($(stat -c%s {{TOKEN_FILE}} 2>/dev/null || echo "unknown") bytes)"
    @echo "🔧 Testing remote Incus server..."
    @SERVER_IP=$(ansible-inventory --list | jq -r '.incus_server.hosts[0]' 2>/dev/null || grep -v '#' inventory.ini | awk 'NF {print $1; exit}'); \
    if timeout 5 bash -c "</dev/tcp/${SERVER_IP}/8443" >/dev/null 2>&1; then \
        echo "✅ Incus API is accessible on ${SERVER_IP}:8443"; \
    else \
        echo "❌ Cannot reach Incus API on ${SERVER_IP}:8443"; \
    fi

# Complete remote setup workflow
full-remote-setup: check-inventory test-remote-connection provision-remote setup-remote-client
    @echo "🎉 Remote Incus server setup completed!"
    @echo ""
    @echo "✅ Summary:"
    @echo "   - Remote server provisioned"
    @echo "   - Incus client configured"
    @echo "   - Connection tested"
    @echo ""
    @echo "💡 Try these commands:"
    @echo "   just test-container    # Create a test container"
    @echo "   incus list            # List containers"
    @echo "   incus image list      # List available images"

# Clean up remote client configuration
clean-remote-client:
    @echo "🧹 Cleaning up remote client configuration..."
    @if incus remote list | grep -q "incus-remote"; then \
        current_remote=$(incus remote get-default); \
        if [ "$current_remote" = "incus-remote" ]; then \
            echo "Switching from default remote 'incus-remote' to 'local'..."; \
            incus remote switch local; \
        fi; \
        incus remote remove incus-remote; \
        echo "✅ Remote 'incus-remote' removed."; \
    else \
        echo "ℹ️ Remote 'incus-remote' not found."; \
    fi

# --- SSH Key Management ---

# Generate SSH key pair for remote server access
generate-ssh-key:
    @echo "🔑 Generating SSH key pair for remote server access..."
    @mkdir -p ~/.ssh
    @if [ ! -f ~/.ssh/incus_server_key ]; then \
        ssh-keygen -t ed25519 -f ~/.ssh/incus_server_key -N "" -C "incus-server-$(date +%Y%m%d)"; \
        chmod 600 ~/.ssh/incus_server_key; \
        chmod 644 ~/.ssh/incus_server_key.pub; \
        echo "✅ SSH key pair generated:"; \
        echo "   Private key: ~/.ssh/incus_server_key"; \
        echo "   Public key:  ~/.ssh/incus_server_key.pub"; \
    else \
        echo "ℹ️ SSH key already exists at ~/.ssh/incus_server_key"; \
    fi

# Setup SSH key authentication for remote server
setup-ssh-keys: generate-ssh-key check-inventory
    @echo "🔐 Setting up SSH key authentication for remote server..."
    @echo "📋 This will:"
    @echo "   1. Deploy your SSH public key to the remote server"
    @echo "   2. Test the key-based connection"
    @echo "   3. Update inventory to use key authentication"
    @echo ""
    @read -p "Continue? (y/N): " confirm; \
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then \
        ansible-playbook playbooks/setup-ssh-keys.yml --ask-become-pass; \
        echo ""; \
        echo "✅ SSH key deployment completed!"; \
        echo "🔧 Updating inventory configuration..."; \
        just update-inventory-for-keys; \
        echo ""; \
        echo "🧪 Testing new SSH key connection..."; \
        if just test-ssh-key-connection; then \
            echo "✅ SSH key authentication working!"; \
            echo ""; \
            echo "💡 Next step: Run 'just secure-ssh' to disable password authentication"; \
        else \
            echo "❌ SSH key authentication failed"; \
            echo "   Please check the setup and try again"; \
        fi; \
    else \
        echo "❌ Setup cancelled"; \
    fi

# Test SSH key connection to remote server
test-ssh-key-connection:
    @echo "🔗 Testing SSH key connection to remote server..."
    @ansible incus_server -m ping -e ansible_ssh_private_key_file=~/.ssh/incus_server_key

# Update inventory.ini to use SSH key authentication
update-inventory-for-keys:
    @echo "📝 Updating inventory.ini for SSH key authentication..."
    @if grep -q "ansible_ssh_pass" inventory.ini; then \
        SERVER_IP=$(grep -v '^#' inventory.ini | grep -v '^$' | awk 'NF {print $1; exit}'); \
        USER_NAME=$(grep -v '^#' inventory.ini | grep -v '^$' | grep ansible_user | sed 's/.*ansible_user=\([^ ]*\).*/\1/'); \
        if [ -n "$SERVER_IP" ] && [ -n "$USER_NAME" ]; then \
            sed -i.bak "s/.*ansible_ssh_pass.*/$SERVER_IP ansible_user=$USER_NAME ansible_ssh_private_key_file=~\/.ssh\/incus_server_key/" inventory.ini; \
            echo "✅ Updated inventory.ini to use SSH key authentication"; \
            echo "   Backup saved as inventory.ini.bak"; \
        else \
            echo "❌ Could not parse server details from inventory.ini"; \
        fi; \
    else \
        echo "ℹ️ inventory.ini already configured for key authentication or no password auth found"; \
    fi

# Secure SSH configuration (disable password authentication)
secure-ssh: test-ssh-key-connection
    @echo "🔒 Securing SSH configuration on remote server..."
    @echo "⚠️  WARNING: This will disable SSH password authentication!"
    @echo "   Make sure SSH key authentication is working first."
    @echo ""
    @read -p "Disable password authentication? (y/N): " confirm; \
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then \
        ansible-playbook playbooks/secure-ssh.yml; \
        echo ""; \
        echo "🧪 Testing secure connection..."; \
        if just test-ssh-key-connection; then \
            echo "✅ SSH security hardening completed successfully!"; \
            echo "   Password authentication is now disabled"; \
        else \
            echo "❌ Connection test failed after hardening"; \
            echo "   You may need to restore SSH configuration manually"; \
        fi; \
    else \
        echo "❌ SSH hardening cancelled"; \
    fi

# Complete SSH key migration workflow
migrate-to-ssh-keys: setup-ssh-keys secure-ssh
    @echo "🎉 SSH key migration completed!"
    @echo ""
    @echo "✅ Summary:"
    @echo "   - SSH key pair generated"
    @echo "   - Public key deployed to remote server"
    @echo "   - Inventory updated for key authentication"
    @echo "   - Password authentication disabled"
    @echo ""
    @echo "💡 Your remote server is now secured with SSH key authentication"

# Show SSH key information
show-ssh-key-info:
    @echo "🔍 SSH Key Information:"
    @if [ ! -f ~/.ssh/incus_server_key ]; then \
        echo "✅ Private key: ~/.ssh/incus_server_key"; \
        echo "✅ Public key:  ~/.ssh/incus_server_key.pub"; \
        echo ""; \
        echo "📋 Public key content:"; \
        cat ~/.ssh/incus_server_key.pub; \
    else \
        echo "❌ SSH key not found. Run 'just generate-ssh-key' first"; \
    fi
