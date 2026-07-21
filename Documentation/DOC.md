# Praxis Docs

Single-file reference. Covers install, QEMU workflows, commands, packages,
and troubleshooting.

---

## What Praxis Is

Praxis is a shell-first Linux distro with a clear live environment, a direct
install path, local docs in the image, and a runtime toolset that stays close
to the system instead of hiding it.

Praxis is meant to be readable, installable, easy to inspect, and easy to
extend. It is not trying to be a giant installer UI or a heavily abstracted
desktop remix.

## Current Status

Praxis currently includes:

- a live ISO build flow
- a shell-first live environment
- a real install command (`praxis-install`)
- desktop profiles and install bundles
- a native package format and repository (`praxis-pkg`, `.prx`)
- a branded fetch display (`praxis-fetch`)
- local docs available inside the live image and installed target
- QEMU boot, install, and smoke-test workflows

## Repository Layout

```
boot/           boot and init configuration
config/         distro metadata, manifests, package maps
Documentation/  operator docs (this directory)
docs/           architecture notes, roadmap, wiki pages
installer/      live-environment commands
rootfs/         base filesystem skeleton
scripts/        build, boot, and validation helpers
```

---

## Build and QEMU Workflow

```bash
make help            # list all targets
make iso             # build build/praxis.iso
make qemu            # boot the live ISO in QEMU
make qemu-install    # boot live ISO with QEMU disk attached (manual install)
make qemu-chroot     # stage QEMU disk and enter interactive praxis-chroot
make qemu-full       # stage QEMU disk fully non-interactively
make qemu-installed  # boot the staged QEMU disk with UEFI firmware
make smoke           # headless boot, wait for praxis# prompt
make check           # validate shell syntax and rootfs staging
```

### Fast Path

```bash
make iso
make qemu-full
make qemu-installed
```

`make qemu-full` wipes the disk, partitions it, installs the rootfs, builds
the initramfs, and writes the boot config — no interactive prompt. Then
`make qemu-installed` boots it.

### Manual Install Test Loop

```bash
make iso
make qemu-install
```

Inside the live VM:

```bash
praxis-disk /dev/vda /mnt/praxis
praxis-install --hostname praxisvm /mnt/praxis
mkinitrd /mnt/praxis
praxis-chroot /mnt/praxis    # passwd; exit
targetcheck /mnt/praxis
sync && umount /mnt/praxis/boot && umount /mnt/praxis
```

Then:

```bash
make qemu-installed
```

---

## Live Environment

Praxis boots into a shell-first live environment. You get a terminal, the
Praxis tools, and local docs in `/usr/share/doc/praxis`.

Useful commands:

```bash
praxis-help
praxis-status
preflight
praxis-disk-report
praxis-netcheck
praxis-support
praxis-fetch
```

---

## Installing Praxis

### Partition and Format

#### Option A — praxis-disk

```bash
praxis-disk /dev/vda /mnt/praxis
```

Wipes the disk, creates a GPT (512M EFI + rest root), formats both partitions,
and mounts everything. Supports `--boot-size` and `--dry-run`.

#### Option B — Manual

```bash
fdisk /dev/vda           # g, n 1 +512M, t 1, n 2, w
mkfs.vfat -F32 -n BOOT /dev/vda1
mkfs.ext4 -L ROOT /dev/vda2
mkdir -p /mnt/praxis
mount /dev/vda2 /mnt/praxis
mkdir -p /mnt/praxis/boot
mount /dev/vda1 /mnt/praxis/boot
```

### Stage 1 — Deploy Rootfs

```bash
praxis-install --hostname <name> /mnt/praxis
```

Copies the live rootfs to the target. Written automatically:

- `/etc/fstab` — UUID mounts from live mounts
- `/etc/machine-id` — random 32-hex-char ID
- `/etc/locale.conf` — `LANG=en_US.UTF-8`
- `/etc/localtime` — UTC symlink
- `/etc/praxis/initramfs.conf` — initramfs policy
- `/boot/EFI/BOOT/BOOTX64.EFI` — Limine UEFI binary
- `/boot/limine.conf`, `/boot/limine/limine.conf`, `/boot/EFI/BOOT/limine.conf`
- `/boot/loader/loader.conf`, `/boot/loader/entries/praxis.conf`

Stamps `install-stage: rootfs`.

Override timezone/locale if needed before stage 2:

```bash
ln -sf /usr/share/zoneinfo/Region/City /mnt/praxis/etc/localtime
printf 'LANG=xx_XX.UTF-8\n' > /mnt/praxis/etc/locale.conf
```

### Stage 2 — Build Initramfs

```bash
mkinitrd /mnt/praxis
```

Copies the kernel to `/boot/praxis/vmlinuz` and builds the initramfs at
`/boot/praxis/initramfs.cpio.gz`. Requires stage 1 and UUID fstab entries
for both `/` and `/boot`. Stamps `install-stage: initrd`.

### Stage 3 — Configure Target

```bash
praxis-chroot /mnt/praxis
```

Binds `/proc`, `/sys`, `/dev`, `/run` and drops into a shell inside the target.
At minimum:

```sh
passwd
exit
```

Stamps `install-stage: chroot` on clean exit.

### Verify

```bash
targetcheck /mnt/praxis
```

### Finish

