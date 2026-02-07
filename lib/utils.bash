#!/usr/bin/env bash
# QLab - Utility functions (colors, prompts, validation)

# Terminal colors (only when stdout is a terminal)
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

info() {
    echo "${BOLD}[INFO]${RESET} $*"
}

warn() {
    echo "${YELLOW}[WARN]${RESET} $*" >&2
}

error() {
    echo "${RED}[ERROR]${RESET} $*" >&2
}

success() {
    echo "${GREEN}[OK]${RESET} $*"
}

confirm_yesno() {
    local prompt="${1:-Continue?}"
    local answer
    read -r -p "${BOLD}${prompt} [Y/n]${RESET} " answer
    case "${answer,,}" in
        ""|y|yes) return 0 ;;
        *)        return 1 ;;
    esac
}

validate_plugin_name() {
    local name="$1"
    if [[ "$name" =~ ^[a-z0-9_-]+$ ]]; then
        return 0
    else
        error "Invalid plugin name '$name'. Use only lowercase letters, digits, hyphens, and underscores."
        return 1
    fi
}

check_dependency() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        error "Required dependency '$cmd' not found. Please install it."
        return 1
    fi
}
