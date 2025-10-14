# Cloud-init Debian VM (WSL2)

All steps were developed and tested on Windows Subsystem for Linux 2 (WSL2).

## Prerequisites (WSL2)

- WSL2 distro (Ubuntu 22.04)
- Internet access in WSL2
- Open ports 2222 and 8080 on the Windows host
- Packages installed inside WSL2:
  - qemu-system-x86, qemu-utils, cloud-image-utils, genisoimage, curl

You can install them via the helper script:

```bash
./scripts/setup.sh
```

## Files overview

- `scripts/make-vm.sh` — end-to-end script: downloads the Debian cloud image (if missing), builds a per-VM overlay disk, renders cloud-init user-data/meta-data, creates a seed ISO, and boots QEMU.
- `scripts/setup.sh` — installs required packages in your WSL2 distro.
- `files/user-data` — cloud-init template (user, packages, nginx, index.html content).
- `files/meta-data` — cloud-init template for instance-id and hostname.
- `images/` — stores the base Debian cloud image (downloaded on first run).
- `vm/<name>/` — per-VM working directory (disk, seed ISO, rendered cloud-init files).

## Create and boot a VM

Usage:

```bash
./scripts/make-vm.sh <name> <ram_mb> <vcpus> <ssh_pubkey_path> [site_content] [username] [password]
```

Quick start (uses defaults):

```bash
./scripts/make-vm.sh
```

Defaults used when omitted:

- name: `debian-vm`
- ram_mb: `2048`
- vcpus: `2`
- ssh_pubkey_path: `$HOME/.ssh/id_rsa.pub`
- site_content: `It works!`
- username: `user`
- password: `password`

On first run, the script will download the Debian 12 cloud image into `images/`.

When the VM boots, cloud-init will:

- Add your SSH public key to the specified user
- Install and enable nginx
- Write `/var/www/html/index.html` with your provided content

## Access the VM

- SSH: `ssh -p 2222 <username>@localhost`. Initial user defaults to `user` unless you override it.
- HTTP: open `http://localhost:8080` in your browser to see the landing page or use command `curl http://localhost:8080`.
