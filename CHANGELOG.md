# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `install.sh` automated installer script (one-liner `curl | bash` or from clone)
- Automatic dependency installation on Debian/Ubuntu
- System-wide (`/usr/local/bin`) or user-local (`~/.local/bin`) installation
- Idempotent: safe to run multiple times
- `--skip-deps` flag to skip dependency installation

## v0.1.1 - Automated SSH Key Management

### Added

- Automated workspace SSH key generation in `.qlab/ssh/`
- Workspace-wide SSH public key exported to plugins via `QLAB_SSH_PUB_KEY`
- Passwordless login support for all laboratory VMs via `qlab shell`
- Automatic SSH key provisioning in `hello-lab`, `raid-lab`, and `nginx-lab`
- Guidelines for SSH key management in `doc/CREATE_PLUGIN_PROMPT.md`

### Fixed

- Improved SSH connection reliability with custom options (`StrictHostKeyChecking=no`, etc.)


## v0.1.0 - Initial MVP

### Added

- CLI entry point (`bin/qlab`) with argument parser and help
- Workspace management: `init`, `status`, `reset`
- Core libraries:
  - `lib/utils.bash`: colored output, confirmation prompts, validation
  - `lib/config.bash`: key=value configuration parser
  - `lib/vm.bash`: QEMU VM management with KVM detection and serial console
  - `lib/disk.bash`: qcow2 disk creation and overlay (COW) support
  - `lib/plugin.bash`: plugin install/uninstall/run/list
  - `lib/registry.bash`: local and remote plugin registry with caching
- Plugin system:
  - Install from bundled plugins, local paths, git URLs, or registry
  - Plugin metadata via `plugin.conf` (JSON)
  - Install hooks via `install.sh`
  - Run entry point via `run.sh`
- `hello-lab` plugin:
  - Downloads Ubuntu cloud image
  - Creates cloud-init ISO for user provisioning
  - Boots VM with overlay disk and serial console
  - Educational echo messages throughout
- Configurable plugin registry:
  - Local (`file://`) and remote (`https://`) registry support
  - Automatic caching with fallback
  - `qlab list available` to browse registry
- Test suite with ShellSpec (utils, config, plugin validation)
- GitHub Actions CI (ShellCheck lint + ShellSpec tests)
- Documentation: README, CONTRIBUTING
