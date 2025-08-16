# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "incus-server-vm" do |node|
    # Use Debian 12 (Bookworm) as the base box
    config.vm.box = "debian/bookworm64"
    config.vm.box_version = ">= 12.0.0"

    # Configure the VM hostname
    config.vm.hostname = "incus-server"

    # Network configuration - private network for WSL access
    # This creates a private network that WSL can access
    config.vm.network "private_network", ip: "192.168.56.10"
    
    # Forward SSH port for direct access if needed
    config.vm.network "forwarded_port", guest: 22, host: 2222, id: "ssh"
    
    # Forward Incus API port (8443) for client connections
    config.vm.network "forwarded_port", guest: 8443, host: 8443, id: "incus-api"

    # Hyper-V specific configuration
    config.vm.provider "hyperv" do |h|
      h.vm_name = "incus-server-vm"
      h.memory = 12288
      h.cpus = 4
      
      # Enable nested virtualization for running KVM inside the VM
      h.enable_virtualization_extensions = true
    end

    # SSH configuration
    config.ssh.insert_key = false
    config.ssh.private_key_path = ["~/.vagrant.d/insecure_private_key"]
    
    # Provisioning scripts
    config.vm.provision "shell", path: "scripts/bootstrap.sh", privileged: true
    config.vm.provision "shell", path: "scripts/install_incus.sh", privileged: true

    # Reload the VM to apply group membership changes for the vagrant user
    config.vm.provision "shell", inline: "echo 'Rebooting to apply group memberships...'", reboot: true

    config.vm.provision "shell", path: "scripts/configure_incus.sh", privileged: true
    
    # Copy SSH keys for easier access
    config.vm.provision "file", source: "~/.ssh/id_ed25519.pub", destination: "/tmp/host_ssh_key.pub"
    config.vm.provision "shell", inline: <<-SHELL
      if [ -f /tmp/host_ssh_key.pub ]; then
        mkdir -p /home/vagrant/.ssh
        cat /tmp/host_ssh_key.pub >> /home/vagrant/.ssh/authorized_keys
        chmod 700 /home/vagrant/.ssh
        chmod 600 /home/vagrant/.ssh/authorized_keys
        chown -R vagrant:vagrant /home/vagrant/.ssh
        rm /tmp/host_ssh_key.pub
      fi
    SHELL
  end
end