```bash
sync
umount /mnt/praxis/boot
umount /mnt/praxis
```

---

## Commands

### Install

```bash
praxis-disk /dev/vda /mnt/praxis
praxis-install --hostname <name> /mnt/praxis
mkinitrd /mnt/praxis
praxis-chroot /mnt/praxis
targetcheck /mnt/praxis
```

### Live Toolkit

```bash
preflight [<target>]
praxis-status
praxis-disk-report
praxis-netcheck
praxis-support
praxis-postinstall <target>
```

### Packages

Desktop environments and bundles are installed through pacman, driven by
`config/packages/*.list`. Praxis vendors pacman for this rather than
repackaging every upstream desktop project.

```bash
praxis-packages list
praxis-packages show desktop <name>
praxis-packages show bundle <name>
praxis-desktop list
praxis-desktop start <name>
```

### Native Package Manager

`praxis-pkg` is a separate, lightweight tool for Praxis's own `.prx`
packages — not a replacement for the pacman-driven desktop/bundle path
above. See `docs/pkg-format.md` for the full format and repo status.

```bash
praxis-pkg sync
praxis-pkg list [repo]
praxis-pkg info <id>
praxis-pkg search <term>
praxis-pkg install <id> [<id>...]
praxis-pkg install-local --root /mnt/praxis package.prx
praxis-pkg remove <id>
praxis-pkg repos
```

Package identifiers: `dev.praxis.neovim`, `org.mozilla.firefox`.

### Docs

```bash
praxis-help install
praxis-help qemu
praxis-help commands
praxis-help packages
praxis-help troubleshooting
praxis-help first-boot
praxis-help changelog
```

---

## Packages and Desktop Profiles

### List Available

```bash
praxis-packages list
praxis-packages list desktops
praxis-packages list bundles
praxis-packages show desktop xfce
praxis-packages show bundle developer
```

### Desktop Profiles

`gnome`, `plasma`, `xfce`, `budgie`, `mate`, `lxqt`, `i3`, `openbox`

```bash
praxis-install --hostname praxisvm --desktop xfce /mnt/praxis
```

### Bundles

`developer`, `internet`, `media`, `essentials`, `fonts`

```bash
praxis-install --hostname praxisvm --bundle developer /mnt/praxis
```

### Combined

```bash
praxis-install \
  --hostname praxisvm \
  --desktop xfce \
  --bundle essentials \
  --bundle developer \
  /mnt/praxis
```

---

## First Boot

```bash
hostname
praxis-fetch
praxis-status
praxis-netcheck
ls /boot/praxis
cat /boot/loader/entries/praxis.conf
```

---

## Troubleshooting

### Quick Checks

```bash
preflight
praxis-status
praxis-support
```

### Target Check Fails

```bash
targetcheck /mnt/praxis
```

Read every line. Fix whatever is reported missing or wrong.

### Limine: "[config file not found]"

Limine searches these paths on the ESP:

- `/boot/limine/limine.conf`
- `/boot/limine.conf`
- `/limine/limine.conf`
- `/limine.conf`
- `/EFI/BOOT/limine.conf` (UEFI)

`praxis-install` writes all of these. In QEMU, `repair-qemu-esp.sh` also writes
them on every `make qemu-installed`. If still missing, re-run `make qemu-full`.

### Limine: Kernel Not Found

```
PANIC: linux: Failed to open kernel with path 'boot():/praxis/vmlinuz'
```

`/praxis/vmlinuz` on the ESP is placed by `mkinitrd`, not by the repair script.

- **QEMU:** run `make qemu-full` then `make qemu-installed`.
- **Real hardware:** re-run `mkinitrd /mnt/praxis` with the ESP still mounted.

### QEMU: make qemu-installed Shows Kernel Missing

`make qemu-installed` only calls `repair-qemu-esp.sh` — it does not stage the
disk. You must run `make qemu-full` (or `make qemu-chroot`) first to get the
kernel onto the ESP.

---

## Praxis Package Repository

### Identifiers

All packages use reverse-domain identifiers:

```
dev.praxis.neovim
org.mozilla.firefox
org.videolan.vlc
```

`dev.praxis.*` is the Praxis native namespace. Bare names like `firefox` are
rejected by the tool.

### praxis-pkg

```bash
praxis-pkg sync
praxis-pkg list
praxis-pkg info dev.praxis.neovim
praxis-pkg search editor
praxis-pkg install dev.praxis.neovim org.mozilla.firefox
praxis-pkg install-local --root /mnt/praxis package.prx
praxis-pkg remove dev.praxis.neovim
praxis-pkg repos
```

### Repository Configuration

`/etc/praxis/repos.conf` — ini-style blocks with `name`, `url`, `enabled`,
`signed`. Three repos ship by default: `praxis-core`, `praxis-extra`,
`praxis-community`.

### Package Format

`.prx` — gzip-compressed tar with a `PKGINFO` metadata file and a `data/`
filesystem tree. Full spec: `docs/pkg-format.md`.

---

## Local Docs Path

Inside the live image and installed target:

```
/usr/share/doc/praxis/
  README.md
  INSTALL.md
  QEMU.md
  COMMANDS.md
  PACKAGES.md
  FIRST-BOOT.md
  TROUBLESHOOTING.md
  DOC.md
  CHANGELOG.md
```
