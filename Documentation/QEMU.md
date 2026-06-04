# QEMU

Praxis uses QEMU in several ways. All targets build on `build/praxis.iso` and
`build/praxis.qcow2`.

| Target | What it does |
|--------|-------------|
| `make qemu` | Boot the live ISO in a QEMU window |
| `make qemu-install` | Boot the live ISO with the QEMU disk attached for manual install |
| `make qemu-chroot` | Stage the QEMU disk and enter an interactive `praxis-chroot` |
| `make qemu-full` | Stage the QEMU disk fully non-interactively (no chroot prompt) |
| `make qemu-installed` | Boot the staged QEMU disk with UEFI firmware |
| `make smoke` | Headless boot; waits for the `praxis#` prompt |

## Fast Path — Automated Disk Setup

The quickest way to get a running installed QEMU system:

```bash
make iso
make qemu-full
make qemu-installed
```

`make qemu-full` wipes `build/praxis.qcow2`, partitions and formats it, runs
`praxis-install`, builds the initramfs, writes the boot config, and exits. No
interactive prompt. `make qemu-installed` then boots the result with UEFI.

## Live ISO Boot

```bash
make iso
make qemu
```

## Manual Install Test Loop

Boot the live ISO with the QEMU disk attached:

```bash
make iso
make qemu-install
```

Inside the live environment:

```bash
preflight
lsblk

# Partition, format, and mount:
praxis-disk /dev/vda /mnt/praxis

# Deploy rootfs:
praxis-install --hostname praxisvm /mnt/praxis

# Build initramfs:
mkinitrd /mnt/praxis

# Configure target (set passwd, etc.):
praxis-chroot /mnt/praxis

# Verify:
targetcheck /mnt/praxis

sync
umount /mnt/praxis/boot
umount /mnt/praxis
```

Shut down or exit the VM, then boot the installed disk:

```bash
make qemu-installed
```

## Interactive Chroot Setup

Stage the disk and drop into a `praxis-chroot` to inspect or configure:

```bash
make iso
make qemu-chroot
```

This recreates `build/praxis.qcow2`, partitions and formats it, runs
`praxis-install`, builds the initramfs, then opens an interactive
`praxis-chroot`. Exit the chroot when done. The boot config is written
automatically after you exit.

```bash
make qemu-installed
```

## Desktop Test Targets

Build and boot a desktop profile non-interactively:

```bash
make qemu-full DESKTOP=xfce
make qemu-installed
```

Shorthand targets:

```bash
make qemu-full-xfce
make qemu-full-plasma
make qemu-full-gnome
make qemu-full-mate
make qemu-full-lxqt
make qemu-full-i3
make qemu-full-openbox
make qemu-full-budgie
```

Desktop targets install the selected profile plus the essentials bundle, write
boot metadata, and leave the disk ready for `make qemu-installed`. Installed
desktop targets autostart the desktop session on boot.

The installed-disk target uses `virtio-gpu` by default so that Wayland
compositors can access a DRM device. Override with `QEMU_VGA=std` if needed.

## Headless Smoke Boot

```bash
make smoke
```

## Terminal-Only Fallback

```bash
QEMU_UI=nographic make qemu
```

## Notes

- `make qemu-installed` calls `repair-qemu-esp.sh` on every boot to ensure
  `BOOTX64.EFI` and `limine.conf` are present on the ESP. The kernel and
  initramfs are placed on the ESP by `mkinitrd` during `qemu-chroot` or
  `qemu-full` — not by the repair script.
- `make qemu-full` always wipes and recreates `build/praxis.qcow2`. To keep
  an existing disk, run `make qemu-installed` directly.
- The QEMU disk artifact is at `build/praxis.qcow2`. Delete it to start fresh.
- Inside the live image, docs are at `/usr/share/doc/praxis/`.
