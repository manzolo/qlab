#!/usr/bin/env bash
# hello-lab run script — boots a VM in background with SSH access

set -euo pipefail

PLUGIN_NAME="hello-lab"
SSH_PORT=2222

echo "============================================="
echo "  hello-lab: Boot a VM with cloud-init + SSH"
echo "============================================="
echo ""
echo "  This lab demonstrates:"
echo "    1. Downloading a Ubuntu cloud image"
echo "    2. Creating a cloud-init ISO for user provisioning"
echo "    3. Creating an overlay disk (copy-on-write)"
echo "    4. Booting the VM in background with SSH access"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run hello-lab'."
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
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY=$(get_config DEFAULT_MEMORY 1024)

# Ensure lab directory exists
mkdir -p "$LAB_DIR"
mkdir -p "$IMAGE_DIR"

# Step 1: Download cloud image if not present
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  They are minimal and expect cloud-init to configure them on first boot."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# Step 2: Create cloud-init configuration
info "Step 2: Cloud-init configuration"
echo ""
echo "  cloud-init is the standard for initializing cloud instances."
echo "  We create two files:"
echo "    - user-data: defines users, packages, SSH config"
echo "    - meta-data: instance identification"
echo ""

cat > "$LAB_DIR/user-data" <<'USERDATA'
#cloud-config
hostname: hello-lab
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
ssh_pwauth: true
runcmd:
  - echo "=== hello-lab VM is ready! ==="
  - echo "SSH is enabled — connect with: ssh -p 2222 labuser@localhost"
USERDATA

cat > "$LAB_DIR/meta-data" <<METADATA
instance-id: hello-lab-001
local-hostname: hello-lab
METADATA

success "Created cloud-init files in $LAB_DIR/"
echo ""

# Step 3: Generate cloud-init ISO
info "Step 3: Cloud-init ISO"
echo ""
echo "  QEMU reads cloud-init data from a small ISO image (CD-ROM)."
echo "  We use genisoimage to create it with the 'cidata' volume label."
echo ""

CIDATA_ISO="$LAB_DIR/cidata.iso"
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}
genisoimage -output "$CIDATA_ISO" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data" "$LAB_DIR/meta-data" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ISO"
echo ""

# Step 4: Create overlay disk
info "Step 4: Overlay disk"
echo ""
echo "  An overlay disk uses copy-on-write (COW) on top of the base image."
echo "  This means:"
echo "    - The original cloud image stays untouched"
echo "    - All writes go to the overlay file"
echo "    - You can reset the lab by deleting the overlay"
echo ""

OVERLAY_DISK="$LAB_DIR/hello-lab-disk.qcow2"
if [[ -f "$OVERLAY_DISK" ]]; then
    info "Removing previous overlay disk..."
    rm -f "$OVERLAY_DISK"
fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_DISK"
echo ""

# Step 5: Boot the VM in background
info "Step 5: Starting VM in background"
echo ""
echo "  The VM will run in background with:"
echo "    - Serial output logged to .qlab/logs/$PLUGIN_NAME.log"
echo "    - SSH access on port $SSH_PORT"
echo ""

start_vm "$OVERLAY_DISK" "$CIDATA_ISO" "$MEMORY" "$PLUGIN_NAME" "$SSH_PORT"

echo ""
echo "============================================="
echo "  hello-lab: VM is booting"
echo "============================================="
echo ""
echo "  Credentials:"
echo "    Username: labuser"
echo "    Password: labpass"
echo ""
echo "  Connect via SSH (wait ~30s for boot to complete):"
echo "    ssh -o StrictHostKeyChecking=no -p $SSH_PORT labuser@localhost"
echo ""
echo "  View boot log:"
echo "    tail -f .qlab/logs/$PLUGIN_NAME.log"
echo ""
echo "  Stop VM:"
echo "    qlab stop $PLUGIN_NAME"
echo "============================================="
