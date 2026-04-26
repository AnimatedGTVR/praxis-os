# Praxis Docs

This file is the single-file Praxis documentation pass.

It pulls the main install, runtime, package, QEMU, troubleshooting, and PAX
notes into one place so you can read or ship the docs as one document.

## What Praxis Is

Praxis is a shell-first Linux distro with a clear live environment, a direct
install path, local docs in the image, and a runtime toolset that stays close
to the system instead of hiding it.

Praxis is meant to be:

- readable
- installable
- easy to inspect
- easy to extend

It is not trying to be a giant installer UI or a heavily abstracted desktop
remix.

## Current Status

Praxis currently includes:

- a live ISO build flow
- a shell-first live environment
- a real install command
- desktop profiles and install bundles
- package selection during install
- a branded fastfetch setup with `praxis-fetch`
- local docs available inside the live image and installed target
- QEMU boot, install, and smoke-test workflows

The current package layer uses `pacman` repositories so Praxis can already
install real desktop environments and software bundles while the distro grows.

## Repository Layout

- `boot/` for boot and init entry logic
- `config/` for distro metadata, manifests, and package maps
- `Documentation/` for operator docs
- `docs/` for architecture notes, roadmap, and wiki pages
- `installer/` for live-environment commands
- `rootfs/` for the base filesystem skeleton
- `scripts/` for build, boot, and validation helpers
- `pax/` for the Praxis domain-specific language

## Build and QEMU Workflow

Main commands:

```bash
make help
make iso
make qemu
make qemu-install
make qemu-installed
make smoke
make check
```

What they do:

- `make iso` builds `build/praxis.iso`
- `make qemu` boots the live ISO in QEMU
- `make qemu-install` boots the ISO with a writable VM disk attached
- `make qemu-installed` boots the installed VM disk with UEFI firmware
- `make smoke` runs a headless boot and waits for the `praxis#` prompt
- `make check` validates shell syntax and rootfs staging

Recommended local loop:

```bash
make check
make smoke
make qemu-install
```

Then after the install inside the VM:

```bash
make qemu-installed
```

If you want terminal-only QEMU logs:

```bash
QEMU_UI=nographic make qemu
```

## Live Environment

Praxis boots into a shell-first live environment.

You get:

- a terminal
- the Praxis tools
- local docs in `/usr/share/doc/praxis`
- a direct install path

Useful commands:

```bash
praxis-help
praxis-status
praxis-preflight
praxis-disk-report
praxis-netcheck
praxis-support
praxis-fetch
praxis-fetch --text
```

The live toolkit is meant to help you inspect the system before you write it.

## Installing Praxis

Praxis does not partition disks for you. You choose the layout, mount the
target, and then run the install command.

From the live shell, a common starting flow is:

```bash
praxis-help
praxis-preflight
praxis-help install
lsblk
praxis-disk-report
```

### Example Disk Layout

This example assumes:

- `/dev/sda1` is the EFI system partition
- `/dev/sda2` is the Praxis root partition

### Format and Mount

```bash
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2

mkdir -p /mnt/praxis
mount /dev/sda2 /mnt/praxis
mkdir -p /mnt/praxis/boot
mount /dev/sda1 /mnt/praxis/boot
```

Praxis expects the EFI system partition to be mounted at:

```text
/mnt/praxis/boot
```

### Inspect Available Desktop Profiles and Bundles

```bash
praxis-packages list
praxis-packages show desktop xfce
praxis-packages show bundle developer
```

### Install Praxis

Base example:

```bash
praxis-install --hostname praxisbox --desktop xfce --bundle internet /mnt/praxis
```

More complete example:

```bash
praxis-install \
  --hostname praxisbox \
  --desktop xfce \
  --bundle essentials \
  --bundle developer \
  --packages firefox,vlc \
  /mnt/praxis
```

Current desktop profiles:

- `gnome`
- `plasma`
- `xfce`
- `budgie`
- `mate`
- `lxqt`
- `i3`
- `openbox`

Current bundles:

- `developer`
- `internet`
- `media`
- `essentials`
- `fonts`

### What Praxis Writes

The install writes:

- `/mnt/praxis/boot/praxis/vmlinuz`
- `/mnt/praxis/boot/praxis/initramfs.cpio.gz`
- `/mnt/praxis/boot/loader/entries/praxis.conf`
- `/mnt/praxis/etc/fstab`
- `/mnt/praxis/etc/praxis/install`
- `/mnt/praxis/etc/hostname`
- `/mnt/praxis/etc/hosts`
- `/mnt/praxis/boot/loader/loader.conf`
- `/mnt/praxis/boot/praxis/README.txt`

If `bootctl` is available and the EFI system partition is mounted correctly,
Praxis also attempts a systemd-boot install.

### Verify the Target

Use:

```bash
praxis-target-check /mnt/praxis
```

Useful manual checks:

```bash
cat /mnt/praxis/etc/fstab
cat /mnt/praxis/etc/hostname
cat /mnt/praxis/boot/loader/entries/praxis.conf
ls /mnt/praxis/boot/praxis
cat /mnt/praxis/etc/praxis/packages.selected
```

### Finish

```bash
praxis-postinstall /mnt/praxis
sync
umount /mnt/praxis/boot
umount /mnt/praxis
```

Then boot the installed target:

```bash
make qemu-installed
```

### Developer Install

For a fast directory-target developer install:

```bash
praxis-dev-install /mnt/praxis-dev
```

## Commands

### Quick Start

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

### Branding and System Info

```bash
praxis-fetch
praxis-fetch --text
fastfetch
```

### Install Commands

```bash
praxis-install --hostname praxisbox /mnt/praxis
praxis-install --hostname praxisbox --desktop xfce --bundle internet /mnt/praxis
praxis-dev-install /mnt/praxis-dev
praxis-target-check /mnt/praxis
praxis-postinstall /mnt/praxis
```

