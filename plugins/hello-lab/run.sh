#!/usr/bin/env bash
# hello-lab run script

echo "============================================="
echo "  Welcome to hello-lab!"
echo "============================================="
echo ""
echo "  This lab boots a minimal VM using QEMU."
echo "  In the full version, you would see a Linux"
echo "  system booting via serial console."
echo ""

# Source QLAB_ROOT libs if available
if [[ -n "${QLAB_ROOT:-}" ]]; then
    for lib_file in "$QLAB_ROOT"/lib/*.bash; do
        # shellcheck source=/dev/null
        [[ -f "$lib_file" ]] && source "$lib_file"
    done
    start_vm_stub
else
    echo "  (QLAB_ROOT not set — running standalone)"
fi

echo ""
echo "  Lab complete! You've seen how QLab manages"
echo "  plugin lifecycle and VM execution."
echo "============================================="
