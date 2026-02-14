# QLab

[![CI](https://github.com/manzolo/qlab/actions/workflows/ci.yml/badge.svg)](https://github.com/manzolo/qlab/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash 4.0+](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)](https://www.kernel.org/)

> **Modular CLI tool for QEMU/KVM educational labs.**

QLab makes it easy to create, share, and run hands-on virtualization labs. Each lab is a plugin that sets up a QEMU virtual machine with a specific configuration, letting students learn by doing.

## Features

- **Plugin-based labs** — each lab is a self-contained plugin you can install, run, and share
- **Cloud-init provisioning** — VMs boot fully configured, no manual setup
- **Overlay disks** — copy-on-write snapshots keep base images untouched
- **Automatic SSH keys** — passwordless login, generated per workspace
- **Serial console or SSH** — connect via `qlab shell` or nographic console
- **Plugin registry** — install labs from a local or remote registry
- **Pure Bash** — no frameworks, no compilation, just shell

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | sudo bash
mkdir my-lab && cd my-lab
qlab init
qlab install hello-lab
qlab run hello-lab
```

## Installation

### From source

```bash
git clone https://github.com/manzolo/qlab.git
cd qlab
sudo ./install.sh
```

### Manual

```bash
git clone https://github.com/manzolo/qlab.git
cd qlab
sudo apt install qemu-kvm qemu-utils genisoimage git jq curl
export PATH="$PWD/bin:$PATH"
```

Without root, the install script falls back to a user-local install (`~/.local/bin`):

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | bash
```

## Updating

The install script handles updates automatically (`git pull --ff-only` if QLab is already installed). Just re-run:

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | sudo bash
```

Or from a local clone: `git pull` inside the qlab directory.

## Commands

| Command | Description |
|---------|-------------|
| `qlab init` | Initialize a new workspace |
| `qlab install <name>` | Install a plugin (bundled, registry, or git URL) |
| `qlab run <name>` | Run a lab (boots VM with cloud-init) |
| `qlab shell <name>` | SSH into a running VM |
| `qlab stop <name>` | Stop a running VM |
| `qlab reset [name]` | Reset a single plugin, or the entire workspace |
| `qlab log <name>` | Tail the VM boot log |
| `qlab list installed` | Show installed plugins |
| `qlab list available` | Show registry plugins |
| `qlab status` | Show workspace and VM status |
| `qlab uninstall <name>` | Remove a plugin |

Default VM credentials: `labuser` / `labpass`. Each lab uses overlay disks so base images are never modified. SSH keys are auto-generated per workspace for passwordless login.

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
| [dhcp-lab](https://github.com/manzolo/qlab-plugin-dhcp-lab) | DHCP server/client lab for dynamic IP addressing (2 VMs) |

List them from the CLI: `qlab list available`

## Runtime Resource Overrides

You can override the default RAM and disk size for any plugin at runtime using environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `QLAB_MEMORY` | VM RAM in MB | `4096` |
| `QLAB_DISK_SIZE` | Overlay disk size | `30G` |

```bash
# Run docker-lab with 4 GB RAM and 30 GB disk
QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run docker-lab
```

Priority: environment variable > `qlab.conf` (`DEFAULT_MEMORY`) > plugin default.

## Creating Your Own Plugin

See [doc/CREATE_PLUGIN_PROMPT.md](doc/CREATE_PLUGIN_PROMPT.md) for a step-by-step guide to building a new lab plugin.

## Plugin Structure

Each plugin is a directory containing:

```
my-plugin/
├── plugin.conf    # JSON metadata (name, description, version)
├── install.sh     # Runs on install (setup, dependency checks)
└── run.sh         # Main entry point (lab execution)
```

Plugins can use QLab core functions by sourcing `$QLAB_ROOT/lib/*.bash`.

---

**License:** [MIT](LICENSE) | [Contributing](CONTRIBUTING.md) | [Changelog](CHANGELOG.md)
