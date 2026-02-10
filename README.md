# QLab

[![CI](https://github.com/manzolo/qlab/actions/workflows/ci.yml/badge.svg)](https://github.com/manzolo/qlab/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash 4.0+](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)](https://www.kernel.org/)

> **Modular CLI tool for QEMU/KVM educational labs.**

QLab makes it easy to create, share, and run hands-on virtualization labs. Each lab is a plugin that sets up a QEMU virtual machine with a specific configuration, letting students learn by doing.

## Features

- Automated SSH key management and passwordless login
- Workspace management (`init`, `status`, `reset`)
- Plugin system for modular labs (install, run, uninstall)
- Cloud-init integration for automatic VM provisioning
- Overlay disks (copy-on-write) to preserve base images
- Serial console (nographic) or SSH (`qlab shell`) access
- Configurable plugin registry (local or remote)
- Pure Bash — no frameworks, no compilation needed

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | sudo bash
mkdir my-lab && cd my-lab
qlab init
qlab install hello-lab
qlab run hello-lab
```

## Installation

### Quick install (recommended)

One-liner that installs dependencies and adds `qlab` to your PATH:

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | sudo bash
```

Without root, the installer falls back to a user-local install (`~/.local/bin`):

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | bash
```

### Install from a clone

```bash
git clone https://github.com/manzolo/qlab.git
cd qlab
sudo ./install.sh
```

### Manual installation

If you prefer to set things up yourself:

```bash
git clone https://github.com/manzolo/qlab.git
cd qlab
sudo apt install qemu-kvm qemu-utils genisoimage git jq curl
export PATH="$PWD/bin:$PATH"
```

## Usage

### Initialize a workspace

```bash
qlab init
```

Creates a `.qlab/` directory with subdirectories for disks, images, plugins, state, and cache.

### Install a lab plugin

```bash
qlab install hello-lab
```

Installs from bundled plugins, a local path, a git URL, or the registry.

### Run a lab

```bash
qlab run hello-lab
```

Boots a VM with cloud-init and serial console. Login with `labuser` / `labpass`.
You can view the boot log with `qlab log hello-lab`.

### Connect to a lab VM

```bash
qlab shell hello-lab
```

Opens a passwordless SSH session to the running VM using automatically generated workspace keys.

### List plugins

```bash
qlab list installed     # show installed plugins
qlab list available     # show plugins from registry
```

### Reset workspace

```bash
qlab reset
```

Deletes all workspace data and re-initializes.

## Plugin Architecture

Each plugin is a directory containing:

```
my-plugin/
├── plugin.conf    # JSON metadata (name, description, version)
├── install.sh     # Runs on install (setup, dependency checks)
└── run.sh         # Main entry point (lab execution)
```

Plugins can use QLab core functions by sourcing `$QLAB_ROOT/lib/*.bash`.

## Dependencies

Install on Ubuntu/Debian:

```bash
sudo apt install qemu-kvm qemu-utils genisoimage git jq curl
```

Requirements:
- QEMU (>= 8.0) with KVM support
- qemu-img (from qemu-utils)
- genisoimage (for cloud-init ISO generation)
- jq (>= 1.6)
- bash (>= 4.0)
- git
- curl

## Troubleshooting

### KVM not available

```bash
kvm-ok
```

If KVM is not available:
- Enable virtualization in BIOS/UEFI (Intel VT-x or AMD-V)
- Load the KVM module: `sudo modprobe kvm_intel` or `sudo modprobe kvm_amd`
- Add your user to the `kvm` group: `sudo usermod -aG kvm $USER`

QEMU will fall back to software emulation if KVM is unavailable (much slower).

### genisoimage not found

```bash
sudo apt install genisoimage
```

## Available Plugins

QLab ships with a growing registry of ready-to-use lab plugins. Install any of them with `qlab install <name>`:

| Plugin | Description |
|--------|-------------|
| [hello-lab](https://github.com/manzolo/qlab-plugin-hello-lab) | Basic VM boot lab with cloud-init |
| [nginx-lab](https://github.com/manzolo/qlab-plugin-nginx-lab) | Nginx web server installation and configuration |
| [apache-lab](https://github.com/manzolo/qlab-plugin-apache-lab) | Apache web server with SSL/TLS and virtual hosts |
| [docker-lab](https://github.com/manzolo/qlab-plugin-docker-lab) | Docker containers and Docker Compose |
| [mysql-lab](https://github.com/manzolo/qlab-plugin-mysql-lab) | MySQL/MariaDB database management, users, and backups |
| [ssh-lab](https://github.com/manzolo/qlab-plugin-ssh-lab) | SSH hardening with fail2ban, port knocking, and key auth |
| [lvm-lab](https://github.com/manzolo/qlab-plugin-lvm-lab) | LVM with extra virtual disks for PV, VG, and LV management |
| [raid-lab](https://github.com/manzolo/qlab-plugin-raid-lab) | LVM & ZFS disk management with 4 extra disks per VM |
| [dns-lab](https://github.com/manzolo/qlab-plugin-dns-lab) | DNS & BIND9 server/client for record types and zone management |
| [firewall-lab](https://github.com/manzolo/qlab-plugin-firewall-lab) | Firewall with iptables, ufw, and traffic analysis (2 VMs) |
| [vpn-lab](https://github.com/manzolo/qlab-plugin-vpn-lab) | VPN with WireGuard and OpenVPN (server + client VMs) |
| [systemd-lab](https://github.com/manzolo/qlab-plugin-systemd-lab) | Systemd service management, unit files, timers, and journald |

You can also list them from the CLI:

```bash
qlab list available
```

---

## License

MIT
