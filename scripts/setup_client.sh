#!/usr/bin/env bash
set -euo pipefail

VM_IP=$1
REMOTE_NAME=$2
TOKEN_FILE=$3

echo "🔧 Setting up Incus client in WSL..."

if ! command -v incus >/dev/null 2>&1; then
    echo "Installing Incus via apt...";
    sudo apt install -y incus qemu-system;
else
    echo "Incus client already installed";
fi



if ! incus remote list | grep -q "${REMOTE_NAME}"; then
    echo "Adding remote server...";
    if [ -f "${TOKEN_FILE}" ]; then
        TOKEN=$(cat ${TOKEN_FILE});
        echo "Token: ${TOKEN}"
        echo "y" | incus remote add ${REMOTE_NAME} ${VM_IP} --token ${TOKEN} --accept-certificate;
    else
        echo "Error: Token file not found at ${TOKEN_FILE}";
        exit 1;
    fi
else
    echo "Remote server already configured";
fi

echo "Setting default remote..."
incus remote set-default ${REMOTE_NAME}
echo "✅ Incus client setup complete!"