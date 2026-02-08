# Contributing to QLab

Thank you for your interest in contributing to QLab! This document explains how to create and submit plugins.

## Plugin Structure

Each plugin is a directory with the following structure:

```
my-plugin/
├── plugin.conf    # Required: JSON metadata
├── install.sh     # Optional: runs on install
├── run.sh         # Required: main entry point
└── README.md      # Recommended: documentation
```

### plugin.conf (required)

A JSON file with plugin metadata:

```json
{
  "name": "my-plugin",
  "description": "Short description of what this lab does",
  "version": "1.0"
}
```

- `name`: must match the directory name, lowercase with hyphens/underscores only
- `description`: one-line summary shown in `qlab list`
- `version`: semantic version string

### install.sh (optional)

Runs when the user installs the plugin via `qlab install`. Use it to:

- Check for required dependencies
- Create working directories
- Print educational information about the lab

### run.sh (required)

The main entry point. This script runs when the user executes `qlab run <plugin-name>`.

Best practices:

- Start with `set -euo pipefail`
- Source QLab core libraries for utility functions:
  ```bash
  for lib_file in "$QLAB_ROOT"/lib/*.bash; do
      [[ -f "$lib_file" ]] && source "$lib_file"
  done
  ```
- Use `info()`, `warn()`, `error()`, `success()` for output
- Print educational messages explaining what each step does
- Use `create_overlay()` instead of modifying base images directly
- Use `start_vm()` to boot VMs with proper arguments
- Always include `${QLAB_SSH_PUB_KEY:-}` in `cloud-init`'s `ssh_authorized_keys` to support `qlab shell`

## Core Utilities

Plugins can use these functions from `$QLAB_ROOT/lib/`:

| Function | Description |
|----------|-------------|
| `info(msg)` | Print informational message |
| `warn(msg)` | Print warning to stderr |
| `error(msg)` | Print error to stderr |
| `success(msg)` | Print success message |
| `confirm_yesno(prompt)` | Ask Y/n confirmation |
| `check_dependency(cmd)` | Verify a command is available |
| `get_config(key, default)` | Read config value |
| `create_disk(path, size)` | Create a qcow2 disk |
| `create_overlay(base, overlay)` | Create COW overlay disk |
| `start_vm(disk, cdrom, memory)` | Start a VM with QEMU |
| `check_kvm()` | Check if KVM is available |
| `ensure_ssh_key()` | Generate workspace SSH key if missing |
| `get_ssh_public_key()` | Return workspace public key content |

## Security

- Never run commands as root inside plugins
- Always use overlay disks to avoid modifying shared images
- Validate user input before passing to shell commands
- Do not download binaries from untrusted sources

## Submitting a Plugin

1. Create your plugin following the structure above
2. Test it locally: `qlab install ./my-plugin && qlab run my-plugin`
3. Publish it to a git repository
4. Submit a PR to add it to the registry (`registry/index.json`)

## Development

### Running Tests

```bash
# Install shellspec
curl -fsSL https://git.io/shellspec | sh -s -- --yes

# Run tests
~/.local/lib/shellspec/shellspec

# Lint
shellcheck bin/qlab lib/*.bash
```

### Code Style

- Use `set -euo pipefail` in all scripts
- Quote all variable expansions
- Use `[[ ]]` instead of `[ ]` for conditionals
- Use meaningful function and variable names
- Add educational echo statements in plugins
- Use `${QLAB_SSH_PUB_KEY:-}` for SSH key provisioning in `run.sh`
