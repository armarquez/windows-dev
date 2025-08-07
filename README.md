# Incus on Windows Development Environment

This repository provides a complete DevOps setup for running an Incus server in a Vagrant VM, with client access from WSL for CI/CD and Ansible testing.

## Architecture

```
Windows Host
├── WSL (Incus Client)
│   ├── Your code development
│   ├── Ansible playbooks
│   └── Incus client commands
└── VirtualBox VM (Incus Server)
    ├── Debian 12 base
    ├── 4 CPU cores, 12GB RAM
    ├── Incus daemon
    └── Container/VM orchestration
```

## Prerequisites

### Windows Host

- [VirtualBox](https://www.virtualbox.org/) 6.1 or later

    ```powershell
    winget install --id Oracle.Virtualbox
    ```

- [Vagrant](https://www.vagrantup.com/) 2.3 or later

    ```powershell
    winget install --id Hashicorp.Vagrant
    ```

### WSL Environment

- Ubuntu 24.04+ or Debian 13+ recommended
- [Cargo](https://crates.io/)

    ```bash
    curl https://sh.rustup.rs -sSf | sh
    ```

- [Just](https://github.com/casey/just)

    ```bash
    cargo install just
    ```

## Quick Start

1. **Clone this repository:**
   ```bash
   git clone https://github.com/armarquez/infra.git
   cd infra/incus/windows
   ```

2. **Create the VM (from Windows/WSL):**
   ```bash
   # Using Just (recommended)
   just up
   
   # Or using Vagrant directly
   vagrant up
   ```

3. **Setup Incus client (from WSL):**
   ```bash
   just setup-client
   ```

4. **Test the connection:**
   ```bash
   just test-connection
   ```

## File Structure

```
.
├── Vagrantfile              # VM configuration
├── justfile                 # Task automation
├── README.md               # This file
└── scripts/
    ├── bootstrap.sh        # System setup and dependencies
    ├── install-incus.sh    # Incus installation
    └── configure-incus.sh  # Incus server configuration
```

## VM Specifications

- **OS:** Debian 12 (Bookworm)
- **CPU:** 4 cores
- **RAM:** 12 GB
- **Network:** 
  - Private network: 192.168.56.10
  - Port forwarding: SSH (2222), Incus API (8443)
- **Storage:** 50GB Btrfs pool for containers/VMs

## Available Commands (Just)

| Command | Description |
|---------|-------------|
| `just up` | Create and provision the Incus server VM |
| `just down` | Destroy the Incus server VM |
| `just ssh` | SSH into the Incus server VM |
| `just setup-client` | Configure Incus client in WSL |
| `just test-connection` | Test Incus client connectivity |
| `just test-container` | Create a test container |
| `just health-check` | Perform system health check |
| `just full-setup` | Complete environment setup |

Run `just` without arguments to see all available commands.

## Usage Examples

### Basic Container Operations

```bash
# List containers
incus list

# Launch a new container
incus launch ubuntu2204 my-test-container

# Execute commands in container
incus exec my-test-container -- bash

# Launch with CI profile (optimized for testing)
incus launch ubuntu2204 ci-container --profile ci
```

### Ansible Testing Workflow

```bash
# Create test environment
incus launch ubuntu2204 ansible-target --profile ci

# Run Ansible playbook
ansible-playbook -i inventory.yml site.yml

# Clean up
incus delete ansible-target --force
```

### VM Management

```bash
# Launch a VM (requires VM-capable image)
incus launch ubuntu2204 my-vm --vm

# Monitor resources
incus info my-vm
```

## Network Configuration

- **VM IP:** 192.168.56.10
- **Incus API:** https://192.168.56.10:8443
- **SSH Access:** `vagrant@192.168.56.10` or `localhost:2222`
- **Container Network:** 10.0.10.0/24 (incusbr0)

## Profiles

### Default Profile

- Standard container configuration
- 1 CPU, 1GB RAM (Incus defaults)
- Connected to incusbr0 network

### CI Profile

- Optimized for CI/CD workloads
- 2 CPU cores, 2GB RAM
- Nesting enabled for Docker-in-Docker
- Non-privileged containers

## Troubleshooting

### VM Won't Start

```bash
# Check VirtualBox VM status
VBoxManage list runningvms

# Check Vagrant status
vagrant status

# View detailed logs
vagrant up --debug
```

### Incus Client Connection Issues

```bash
# Test network connectivity
ping 192.168.56.10

# Test API port
telnet 192.168.56.10 8443

# Reconfigure remote
incus remote remove incus-vm
just setup-client
```

### Performance Issues

```bash
# Check VM resources
just resources

# Monitor container usage
incus info

# View system logs
just logs
```

### WSL Networking Issues

If you can't reach the VM from WSL:
1. Ensure WSL can access Windows network interfaces
2. Try accessing via `localhost:8443` instead of the VM IP
3. Check Windows firewall settings

## Security Considerations

- Default trust password: `incus-server-password` (change in production)
- VM accessible on host-only network
- SSH key authentication configured
- Containers run unprivileged by default

## Customization

### Modify VM Resources

Edit `Vagrantfile`:
```ruby
vb.memory = "16384"  # 16GB RAM
vb.cpus = 6          # 6 CPU cores
```

### Add Custom Images

In `scripts/configure-incus.sh`:
```bash
incus image copy images:centos/9 local: --alias centos9
```

### Custom Profiles

Create additional profiles for specific workloads:
```bash
incus profile create ansible-target
incus profile edit ansible-target < profile-config.yml
```

## Integration with CI/CD

This environment is perfect for:
- **Ansible Development:** Test playbooks in clean containers
- **Infrastructure Testing:** Validate configurations
- **Application Testing:** Multi-service testing with containers
- **Security Testing:** Isolated environments for testing

### Example GitHub Actions Integration

```yaml
- name: Setup Incus Environment
  run: |
    just up
    just setup-client
    just test-connection

- name: Run Ansible Tests
  run: |
    incus launch ubuntu2204 test-target --profile ci
    ansible-playbook tests/site.yml -i tests/inventory
    incus delete test-target --force
```

## Performance Tips

1. **Enable nested virtualization** for VM workloads
2. **Use profiles** to standardize container configs
3. **Monitor resources** with `just resources`
4. **Use image aliases** for consistent deployments
5. **Clean up** unused containers regularly

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes with `just health-check`
4. Submit a pull request

## License

MIT License - see LICENSE file for details