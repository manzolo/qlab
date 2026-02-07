#!/usr/bin/env bash
# QLab - VM management (stubs for now)

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
