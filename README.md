> [!WARNING]
> **Praxis is back.**
>
> After rethinking my decision to archive Praxis, I've decided to bring the project back with a new vision.
>
> Instead of pursuing its previous direction, Praxis is being rebuilt as a lightweight, minimal Linux distribution inspired by the philosophy of Alpine Linux and Void Linux while maintaining its own identity and goals.
>
> Praxis is currently **experimental** and **not ready for production use**. It may contain incomplete features, bugs, installation failures, boot issues, or data loss risks. Interfaces, commands, package formats, and installation procedures may change between releases without notice.
>
> Praxis is designed for experienced Linux users who want complete control over their system. If you're looking for an automated installer or a beginner-friendly distribution, Praxis is probably not the right choice.
>
> **Use at your own risk, and never install Praxis on hardware containing important data without verified backups.**

# Praxis

Praxis is a minimal Linux distro where you control the system.

It is not a themed remix of another distro. The point is to own the stack, the
boot path, the root filesystem, and the install experience.

Praxis is shell-first by design:

- boots to a raw shell, no menu, no prompt
- explicit multi-stage install with no automation
- explicit kernel, init, desktop, bundle, and package choices
- local documentation in the image
- readable tooling for build, boot, install, and verification

The project goal: own the stack without abstraction. Partitioning, fstab,
initramfs, chroot configuration, boot entry — each step is yours.

Praxis is not for beginners. The live ISO gives you tools, catalogs, and docs.
It does not try to hide the machine from you.

## What's Real Right Now

- a Praxis-owned kernel (`make kernel`, profile-selectable: stock, tiny,
  hardened) and a Praxis-owned static BusyBox userspace (`make userspace`)
- a runit-style supervise tree for PID 1: `boot/init` mounts pseudo
  filesystems, handles the initramfs-to-installed-root switch, then hands off
  to BusyBox `runsvdir` over `/etc/service`. Service definitions live in
  `/etc/sv/<name>/`; `/etc/service/<name>` is a symlink present only when
  enabled. `praxis-sv list`/`status`/`enable`/`disable` manages that
- `s6` as a second, genuinely working init choice — `make s6` builds
  statically-linked skalibs/execline/s6 from source, `PRAXIS_ENABLE_S6=1`
  stages it opt-in. `systemd` is still listed in the init catalog but nothing
  builds it; choosing it is expected to fail
- `praxis-pkg`: a native `.prx` binary package format (reverse-domain IDs,
  gzip-tar archives, tab-delimited repo indexes) with real dependency
  resolution on install and real file removal on uninstall. It's a small
  companion tool for Praxis's own packages, not a replacement for the
  pacman-driven desktop/bundle path — see `docs/pkg-format.md`
- hard choice catalogs (`praxis-choice`), seed ledgers (`praxis-seed`),
  base-system manifests (`praxis-manifest`), build provenance
  (`praxis-provenance`), portable contracts (`praxis-contract`), and a manual
  recovery ledger (`praxis-recover`)
- `make iso` is actually reproducible under `SOURCE_DATE_EPOCH` — two builds
  from the same inputs produce a byte-identical ISO, verified by
  `make check-reproducible`
- a live toolkit (`praxis-status`, `praxis-disk-report`, `praxis-netcheck`,
  `praxis-support`, `praxis-fetch`) and local docs from `praxis-help`
- a layered check suite (`make check`, `make v1-check`, `make v2-check`, and
  the individual `check-*` targets) that's exercised against real QEMU boots,
  not just static checks

