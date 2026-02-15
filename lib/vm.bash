#!/usr/bin/env bash
# QLab - VM management

STATE_DIR="${WORKSPACE_DIR:-.qlab}/state"
LOG_DIR="${WORKSPACE_DIR:-.qlab}/logs"
SSH_DIR="${WORKSPACE_DIR:-.qlab}/ssh"
SSH_KEY="$SSH_DIR/qlab_id_rsa"

# --- SSH Key Management ---

# Ensure workspace-specific SSH key pair exists
ensure_ssh_key() {
    if [[ ! -f "$SSH_KEY" ]]; then
        mkdir -p "$SSH_DIR"
        info "Generating QLab SSH key pair for workspace..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N "" -q
        success "SSH key generated: $SSH_KEY"
    fi
}

# Return the content of the public key
get_ssh_public_key() {
    ensure_ssh_key
    if [[ -f "${SSH_KEY}.pub" ]]; then
        cat "${SSH_KEY}.pub"
    fi
}

# --- Hardware Checks ---

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

# --- Dynamic Port Allocation ---

# Check if a port is already tracked in the allocated ports file
# Usage: _port_is_allocated port
_port_is_allocated() {
    local port="$1"
    local alloc_file="$STATE_DIR/.allocated_ports"
    [[ -f "$alloc_file" ]] || return 1
    grep -qx "$port" "$alloc_file" 2>/dev/null
}

# Record a port in the allocated ports file
# Usage: _record_allocated_port port
_record_allocated_port() {
    local port="$1"
    mkdir -p "$STATE_DIR"
    echo "$port" >> "$STATE_DIR/.allocated_ports"
}

# Remove a port from the allocated ports file
# Usage: _release_allocated_port port
_release_allocated_port() {
    local port="$1"
    local alloc_file="$STATE_DIR/.allocated_ports"
    [[ -f "$alloc_file" ]] || return 0
    local tmp
    tmp=$(grep -vx "$port" "$alloc_file" 2>/dev/null || true)
    if [[ -n "$tmp" ]]; then
        echo "$tmp" > "$alloc_file"
    else
        rm -f "$alloc_file"
    fi
}

# Allocate a free TCP port (from 2222 upward)
# Uses flock to prevent race conditions between concurrent VM starts.
# Usage: allocate_port [preferred_port]
# Outputs the allocated port to stdout.
allocate_port() {
    local preferred="${1:-}"
    local lock_file="$STATE_DIR/.port_lock"
    mkdir -p "$STATE_DIR"

    # Use flock for atomic port allocation
    (
        flock -w 10 200 || { echo "ERROR: could not acquire port lock" >&2; exit 1; }

        if [[ -n "$preferred" && "$preferred" =~ ^[0-9]+$ && "$preferred" -ge 1024 ]]; then
            if check_port_available "$preferred" && ! _port_is_allocated "$preferred"; then
                _record_allocated_port "$preferred"
                echo "$preferred"
                exit 0
            fi
        fi

        local port=2222
        while true; do
            if check_port_available "$port" && ! _port_is_allocated "$port"; then
                _record_allocated_port "$port"
                echo "$port"
                exit 0
            fi
            port=$((port + 1))
            if [[ $port -gt 65535 ]]; then
                echo "ERROR: no free port found" >&2
                exit 1
            fi
        done
    ) 200>"$lock_file"
}

