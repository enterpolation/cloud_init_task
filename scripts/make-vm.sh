#!/usr/bin/env bash
set -euo pipefail

# Usage: make-vm.sh <name> <ram_mb> <vcpus> <ssh_pubkey_path> [site_content] [username] [password]
NAME="${1:-debian-vm}"
RAM="${2:-2048}"
VCPUS="${3:-2}"
PUBKEY_PATH="${4:-$HOME/.ssh/id_rsa.pub}"
SITE_CONTENT="${5:-It works!}"
USERNAME="${6:-user}"
PASSWORD="${7:-password}"

# Directories and file paths
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG_DIR="$ROOT_DIR/images"
VM_DIR="$ROOT_DIR/vm/$NAME"
FILES_DIR="$ROOT_DIR/files"
BASE_IMG="$IMG_DIR/debian-12-genericcloud-amd64.qcow2"
VM_IMG="$VM_DIR/${NAME}.qcow2"
SEED_ISO="$VM_DIR/cloud-data.iso"
USER_DATA="$VM_DIR/user-data"
META_DATA="$VM_DIR/meta-data"

# Create necessary directories
mkdir -p "$IMG_DIR" "$VM_DIR"

# For this task, we use Debian 12 (Bookworm) cloud image
# https://cloud.debian.org/images/cloud/bookworm/latest/
if [[ ! -f "$BASE_IMG" ]]; then
  echo "[1] Downloading Debian cloud image..."
  wget -O "$BASE_IMG" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
fi

# Overlay disk is a copy-on-write layer on top of the base image
if [[ ! -f "$VM_IMG" ]]; then
  echo "[2] Creating overlay disk..."
  qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMG" "$VM_IMG" 10G >/dev/null
fi

# Read SSH public key
PUBKEY="$(cat "$PUBKEY_PATH")"

# Prepare cloud-init user-data and meta-data files
# Set hostname and SSH public key in user-data
sed "s|__HOSTNAME__|$NAME|g; s|__SSH_PUBKEY__|$PUBKEY|g; s|__SITE_CONTENT__|$SITE_CONTENT|g; s|__USERNAME__|$USERNAME|g; s|__PASSWORD__|$PASSWORD|g" \
  "$FILES_DIR/user-data" > "$USER_DATA"

# Set hostname in meta-data
sed "s|__HOSTNAME__|$NAME|g" "$FILES_DIR/meta-data" > "$META_DATA"

# Create cloud-init seed ISO
genisoimage -output "$SEED_ISO" -volid cidata -rational-rock -joliet "$USER_DATA" "$META_DATA" >/dev/null 2>&1

echo "[3] Booting VM..."
# Using virtual SLiRP networking with port forwarding:
#  - Host port 2222 -> Guest port 22 (SSH)
#  - Host port 8080 -> Guest port 80 (HTTP)
# Access the VM via: ssh -p 2222 user@localhost
# Access the web server via: http://localhost:8080
# Virtual machine executes without sudo
exec qemu-system-x86_64 \
  -m "$RAM" -smp "$VCPUS" \
  -drive file="$VM_IMG",if=virtio \
  -cdrom "$SEED_ISO" \
  -nic user,model=virtio,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:8080-:80 \
  -display none \
  -serial mon:stdio