Desktop environments and bundles still install through `pacman`
(`config/packages/*.list`, driven by `praxis-packages`) — Praxis vendors
pacman for that job rather than repackaging every upstream desktop project.
See `docs/roadmap.md` for what's shipped, in progress, and explicitly not
happening (PAX, the project's old system-intent language, is gone for good).

## Repository Layout

- `boot/`: boot configuration and the `/init` PID 1 handoff
- `config/`: hard choice catalogs, base-system manifests, package/bundle
  lists, seed ledgers
- `Documentation/`: install steps and operator notes
- `docs/`: architecture notes (`v2.md`), package format (`pkg-format.md`),
  and the roadmap
- `installer/`: live-environment shell tools (`praxis-*`, `mkinitrd`,
  `targetcheck`)
- `kernel/`: kernel config fragments, profiles, and the generated `bzImage`
- `rootfs/`: base filesystem skeleton staged into the initramfs, including
  `etc/sv/` (service definitions) and `etc/service/` (enabled symlinks)
- `scripts/`: build, run, and validation helpers
- `userspace/`: generated BusyBox (and, if built, s6) artifacts

## Commands

```bash
make help
make kernel
make userspace
make s6
make iso
make qemu
make qemu-install
make qemu-installed
make smoke
make check
make check-contract
make check-owned
make check-init-profiles
make check-kernel-profiles
make check-manifests
make check-pkg-format
make check-reproducible
make check-seeds
make check-target-audit
make v1-check
make v2-half-check
make v2-check
```

- `make kernel` builds `kernel/bzImage` from upstream Linux source and records `kernel/PROFILE.applied` plus `kernel/build-info`.
- `make userspace` builds `userspace/busybox` from upstream BusyBox source.
- `make s6` builds a fully static skalibs/execline/s6 toolset into `userspace/s6/` (opt-in; not part of the default rootfs).
- `make iso` builds the Praxis kernel and BusyBox userspace if needed, stages the live rootfs, packages the initramfs, and emits `build/praxis.iso`.
- `make qemu` boots the latest ISO in a real QEMU window.
- `make qemu-install` boots the ISO with a writable QEMU disk attached for install testing.
- `make qemu-installed` boots the installed Praxis QEMU disk with UEFI firmware.
- `make smoke` boots the ISO headlessly and verifies Praxis reaches the `praxis#` shell prompt.
- `make check` validates shell syntax and stages the rootfs in a temporary directory.
- `make check-contract` validates contract export, inspect, and verify behavior.
- `make check-owned` verifies the default rootfs uses the Praxis kernel, static BusyBox, relative BusyBox applet links, and no host package-manager payloads.
- `make check-init-profiles` validates `RDINIT`, required files, and required directories for init choices.
- `make check-kernel-profiles` validates kernel choice/profile wiring.
- `make check-manifests` validates base-system manifests and package catalog lists.
- `make check-pkg-format` validates `.prx` metadata, archive layout, local install, and repository index rules.
- `make check-reproducible` validates build provenance, checksum verification, and that a real double ISO build is byte-identical under `SOURCE_DATE_EPOCH`.
- `make check-seeds` validates Praxis seed ledgers.
- `make check-target-audit` validates `targetcheck --strict` and negative audit fixtures.
- `make v1-check` runs the owned-rootfs check, the full sanity suite, and a headless QEMU smoke boot.
- `make v2-half-check` verifies the Praxis v2-half contract: hard choices, seed ledgers, and v2 docs.
- `make v2-check` verifies most of the Praxis v2 contract, including hard choices, manifests, and recovery ledgers.

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
praxis-help v2
praxis-help first-boot
praxis-help troubleshooting
praxis-help changelog
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
praxis-choice list
praxis-sv status
praxis-pkg list
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

# write /mnt/praxis/etc/fstab yourself
# UUID mounts for both / and /boot are required

# write /mnt/praxis/etc/praxis/initramfs.conf yourself
# required: newc format, gzip compression, manual owner

# stage 2: build initramfs + kernel
mkinitrd /mnt/praxis

# stage 3: configure inside the target
praxis-chroot /mnt/praxis
# inside: passwd, localtime symlink, locale.conf, machine-id, then exit
# targetcheck fails if localtime, locale.conf, or machine-id is missing

# write boot entries yourself (loader.conf, entries/praxis.conf, EFI)
# praxis.conf options must include root=UUID=..., rdinit=/init, praxis.live=0
# root=UUID must match the / UUID in fstab

# verify
targetcheck /mnt/praxis
```

Each stage gates on the previous one. Skipping a step causes the next command to refuse to run.

If something goes wrong partway through, `praxis-recover /mnt/praxis` runs
`targetcheck` and prints a manual recovery ledger for whatever's missing —
it's inspect-only and never modifies the target itself.

For a single-file doc pass, use:

```text
Documentation/DOC.md
```

Praxis installs a Limine removable-UEFI fallback at `boot/EFI/BOOT/BOOTX64.EFI`. If `/boot` is the mounted EFI system partition and `bootctl` is available, Praxis also tries to install systemd-boot automatically without touching EFI variables.

To inspect a target after install:

```bash
targetcheck /mnt/praxis
```

That validator checks the required install artifacts, the boot metadata, and whether the chroot step was completed.

Full manual install steps live in [`Documentation/INSTALL.md`](Documentation/INSTALL.md).
QEMU-specific test loops live in [`Documentation/QEMU.md`](Documentation/QEMU.md).
Command reference lives in [`Documentation/COMMANDS.md`](Documentation/COMMANDS.md).
Package and desktop profile notes live in [`Documentation/PACKAGES.md`](Documentation/PACKAGES.md).
First boot notes live in [`Documentation/FIRST-BOOT.md`](Documentation/FIRST-BOOT.md).
Troubleshooting notes live in [`Documentation/TROUBLESHOOTING.md`](Documentation/TROUBLESHOOTING.md).
The v2 contract (choice catalogs, init/kernel rules, package/provenance/contract rules) lives in [`docs/v2.md`](docs/v2.md).
Where the project is headed lives in [`docs/roadmap.md`](docs/roadmap.md).

## Philosophy

Praxis follows a clear shell-first model:

- boot to a raw shell, no guidance
- keep the install path explicit and manual
- ship local docs with the image
- favor readable tooling over hidden layers
- let the distro grow without turning it into a black box
