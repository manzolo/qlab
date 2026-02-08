# hello-lab

A basic QEMU/KVM lab that boots a virtual machine using cloud-init.

## Objectives

- Understand how QEMU boots a virtual machine
- Learn how cloud-init provisions users and configures a VM
- Practice interacting with a VM via serial console (nographic mode)
- Understand overlay disks (copy-on-write) for reproducible labs

## How It Works

1. **Cloud image**: Downloads a minimal Ubuntu cloud image (~250MB)
2. **Cloud-init**: Creates `user-data` and `meta-data` for automatic user provisioning
3. **ISO generation**: Packs cloud-init files into a small ISO (cidata)
4. **Overlay disk**: Creates a COW disk on top of the base image (original stays untouched)
5. **QEMU boot**: Starts the VM with serial console

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

## Serial Console

The VM runs in nographic mode (text-only serial console).

- **Exit QEMU:** Press `Ctrl+A` then `X`
- **QEMU monitor:** Press `Ctrl+A` then `C` (type `quit` to exit)

## Resetting

To start fresh, delete the overlay disk:

```bash
rm .qlab/plugins/hello-lab/lab/hello-lab-disk.qcow2
qlab run hello-lab
```

Or reset the entire workspace:

```bash
qlab reset
```
