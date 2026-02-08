#!/usr/bin/env bash
# QLab - Plugin management

PLUGIN_DIR="${WORKSPACE_DIR:-".qlab"}/plugins"

install_plugin() {
    local name_or_path="$1"

    # If it's a local directory path
    if [[ -d "$name_or_path" ]]; then
        local pname
        pname="$(basename "$name_or_path")"
        validate_plugin_name "$pname" || return 1

        if [[ ! -f "$name_or_path/plugin.conf" ]]; then
            error "No plugin.conf found in '$name_or_path'. Not a valid plugin."
            return 1
        fi

        mkdir -p "$PLUGIN_DIR"
        cp -r "$name_or_path" "$PLUGIN_DIR/$pname"
        success "Installed plugin '$pname' from local path."

        # Run install.sh if present
        if [[ -f "$PLUGIN_DIR/$pname/install.sh" ]]; then
            info "Running install script for '$pname'..."
            (cd "$PLUGIN_DIR/$pname" && bash install.sh)
        fi
        return 0
    fi

    # If it looks like a git URL
    if [[ "$name_or_path" == *.git || "$name_or_path" == https://* ]]; then
        local pname
        pname="$(basename "$name_or_path" .git)"
        # Strip qlab-plugin- prefix if present
        pname="${pname#qlab-plugin-}"
        validate_plugin_name "$pname" || return 1

        mkdir -p "$PLUGIN_DIR"
        info "Cloning plugin '$pname' from $name_or_path..."
        git clone "$name_or_path" "$PLUGIN_DIR/$pname" || {
            error "Failed to clone '$name_or_path'"
            return 1
        }

        if [[ ! -f "$PLUGIN_DIR/$pname/plugin.conf" ]]; then
            error "No plugin.conf found after clone. Not a valid plugin."
            rm -rf "${PLUGIN_DIR:?}/$pname"
            return 1
        fi

        # Run install.sh if present
        if [[ -f "$PLUGIN_DIR/$pname/install.sh" ]]; then
            info "Running install script for '$pname'..."
            (cd "$PLUGIN_DIR/$pname" && bash install.sh)
        fi

        success "Installed plugin '$pname' from git."
        return 0
    fi

    # Otherwise treat as a plugin name — look in bundled plugins first
    local pname="$name_or_path"
    validate_plugin_name "$pname" || return 1

    # Check bundled plugins directory
    if [[ -d "$QLAB_ROOT/plugins/$pname" ]]; then
        if [[ ! -f "$QLAB_ROOT/plugins/$pname/plugin.conf" ]]; then
            error "Bundled plugin '$pname' has no plugin.conf."
            return 1
        fi
        mkdir -p "$PLUGIN_DIR"
        cp -r "$QLAB_ROOT/plugins/$pname" "$PLUGIN_DIR/$pname"
        success "Installed bundled plugin '$pname'."

        if [[ -f "$PLUGIN_DIR/$pname/install.sh" ]]; then
            info "Running install script for '$pname'..."
            (cd "$PLUGIN_DIR/$pname" && bash install.sh)
        fi
        return 0
    fi

    error "Plugin '$pname' not found. Provide a path, git URL, or valid plugin name."
    return 1
}

run_plugin() {
    local pname="$1"
    validate_plugin_name "$pname" || return 1

    if [[ ! -d "$PLUGIN_DIR/$pname" ]]; then
        error "Plugin '$pname' is not installed. Run 'qlab install $pname' first."
        return 1
    fi

    if [[ ! -f "$PLUGIN_DIR/$pname/run.sh" ]]; then
        error "Plugin '$pname' has no run.sh script."
        return 1
    fi

    info "Running plugin '$pname'..."
    echo ""
    # Export absolute WORKSPACE_DIR so the plugin uses the project-level workspace
    local abs_workspace
    abs_workspace="$(cd "$WORKSPACE_DIR" && pwd)"
    (cd "$PLUGIN_DIR/$pname" && WORKSPACE_DIR="$abs_workspace" bash run.sh)
}

uninstall_plugin() {
    local pname="$1"
    validate_plugin_name "$pname" || return 1

    if [[ ! -d "$PLUGIN_DIR/$pname" ]]; then
        error "Plugin '$pname' is not installed."
        return 1
    fi

    warn "This will remove plugin '$pname' and all its data."
    if ! confirm_yesno "Uninstall plugin '$pname'?"; then
        info "Uninstall cancelled."
        return 0
    fi

    # Stop VM if running (exact match)
    if is_vm_running "$pname" 2>/dev/null; then
        info "Stopping running VM for '$pname'..."
        stop_vm "$pname"
    fi

    # Stop any sub-VMs matching <pname>-*
    for pidfile in "$STATE_DIR/${pname}"-*.pid; do
        [[ -f "$pidfile" ]] || continue
        local sub_vm
        sub_vm="$(basename "$pidfile" .pid)"
        if is_vm_running "$sub_vm" 2>/dev/null; then
            info "Stopping sub-VM '$sub_vm'..."
            stop_vm "$sub_vm"
        fi
    done

    rm -rf "${PLUGIN_DIR:?}/$pname"
    success "Uninstalled plugin '$pname'."
}

list_installed_plugins() {
    if [[ ! -d "$PLUGIN_DIR" ]]; then
        echo "  (no plugins directory — run 'qlab init' first)"
        return 0
    fi

    local count=0
    for pdir in "$PLUGIN_DIR"/*/; do
        [[ -d "$pdir" ]] || continue
        local pname
        pname="$(basename "$pdir")"
        local pdesc="(no description)"
        local pver="?"
        if [[ -f "$pdir/plugin.conf" ]]; then
            pdesc=$(jq -r '.description // "(no description)"' "$pdir/plugin.conf" 2>/dev/null || echo "(no description)")
            pver=$(jq -r '.version // "?"' "$pdir/plugin.conf" 2>/dev/null || echo "?")
        fi
        echo "  $pname (v$pver) - $pdesc"
        count=$((count + 1))
    done

    if [[ $count -eq 0 ]]; then
        echo "  (none installed)"
    fi
}
