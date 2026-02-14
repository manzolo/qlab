#!/usr/bin/env bash
# Local-only test: install, run VM, verify SSH + cloud-init, stop, and uninstall
# every plugin in the registry.
# NOT intended for CI (clones all repos, boots VMs, takes time and bandwidth).
#
# Usage:
#   cd qlab
#   bash tests/test_registry_plugins.sh          # full test (install + VM + SSH)
#   bash tests/test_registry_plugins.sh --no-vm  # quick test (install only)
#
# Options:
#   --no-vm            Skip VM boot / SSH / cloud-init checks
#   --keep-workspace   Do not delete the temp workspace at the end
#   --timeout N        SSH wait timeout in seconds per VM (default: 180)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QLAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QLAB="$QLAB_ROOT/bin/qlab"
REGISTRY="$QLAB_ROOT/registry/index.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

# Defaults
KEEP_WORKSPACE=false
RUN_VM=true
SSH_TIMEOUT=180
CLOUD_INIT_TIMEOUT=300
SSH_USER="labuser"
SSH_PASS="labpass"

for arg in "$@"; do
    case "$arg" in
        --keep-workspace) KEEP_WORKSPACE=true ;;
        --no-vm)          RUN_VM=false ;;
        --timeout)        shift; SSH_TIMEOUT="$1" ;;
    esac
done

passed=0
failed=0
skipped=0
errors=()

log_ok()   { printf "${GREEN}  [PASS]${RESET} %s\n" "$*"; }
log_fail() { printf "${RED}  [FAIL]${RESET} %s\n" "$*"; }
log_skip() { printf "${YELLOW}  [SKIP]${RESET} %s\n" "$*"; skipped=$((skipped + 1)); }
log_info() { printf "${YELLOW}  [INFO]${RESET} %s\n" "$*"; }

assert() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        log_ok "$description"
        passed=$((passed + 1))
    else
        log_fail "$description"
        failed=$((failed + 1))
        errors+=("$description")
    fi
}

# SSH helper — run a command on a VM via sshpass
ssh_cmd() {
    local port="$1"
    shift
    sshpass -p "$SSH_PASS" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        -p "$port" "${SSH_USER}@localhost" "$@"
}

# Wait for SSH to become reachable on a given port
# Returns 0 on success, 1 on timeout
wait_for_ssh() {
    local port="$1"
    local timeout="$2"
    local elapsed=0
    local interval=10

    while [[ $elapsed -lt $timeout ]]; do
        if ssh_cmd "$port" "echo OK" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    return 1
}

