# Changelog

All notable changes to this project will be documented in this file.

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
