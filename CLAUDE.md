# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

QLab is a modular CLI for QEMU/KVM educational labs, written in pure Bash. Each lab is a plugin that provisions a QEMU VM via cloud-init. All code, docs, and commits must be in English.

## Commands

```bash
# Lint
shellcheck bin/qlab lib/*.bash

# Run tests (ShellSpec must be installed first)
curl -fsSL https://git.io/shellspec | sh -s -- --yes   # one-time install
~/.local/lib/shellspec/shellspec                         # run all tests
~/.local/lib/shellspec/shellspec spec/utils_spec.sh      # run a single test file
~/.local/lib/shellspec/shellspec --format tap             # TAP output (used in CI)

# Manual integration test
./bin/qlab init
./bin/qlab install hello-lab
./bin/qlab run hello-lab
./bin/qlab shell hello-lab
./bin/qlab stop hello-lab
```

CI (`.github/workflows/ci.yml`) runs shellcheck, shellspec, an integration test that verifies install/list/status, and an end-to-end VM test with SSH verification under software emulation.

## Architecture

**Entry point:** `bin/qlab` — sources all `lib/*.bash`, then dispatches via a `case` statement in `main()`. A symlink `./qlab -> bin/qlab` exists at the project root.

**Libraries (`lib/*.bash`)** — each file is sourced into the same shell; they share global state:

| File | Responsibility | Key globals |
|------|---------------|-------------|
| `utils.bash` | Colors, `info`/`warn`/`error`/`success`, `confirm_yesno`, `validate_plugin_name`, `check_dependency` | `GREEN`, `YELLOW`, `RED`, `BOLD`, `RESET` |
| `config.bash` | INI-style config loader | `declare -A CONFIG` |
| `vm.bash` | `start_vm`, `stop_vm`, `shell_vm`, `is_vm_running`, `check_kvm`, `list_running_vms`, `ensure_ssh_key`, `get_ssh_public_key`, `allocate_port`, `check_all_ports`, `wait_for_vm`, `start_vm_or_fail`, `check_host_resources`, `register_vm_cleanup` | `STATE_DIR`, `LOG_DIR`, `SSH_DIR`, `SSH_KEY`, `LAST_SSH_PORT` |
| `disk.bash` | `create_disk`, `create_overlay` (qcow2 COW) | — |
| `plugin.bash` | `install_plugin`, `run_plugin`, `uninstall_plugin`, `list_installed_plugins` | `PLUGIN_DIR` |
| `registry.bash` | `load_registry`, `get_plugin_git_url`, `list_available_plugins` | `REGISTRY_DATA`, `REGISTRY_CACHE_DIR` |

**Plugin resolution order** in `cmd_install`: bundled (`plugins/`) → registry lookup → treat as path/git-URL.

**Workspace (`.qlab/`):** Created by `qlab init`. Contains `disks/`, `state/`, `plugins/`, `images/`, `cache/`, `logs/`, `ssh/` (auto-generated key pair), and `qlab.conf` (copied from `etc/qlab.conf.example`).

**Plugin structure:** Each plugin is a directory with `plugin.conf` (JSON metadata), `run.sh` (required entry point), and optionally `install.sh`. Plugins source `$QLAB_ROOT/lib/*.bash` for core functions. `run.sh` executes in a subshell with `WORKSPACE_DIR` set to the absolute workspace path and `QLAB_SSH_PUB_KEY` set to the workspace SSH public key for cloud-init provisioning.

**VM lifecycle:** `start_vm` launches QEMU daemonized with `-pidfile` and serial log. PID goes to `.qlab/state/<name>.pid`, SSH port to `.qlab/state/<name>.port`, all forwarded ports to `.qlab/state/<name>.ports`. `stop_vm` does graceful SIGTERM with 10s timeout, then SIGKILL. Extra `hostfwd=` args in `start_vm` are merged into the same netdev. `shell_vm` connects via SSH using the workspace key (`.qlab/ssh/qlab_id_rsa`) for passwordless login.

**Dynamic port allocation:** All ports (SSH and service ports) are allocated dynamically at runtime via `allocate_port()`. Plugins pass `auto` as the SSH port and `hostfwd=tcp::0-:GUEST_PORT` for service ports. The core allocates free host ports starting from 2222, using `flock` to prevent race conditions between concurrent VM starts. After `start_vm` returns, `LAST_SSH_PORT` contains the allocated SSH port. Use `qlab ports` to see all active port forwards for running VMs.

**Multi-VM support:** Multi-VM plugins use `start_vm_or_fail` for automatic rollback if a VM fails to start, `register_vm_cleanup` for EXIT trap cleanup, and `check_host_resources` for memory warnings. The `cmd_stop` command stops 2+ VMs in parallel for faster shutdown.

**Registry (`registry/index.json`):** JSON array of `{name, description, version, git_url}`. Config key `REGISTRY_URL` supports `file://` (local) or `https://` (remote with cache fallback).

## Tests

ShellSpec tests live in `spec/`. The spec helper (`spec/spec_helper.sh`) sources all `lib/*.bash`. ShellSpec config is in `.shellspec` (requires spec_helper, uses bash shell). shellcheck and shellspec are not installed locally — they run only in CI.

**Local integration test** (`tests/test_registry_plugins.sh`): installs every plugin from the registry, boots its VM(s), verifies SSH + cloud-init, stops and uninstalls. Not run in CI.

```bash
bash tests/test_registry_plugins.sh          # full test (install + VM + SSH)
bash tests/test_registry_plugins.sh --no-vm  # quick test (install/uninstall only)
```

## Conventions

- All scripts use `set -euo pipefail`
- Use `[[ ]]` for conditionals, quote all variable expansions
- Plugin names: lowercase, digits, hyphens, underscores only (`^[a-z0-9_-]+$`)
- Ports are allocated dynamically — plugins must NOT hardcode SSH or service ports
- Plugins use `auto` as the SSH port parameter and `hostfwd=tcp::0-:GUEST_PORT` for service ports
- Multi-VM plugins use `start_vm_or_fail`, `register_vm_cleanup`, and `check_host_resources`
- Always use overlay disks — never modify base cloud images directly
- Plugin git repos are named `qlab-plugin-<name>` on GitHub
- New plugins can be generated using the prompt template in `doc/CREATE_PLUGIN_PROMPT.md`
