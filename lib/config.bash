#!/usr/bin/env bash
# QLab - Configuration management

declare -A CONFIG

load_config() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        warn "Config file not found: $file"
        return 1
    fi

    while IFS='=' read -r key value; do
        # Skip comments and blank lines
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        CONFIG["$key"]="$value"
    done < "$file"
}

get_config() {
    local key="$1"
    local default="${2:-}"
    echo "${CONFIG[$key]:-$default}"
}