# Check all host ports needed by the VM are available
# Usage: check_all_ports ssh_port netdev_opts
check_all_ports() {
    local ssh_port="$1"
    local netdev_opts="$2"
    local ports=()
    local busy_ports=()

    ports+=("$ssh_port")

    # Extract extra host ports from hostfwd entries (skip port 0 = dynamic)
    local remaining="$netdev_opts"
    while [[ "$remaining" =~ hostfwd=(tcp|udp)::([0-9]+)-: ]]; do
        local found_port="${BASH_REMATCH[2]}"
        if [[ "$found_port" != "0" && "$found_port" != "$ssh_port" ]]; then
            ports+=("$found_port")
        fi
        remaining="${remaining#*hostfwd="${BASH_REMATCH[1]}"::"${found_port}"-:}"
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

# --- VM Lifecycle ---

# Start a VM in background with serial log and SSH port forwarding
# Usage: start_vm disk_path cdrom_path memory plugin_name ssh_port [extra_args...]
#
# ssh_port accepts:
#   - "auto", "0", or "" → dynamically allocate a free port
#   - a specific port number → validate and use it (via allocate_port)
#
# Extra args starting with "hostfwd=" are appended to the netdev (same NIC).
#   - "hostfwd=tcp::0-:3306" → the host port is dynamically allocated
# All other extra args are appended as raw QEMU options.
#
# After start, sets LAST_SSH_PORT for the calling plugin.
# Saves all forwarded ports to $STATE_DIR/${vm_name}.ports
start_vm() {
    local disk_path="$1"
    local cdrom_path="${2:-}"
    local memory="${3:-1024}"
    local plugin_name="${4:-vm}"
    local ssh_port="${5:-auto}"
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
            local existing_port="?"
            [[ -f "$STATE_DIR/${plugin_name}.port" ]] && existing_port=$(cat "$STATE_DIR/${plugin_name}.port")
            warn "VM '$plugin_name' is already running (PID $old_pid)."
            echo "  SSH:  ssh -p $existing_port labuser@localhost"
            echo "  Log:  $log_file"
            echo "  Stop: qlab stop $plugin_name"
            return 1
        fi
        # Stale PID file
        rm -f "$pid_file"
    fi

    # Dynamic SSH port allocation
    if [[ -z "$ssh_port" || "$ssh_port" == "auto" || "$ssh_port" == "0" ]]; then
        ssh_port=$(allocate_port)
    else
        ssh_port=$(allocate_port "$ssh_port")
    fi

    if [[ -z "$ssh_port" || "$ssh_port" == ERROR* ]]; then
        error "Failed to allocate SSH port."
        return 1
    fi

    # Build netdev options: SSH port forward + any extra hostfwd from extra_args
    local netdev_opts="user,id=net0,hostfwd=tcp::${ssh_port}-:22"
    local qemu_extra_args=()
    # Track all forwarded ports for .ports file
    local -a port_entries=("tcp:${ssh_port}:22")

    for arg in "${extra_args[@]}"; do
        if [[ "$arg" == hostfwd=* ]]; then
            # Parse hostfwd to handle dynamic port (0)
            # Format: hostfwd=tcp::HOST_PORT-:GUEST_PORT or hostfwd=udp::HOST_PORT-:GUEST_PORT
            if [[ "$arg" =~ ^hostfwd=(tcp|udp)::0-:([0-9]+)$ ]]; then
                local proto="${BASH_REMATCH[1]}"
                local guest_port="${BASH_REMATCH[2]}"
                local dyn_port
                dyn_port=$(allocate_port)
                netdev_opts+=",hostfwd=${proto}::${dyn_port}-:${guest_port}"
                port_entries+=("${proto}:${dyn_port}:${guest_port}")
            else
                netdev_opts+=",$arg"
                # Extract port info for .ports file
                if [[ "$arg" =~ ^hostfwd=(tcp|udp)::([0-9]+)-:([0-9]+)$ ]]; then
                    port_entries+=("${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]}")
                fi
            fi
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
        # Release allocated ports on failure
        for entry in "${port_entries[@]}"; do
            local p
            p=$(echo "$entry" | cut -d: -f2)
            _release_allocated_port "$p"
        done
        return 1
    }

    # Save SSH port for shell command (backward compat .port file)
    echo "$ssh_port" > "$STATE_DIR/${plugin_name}.port"

    # Save all forwarded ports (format: proto:host_port:guest_port)
    printf '%s\n' "${port_entries[@]}" > "$STATE_DIR/${plugin_name}.ports"

    # Release allocated port tracking (QEMU now owns the bind)
    for entry in "${port_entries[@]}"; do
        local p
        p=$(echo "$entry" | cut -d: -f2)
        _release_allocated_port "$p"
    done

    # Expose SSH port to calling plugin (used by plugins, not this file)
    # shellcheck disable=SC2034
    LAST_SSH_PORT="$ssh_port"

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

    rm -f "$pid_file" "$STATE_DIR/${plugin_name}.port" "$STATE_DIR/${plugin_name}.ports"
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

    local ssh_opts=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
    )

    if [[ -f "$SSH_KEY" ]]; then
        ssh_opts+=(-i "$SSH_KEY")
    fi

    ssh "${ssh_opts[@]}" -p "$ssh_port" "${ssh_user}@localhost"
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