# Wait for cloud-init to finish on a VM
wait_for_cloud_init() {
    local port="$1"
    local timeout="$2"
    # cloud-init status --wait blocks until done; wrap with timeout
    if ssh_cmd "$port" "timeout $timeout cloud-init status --wait" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Extract SSH ports for a given plugin from qlab ports output
# Outputs one "port:varname" per line
get_plugin_ports() {
    local pname="$1"
    "$QLAB" ports 2>/dev/null | grep "$pname" | awk '{print $1}'
}

# --- Dependency check ---

echo ""
printf "${BOLD}Registry Plugin Test${RESET}\n"
echo ""

if [[ "$RUN_VM" == true ]]; then
    missing_deps=()
    for cmd in qemu-system-x86_64 qemu-img genisoimage sshpass curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        printf "${RED}Missing dependencies for VM tests: %s${RESET}\n" "${missing_deps[*]}"
        echo "  Install them or use --no-vm to skip VM tests."
        echo "  sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    log_info "Mode: full (install + VM boot + SSH + cloud-init)"
    log_info "SSH timeout: ${SSH_TIMEOUT}s per VM, cloud-init timeout: ${CLOUD_INIT_TIMEOUT}s"
else
    log_info "Mode: quick (install only, --no-vm)"
fi

# --- Setup ---

WORK_DIR=$(mktemp -d)
echo "  Working directory: $WORK_DIR"
echo ""

cleanup() {
    # Stop any running VMs on exit
    if [[ -d "$WORK_DIR/.qlab/state" ]]; then
        for pidfile in "$WORK_DIR/.qlab/state"/*.pid; do
            [[ -f "$pidfile" ]] || continue
            local vm
            vm="$(basename "$pidfile" .pid)"
            cd "$WORK_DIR" && "$QLAB" stop "$vm" >/dev/null 2>&1 || true
        done
    fi
    if [[ "$KEEP_WORKSPACE" == false ]]; then
        rm -rf "$WORK_DIR"
    else
        log_info "Workspace kept at: $WORK_DIR"
    fi
}
trap cleanup EXIT

cd "$WORK_DIR"

# Initialize workspace
log_info "Initializing workspace..."
"$QLAB" init >/dev/null 2>&1
assert "Workspace initialized" test -d .qlab/plugins

# Read plugin names from registry
mapfile -t PLUGINS < <(jq -r '.[].name' "$REGISTRY")
echo ""
printf "${BOLD}Testing %d plugins from registry${RESET}\n" "${#PLUGINS[@]}"
echo ""

# --- Per-plugin tests ---

for pname in "${PLUGINS[@]}"; do
    printf "${BOLD}--- %s ---${RESET}\n" "$pname"

    # ===== Install =====
    log_info "Installing $pname..."
    if ! "$QLAB" install "$pname" >/dev/null 2>&1; then
        log_fail "$pname: install failed"
        failed=$((failed + 1))
        errors+=("$pname: install failed")
        echo ""
        continue
    fi
    assert "$pname: plugin directory created" test -d ".qlab/plugins/$pname"
    assert "$pname: plugin.conf exists" test -f ".qlab/plugins/$pname/plugin.conf"
    assert "$pname: run.sh exists" test -f ".qlab/plugins/$pname/run.sh"
    assert "$pname: plugin.conf is valid JSON" jq -e . ".qlab/plugins/$pname/plugin.conf"
    assert "$pname: plugin.conf name matches" \
        bash -c "jq -re '.name == \"$pname\"' '.qlab/plugins/$pname/plugin.conf'"

    # List shows it
    assert "$pname: appears in 'list installed'" \
        bash -c "'$QLAB' list installed 2>/dev/null | grep -q '$pname'"

    # Status shows it
    assert "$pname: appears in 'status'" \
        bash -c "'$QLAB' status 2>/dev/null | grep -q '$pname'"

    # Ports shows it
    assert "$pname: appears in 'ports'" \
        bash -c "'$QLAB' ports 2>/dev/null | grep -q '$pname'"

    # ===== VM boot + SSH + cloud-init =====
    if [[ "$RUN_VM" == true ]]; then
        log_info "Running $pname (qlab run)..."
        if ! "$QLAB" run "$pname" >/dev/null 2>&1; then
            log_fail "$pname: qlab run failed"
            failed=$((failed + 1))
            errors+=("$pname: qlab run failed")
            # Try to stop anything that started
            "$QLAB" stop "$pname" >/dev/null 2>&1 || true
        else
            # Get declared SSH ports for this plugin
            mapfile -t ports < <(get_plugin_ports "$pname")

            if [[ ${#ports[@]} -eq 0 ]]; then
                log_fail "$pname: no SSH ports found"
                failed=$((failed + 1))
                errors+=("$pname: no SSH ports found")
            else
                log_info "$pname: ${#ports[@]} SSH port(s): ${ports[*]}"

                for port in "${ports[@]}"; do
                    # Wait for SSH
                    log_info "Waiting for SSH on port $port (timeout ${SSH_TIMEOUT}s)..."
                    if wait_for_ssh "$port" "$SSH_TIMEOUT"; then
                        assert "$pname: SSH reachable on port $port" true

                        # Wait for cloud-init
                        log_info "Waiting for cloud-init on port $port (timeout ${CLOUD_INIT_TIMEOUT}s)..."
                        if wait_for_cloud_init "$port" "$CLOUD_INIT_TIMEOUT"; then
                            assert "$pname: cloud-init completed on port $port" true
                        else
                            log_fail "$pname: cloud-init timeout on port $port"
                            failed=$((failed + 1))
                            errors+=("$pname: cloud-init timeout on port $port")
                        fi

                        # Verify basic SSH command
                        assert "$pname: 'hostname' via SSH on port $port" \
                            ssh_cmd "$port" "hostname"
                        assert "$pname: 'uname -a' via SSH on port $port" \
                            ssh_cmd "$port" "uname -a"
                    else
                        log_fail "$pname: SSH timeout on port $port after ${SSH_TIMEOUT}s"
                        failed=$((failed + 1))
                        errors+=("$pname: SSH timeout on port $port")
                        log_skip "$pname: cloud-init check on port $port (SSH not available)"
                        log_skip "$pname: SSH commands on port $port (SSH not available)"
                    fi
                done
            fi

            # Stop
            log_info "Stopping $pname..."
            "$QLAB" stop "$pname" >/dev/null 2>&1 || true
        fi
    fi

    # ===== Uninstall =====
    log_info "Uninstalling $pname..."
    if ! echo "y" | "$QLAB" uninstall "$pname" >/dev/null 2>&1; then
        log_fail "$pname: uninstall failed"
        failed=$((failed + 1))
        errors+=("$pname: uninstall failed")
        echo ""
        continue
    fi
    assert "$pname: plugin directory removed after uninstall" \
        bash -c "! test -d '.qlab/plugins/$pname'"

    echo ""
done

# --- Port conflict check (install all, then verify) ---

printf "${BOLD}--- Port conflict check (all plugins) ---${RESET}\n"
log_info "Installing all plugins..."
for pname in "${PLUGINS[@]}"; do
    "$QLAB" install "$pname" >/dev/null 2>&1 || true
done

assert "No port conflicts when all plugins installed" \
    bash -c "'$QLAB' ports 2>/dev/null | grep -q '\[CONFLICT\]' && exit 1 || exit 0"

# Show full port map for reference
log_info "Port map with all plugins installed:"
"$QLAB" ports 2>/dev/null | sed 's/^/    /'

# Uninstall all
log_info "Cleaning up all plugins..."
for pname in "${PLUGINS[@]}"; do
    echo "y" | "$QLAB" uninstall "$pname" >/dev/null 2>&1 || true
done
echo ""

# --- Summary ---

printf "${BOLD}Results:${RESET}  "
printf "${GREEN}%d passed${RESET}, " "$passed"
if [[ $failed -gt 0 ]]; then
    printf "${RED}%d failed${RESET}" "$failed"
else
    printf "0 failed"
fi
if [[ $skipped -gt 0 ]]; then
    printf ", ${YELLOW}%d skipped${RESET}" "$skipped"
fi
echo ""

if [[ $failed -gt 0 ]]; then
    echo ""
    printf "${RED}Failures:${RESET}\n"
    for e in "${errors[@]}"; do
        echo "  - $e"
    done
    echo ""
    exit 1
fi

echo ""
exit 0
