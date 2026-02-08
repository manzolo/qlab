#!/usr/bin/env bash
# QLab - VM management

STATE_DIR="${WORKSPACE_DIR:-.qlab}/state"
LOG_DIR="${WORKSPACE_DIR:-.qlab}/logs"

# Check if KVM acceleration is available
check_kvm() {
    if [[ ! -w /dev/kvm ]]; then
        warn "/dev/kvm not accessible. KVM acceleration is not available."
        echo "  Tip: run 'kvm-ok' or check that virtualization is enabled in BIOS."
        echo "  QEMU will fall back to software emulation (much slower)."
        return 1
    fi
    return 0
}

# Check if a TCP port is available (not already listening)
# Usage: check_port_available port
check_port_available() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        error "Invalid port number: $port"
        return 1
    fi
    if ss -tlnH sport = :"$port" 2>/dev/null | grep -q .; then
        return 1
    fi
    return 0
}

# Check all host ports needed by the VM are available
# Usage: check_all_ports ssh_port netdev_opts
check_all_ports() {
    local ssh_port="$1"
    local netdev_opts="$2"
    local ports=()
    local busy_ports=()

    ports+=("$ssh_port")

    # Extract extra host ports from hostfwd entries
    local remaining="$netdev_opts"
    while [[ "$remaining" =~ hostfwd=tcp::([0-9]+)-: ]]; do
        local found_port="${BASH_REMATCH[1]}"
        if [[ "$found_port" != "$ssh_port" ]]; then
            ports+=("$found_port")
        fi
        remaining="${remaining#*hostfwd=tcp::${found_port}-:}"
    done

    for port in "${ports[@]}"; do
        if ! check_port_available "$port"; then
            busy_ports+=("$port")
        fi
    done

    if [[ ${#busy_ports[@]} -gt 0 ]]; then
        error "The following port(s) are already in use: ${busy_ports[*]}"
        echo "  Tip: check what is using them with: ss -tlnp sport = :<port>" >&2
        return 1
    fi
    return 0
}

# Start a VM in background with serial log and SSH port forwarding
# Usage: start_vm disk_path cdrom_path memory plugin_name ssh_port [extra_args...]
# Extra args starting with "hostfwd=" are appended to the netdev (same NIC).
# All other extra args are appended as raw QEMU options.
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

    # Build netdev options: SSH port forward + any extra hostfwd from extra_args
    local netdev_opts="user,id=net0,hostfwd=tcp::${ssh_port}-:22"
    local qemu_extra_args=()
    for arg in "${extra_args[@]}"; do
        if [[ "$arg" == hostfwd=* ]]; then
            netdev_opts+=",$arg"
        else
            qemu_extra_args+=("$arg")
        fi
    done

    # Check that all forwarded host ports are available
    check_all_ports "$ssh_port" "$netdev_opts" || return 1

    local qemu_args=(
        qemu-system-x86_64
        -m "$memory"
        -display none
        -serial "file:$log_file"
        -monitor none
        -pidfile "$pid_file"
        -daemonize
        -drive "file=$disk_path,format=qcow2,if=virtio"
        -netdev "$netdev_opts"
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

    # Add any extra QEMU arguments (hostfwd entries already merged into netdev)
    if [[ ${#qemu_extra_args[@]} -gt 0 ]]; then
        qemu_args+=("${qemu_extra_args[@]}")
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

    # Save SSH port for shell command
    echo "$ssh_port" > "$STATE_DIR/${plugin_name}.port"

    success "VM '$plugin_name' started (PID $(cat "$pid_file"))."
    echo ""
    echo "  Connect via SSH (wait ~30s for boot):"
    echo "    qlab shell $plugin_name"
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

    rm -f "$pid_file" "$STATE_DIR/${plugin_name}.port"
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

# Open an SSH shell to a running VM
# Usage: shell_vm plugin_name [ssh_user]
shell_vm() {
    local plugin_name="$1"
    local ssh_user="${2:-labuser}"
    local pid_file="$STATE_DIR/${plugin_name}.pid"
    local port_file="$STATE_DIR/${plugin_name}.port"

    if [[ ! -f "$pid_file" ]]; then
        error "No running VM found for '$plugin_name'."
        echo "  Start it first: qlab run <plugin>"
        return 1
    fi

    local pid
    pid=$(cat "$pid_file")
    if ! kill -0 "$pid" 2>/dev/null; then
        error "VM '$plugin_name' is not running (stale PID)."
        rm -f "$pid_file" "$port_file"
        return 1
    fi

    if [[ ! -f "$port_file" ]]; then
        error "SSH port not found for '$plugin_name'."
        return 1
    fi

    local ssh_port
    ssh_port=$(cat "$port_file")

    info "Connecting to '$plugin_name' (SSH port $ssh_port, user $ssh_user)..."
    echo "  Type 'exit' to disconnect."
    echo ""
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -p "$ssh_port" "${ssh_user}@localhost"
}

# List all running VMs with their SSH ports
list_running_vms() {
    local count=0
    if [[ -d "$STATE_DIR" ]]; then
        for pidfile in "$STATE_DIR"/*.pid; do
            [[ -f "$pidfile" ]] || continue
            local vm_name pid ssh_port
            vm_name="$(basename "$pidfile" .pid)"
            pid=$(cat "$pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                ssh_port="?"
                if [[ -f "$STATE_DIR/${vm_name}.port" ]]; then
                    ssh_port=$(cat "$STATE_DIR/${vm_name}.port")
                fi
                echo "  $vm_name (PID $pid, SSH port $ssh_port)"
                count=$((count + 1))
            fi
        done
    fi
    if [[ $count -eq 0 ]]; then
        echo "  (none)"
    fi
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
