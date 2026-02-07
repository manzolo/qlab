Prompt 1 – Setup repo + struttura + bashly skeleton
textYou are an expert Bash developer building an open-source CLI tool called "QLab": a modular QEMU/KVM educational lab platform.

Project rules:
- Target: Ubuntu, CLI-only, QEMU/KVM
- Workspace default: ./.qlab (relative to current directory)
- Dependencies: bashly (CLI), jq (JSON), tput (colors), git, qemu-system-x86_64, qemu-img
- Bash ≥4.2, strict mode: set -euo pipefail
- Educational focus: plugins explain concepts, encourage safe failure
- Safety: all operations confined to ./.qlab, confirm destructive actions
- MVP scope v0.1: minimal CLI + workspace + simple VM + hello-lab plugin

Task for this step:
Generate the initial repository structure and bashly configuration for the qlab CLI.

Output:
1. Full directory tree
2. bashly config.yaml (with subcommands: init, status, reset, install <plugin>, uninstall <plugin>, run <plugin>, list installed, --help)
3. Instructions how to initialize bashly (commands to run)
4. Skeleton of generated bin/qlab (after bashly generate)
5. .gitignore content
6. README.md stub (project name, description, install deps, basic usage)

Do NOT implement lib/ logic yet — focus on structure and CLI skeleton only.
Use TODO comments where logic will come later.
Prompt 2 – Core lib/ + workspace init/status/reset
textContinuing from previous step: we have qlab-core repo with bashly-generated CLI skeleton.

Now implement core logic in lib/ for:
- Workspace creation (.qlab) on init
- Basic config loading (etc/qlab.conf.example → associative array)
- utils.bash: tput-based colors (GREEN, YELLOW, RED, RESET), confirm_yesno(prompt), validate_plugin_name
- Minimal vm.bash: start_vm_stub, stop_vm_stub (just echo for now)
- Minimal disk.bash: create_stub, delete_stub (echo)
- init: create .qlab/{disks,state,plugins}, write default config if missing
- status: show workspace path, installed plugins (ls .qlab/plugins), dummy VM status
- reset: confirm, rm -rf .qlab/*, re-init

Rules:
- Workspace: ./.qlab (relative)
- Use associative array CONFIG[...]
- tput for colors, reset always
- Educational echoes in init/status

Output full code for:
- lib/utils.bash
- lib/config.bash
- lib/vm.bash (stub)
- lib/disk.bash (stub)
- Updated bin/qlab dispatch for init/status/reset
- etc/qlab.conf.example

Add shellspec stubs in spec/ (just one example test for utils echo_color)
Prompt 3 – Plugin system minimal + hello-lab stub
textContinuing QLab development.

Now add minimal plugin system:
- plugin.bash: install_plugin(name) → git clone if git url, validate plugin.conf exists, run install.sh if present
- run_plugin(name) → cd to plugin dir, source run.sh
- uninstall_plugin(name) → confirm, rm -rf plugins/name
- list installed → ls plugins/
- plugin.conf must be JSON: { "name": "...", "description": "...", "version": "1.0", "git_url": "..." }

Create first plugin repo skeleton (separate, but show structure):
Repo: qlab-plugin-hello-lab
- plugin.conf (JSON)
- install.sh (echo educational message, create dummy disk)
- run.sh (echo "Welcome to hello-lab! This lab shows basic VM boot.", then start dummy VM)

In core:
- Add qlab install hello-lab (assume local path or git stub for now)
- qlab run hello-lab → prints message + starts VM stub

Output:
- lib/plugin.bash full
- Updated CLI dispatch for install/uninstall/run/list
- Full qlab-plugin-hello-lab structure + files content
Prompt 4 – hello-lab plugin reale con cloud-init + serial console
textNow make hello-lab plugin real.

Goals:
- Create 1 qcow2 disk (cloud-init enabled)
- Use cloud-init to set up Ubuntu user (user: labuser, pass: labpass)
- VM: Ubuntu cloud image (download if missing), -nographic -serial mon:stdio
- Educational: run.sh prints explanations before/after boot

Steps in run.sh:
1. Echo: "This lab demonstrates basic VM creation with cloud-init..."
2. Create disk if missing (call core disk create)
3. Download Ubuntu cloud image (e.g. https://cloud-images.ubuntu.com/minimal/releases/... )
4. Create cloud-init user-data/meta-data (simple: user labuser, password, ssh key optional)
5. qemu-img create overlay disk
6. Launch: qemu-system-x86_64 -enable-kvm -m 1024 -nographic -serial mon:stdio \
   -drive file=overlay.qcow2,if=virtio -cdrom cloud-init.iso
7. After exit: echo educational summary

install.sh: prepare directories, download base image if needed

Output full:
- qlab-plugin-hello-lab/install.sh
- qlab-plugin-hello-lab/run.sh (detailed, with comments)
- qlab-plugin-hello-lab/plugin.conf
- qlab-plugin-hello-lab/README.md (lab goals, how to interact)

Update core vm.bash to have real start_vm(disk_path, extra_args)
Prompt 5 – Registry locale minimal (JSON index)
textAdd local registry support to QLab.

Create registry/ directory structure (can be inside core for MVP):
- registry/index.json: [ {name:"hello-lab", description:"...", git_url:"https://github.com/.../qlab-plugin-hello-lab.git", version:"1.0"} ]

In lib/registry.bash:
- load_registry() → jq parse index.json or stub if missing
- search_plugins(keyword) → jq filter by name/description
- get_plugin_metadata(name) → jq extract git_url etc.

CLI:
- qlab list available → show from registry
- qlab install <name> → lookup git_url, git clone

For now: local file only (file://./registry/index.json), no HTTP.

Output:
- registry/index.json example with hello-lab
- lib/registry.bash full
- Updated CLI for list available + search stub
Prompt 6 – Tests shellspec minimal + CI GitHub Actions
textAdd testing and CI to QLab.

Focus v0.1: minimal shellspec coverage
- Test utils: echo_color, confirm_yesno (mock read)
- Test config: load_config parses correctly
- Test plugin: validate_plugin_name, stub install

Create:
- .github/workflows/ci.yml (shellcheck, bashate, shellspec --format tap)
- spec/utils_spec.sh (2-3 examples)
- spec/config_spec.sh (basic)
- spec/ (shellspec --init style)

Also add .shellspec config file.

Output full files for CI and 2-3 spec files.
Prompt 7 – Polish: README, CONTRIBUTING, first release notes
textFinal polish for QLab v0.1.0

Create professional documentation:

1. README.md full:
   - Badges (CI)
   - Description
   - Features
   - Installation (apt install qemu-kvm qemu-utils git jq, gem install bashly)
   - Usage examples (qlab init, install hello-lab, run hello-lab, reset)
   - How plugin works
   - Troubleshooting (KVM check: kvm-ok)

2. CONTRIBUTING.md:
   - How to create new plugin (structure, plugin.conf JSON, expected scripts)
   - Contract: use core utils, educational echoes, safety
   - Submitting plugin (PR with repo link)

3. CHANGELOG.md stub
4. Tag suggestion: v0.1.0 "Initial MVP with hello-lab and local registry"

Output full content for README.md, CONTRIBUTING.md, CHANGELOG.md
