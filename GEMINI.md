# Gemini Project Summary: Incus on Windows Development Environment

This document provides a condensed overview of the project for quick context and reference. The canonical documentation is in `README.md`.

## 1. Project Purpose

This project automates the setup of a development environment using Incus for container and VM orchestration. It supports two main methods:

1.  **Local VM:** An Ubuntu 24.04 VM (upgraded from 22.04) managed by Vagrant on the Windows host.
2.  **Remote Server:** A pre-existing Debian 12/13 server provisioned with Ansible.

The primary client for interacting with the Incus server is WSL (Windows Subsystem for Linux).

## 2. Core Technologies

- **Orchestration:** [Incus](https://linuxcontainers.org/incus/)
- **Local VM:** [Vagrant](https://www.vagrantup.com/) + [VirtualBox](https://www.virtualbox.org/)
- **Remote Provisioning:** [Ansible](https://www.ansible.com/)
- **Task Runner:** [Just](https://github.com/casey/just)
- **Client Environment:** WSL (Ubuntu/Debian)
- **Server OS:** Debian 12+

## 3. Key Workflows & Commands

The `justfile` provides a simplified command interface for all major operations.

### Workflow 1: Local VM Setup (Vagrant)

This is the quickest way to get a local Incus server running.

1.  **Start & Provision VM:**
    ```bash
    just up
    ```

2.  **Configure WSL Client:**
    ```bash
    just setup-client
    ```

3.  **Verify Connection:**
    ```bash
    just test-connection
    # or
    incus list
    ```

4.  **Destroy VM:**
    ```bash
    just down
    ```

### Workflow 2: Remote Server Setup (Ansible)

This provisions an existing remote server.

1.  **Configure Inventory:** Edit `inventory.ini` with server IP and user.
    ```ini
    # Example:
    192.168.1.100 ansible_user=debian
    ```
2.  **Run Full Setup:** Provisions server and configures the local client.
    ```bash
    just full-remote-setup
    ```
3.  **Verify Connection:**
    ```bash
    incus list
    ```

## 4. Essential Commands (`just`)

| Command | Description | Workflow |
| :--- | :--- | :--- |
| `just up` | Create and provision the local Incus VM. | Local VM |
| `just down` | Destroy the local Incus VM. | Local VM |
| `just ssh` | SSH into the local Incus VM. | Local VM |
| `just setup-client` | Configure WSL client for the local VM. | Local VM |
| `just full-remote-setup` | Run complete setup for a remote server. | Remote |
| `just provision-remote` | Provision a remote server with Ansible. | Remote |
| `just setup-remote-client` | Configure WSL client for the remote server. | Remote |
| `just test-connection` | Test Incus client connectivity to the local VM. | Local VM |
| `just validate-remote-provision` | Test Incus client connectivity to the remote server. | Remote |
| `just health-check` | Perform a system health check. | Both |
| `just test-container` | Create a test container. | Both |

## 5. Core Concepts

- **Networking (Local VM):**
    - **VM IP:** `192.168.56.10`
    - **Incus API:** `https://192.168.56.10:8443`
    - **SSH Forward:** `localhost:2222`
- **Incus Profiles:**
    - `default`: Standard container settings.
    - `ci`: Optimized for CI/CD (2 CPU, 2GB RAM, nesting enabled).
- **Security:**
    - The default trust password is `incus-server-password`. This should be changed in a production environment.
    - Containers run unprivileged by default.
