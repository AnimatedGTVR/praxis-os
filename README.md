# Praxis

Praxis is a base Linux distro you can build on.

It is not a themed remix of another distro. The point is to own the stack, the
boot path, the root filesystem, and the install experience.

Praxis is shell-first by design:

- a live terminal environment
- a real install command
- local documentation in the image
- clear tooling for build, boot, install, and verification

The project goal is simple: make the system easy to inspect, easy to install,
and easy to understand without hiding how it works.

## Current Status

This repository is now an early first-version scaffold:

- boot and initramfs layout
- rootfs staging with a bundled live userspace
- live environment entrypoint with local docs and install tooling
- install commands for mounted targets
- desktop profiles, install bundles, and extra package selection at install time
- Praxis shell branding with a system-wide Fastfetch profile and ASCII art
- built-in live toolkit for status, preflight, disk, network, and support reporting
- local documentation available from `praxis-help`
- ISO and QEMU workflows
- build and sanity-check scripts

Praxis still owns its own live image and install path. The current first-version
package layer uses `pacman` repositories so Praxis can already install real
desktop environments and software bundles while the distro matures.

## Repository Layout

- `boot/`: boot configuration and init entrypoint
- `config/`: distro metadata, manifests, and live-tool definitions
- `Documentation/`: install steps and operator notes
- `installer/`: live-environment shell tools
- `kernel/`: Praxis kernel ownership notes and future kernel artifacts
- `rootfs/`: base filesystem skeleton staged into initramfs
- `scripts/`: build, run, and validation helpers
- `docs/`: architecture notes and roadmap

## Commands

```bash
make help
make iso
make qemu
make qemu-install
make qemu-installed
make smoke
make check
```

- `make iso` stages the live rootfs, packages the initramfs, and emits `build/praxis.iso`.
- `make qemu` boots the latest ISO in a real QEMU window.
- `make qemu-install` boots the ISO with a writable QEMU disk attached for install testing.
- `make qemu-installed` boots the installed Praxis QEMU disk with UEFI firmware.
- `make smoke` boots the ISO headlessly and verifies Praxis reaches the `praxis#` shell prompt.
- `make check` validates shell syntax and stages the rootfs in a temporary directory.

## Recommended Workflow

If you want the fastest realistic local loop, use:

```bash
make check
make smoke
make qemu-install
```

That sequence proves three different things:

- `make check` catches shell and staging regressions
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
praxis-help first-boot
praxis-help troubleshooting
```

The live toolkit also includes:

```bash
praxis-status
praxis-preflight
praxis-disk-report
praxis-netcheck
praxis-support
praxis-postinstall /mnt/praxis
praxis-packages list
praxis-desktop list
```

Inside the live Praxis shell, the main install flow is:

```bash
praxis-install --hostname praxisbox --desktop xfce --bundle internet /mnt/praxis
```

Mount the target root at `/mnt/praxis` and the EFI system partition at `/mnt/praxis/boot` first.

To inspect the available install profiles:

```bash
praxis-packages list
praxis-packages show desktop xfce
praxis-packages show bundle developer
```

You can combine a desktop profile, one or more bundles, and direct package names:

```bash
praxis-install \
  --hostname praxisbox \
  --desktop xfce \
  --bundle essentials \
  --bundle developer \
  --packages firefox,vlc \
  /mnt/praxis
```

For fast developer installs:

```bash
praxis-dev-install /mnt/praxis-dev
```

Praxis writes:

- `boot/praxis/vmlinuz`
- `boot/praxis/initramfs.cpio.gz`
- `boot/loader/entries/praxis.conf` or `praxis-dev.conf`
- `etc/fstab`
- `etc/hostname`
- `etc/hosts`
- `etc/praxis/install`
- `boot/loader/loader.conf`
- `boot/praxis/README.txt`

The installed target keeps the hostname you choose at install time and the Praxis Fastfetch profile, so `praxis-fetch` works after install too.

If `/boot` is the mounted EFI system partition and `bootctl` is available, Praxis will also try to install systemd-boot automatically without touching EFI variables.

To inspect a target after install:

```bash
praxis-target-check /mnt/praxis
```

That validator now checks the required install artifacts and the boot metadata together, so it is worth running before every reboot after a fresh install test.

Full manual install steps live in [`Documentation/INSTALL.md`](/home/animated/Praxis/Documentation/INSTALL.md).
QEMU-specific test loops live in [`Documentation/QEMU.md`](/home/animated/Praxis/Documentation/QEMU.md).
Command reference lives in [`Documentation/COMMANDS.md`](/home/animated/Praxis/Documentation/COMMANDS.md).
Package and desktop profile notes live in [`Documentation/PACKAGES.md`](/home/animated/Praxis/Documentation/PACKAGES.md).
First boot notes live in [`Documentation/FIRST-BOOT.md`](/home/animated/Praxis/Documentation/FIRST-BOOT.md).
Troubleshooting notes live in [`Documentation/TROUBLESHOOTING.md`](/home/animated/Praxis/Documentation/TROUBLESHOOTING.md).

## Philosophy

Praxis follows a clear shell-first model:

- boot into a real live environment
- keep the install path explicit
- ship local docs with the image
- favor readable tooling over hidden layers
- let the distro grow without turning it into a black box
