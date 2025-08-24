#!/bin/bash
set -euo pipefail

echo "=== Starting release upgrade ==="

# Set non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

# Check if the OS is Ubuntu and the current version is not 24.04
if [[ "$(lsb_release -is)" == "Ubuntu" ]]; then
  if [[ "$(lsb_release -rs)" == "24.04" ]]; then
    echo "Already on Ubuntu 24.04, skipping release upgrade."
  else
    # Install release upgrader
    echo "Installing ubuntu-release-upgrader-core..."
    apt-get install -y ubuntu-release-upgrader-core

    # Perform release upgrade
    echo "Performing release upgrade..."
    do-release-upgrade -f DistUpgradeViewNonInteractive

    # Update package lists again after upgrade
    echo "Updating package lists after release upgrade..."
    apt-get update
  fi
else
  echo "Not an Ubuntu system, skipping release upgrade."
fi

echo "=== Release upgrade completed successfully ==="