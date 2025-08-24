# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Incus containerization development environment for Windows developers using WSL. It provides two deployment methods:

1. **Local VM Setup**: Creates an Ubuntu 24.04 VM using Vagrant/VirtualBox for local development
2. **Remote Server Setup**: Provisions existing Debian 12+ servers using Ansible

The primary client interface is through WSL (Windows Subsystem for Linux) connecting to the Incus server.

## Essential Commands

All operations are managed through the `just` command runner. Key commands:

### Local VM Workflow
- `just up` - Create and provision Incus server VM
- `just setup-client` - Configure WSL client to connect to local VM
- `just test-connection` - Verify connection and list containers
- `just down` - Destroy VM and clean up client configuration

### Remote Server Workflow  
- `just check-inventory` - Verify inventory.ini configuration
- `just full-remote-setup` - Complete end-to-end remote setup
- `just provision-remote` - Run Ansible playbook on remote server
- `just setup-remote-client` - Configure WSL client for remote server

### Development & Testing
- `just test-container` - Create test container for validation
- `just health-check` - System health verification
- `just ssh` - SSH into local VM
- `just logs` - View Incus daemon logs

### SSH Key Management
- `just generate-ssh-key` - Generate SSH key pair for remote access
- `just setup-ssh-keys` - Deploy SSH keys to remote server
- `just secure-ssh` - Disable password authentication

## Architecture

### Core Components
- **Incus Server**: Container/VM orchestration (installed via Zabbly packages)
- **Vagrant**: Local VM management (Windows host)  
- **Ansible**: Remote server provisioning
- **WSL**: Primary client environment

### Network Configuration
- **Local VM IP**: 192.168.56.10
- **Incus API Port**: 8443
- **SSH Forward**: localhost:2222
- **Container Network**: 10.0.10.0/24 (incusbr0)

### Key Files Structure
```
├── Vagrantfile              # VM configuration (12GB RAM, 4 CPU)
├── justfile                 # All automation commands
├── playbook.yml            # Main Ansible playbook
├── inventory.ini           # Ansible hosts configuration
├── scripts/
│   ├── bootstrap.sh        # System dependencies & kernel config
│   ├── install_incus.sh    # Incus package installation  
│   ├── configure_incus.sh  # Server initialization & token generation
│   └── setup_client.sh     # WSL client configuration
└── secrets/                # Generated client tokens
```

## Development Workflow

### Before Making Changes
1. Always run `just health-check` to verify system status
2. Use `just test-container` to validate functionality
3. Check VM status with `just status`

### Configuration Management
- **VM Resources**: Modify memory/CPU in Vagrantfile:1926-27
- **Network Settings**: Update IP addresses in Vagrantfile:13-21 and justfile:6
- **Incus Settings**: Modify preseed configuration in configure_incus.sh:63-109
- **Remote Hosts**: Update inventory.ini for Ansible targets

### Profiles Available
- `default`: Standard container (1 CPU, 1GB RAM)
- `ci`: CI/CD optimized (2 CPU, 2GB RAM, nesting enabled)

### Authentication
- **Local VM**: Uses generated token in secrets/incus-server-wsl-client.token
- **Remote Server**: SSH key authentication preferred (see SSH key management commands)
- **Default Trust Password**: `incus-server-password` (change for production)

## Testing Commands

After modifications, validate with:
```bash
just health-check          # Overall system verification
just test-connection       # Client connectivity test
incus image list           # Available images
incus network list         # Network configuration
incus profile list         # Available profiles
```

## Common Issues & Solutions

### VM Won't Start
- Check VirtualBox status: `VBoxManage list runningvms`
- Review logs: `just logs`
- Clean restart: `just down && just up`

### Client Connection Issues  
- Verify network: `ping 192.168.56.10`
- Reset client: `just reset-client true`
- Regenerate token: `just provision && just setup-client`

### Remote Server Problems
- Test SSH: `just test-remote-connection`
- Validate provisioning: `just validate-remote-provision`
- Check inventory: `just check-inventory`

## Important Notes

- Vagrant commands use Windows paths: `'/mnt/c/Program Files/Vagrant/bin/vagrant.exe'`
- Kernel modules are auto-loaded for containerization (overlay, br_netfilter, etc.)
- Unprivileged containers are default for security
- Swap is disabled for optimal container performance
- btrfs storage pool provides efficient container snapshots