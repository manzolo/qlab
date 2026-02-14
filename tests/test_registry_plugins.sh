#!/usr/bin/env bash
# Local-only test: install, verify, and uninstall every plugin in the registry.
# NOT intended for CI (clones all repos, takes time and bandwidth).
#
# Usage:
#   cd qlab
#   bash tests/test_registry_plugins.sh
#
# Options:
#   --keep-workspace   Do not delete .qlab at the end (useful for inspection)

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

KEEP_WORKSPACE=false
for arg in "$@"; do
    case "$arg" in
        --keep-workspace) KEEP_WORKSPACE=true ;;
    esac
done

passed=0
failed=0
errors=()

log_ok()   { printf "${GREEN}  [PASS]${RESET} %s\n" "$*"; }
log_fail() { printf "${RED}  [FAIL]${RESET} %s\n" "$*"; }
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

# --- Setup ---

WORK_DIR=$(mktemp -d)
echo ""
printf "${BOLD}Registry Plugin Test${RESET}\n"
echo "  Working directory: $WORK_DIR"
echo ""

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

    # Install
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

    # Ports shows it (plugin must declare at least one SSH port)
    assert "$pname: appears in 'ports'" \
        bash -c "'$QLAB' ports 2>/dev/null | grep -q '$pname'"

    # Uninstall (pipe 'y' for confirmation)
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

# --- Cleanup ---

if [[ "$KEEP_WORKSPACE" == false ]]; then
    rm -rf "$WORK_DIR"
fi

# --- Summary ---

printf "${BOLD}Results:${RESET}  "
printf "${GREEN}%d passed${RESET}, " "$passed"
if [[ $failed -gt 0 ]]; then
    printf "${RED}%d failed${RESET}\n" "$failed"
    echo ""
    printf "${RED}Failures:${RESET}\n"
    for e in "${errors[@]}"; do
        echo "  - $e"
    done
    echo ""
    exit 1
else
    printf "0 failed\n"
    echo ""
    exit 0
fi
