# Praxis

Praxis is a base Linux distro you can build on.

It is not a themed remix of another distro. The point is to own the stack, the
boot path, the root filesystem, and the install experience.

Praxis is shell-first by design:

- boots to a raw shell, no menu, no prompt
- explicit multi-stage install with no automation
- local documentation in the image
- readable tooling for build, boot, install, and verification

The project goal: own the stack without abstraction. Partitioning, fstab,
initramfs, chroot configuration, boot entry — each step is yours.

## Current Status

This repository is now an early first-version scaffold:

- boot and initramfs layout
- rootfs staging with a bundled live userspace
- live environment drops to a raw shell with local docs and install tooling
- explicit staged install: rootfs deploy, fstab, initramfs, chroot, boot entries
- Praxis shell branding with a system-wide Fastfetch profile and ASCII art
- built-in live toolkit for status, preflight, disk, network, and support reporting
- local documentation available from `praxis-help`
- ISO and QEMU workflows
- build and sanity-check scripts
- Praxis-owned kernel build path via `make kernel`
- Praxis-owned static BusyBox userspace via `make userspace`

Praxis now owns the default kernel and base shell/tool userspace artifacts. The
package layer can still use `pacman` repositories when host compatibility tools
are deliberately included, while the distro-native package path matures.

## Repository Layout

- `boot/`: boot configuration and init entrypoint
- `config/`: distro metadata, manifests, and live-tool definitions
- `Documentation/`: install steps and operator notes
- `installer/`: live-environment shell tools
- `kernel/`: Praxis kernel ownership notes and future kernel artifacts
- `kernel/bzImage`: generated Praxis kernel artifact used by the ISO build
- `rootfs/`: base filesystem skeleton staged into initramfs
- `scripts/`: build, run, and validation helpers
- `userspace/`: generated Praxis userspace artifacts
- `docs/`: architecture notes and roadmap

## Commands

```bash
make help
make kernel
make userspace
make iso
make qemu
make qemu-install
make qemu-installed
make smoke
make check
make check-owned
make v1-check
```

- `make kernel` builds `kernel/bzImage` from upstream Linux source.
- `make userspace` builds `userspace/busybox` from upstream BusyBox source.
- `make iso` builds the Praxis kernel and BusyBox userspace if needed, stages the live rootfs, packages the initramfs, and emits `build/praxis.iso`.
- `make qemu` boots the latest ISO in a real QEMU window.
- `make qemu-install` boots the ISO with a writable QEMU disk attached for install testing.
- `make qemu-installed` boots the installed Praxis QEMU disk with UEFI firmware.
- `make smoke` boots the ISO headlessly and verifies Praxis reaches the `praxis#` shell prompt.
- `make check` validates shell syntax and stages the rootfs in a temporary directory.
- `make check-owned` verifies the default rootfs uses the Praxis kernel, static BusyBox, relative BusyBox applet links, and no host package-manager payloads.
- `make v1-check` runs the owned-rootfs check, the full sanity suite, and a headless QEMU smoke boot.

## Recommended Workflow

If you want the fastest realistic local loop, use:

```bash
make check
make check-owned
make smoke
make qemu-install
```

That sequence proves three different things:

- `make check` catches shell and staging regressions
- `make check-owned` catches accidental host artifacts in the default rootfs
- `make smoke` proves Praxis can actually reach the live shell prompt
- `make qemu-install` gives you the full install path with a writable disk attached

After you install inside the VM, boot the resulting target with:

```bash
make qemu-installed
```

If you ever want terminal-only boot logs instead of the QEMU window:

```bash
QEMU_UI=nographic make qemu
```

Inside Praxis, the branded fetch path is:

```bash
praxis-fetch
praxis-fetch --text
```

For the built-in quick-start guide and local documentation:

```bash
praxis-help
praxis-help install
praxis-help qemu
praxis-help commands
praxis-help packages
praxis-help docs
praxis-help pax
praxis-help first-boot
praxis-help troubleshooting
```

The live toolkit also includes:

```bash
praxis-status
lsblk
preflight
praxis-disk-report
praxis-netcheck
praxis-support
praxis-postinstall /mnt/praxis
praxis-packages list
praxis-desktop list
```

The install has no wizard and no automation. Each step is manual:

```bash
# partition, format, mount — your job
fdisk /dev/vda
mkfs.vfat -F32 /dev/vda1
mkfs.ext4 /dev/vda2
mount /dev/vda2 /mnt/praxis
mkdir /mnt/praxis/boot && mount /dev/vda1 /mnt/praxis/boot

# stage 1: deploy rootfs
praxis-install --hostname <name> /mnt/praxis

# write /mnt/praxis/etc/fstab yourself (blkid for UUIDs)

# stage 2: build initramfs + kernel
mkinitrd /mnt/praxis

# stage 3: configure inside the target
praxis-chroot /mnt/praxis
# inside: passwd, localtime symlink, locale.conf, then exit

# write boot entries yourself (loader.conf, entries/praxis.conf, EFI)

# verify
targetcheck /mnt/praxis
```

Each stage gates on the previous one. Skipping a step causes the next command to refuse to run.

For a single-file doc pass, use:

```text
Documentation/DOC.md
```

For Praxis language docs, use:

```text
pax/README.md
pax/spec/PAX.md
```

Praxis installs a Limine removable-UEFI fallback at `boot/EFI/BOOT/BOOTX64.EFI`. If `/boot` is the mounted EFI system partition and `bootctl` is available, Praxis also tries to install systemd-boot automatically without touching EFI variables.

To inspect a target after install:

```bash
targetcheck /mnt/praxis
```

That validator checks the required install artifacts, the boot metadata, and whether the chroot step was completed.

Full manual install steps live in [`Documentation/INSTALL.md`](/home/animated/Praxis/Documentation/INSTALL.md).
QEMU-specific test loops live in [`Documentation/QEMU.md`](/home/animated/Praxis/Documentation/QEMU.md).
Command reference lives in [`Documentation/COMMANDS.md`](/home/animated/Praxis/Documentation/COMMANDS.md).
Package and desktop profile notes live in [`Documentation/PACKAGES.md`](/home/animated/Praxis/Documentation/PACKAGES.md).
First boot notes live in [`Documentation/FIRST-BOOT.md`](/home/animated/Praxis/Documentation/FIRST-BOOT.md).
Troubleshooting notes live in [`Documentation/TROUBLESHOOTING.md`](/home/animated/Praxis/Documentation/TROUBLESHOOTING.md).

## Philosophy

Praxis follows a clear shell-first model:

- boot to a raw shell, no guidance
- keep the install path explicit and manual
- ship local docs with the image
- favor readable tooling over hidden layers
- let the distro grow without turning it into a black box
