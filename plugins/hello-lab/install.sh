#!/usr/bin/env bash
# hello-lab install script

set -euo pipefail

echo ""
echo "  [hello-lab] Installing..."
echo ""
echo "  This plugin demonstrates how to boot a minimal VM using QEMU"
echo "  with cloud-init for automatic user provisioning."
echo ""
echo "  What you will learn:"
echo "    - How QEMU boots a virtual machine"
echo "    - How cloud-init configures a VM on first boot"
echo "    - How to interact with a VM via serial console"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [hello-lab] Installation complete."
echo "  Run with: qlab run hello-lab"
