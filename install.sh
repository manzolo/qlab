#!/usr/bin/env bash
set -euo pipefail

# QLab Installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | sudo bash
#   curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | bash
#   ./install.sh              (from a cloned repo)
#   ./install.sh --skip-deps  (skip dependency installation)

# --- Standalone output helpers (no lib/ dependency) ---

if [[ -t 1 ]]; then
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    GREEN=""
    YELLOW=""
    RED=""
    BOLD=""
    RESET=""
fi

info()    { echo "${BOLD}[INFO]${RESET} $*"; }
warn()    { echo "${YELLOW}[WARN]${RESET} $*" >&2; }
error()   { echo "${RED}[ERROR]${RESET} $*" >&2; }
success() { echo "${GREEN}[OK]${RESET} $*"; }

die() { error "$@"; exit 1; }

# --- Banner ---

print_banner() {
    echo ""
    echo "${BOLD}  QLab Installer${RESET}"
    echo "  Modular CLI for QEMU/KVM educational labs"
    echo ""
}

# --- Helpers ---

check_bash_version() {
    local major="${BASH_VERSINFO[0]}"
    if (( major < 4 )); then
        die "Bash >= 4.0 is required (found ${BASH_VERSION})."
    fi
}

detect_os() {
    OS_ID="unknown"
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "${ID:-}" in
            ubuntu|debian|linuxmint|pop) OS_ID="debian" ;;
            fedora|rhel|centos|rocky|alma) OS_ID="fedora" ;;
            arch|manjaro) OS_ID="arch" ;;
        esac
    fi
}

check_root_or_sudo() {
    if [[ $EUID -eq 0 ]]; then
        INSTALL_MODE="system"
    elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        INSTALL_MODE="system"
    else
        INSTALL_MODE="user"
    fi
}

detect_repo_context() {
    # Are we running from inside a QLab git clone?
    IN_REPO="false"
    SCRIPT_DIR=""

    # Resolve the real path of this script (follows symlinks)
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        source="$(readlink "$source")"
    done
    SCRIPT_DIR="$(cd "$(dirname "$source")" && pwd)"

    if [[ -f "$SCRIPT_DIR/bin/qlab" && -d "$SCRIPT_DIR/lib" ]]; then
        IN_REPO="true"
    fi
}

# --- Step 1: Dependencies ---

RUNTIME_DEPS=(qemu-system-x86_64 qemu-img genisoimage git jq curl ssh sshpass)
APT_PACKAGES=(qemu-system-x86 qemu-utils genisoimage git jq curl openssh-client sshpass)

install_dependencies() {
    info "Checking runtime dependencies..."
    local missing=()
    for cmd in "${RUNTIME_DEPS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "All dependencies are already installed."
        return 0
    fi

    warn "Missing commands: ${missing[*]}"

    if [[ "$OS_ID" == "debian" ]]; then
        info "Installing packages via apt-get: ${APT_PACKAGES[*]}"
        if [[ $EUID -eq 0 ]]; then
            apt-get update -qq
            apt-get install -y -qq "${APT_PACKAGES[@]}"
        elif command -v sudo &>/dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq "${APT_PACKAGES[@]}"
        else
            warn "Cannot install packages without root or sudo."
            warn "Please install manually: sudo apt-get install ${APT_PACKAGES[*]}"
            return 1
        fi
        success "Dependencies installed."
    else
        warn "Automatic dependency installation is only supported on Debian/Ubuntu."
        warn "Please install these commands manually: ${missing[*]}"
    fi
}

# --- Step 2: Ensure QLab source ---

ensure_qlab_source() {
    if [[ "$IN_REPO" == "true" ]]; then
        QLAB_DIR="$SCRIPT_DIR"
        info "Using existing QLab source: $QLAB_DIR"
        return 0
    fi

    # Determine install location
    if [[ "$INSTALL_MODE" == "system" ]]; then
        QLAB_DIR="/opt/qlab"
    else
        QLAB_DIR="${HOME}/.local/share/qlab"
    fi

    if [[ -d "$QLAB_DIR/.git" ]]; then
        info "QLab source already exists at $QLAB_DIR, updating..."
        git -C "$QLAB_DIR" pull --ff-only || warn "Could not update (non-fast-forward). Using existing version."
    else
        info "Cloning QLab to $QLAB_DIR..."
        mkdir -p "$(dirname "$QLAB_DIR")"
        git clone https://github.com/manzolo/qlab.git "$QLAB_DIR"
    fi

    success "QLab source ready at $QLAB_DIR"
}

