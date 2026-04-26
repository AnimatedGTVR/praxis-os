# QEMU

Praxis uses QEMU in three distinct ways:

- `make qemu` opens the ISO in a real QEMU window
- `make qemu-install` opens the ISO with a writable disk attached for install testing
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
