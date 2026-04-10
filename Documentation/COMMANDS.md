# Praxis Commands

Praxis ships a small shell-first command set in the live image.

## Quick Start

```bash
praxis-help
praxis-status
praxis-preflight
praxis-help install
praxis-help qemu
praxis-help commands
praxis-help packages
praxis-help first-boot
praxis-help troubleshooting
```

## Branding and System Info

```bash
praxis-fetch
praxis-fetch --text
fastfetch
```

## Install Commands

```bash
praxis-install --hostname praxisbox /mnt/praxis
praxis-install --hostname praxisbox --desktop xfce --bundle internet /mnt/praxis
praxis-dev-install /mnt/praxis-dev
praxis-target-check /mnt/praxis
praxis-postinstall /mnt/praxis
```

## Package and Desktop Commands

```bash
praxis-packages list
praxis-packages show desktop xfce
praxis-packages show bundle developer
praxis-packages install --target /mnt/praxis --desktop xfce --bundle developer
praxis-desktop list
praxis-desktop start xfce
```

## Live Toolkit

```bash
praxis-status
praxis-preflight
praxis-disk-report
praxis-netcheck
praxis-support
```

- `praxis-status` prints the current Praxis live-system summary.
- `praxis-preflight` checks whether the live environment is ready for install work.
- `praxis-disk-report` shows the current block-device layout.
- `praxis-netcheck` prints interface and route info and runs a quick ping test.
- `praxis-support` creates a compressed support bundle in `/tmp`.
- `praxis-postinstall` prints the next steps after a target install.

## Useful Base Tools

```bash
lsblk
blkid
fdisk /dev/sda
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt/praxis
mount /dev/sda1 /mnt/praxis/boot
```

## Local Docs

The live image and installed target keep local docs here:

```text
/usr/share/doc/praxis
```

Available docs:

- `README.md`
- `INSTALL.md`
- `QEMU.md`
- `COMMANDS.md`
- `PACKAGES.md`
- `FIRST-BOOT.md`
- `TROUBLESHOOTING.md`
