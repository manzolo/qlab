#!/usr/bin/env bash
# QLab - Disk management (stubs for now)

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
