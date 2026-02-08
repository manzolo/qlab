#!/usr/bin/env bash
# QLab - Disk management

# Create a new qcow2 disk image
# Usage: create_disk path [size] [format]
create_disk() {
    local path="$1"
    local size="${2:-10G}"
    local format="${3:-qcow2}"

    check_dependency qemu-img || return 1

    info "Creating disk image: $path ($size, $format)"
    qemu-img create -f "$format" "$path" "$size"
    success "Disk created: $path"
}

# Create an overlay (copy-on-write) disk backed by a base image
# Usage: create_overlay backing_file overlay_path
create_overlay() {
    local backing_file="$1"
    local overlay_path="$2"

    check_dependency qemu-img || return 1

    if [[ ! -f "$backing_file" ]]; then
        error "Backing file not found: $backing_file"
        return 1
    fi

    # Use absolute path for backing file
    local abs_backing
    abs_backing="$(cd "$(dirname "$backing_file")" && pwd)/$(basename "$backing_file")"

    info "Creating overlay disk..."
    echo "  Backing: $abs_backing"
    echo "  Overlay: $overlay_path"
    qemu-img create -f qcow2 -b "$abs_backing" -F qcow2 "$overlay_path"
    success "Overlay disk created: $overlay_path"
}

# Stubs kept for backward compatibility
create_disk_stub() {
    local path="${1:-disk.qcow2}"
    local size="${2:-10G}"
    info "--- Create Disk (stub) ---"
    echo "  Would create disk: $path (size: $size, format: qcow2)"
    echo "  Command: qemu-img create -f qcow2 $path $size"
    info "--- End Create Disk ---"
}

delete_disk_stub() {
    local path="${1:-disk.qcow2}"
    info "--- Delete Disk (stub) ---"
    echo "  Would delete disk: $path"
    info "--- End Delete Disk ---"
}
