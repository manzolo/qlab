#!/usr/bin/env bash
# QLab - Plugin registry management

REGISTRY_CACHE_DIR="${WORKSPACE_DIR:-.qlab}/cache"
REGISTRY_CACHE_FILE="$REGISTRY_CACHE_DIR/registry.json"

# Load registry data from configured URL (local file or remote)
# Sets REGISTRY_DATA variable with the JSON content
load_registry() {
    local registry_url
    registry_url=$(get_config REGISTRY_URL "file://./registry/index.json")

    mkdir -p "$REGISTRY_CACHE_DIR"

    if [[ "$registry_url" == file://* ]]; then
        # Local file registry
        local file_path="${registry_url#file://}"
        # Resolve relative paths from QLAB_ROOT
        if [[ "$file_path" == ./* ]]; then
            file_path="$QLAB_ROOT/${file_path#./}"
        fi
        if [[ ! -f "$file_path" ]]; then
            error "Local registry file not found: $file_path"
            return 1
        fi
        REGISTRY_DATA=$(jq '.' "$file_path") || {
            error "Failed to parse registry file: $file_path"
            return 1
        }
    elif [[ "$registry_url" == https://* ]]; then
        # Remote registry
        check_dependency curl || return 1
        local tmp_file
        tmp_file=$(mktemp) || {
            error "Failed to create temporary file."
            return 1
        }
        if curl -sL -o "$tmp_file" "$registry_url" 2>/dev/null; then
            if jq '.' "$tmp_file" >/dev/null 2>&1; then
                REGISTRY_DATA=$(jq '.' "$tmp_file")
                # Update cache
                cp "$tmp_file" "$REGISTRY_CACHE_FILE"
            else
                error "Invalid JSON from registry URL: $registry_url"
                rm -f "$tmp_file"
                # Try cache fallback
                if [[ -f "$REGISTRY_CACHE_FILE" ]]; then
                    warn "Using cached registry data."
                    REGISTRY_DATA=$(jq '.' "$REGISTRY_CACHE_FILE")
                else
                    return 1
                fi
            fi
            rm -f "$tmp_file"
        else
            warn "Failed to fetch registry from $registry_url"
            # Fallback to cache
            if [[ -f "$REGISTRY_CACHE_FILE" ]]; then
                warn "Using cached registry data."
                REGISTRY_DATA=$(jq '.' "$REGISTRY_CACHE_FILE")
            else
                error "No cached registry available. Check your connection."
                return 1
            fi
        fi
    else
        error "Unsupported registry URL scheme: $registry_url"
        return 1
    fi
}

# Search plugins by keyword in name or description
search_plugins() {
    local keyword="$1"
    load_registry || return 1
    echo "$REGISTRY_DATA" | jq -r --arg kw "$keyword" \
        '.[] | select(.name | test($kw; "i")) // select(.description | test($kw; "i")) | "\(.name) (v\(.version)) - \(.description)"'
}

# Get metadata for a specific plugin by name
get_plugin_metadata() {
    local name="$1"
    load_registry || return 1
    echo "$REGISTRY_DATA" | jq -r --arg name "$name" '.[] | select(.name == $name)'
}

# Get the git URL for a plugin from the registry
get_plugin_git_url() {
    local name="$1"
    load_registry || return 1
    echo "$REGISTRY_DATA" | jq -r --arg name "$name" '.[] | select(.name == $name) | .git_url // empty'
}

# Get the version for a plugin from the registry
get_plugin_version() {
    local name="$1"
    load_registry || return 1
    echo "$REGISTRY_DATA" | jq -r --arg name "$name" '.[] | select(.name == $name) | .version // empty'
}

# List all available plugins in the registry
list_available_plugins() {
    load_registry || return 1
    local count
    count=$(echo "$REGISTRY_DATA" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        echo "  (no plugins in registry)"
        return 0
    fi

    echo "$REGISTRY_DATA" | jq -r '.[] | "  \(.name) (v\(.version)) - \(.description)"'
}