# --- Multi-VM Support ---

# Wait for a VM to become reachable via SSH
# Usage: wait_for_vm vm_name [timeout_seconds] [ssh_user]
# Reads SSH port from .port file in state dir.
# Returns 0 if reachable, 1 if timeout.
wait_for_vm() {
    local vm_name="$1"
    local timeout="${2:-120}"
    local ssh_user="${3:-labuser}"
    local port_file="$STATE_DIR/${vm_name}.port"

    if [[ ! -f "$port_file" ]]; then
        error "No port file found for VM '$vm_name'."
        return 1
    fi

    local ssh_port
    ssh_port=$(cat "$port_file")
    local elapsed=0

    info "Waiting for VM '$vm_name' to become reachable (SSH port $ssh_port, timeout ${timeout}s)..."

    while [[ $elapsed -lt $timeout ]]; do
        if ssh -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              -o LogLevel=ERROR \
              -o BatchMode=yes \
              -o ConnectTimeout=3 \
              ${SSH_KEY:+-i "$SSH_KEY"} \
              -p "$ssh_port" "${ssh_user}@localhost" true 2>/dev/null; then
            success "VM '$vm_name' is reachable."
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    error "Timeout waiting for VM '$vm_name' after ${timeout}s."
    return 1
}

# Start a VM or roll back all previously started VMs in the group
# Usage: start_vm_or_fail GROUP_VAR_NAME disk cdrom memory name ssh_port [extra_args...]
# The first argument is the NAME of a bash array variable that tracks started VMs.
# On failure, all VMs in the group are stopped.
start_vm_or_fail() {
    local group_var="$1"
    shift

    # Extract plugin_name (4th positional arg to start_vm)
    local plugin_name="${4:-vm}"

    if start_vm "$@"; then
        # Append to the group tracking array
        eval "${group_var}+=(\"\$plugin_name\")"
        return 0
    else
        error "Failed to start VM '$plugin_name'. Rolling back..."
        # Stop all VMs already started in this group
        local -n group_ref="$group_var"
        local vm
        for vm in "${group_ref[@]}"; do
            stop_vm "$vm" 2>/dev/null || true
        done
        return 1
    fi
}

# Check if the host has enough resources for the planned VMs
# Usage: check_host_resources total_mem_mb vm_count
# Prints a warning if insufficient memory (does not block).
check_host_resources() {
    local total_mem_mb="$1"
    local vm_count="$2"
    local overhead_per_vm=200  # MB overhead per QEMU process

    local needed_mb=$(( total_mem_mb + (vm_count * overhead_per_vm) ))

    if [[ ! -f /proc/meminfo ]]; then
        return 0
    fi

    local avail_kb
    avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    local avail_mb=$(( avail_kb / 1024 ))

    if [[ $avail_mb -lt $needed_mb ]]; then
        warn "Low memory: ${avail_mb}MB available, ~${needed_mb}MB needed (${total_mem_mb}MB for VMs + overhead)."
        echo "  The lab may run slowly or fail. Consider closing other applications." >&2
    fi
}

# Install an EXIT trap that stops all VMs in the group on error exit
# Usage: register_vm_cleanup GROUP_VAR_NAME
# The plugin should call `trap - EXIT` after successful completion.
register_vm_cleanup() {
    local group_var="$1"
    # shellcheck disable=SC2064
    trap "_cleanup_vm_group $group_var" EXIT
}

# Internal: stop all VMs in a group array (called by trap)
_cleanup_vm_group() {
    local group_var="$1"
    local -n group_ref="$group_var"
    if [[ ${#group_ref[@]} -gt 0 ]]; then
        warn "Cleaning up VMs due to error..."
        local vm
        for vm in "${group_ref[@]}"; do
            stop_vm "$vm" 2>/dev/null || true
        done
    fi
}

# --- Stubs (backward compatibility) ---

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
