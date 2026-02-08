# Prompt for creating a new QLab plugin

Use this prompt with an AI assistant to generate a new QLab plugin. Copy the entire content below and replace the placeholders in the "User Input" section.

---

## Prompt

```
Create a new QLab plugin with the following details:

PLUGIN_NAME: <name>
DESCRIPTION: <what the lab teaches>
CLOUD_IMAGE: <URL of the cloud image to use, or "same as hello-lab" for Ubuntu 22.04 minimal>
SSH_PORT: <port number, must be unique per plugin, e.g. 2223, 2224...>
SSH_USER: <username to create in the VM, e.g. labuser>
SSH_PASS: <password for the user>
PACKAGES: <comma-separated list of packages to install via cloud-init, e.g. nginx, docker.io>
MEMORY: <VM memory in MB, e.g. 1024>
MOTD: <multi-line welcome message shown on SSH login, with lab objectives and useful commands>
RUNCMD: <list of commands to run on first boot, one per line>

---

## QLab Plugin Architecture

A QLab plugin is a git repository with this structure:

```
my-plugin/
├── plugin.conf    # Required: JSON metadata
├── install.sh     # Required: runs on install
├── run.sh         # Required: main entry point
└── README.md      # Recommended: documentation
```

The plugin is installed via `qlab install <name>` (from registry) or `qlab install <git-url>`.
It runs via `qlab run <name>`, which `cd`s into `.qlab/plugins/<name>/` and executes `bash run.sh`.

### plugin.conf

JSON metadata file:

```json
{
  "name": "<plugin-name>",
  "description": "<one-line description>",
  "version": "1.0"
}
```

- `name`: lowercase, hyphens and underscores only (regex: `^[a-z0-9_-]+$`)
- Must match the repository directory name

### install.sh

Runs once on `qlab install`. Should:

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
3. Create cloud-init user-data and meta-data
4. Generate cloud-init ISO with genisoimage
5. Create overlay disk (COW) from base image
6. Start VM in background with SSH port forwarding

Template:

```bash
#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="<plugin-name>"
SSH_PORT=<port>

echo "============================================="
echo "  ${PLUGIN_NAME}: <title>"
echo "============================================="

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi
for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "<cloud-image-url>")
CLOUD_IMAGE_FILE="$IMAGE_DIR/<image-filename>"
MEMORY=$(get_config DEFAULT_MEMORY <memory>)

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
users:
  - name: <ssh-user>
    plain_text_passwd: <ssh-pass>
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
write_files:
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
packages:
  - <package1>
  - <package2>
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
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_DISK"

# Step 5: Start VM
info "Step 5: Starting VM"
start_vm "$OVERLAY_DISK" "$CIDATA_ISO" "$MEMORY" "$PLUGIN_NAME" "$SSH_PORT"

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

### Config (lib/config.bash)
- `get_config KEY default` — read value from `.qlab/qlab.conf`

### Disk (lib/disk.bash)
- `create_disk path [size] [format]` — create qcow2 disk (default 10G)
- `create_overlay backing_file overlay_path` — create COW overlay disk

### VM (lib/vm.bash)
- `start_vm disk cdrom memory plugin_name ssh_port [extra_args...]` — start VM in background with:
  - Serial output to `.qlab/logs/<plugin_name>.log`
  - SSH port forwarding `localhost:<ssh_port>` → VM port 22
  - PID saved to `.qlab/state/<plugin_name>.pid`
  - Port saved to `.qlab/state/<plugin_name>.port`
  - KVM if available, software emulation otherwise
  - Extra args starting with `hostfwd=` are added to the same netdev (e.g. `"hostfwd=tcp::8080-:80"` for HTTP)
- `stop_vm plugin_name` — graceful stop with timeout, then force kill
- `is_vm_running plugin_name` — returns 0 if running
- `check_kvm` — returns 0 if KVM is accessible

### Key variables available in run.sh
- `QLAB_ROOT` — absolute path to the QLab project
- `WORKSPACE_DIR` — absolute path to `.qlab/` workspace
- `QLAB_SSH_PUB_KEY` — the workspace SSH public key for `cloud-init` provisioning

## Multi-VM Plugins

A single plugin can spawn **multiple named VMs** from its `run.sh`. This is useful for labs that require several interconnected machines (e.g., a RAID lab with separate LVM and ZFS instances).

### Naming convention

Sub-VMs must be named `{plugin_name}-{instance}`, e.g. `raid-lab-lvm`, `raid-lab-zfs`. This allows `qlab stop raid-lab` to stop all sub-VMs via prefix matching.

### Creating extra virtual disks

Use `create_disk` to create additional qcow2 disks, then pass them to `start_vm` as extra `-drive` arguments:

