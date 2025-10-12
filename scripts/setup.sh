#!/usr/bin/env bash
set -euo pipefail

sudo apt update
# Install necessary packages for creating and running VMs with cloud-init
sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils genisoimage curl

echo "[OK] Dependencies installed."
