# QLab

[![CI](https://github.com/user/qlab/actions/workflows/ci.yml/badge.svg)](https://github.com/user/qlab/actions/workflows/ci.yml)

**Modular CLI tool for QEMU/KVM educational labs.**

QLab makes it easy to create, share, and run hands-on virtualization labs. Each lab is a plugin that sets up a QEMU virtual machine with a specific configuration, letting students learn by doing.

## Features

- Workspace management (`init`, `status`, `reset`)
- Plugin system for modular labs (install, run, uninstall)
- Cloud-init integration for automatic VM provisioning
- Overlay disks (copy-on-write) to preserve base images
- Serial console (nographic) for lightweight interaction
- Configurable plugin registry (local or remote)
- Pure Bash — no frameworks, no compilation needed

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

## Installation

Clone the repository:

```bash
git clone https://github.com/user/qlab.git
cd qlab
```

Optionally add `bin/` to your PATH:

```bash
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

## License

MIT
