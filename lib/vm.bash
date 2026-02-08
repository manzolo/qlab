#!/usr/bin/env bash
# QLab - VM management

# Check if KVM acceleration is available
check_kvm() {
    if [[ ! -e /dev/kvm ]]; then
        warn "/dev/kvm not found. KVM acceleration is not available."
        echo "  Tip: run 'kvm-ok' or check that virtualization is enabled in BIOS."
        echo "  QEMU will fall back to software emulation (much slower)."
        return 1
    fi
    return 0
}

# Start a VM with QEMU
# Usage: start_vm disk_path cdrom_path memory [extra_args...]
start_vm() {
    local disk_path="$1"
    local cdrom_path="${2:-}"
    local memory="${3:-1024}"
    shift 3 || true
    local extra_args=("$@")

    check_dependency qemu-system-x86_64 || return 1

    local qemu_args=(
        qemu-system-x86_64
        -m "$memory"
        -nographic
        -serial mon:stdio
        -drive "file=$disk_path,format=qcow2,if=virtio"
    )

    # Add KVM if available
    if check_kvm 2>/dev/null; then
        qemu_args+=(-enable-kvm -cpu host)
    fi

    # Add CD-ROM (cloud-init ISO) if provided
    if [[ -n "$cdrom_path" && -f "$cdrom_path" ]]; then
        qemu_args+=(-cdrom "$cdrom_path")
    fi

    # Add any extra arguments
    if [[ ${#extra_args[@]} -gt 0 ]]; then
        qemu_args+=("${extra_args[@]}")
    fi

    info "Starting VM..."
    echo "  Disk:    $disk_path"
    echo "  Memory:  ${memory}MB"
    if [[ -n "$cdrom_path" ]]; then
        echo "  CD-ROM:  $cdrom_path"
    fi
    echo ""
    echo "  Console: serial (nographic mode)"
    echo "  To exit:  press Ctrl+A then X"
    echo ""

    "${qemu_args[@]}"
}

# Stubs kept for backward compatibility with stub plugins
start_vm_stub() {
    info "--- VM Start (stub) ---"
    echo "  In a real scenario, QEMU would start a virtual machine here."
    echo "  The VM would boot from a disk image with cloud-init configuration."
    echo "  You would interact via serial console (nographic mode)."
    info "--- End VM Start ---"
}

stop_vm_stub() {
    info "--- VM Stop (stub) ---"
    echo "  In a real scenario, QEMU would gracefully shut down the VM."
    echo "  You can also press Ctrl+A then X in serial console to force quit."
    info "--- End VM Stop ---"
}
