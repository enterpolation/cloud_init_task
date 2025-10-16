#!/usr/bin/env bash
set -euo pipefail

# Default configuration values
NAME="debian-vm"
RAM="2048"
VCPUS="2"
PUBKEY_PATH="$HOME/.ssh/id_rsa.pub"
SITE_CONTENT="It works!"
USERNAME="user"
PASSWORD="password"

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

usage() {
  cat <<'EOF'
Usage: make-vm.sh [options]

Options:
  -n, --name <name>                VM name (default: debian-vm)
  -r, --ram <ram_mb>               RAM in megabytes (default: 2048)
  -c, --vcpus <count>              Number of virtual CPUs (default: 2)
  -k, --ssh-pubkey-path <path>     Path to SSH public key (default: $HOME/.ssh/id_rsa.pub)
  -s, --site-content <text>        Landing page content (default: "It works!")
  -u, --username <name>            Cloud-init username (default: user)
  -p, --password <value>           Cloud-init password (default: password)
  -h, --help                       Show this help message and exit
EOF
}

parse_long_opt_with_value() {
  local opt="$1"
  local var_ref="$2"
  local value
  value="${opt#*=}"
  if [[ -z "$value" ]]; then
    echo "Option ${opt%%=*} requires a value." >&2
    usage >&2
    exit 1
  fi
  printf -v "$var_ref" '%s' "$value"
}

get_opt_value() {
  local option="$1"
  local next_value="$2"
  if [[ -z "$next_value" || "$next_value" == -* ]]; then
    echo "Option $option requires a value." >&2
    usage >&2
    exit 1
  fi
  printf '%s' "$next_value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      NAME="$(get_opt_value "$1" "${2-}")"
      shift 2
      ;;
    --name=*)
      parse_long_opt_with_value "$1" NAME
      shift
      ;;
    -r|--ram)
      RAM="$(get_opt_value "$1" "${2-}")"
      shift 2
      ;;
    --ram=*)
      parse_long_opt_with_value "$1" RAM
      shift
      ;;
    -c|--vcpus)
      VCPUS="$(get_opt_value "$1" "${2-}")"
      shift 2
      ;;
    --vcpus=*)
      parse_long_opt_with_value "$1" VCPUS
      shift
      ;;
    -k|--ssh-pubkey-path)
      PUBKEY_PATH="$(get_opt_value "$1" "${2-}")"
      shift 2
      ;;
    --ssh-pubkey-path=*)
      parse_long_opt_with_value "$1" PUBKEY_PATH
      shift
      ;;
    -s|--site-content)
      SITE_CONTENT="$(get_opt_value "$1" "${2-}")"
      shift 2
      ;;
    --site-content=*)
      parse_long_opt_with_value "$1" SITE_CONTENT
      shift
      ;;
    -u|--username)
      USERNAME="$(get_opt_value "$1" "${2-}")"
      shift 2
      ;;
    --username=*)
      parse_long_opt_with_value "$1" USERNAME
      shift
      ;;
    -p|--password)
      PASSWORD="$(get_opt_value "$1" "${2-}")"
      shift 2
      ;;
    --password=*)
      parse_long_opt_with_value "$1" PASSWORD
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

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
  -nic user,model=virtio,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
  -display none \
  -serial mon:stdio
