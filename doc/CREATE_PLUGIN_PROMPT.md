# Prompt for creating a new QLab plugin

Copy everything between the two horizontal lines below, fill in the **User Input** section with your values, and send it to an AI assistant. See the [Example usage](#example-usage) section at the bottom for a filled-in sample.

---

Create a new QLab plugin with the following details:

## User Input

```
PLUGIN_NAME: <name>
DESCRIPTION: <what the lab teaches>
CLOUD_IMAGE: <URL of the cloud image to use, or "same as hello-lab" for Ubuntu 22.04 minimal>
SSH_USER: <username to create in the VM, e.g. labuser>
SSH_PASS: <password for the user>
PACKAGES: <comma-separated list of packages to install via cloud-init, e.g. nginx, docker.io>
MEMORY: <VM memory in MB, e.g. 1024 (use at least 768 for heavy services)>
MOTD: <multi-line welcome message shown on SSH login, with lab objectives and useful commands>
RUNCMD: <list of commands to run on first boot, one per line>
SERVICE_PORTS: <optional: comma-separated guest ports to forward, e.g. 80, 3306>
```

Use the architecture reference below to generate the plugin files.

## QLab Plugin Architecture

A QLab plugin is a git repository with this structure:

```
my-plugin/
├── plugin.conf    # Required: JSON metadata (name, version, description)
├── install.sh     # Optional: runs on install (failure aborts installation)
├── run.sh         # Required: main entry point
├── tests/         # Optional: automated tests
│   └── run_all.sh # Entry point for `qlab test <name>`
└── README.md      # Recommended: documentation
```

The plugin is installed via `qlab install <name>` (from registry) or `qlab install <git-url>`.
It runs via `qlab run <name>`, which `cd`s into `.qlab/plugins/<name>/` and executes `bash run.sh`.

### plugin.conf

JSON metadata file with **required** fields (`name`, `version`, `description`). Validated on install via `validate_plugin_conf()`:

```json
{
  "name": "<plugin-name>",
  "description": "<one-line description>",
  "version": "1.0"
}
```

- `name`: lowercase, hyphens and underscores only (regex: `^[a-z0-9_-]+$`)
- Must match the repository directory name
- All three fields are mandatory — installation fails if any is missing

### install.sh

Optional. Runs once on `qlab install`. **If it exits non-zero, installation is aborted** and the plugin directory is cleaned up. Should:

- Print educational info about what the lab does
- Check for required dependencies
- Create a `lab/` working directory

Template:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "  [<PLUGIN_NAME>] Installing..."
echo ""
echo "  <description of what this lab teaches>"
echo ""

mkdir -p lab

echo "  Checking dependencies..."
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
    fi
done

echo ""
echo "  [<PLUGIN_NAME>] Installation complete."
echo "  Run with: qlab run <PLUGIN_NAME>"
```

### run.sh

Main entry point. This is where the VM is configured and started. Must:

1. Source QLab core libraries
2. Download/verify cloud image
3. Create cloud-init user-data (with `package_update: true`) and meta-data
4. Generate cloud-init ISO with genisoimage
5. Create overlay disk (COW) from base image
6. Start VM in background with **dynamic** SSH port (`auto`)

Template:

```bash
#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="<plugin-name>"

echo "============================================="
echo "  ${PLUGIN_NAME}: <title>"
echo "============================================="

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi
for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "<cloud-image-url>")
CLOUD_IMAGE_FILE="$IMAGE_DIR/<image-filename>"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY <memory>)}"

mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# Step 1: Download cloud image
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi

# Step 2: Cloud-init
info "Step 2: Cloud-init configuration"

