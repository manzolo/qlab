#!/usr/bin/env bash
# hello-lab install script

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
echo "  [hello-lab] Created lab/ directory for runtime data."
echo "  [hello-lab] Installation complete."