### Package and Desktop Commands

```bash
praxis-packages list
praxis-packages show desktop xfce
praxis-packages show bundle developer
praxis-packages install --target /mnt/praxis --desktop xfce --bundle developer
praxis-desktop list
praxis-desktop start xfce
```

### Live Toolkit

```bash
praxis-status
praxis-preflight
praxis-disk-report
praxis-netcheck
praxis-support
```

## Packages and Desktop Profiles

Praxis can stage extra software into the installed image while you install it.

The install flow stays Praxis-owned:

- you boot the Praxis live image
- you mount the target yourself
- you run `praxis-install`
- Praxis folds the selected packages back into the installed image

List available items:

```bash
praxis-packages list
praxis-packages list desktops
praxis-packages list bundles
```

Inspect a single profile:

```bash
praxis-packages show desktop xfce
praxis-packages show bundle developer
```

Install direct package names:

```bash
praxis-install --hostname praxisbox --packages firefox,vlc,git /mnt/praxis
```

Apply packages to an already-mounted target:

```bash
praxis-packages install --target /mnt/praxis --desktop xfce --bundle internet
praxis-install --hostname praxisbox /mnt/praxis
```

## First Boot

After Praxis boots from the installed disk for the first time, verify the base
system before customizing it.

Useful first checks:

```bash
hostname
praxis-fetch
praxis-status
```

Confirm:

- the hostname matches the install choice
- the kernel and release info look correct
- the Praxis prompt and branding are present
- the package layer looks ready in `praxis-status`

If you installed a desktop profile or bundles:

```bash
cat /etc/praxis/packages.selected
praxis-desktop list
```

Check networking:

```bash
praxis-netcheck
```

Inspect installed boot data:

```bash
ls /boot/praxis
cat /boot/loader/loader.conf
```

## Troubleshooting

Quick commands:

```bash
praxis-preflight
praxis-status
praxis-disk-report
praxis-netcheck
praxis-support
```

### Target Root Is Not Mounted

```bash
findmnt /mnt/praxis
findmnt /mnt/praxis/boot
```

Mount the root at `/mnt/praxis` and the EFI system partition at
`/mnt/praxis/boot`.

### Target Check Fails

```bash
praxis-target-check /mnt/praxis
```

That checks the kernel, initramfs, loader entry, hostname, fstab, and install
metadata.

### Package Or Desktop Install Fails

```bash
praxis-packages list
cat /mnt/praxis/etc/praxis/packages.selected
tail -n 50 /mnt/praxis/var/log/pacman.log
```

Common reasons:

- no working network in the live environment
- invalid package or desktop profile name

### Network Looks Broken

```bash
praxis-netcheck
ip -o link show
ip -o -4 addr show
```

### Need Logs Or A Report

```bash
praxis-support
```

That writes a compressed bundle to `/tmp`.

## PAX

PAX is the planned domain-specific language for Praxis.

It is not a general programming language. It is meant for:

- package installation
- source compilation workflows
- system configuration
- hardware checks
- boot and desktop setup
- installer logic

PAX file roles:

- `.pax` for general config
- `.pkg.pax` for package definitions
- `.profile.pax` for install presets
- `.boot.pax` for boot logic

### Required Header

Every PAX file starts with:

```text
[.Praxis Config - <file purpose or config name> .praxis.pax./]
```

Example:

```text
[.Praxis Config - packageinstall-config .praxis.pax./]
```

### Core Style

- blocks use `{ }`
- assignment uses `=`
- comparisons use `==`
- comments begin with `#`
- strings use double quotes
- booleans are `true` and `false`
- bare words like `xfce`, `source`, `bad`, and `finished` are symbols

### Example Files

- `pax/examples/packageinstall-config.pax`
- `pax/examples/workstation-config.profile.pax`
- `pax/examples/liveboot-config.boot.pax`
- `pax/examples/core-packages.profile.pax`
- `pax/examples/source-pkg.pkg.pax`
- `pax/examples/ricing-desktop.profile.pax`
- `pax/examples/hardware-check.pax`
- `pax/examples/core-system-config.pax`

### PAX Starter Set

Praxis also includes a broader default starter set:

- `core-packages.profile.pax` for common software selection
- `source-pkg.pkg.pax` for source-based package workflows through the Praxis source-pkg path
- `ricing-desktop.profile.pax` for desktop and ricing setup
- `hardware-check.pax` for hardware validation
- `core-system-config.pax` for a general base Praxis config

### Example PAX File

```pax
[.Praxis Config - packageinstall-config .praxis.pax./]

# Define the install target and the desktop that should be enabled.
config "packageinstall-config"
{
    package = "xfce-base/xfce4-meta"
    desktop = xfce
    compile_mode = source
}

# Probe the current machine before the install actions begin.
check hardware

# Stop early if the hardware probe reports a failure.
if hardware.status == bad
{
    print "Hardware failed."
    stop
}

# Run the install workflow using values from the config block.
install package config.package
compile package config.package
enable desktop config.desktop

# Confirm success after the fake installer reports a finished state.
if install.status == finished
{
    print "[XFCE] Installed!"
}
```

### Interpreter

The first interpreter is a small C# console app split into:

- Lexer
- Parser
- AST
- Interpreter

Expected usage when a .NET SDK is present:

```bash
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/packageinstall-config.pax
```

## Local Docs Path

Inside the live image and installed target, Praxis keeps docs in:

```text
/usr/share/doc/praxis
```

That includes:

- `README.md`
- `INSTALL.md`
- `QEMU.md`
- `COMMANDS.md`
- `PACKAGES.md`
- `FIRST-BOOT.md`
- `TROUBLESHOOTING.md`