cat > "$LAB_DIR/user-data" <<'USERDATA'
#cloud-config
hostname: <plugin-name>
package_update: true
users:
  - name: <ssh-user>
    plain_text_passwd: <ssh-pass>
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - <package1>
  - <package2>
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32m<plugin-name>\033[0m — \033[1mQLab Educational VM\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mObjectives:\033[0m
          • <bulleted list of lab goals>

        \033[1;33mUseful commands:\033[0m
          \033[0;32m<cmd1>\033[0m             <description>
          \033[0;32m<cmd2>\033[0m             <description>

        \033[1;33mCredentials:\033[0m  \033[1;36m<user>\033[0m / \033[1;36m<pass>\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== <PLUGIN_NAME> VM is ready! ==="
  - <additional commands>
USERDATA

# Inject the workspace SSH public key
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data"

cat > "$LAB_DIR/meta-data" <<METADATA
instance-id: ${PLUGIN_NAME}-001
local-hostname: ${PLUGIN_NAME}
METADATA

success "Created cloud-init files"

# Step 3: Generate cloud-init ISO
info "Step 3: Cloud-init ISO"
CIDATA_ISO="$LAB_DIR/cidata.iso"
check_dependency genisoimage || exit 1
genisoimage -output "$CIDATA_ISO" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data" "$LAB_DIR/meta-data" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ISO"

# Step 4: Overlay disk
info "Step 4: Overlay disk"
OVERLAY_DISK="$LAB_DIR/${PLUGIN_NAME}-disk.qcow2"
if [[ -f "$OVERLAY_DISK" ]]; then
    rm -f "$OVERLAY_DISK"
fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_DISK" "${QLAB_DISK_SIZE:-}"

# Step 5: Start VM (with optional service port forwarding)
info "Step 5: Starting VM"
start_vm "$OVERLAY_DISK" "$CIDATA_ISO" "$MEMORY" "$PLUGIN_NAME" auto \
    "hostfwd=tcp::0-:<SERVICE_PORT>"  # remove this line if no service ports needed

echo ""
echo "============================================="
echo "  ${PLUGIN_NAME}: VM is booting"
echo "============================================="
echo ""
echo "  Credentials:"
echo "    Username: <ssh-user>"
echo "    Password: <ssh-pass>"
echo ""
echo "  Connect: qlab shell ${PLUGIN_NAME}"
echo "  Log:     qlab log ${PLUGIN_NAME}"
echo "  Stop:    qlab stop ${PLUGIN_NAME}"
echo "  Ports:   qlab ports"
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
```

## Available QLab Core Functions

The plugin sources `$QLAB_ROOT/lib/*.bash` which provides:

### Output (lib/utils.bash)
- `info "message"` — print `[INFO] message`
- `warn "message"` — print `[WARN] message` to stderr
- `error "message"` — print `[ERROR] message` to stderr
- `success "message"` — print `[OK] message`
- `confirm_yesno "prompt"` — ask Y/n, returns 0 for yes
- `check_dependency "cmd"` — verify command exists or error
- `validate_plugin_name "name"` — check name matches `^[a-z0-9_-]+$`

### Config (lib/config.bash)
- `get_config KEY default` — read value from `.qlab/qlab.conf`

### Disk (lib/disk.bash)
- `create_disk path [size] [format]` — create qcow2 disk (default 10G)
- `create_overlay backing_file overlay_path [size]` — create COW overlay disk (optional resize)

### VM (lib/vm.bash)
- `start_vm disk cdrom memory plugin_name ssh_port [extra_args...]` — start VM in background with:
  - Serial output to `.qlab/logs/<plugin_name>.log`
  - SSH port forwarding (use `auto` for dynamic allocation)
  - `-smp` CPU count from `QLAB_CPUS` or `QLAB_DEFAULT_CPUS` (default: 1)
  - PID saved to `.qlab/state/<plugin_name>.pid`
  - Port saved to `.qlab/state/<plugin_name>.port`
  - All forwarded ports saved to `.qlab/state/<plugin_name>.ports`
  - KVM if available, software emulation otherwise
  - Extra args starting with `hostfwd=` are added to the same netdev (e.g. `"hostfwd=tcp::0-:80"` for HTTP)
  - Ports remain tracked in `.allocated_ports` until `stop_vm` releases them
- `stop_vm plugin_name` — graceful stop with timeout, then force kill; releases allocated ports
- `is_vm_running plugin_name` — returns 0 if running (verifies PID is a QEMU process)
- `check_kvm` — returns 0 if KVM is accessible
- `wait_for_vm vm_name [timeout] [ssh_user]` — wait for SSH reachability
- `wait_for_cloud_init vm_name [timeout] [ssh_user]` — wait for cloud-init completion
- `allocate_port [preferred]` — allocate a free TCP port (flock-protected)

### Multi-VM helpers (lib/vm.bash)
- `start_vm_or_fail GROUP_VAR disk cdrom memory name ssh_port [extra...]` — start VM or roll back group
- `register_vm_cleanup GROUP_VAR` — install EXIT trap to stop all VMs in group on error
- `check_host_resources total_mem_mb vm_count` — warn if insufficient memory

### Plugin validation (lib/plugin.bash)
- `validate_plugin_conf path_to_plugin.conf` — verify JSON validity and required fields (name, version, description)

### Key variables available in run.sh
- `QLAB_ROOT` — absolute path to the QLab project
- `WORKSPACE_DIR` — absolute path to `.qlab/` workspace
- `QLAB_SSH_PUB_KEY` — the workspace SSH public key for `cloud-init` provisioning
- `QLAB_DEFAULT_MEMORY` — default VM memory from config (default: 1024)
- `QLAB_DEFAULT_CPUS` — default VM CPUs from config (default: 1)

## Multi-VM Plugins

A single plugin can spawn **multiple named VMs** from its `run.sh`. This is useful for labs that require several interconnected machines (e.g., a mail lab with server and clients).

### Naming convention

Sub-VMs must be named `{plugin_name}-{instance}`, e.g. `mail-lab-server`, `mail-lab-client1`. This allows `qlab stop mail-lab` to stop all sub-VMs via prefix matching.

### Multi-VM required patterns

Multi-VM plugins **must** use these helpers for safe resource management:

```bash
# Check resources before starting
MEMORY_TOTAL=$(( MEMORY * 2 ))
check_host_resources "$MEMORY_TOTAL" 2

# Track started VMs for automatic rollback
declare -a STARTED_VMS=()
register_vm_cleanup STARTED_VMS

# Start VMs with rollback on failure
start_vm_or_fail STARTED_VMS "$OVERLAY1" "$CIDATA1" "$MEMORY" "mylab-server" auto \
    [extra args...] || exit 1

start_vm_or_fail STARTED_VMS "$OVERLAY2" "$CIDATA2" "$MEMORY" "mylab-client" auto \
    [extra args...] || exit 1

# Successful start — disable cleanup trap
trap - EXIT
```

### Creating extra virtual disks

Use `create_disk` to create additional qcow2 disks, then pass them to `start_vm` as extra `-drive` arguments:

```bash
create_disk "$LAB_DIR/extra-disk1.qcow2" 5G
create_disk "$LAB_DIR/extra-disk2.qcow2" 5G
```

### Passing extra drives to start_vm

Extra arguments that are not `hostfwd=` entries are passed as raw QEMU options:

```bash
start_vm_or_fail STARTED_VMS "$OVERLAY" "$CIDATA_ISO" "$MEMORY" "raid-lab-lvm" auto \
    -drive "file=$LAB_DIR/lvm-disk1.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/lvm-disk2.qcow2,format=qcow2,if=virtio"
```

### Internal LAN (VM-to-VM networking)

Multi-VM plugins that need inter-VM communication use QEMU multicast sockets:

```bash
INTERNAL_MCAST="230.0.0.1:10100"
SERVER_LAN_MAC="52:54:00:00:05:01"
CLIENT_LAN_MAC="52:54:00:00:05:02"

start_vm_or_fail STARTED_VMS "$OVERLAY_SERVER" "$CIDATA_SERVER" "$MEMORY" "mylab-server" auto \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${SERVER_LAN_MAC}"
```

Configure static IPs via cloud-init netplan using MAC matching:

```yaml
write_files:
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          mylan:
            match:
              macaddress: "52:54:00:00:05:01"
            addresses:
              - 192.168.100.1/24
runcmd:
  - netplan apply
```

### Multi-VM lifecycle

With the naming convention:
- `qlab stop mylab` stops all sub-VMs (parallel for 2+)
- `qlab stop mylab-server` stops only the server
- `qlab shell mylab-server` connects to the server VM
- `qlab log mylab` lists available sub-VM logs
- `qlab uninstall mylab` stops all sub-VMs before removing the plugin

## Rules

1. **Ports are always dynamic** — use `auto` for SSH and `hostfwd=tcp::0-:GUEST_PORT` for service ports. Never hardcode host ports.
2. **Use overlay disks** — never modify the base cloud image directly
3. **Disk size** — use `${QLAB_DISK_SIZE:-}` to let central config or user override control it. Never hardcode.
4. **Memory** — use `${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY <default>)}`. Use at least 768MB per VM for heavy services (mail, database, Docker).
5. **`package_update: true`** — always include in cloud-init user-data to ensure package lists are up to date
6. **cloud-init-status.sh** — always include the `write_files` block for `/etc/profile.d/cloud-init-status.sh` (warns the user if cloud-init is still running on login)
7. **Educational echoes** — explain what each step does and why
8. **`set -euo pipefail`** — always, in both install.sh and run.sh
9. **Plugin name** — lowercase, hyphens/underscores only
10. **cloud-init user-data** — always include `ssh_authorized_keys` with a placeholder (e.g. `__QLAB_SSH_PUB_KEY__`) and replace it with `sed` after creation using `${QLAB_SSH_PUB_KEY:-}`. Use **quoted heredocs** (`<<'USERDATA'`) to protect MOTD color codes and VM-side commands from host expansion.
11. **MOTD** — use `write_files` to create `/etc/motd.raw` with lab name, objectives, and useful commands. Use ANSI escape codes (e.g. `\033[1;32m`) for colors. In `runcmd`, convert it with `printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd` (the `\n` is needed because `$()` strips trailing newlines) then `rm -f /etc/motd.raw`; disable Ubuntu dynamic MOTD with `chmod -x /etc/update-motd.d/*` in `runcmd`.
12. **Multi-VM plugins** must use `start_vm_or_fail`, `register_vm_cleanup`, and `check_host_resources`
13. **README.md** — document objectives, credentials, and how to interact
14. The plugin repo should be named `qlab-plugin-<name>` on GitHub
15. To register the plugin, add an entry to `registry/index.json` in the main qlab repo
16. **Automated tests** — plugins can provide a `tests/run_all.sh` script that verifies lab exercises. Run via `qlab test <name>`. The script should assume VM(s) are already running and use SSH to check expected state (services, files, configurations). Exit 0 on all-pass, non-zero on failure.

## Example: hello-lab registry entry

```json
{
  "name": "hello-lab",
  "description": "Basic VM boot lab with cloud-init",
  "version": "1.2",
  "git_url": "https://github.com/manzolo/qlab-plugin-hello-lab.git"
}
```

## User commands after plugin creation

```bash
# From the plugin directory:
git init && git add -A && git commit -m "feat: initial <plugin-name> plugin"
git tag v1.0
git remote add origin git@github.com:<user>/qlab-plugin-<name>.git
git push -u origin main --tags

# Test locally:
qlab init
qlab install ./<plugin-dir>     # install from local path
qlab run <plugin-name>
qlab shell <plugin-name>
qlab ports                       # check allocated ports
qlab test <plugin-name>          # run automated tests (if provided)
qlab stop <plugin-name>
```

---

## Example usage

Fill in the placeholders and send the prompt to an AI assistant:

```
PLUGIN_NAME: nginx-lab
DESCRIPTION: Learn to install and configure Nginx as a web server inside a VM
CLOUD_IMAGE: same as hello-lab
SSH_USER: labuser
SSH_PASS: labpass
PACKAGES: nginx, curl
MEMORY: 1024
MOTD: |
  Objective: Install and configure Nginx as a web server
  Useful commands:
    systemctl status nginx
    curl http://localhost
    sudo nano /etc/nginx/sites-available/default
RUNCMD:
  - systemctl enable nginx
  - echo "<h1>nginx-lab is running!</h1>" > /var/www/html/index.html
SERVICE_PORTS: 80
```
