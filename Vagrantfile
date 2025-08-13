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

    # VirtualBox specific configuration
    config.vm.provider "virtualbox" do |vb|
      vb.name = "incus-server-vm"
      vb.memory = "12288"  # 12 GB RAM
      vb.cpus = 4          # 4 CPU cores
      
      # Enable nested virtualization for running VMs inside the VM
      vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
      
      # Increase video memory for better performance
      vb.customize ["modifyvm", :id, "--vram", "32"]
      
      # Enable IOAPIC for multi-core support
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      
      # Enable PAE/NX for better memory management
      vb.customize ["modifyvm", :id, "--pae", "on"]
      
      # Optimize for server workload
      vb.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
    end

    # SSH configuration
    config.ssh.insert_key = false
    config.ssh.private_key_path = ["~/.vagrant.d/insecure_private_key"]
    
    # Provisioning scripts
    config.vm.provision "shell", path: "scripts/bootstrap.sh", privileged: true
    config.vm.provision "shell", path: "scripts/install_incus.sh", privileged: true
    config.vm.provision "shell", path: "scripts/configure_incus.sh", privileged: false
    
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