```bash
create_disk "$LAB_DIR/extra-disk1.qcow2" 5G
create_disk "$LAB_DIR/extra-disk2.qcow2" 5G
```

### Passing extra drives to start_vm

Extra arguments that are not `hostfwd=` entries are passed as raw QEMU options:

```bash
start_vm "$OVERLAY" "$CIDATA_ISO" "$MEMORY" "raid-lab-lvm" 2230 \
    -drive "file=$LAB_DIR/lvm-disk1.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/lvm-disk2.qcow2,format=qcow2,if=virtio"
```

### Example: 2-VM plugin with extra disks

```bash
# In run.sh of a "raid-lab" plugin:

# --- VM 1: LVM instance ---
for i in 1 2 3 4; do
    create_disk "$LAB_DIR/lvm-disk${i}.qcow2" 2G
done
create_overlay "$CLOUD_IMAGE_FILE" "$LAB_DIR/raid-lab-lvm-disk.qcow2"

start_vm "$LAB_DIR/raid-lab-lvm-disk.qcow2" "$LAB_DIR/cidata-lvm.iso" 1024 "raid-lab-lvm" 2230 \
    -drive "file=$LAB_DIR/lvm-disk1.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/lvm-disk2.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/lvm-disk3.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/lvm-disk4.qcow2,format=qcow2,if=virtio"

# --- VM 2: ZFS instance ---
for i in 1 2 3 4; do
    create_disk "$LAB_DIR/zfs-disk${i}.qcow2" 2G
done
create_overlay "$CLOUD_IMAGE_FILE" "$LAB_DIR/raid-lab-zfs-disk.qcow2"

start_vm "$LAB_DIR/raid-lab-zfs-disk.qcow2" "$LAB_DIR/cidata-zfs.iso" 1024 "raid-lab-zfs" 2231 \
    -drive "file=$LAB_DIR/zfs-disk1.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/zfs-disk2.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/zfs-disk3.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB_DIR/zfs-disk4.qcow2,format=qcow2,if=virtio"
```

With this naming convention:
- `qlab stop raid-lab` stops both `raid-lab-lvm` and `raid-lab-zfs`
- `qlab stop raid-lab-lvm` stops only the LVM instance
- `qlab shell raid-lab-lvm` connects to the LVM VM
- `qlab log raid-lab` lists available sub-VM logs
- `qlab uninstall raid-lab` stops all sub-VMs before removing the plugin

## Rules

1. **SSH port must be unique** per plugin (2222 is taken by hello-lab)
2. **Use overlay disks** — never modify the base cloud image directly
3. **Educational echoes** — explain what each step does and why
4. **set -euo pipefail** — always, in both install.sh and run.sh
5. **Plugin name** — lowercase, hyphens/underscores only
6. **cloud-init user-data** — always include `ssh_authorized_keys` with a placeholder (e.g. `__QLAB_SSH_PUB_KEY__`) and replace it with `sed` after creation using `${QLAB_SSH_PUB_KEY:-}`. Use **quoted heredocs** (`<<'USERDATA'`) to protect MOTD color codes and VM-side commands from host expansion.
7. **README.md** — document objectives, credentials, and how to interact
8. **MOTD** — use `write_files` to create `/etc/motd.raw` with lab name, objectives, and useful commands. Use ANSI escape codes (e.g. `\033[1;32m`) for colors. In `runcmd`, convert it with `printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd` (the `\n` is needed because `$()` strips trailing newlines) then `rm -f /etc/motd.raw`; disable Ubuntu dynamic MOTD with `chmod -x /etc/update-motd.d/*` in `runcmd`.
9. The plugin repo should be named `qlab-plugin-<name>` on GitHub
10. To register the plugin, add an entry to `registry/index.json` in the main qlab repo

## Example: hello-lab registry entry

```json
{
  "name": "hello-lab",
  "description": "Basic VM boot lab with cloud-init",
  "version": "1.0",
  "git_url": "https://github.com/manzolo/qlab-plugin-hello-lab.git"
}
```

## User commands after plugin creation

```bash
# From the plugin directory:
git init && git add -A && git commit -m "feat: initial <plugin-name> plugin"
git remote add origin git@github.com:<user>/qlab-plugin-<name>.git
git push -u origin main

# Test locally:
qlab init
qlab install ./<plugin-dir>     # install from local path
qlab run <plugin-name>
qlab shell <plugin-name>
qlab stop <plugin-name>
```
```

---

## Example usage

Fill in the placeholders and send the prompt to an AI assistant:

```
PLUGIN_NAME: nginx-lab
DESCRIPTION: Learn to install and configure Nginx as a web server inside a VM
CLOUD_IMAGE: same as hello-lab
SSH_PORT: 2223
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
```
