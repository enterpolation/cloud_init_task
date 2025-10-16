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
./scripts/make-vm.sh \
  --name <name> \
  --ram <ram_mb> \
  --vcpus <count> \
  --ssh-pubkey-path <path> \
  --site-content <text> \
  --username <name> \
  --password <value>

# All options are optional: specify only what you need; the rest use defaults
# Short flags are supported: -n, -r, -c, -k, -s, -u, -p
```

Examples:

```bash
./scripts/make-vm.sh --name demo --ram 4096 --vcpus 4
./scripts/make-vm.sh -n demo -r 4096 -c 4 -k ~/.ssh/id_ed25519.pub -u alice -p secret
./scripts/make-vm.sh --help
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

## Access through Windows

To access the VM from Windows (outside WSL2), forward ports from Windows to WSL2 using `netsh portproxy`.

Get the WSL2 IPv4 address (in the Linux terminal inside WSL2):

```bash
ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```

Copy the address, for example: `172.29.40.10`.

In an elevated PowerShell on Windows, add rules for ports 2222 (SSH) and 8080 (HTTP):

```powershell
$WslIp = "<WSL2_IPv4>"
netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectaddress=$WslIp connectport=2222
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectaddress=$WslIp connectport=8080
```

Show active rules:

```powershell
netsh interface portproxy show all
```

Remove a rule (example for 8080):

```powershell
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0
```

After that, access from Windows:

- SSH: `ssh -p 2222 user@127.0.0.1`
- HTTP: `http://127.0.0.1:8080`
