# QEMU

Praxis uses QEMU in three distinct ways:

- `make qemu` opens the ISO in a real QEMU window
- `make qemu-install` opens the ISO with a writable disk attached for install testing
- `make qemu-chroot` stages the default QEMU disk and enters `praxis-chroot`
- `make qemu-installed` boots the installed disk with UEFI firmware
- `make smoke` keeps the VM headless and waits for the `praxis#` prompt

## Normal Live Boot

```bash
cd /home/animated/Praxis
make iso
make qemu
```

## Install Test Loop

```bash
cd /home/animated/Praxis
make iso
make qemu-install
```

Inside Praxis:

```bash
praxis-help install
praxis-preflight
praxis-packages list
lsblk
fdisk /dev/vda
mkfs.vfat -n PRAXISBOOT /dev/vda1
mke2fs -F -L PRAXISROOT /dev/vda2
mount /dev/vda2 /mnt/praxis
mount /dev/vda1 /mnt/praxis/boot
praxis-fetch
praxis-install --hostname praxisvm /mnt/praxis
praxis-target-check /mnt/praxis
praxis-postinstall /mnt/praxis
```

Then shut the VM down and boot the installed disk:

```bash
make qemu-installed
```

## Fast Chroot Test Loop

For testing, you can let the host prepare the default QEMU disk up to the target
configuration step:

```bash
make iso
make qemu-chroot
```

That target recreates `build/praxis.qcow2`, partitions and formats it, runs
`praxis-install`, writes UUID fstab and initramfs policy, builds the initramfs,
then writes the minimum target-local test configuration and enters
`praxis-chroot`. You can inspect the target or set a password there; exit when
you are done.

After you exit, the helper writes the boot entries, validates the target, and
leaves the disk ready for:

```bash
make qemu-installed
```

## Full Desktop Test Loop

To build a QEMU target with a desktop profile installed and boot it:

```bash
make qemu-full DESKTOP=xfce
```

There are also shorthand targets:

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

The full target installs the selected desktop profile plus the essentials
bundle into `build/praxis.qcow2`, writes the normal boot metadata, skips the
interactive chroot, and boots the installed disk. Installed targets with a
desktop profile autostart the desktop on boot. Budgie starts a Wayland session
via labwc; all other profiles start an X11 session via startx. If the session
exits, Praxis falls back to the shell.

The installed-disk QEMU target uses `virtio-gpu` by default so that Wayland
compositors (labwc) can access a DRM device. Override with `QEMU_VGA=std` if
needed.

## Headless Smoke Boot

```bash
cd /home/animated/Praxis
make smoke
```

## Terminal-Only Fallback

```bash
cd /home/animated/Praxis
QEMU_UI=nographic make qemu
```

`make qemu` is meant to use the VM window. The terminal-only path is only there when you explicitly ask for it.

Inside the VM, local docs are also available at:

```text
/usr/share/doc/praxis
```

The package and desktop profile reference is:

```text
/usr/share/doc/praxis/PACKAGES.md
```

The all-in-one docs file is:

```text
/usr/share/doc/praxis/DOC.md
```

## Default Disk Artifact

`make qemu-install` creates and reuses:

```text
build/praxis.qcow2
```

Delete that file when you want a completely fresh install test.
