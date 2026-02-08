#!/usr/bin/env bash
# QLab - VM management

STATE_DIR="${WORKSPACE_DIR:-.qlab}/state"
LOG_DIR="${WORKSPACE_DIR:-.qlab}/logs"

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

# Start a VM in background with serial log and SSH port forwarding
# Usage: start_vm disk_path cdrom_path memory plugin_name ssh_port [extra_args...]
start_vm() {
    local disk_path="$1"
    local cdrom_path="${2:-}"
    local memory="${3:-1024}"
    local plugin_name="${4:-vm}"
    local ssh_port="${5:-2222}"
    shift 5 || true
    local extra_args=("$@")

    check_dependency qemu-system-x86_64 || return 1

    mkdir -p "$LOG_DIR" "$STATE_DIR"

    local log_file="$LOG_DIR/${plugin_name}.log"
    local pid_file="$STATE_DIR/${plugin_name}.pid"

    # Check if VM is already running
    if [[ -f "$pid_file" ]]; then
        local old_pid
        old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            warn "VM '$plugin_name' is already running (PID $old_pid)."
            echo "  SSH:  ssh -p $ssh_port labuser@localhost"
            echo "  Log:  $log_file"
            echo "  Stop: qlab stop $plugin_name"
            return 1
        fi
        # Stale PID file
        rm -f "$pid_file"
    fi

    local qemu_args=(
        qemu-system-x86_64
        -m "$memory"
        -display none
        -serial "file:$log_file"
        -monitor none
        -pidfile "$pid_file"
        -daemonize
        -drive "file=$disk_path,format=qcow2,if=virtio"
        -netdev "user,id=net0,hostfwd=tcp::${ssh_port}-:22"
        -device "virtio-net-pci,netdev=net0"
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

    info "Starting VM '$plugin_name' in background..."
    echo "  Disk:     $disk_path"
    echo "  Memory:   ${memory}MB"
    echo "  SSH port: $ssh_port"
    echo "  Log:      $log_file"
    if [[ -n "$cdrom_path" ]]; then
        echo "  CD-ROM:   $cdrom_path"
    fi
    echo ""

    "${qemu_args[@]}" || {
        error "Failed to start VM."
        return 1
    }

    success "VM '$plugin_name' started (PID $(cat "$pid_file"))."
    echo ""
    echo "  Connect via SSH (wait ~30s for boot):"
    echo "    ssh -o StrictHostKeyChecking=no -p $ssh_port labuser@localhost"
    echo ""
    echo "  View boot log:"
    echo "    tail -f $log_file"
    echo ""
    echo "  Stop VM:"
    echo "    qlab stop $plugin_name"
}

# Stop a running VM by plugin name
# Usage: stop_vm plugin_name
stop_vm() {
    local plugin_name="$1"
    local pid_file="$STATE_DIR/${plugin_name}.pid"

    if [[ ! -f "$pid_file" ]]; then
        warn "No running VM found for '$plugin_name'."
        return 1
    fi

    local pid
    pid=$(cat "$pid_file")

    if ! kill -0 "$pid" 2>/dev/null; then
        warn "VM '$plugin_name' is not running (stale PID $pid)."
        rm -f "$pid_file"
        return 0
    fi

    info "Stopping VM '$plugin_name' (PID $pid)..."
    kill "$pid" 2>/dev/null
    # Wait for graceful shutdown
    local timeout=10
    while kill -0 "$pid" 2>/dev/null && [[ $timeout -gt 0 ]]; do
        sleep 1
        timeout=$((timeout - 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        warn "Graceful shutdown timed out, forcing..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$pid_file"
    success "VM '$plugin_name' stopped."
}

# Check if a VM is running for a given plugin
# Usage: is_vm_running plugin_name
is_vm_running() {
    local plugin_name="$1"
    local pid_file="$STATE_DIR/${plugin_name}.pid"

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
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
    info "--- End VM Stop ---"
}