# --- Step 3: Create symlink ---

create_symlink() {
    local target="$QLAB_DIR/bin/qlab"

    if [[ "$INSTALL_MODE" == "system" ]]; then
        local link="/usr/local/bin/qlab"
    else
        local link="${HOME}/.local/bin/qlab"
        mkdir -p "${HOME}/.local/bin"
    fi

    if [[ -L "$link" ]]; then
        local current
        current="$(readlink "$link")"
        if [[ "$current" == "$target" ]]; then
            success "Symlink already correct: $link -> $target"
            return 0
        fi
        info "Updating symlink: $link -> $target (was $current)"
        rm "$link"
    elif [[ -e "$link" ]]; then
        die "$link exists and is not a symlink. Please remove it first."
    fi

    if [[ "$INSTALL_MODE" == "system" && $EUID -ne 0 ]]; then
        sudo ln -s "$target" "$link"
    else
        ln -s "$target" "$link"
    fi
    success "Created symlink: $link -> $target"
}

# --- Step 4: Verify ---

verify_installation() {
    info "Verifying installation..."
    local errors=0

    # Check qlab is on PATH
    if command -v qlab &>/dev/null; then
        success "qlab found at $(command -v qlab)"
    else
        warn "qlab not found on PATH."
        if [[ "$INSTALL_MODE" == "user" ]]; then
            warn "Add ~/.local/bin to your PATH:"
            warn '  export PATH="$HOME/.local/bin:$PATH"'
        fi
        errors=$((errors + 1))
    fi

    # Check runtime dependencies
    for cmd in "${RUNTIME_DEPS[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            success "$cmd found"
        else
            warn "$cmd not found"
            errors=$((errors + 1))
        fi
    done

    # KVM check (informational)
    if [[ -w /dev/kvm ]]; then
        success "KVM is available"
    else
        warn "KVM is not available (VMs will use software emulation - much slower)"
    fi

    return 0
}

# --- Next steps ---

print_next_steps() {
    echo ""
    echo "${BOLD}Installation complete!${RESET}"
    echo ""
    echo "  Get started:"
    echo "    mkdir my-lab && cd my-lab"
    echo "    qlab init"
    echo "    qlab install hello-lab"
    echo "    qlab run hello-lab"
    echo ""
    if [[ "$INSTALL_MODE" == "user" ]] && ! command -v qlab &>/dev/null; then
        echo "${YELLOW}  Note: add ~/.local/bin to your PATH:${RESET}"
        echo '    export PATH="$HOME/.local/bin:$PATH"'
        echo ""
    fi
}

# --- Usage ---

usage() {
    cat <<EOF
QLab Installer

Usage:
  ./install.sh [options]
  curl -fsSL https://raw.githubusercontent.com/manzolo/qlab/main/install.sh | bash

Options:
  --skip-deps   Skip dependency installation
  --help        Show this help message
EOF
}

# --- Main ---

main() {
    local skip_deps=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-deps) skip_deps=true; shift ;;
            --help|-h)   usage; exit 0 ;;
            *)           die "Unknown option: $1. Use --help for usage." ;;
        esac
    done

    print_banner
    check_bash_version
    detect_os
    check_root_or_sudo
    detect_repo_context

    info "Install mode: $INSTALL_MODE | OS: $OS_ID | In repo: $IN_REPO"
    echo ""

    # Step 1: Dependencies
    if [[ "$skip_deps" == "false" ]]; then
        install_dependencies
        echo ""
    else
        info "Skipping dependency installation (--skip-deps)"
        echo ""
    fi

    # Step 2: Ensure source
    ensure_qlab_source
    echo ""

    # Step 3: Symlink
    create_symlink
    echo ""

    # Step 4: Verify
    verify_installation
    echo ""

    # Done
    print_next_steps
}

main "$@"
