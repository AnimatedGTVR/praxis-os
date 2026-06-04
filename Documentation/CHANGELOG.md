# Praxis Changelog

## v1.5 — Bedrock

Full install flow hardening. All installer commands now work end-to-end.

### Install flow fixes

`praxis-install` now writes everything needed for a bootable system in one step:
- **fstab** — generated from live mount UUIDs via `blkid`
- **machine-id** — random 32-hex-char ID from `/dev/urandom`
- **locale.conf** — defaults to `LANG=en_US.UTF-8`
- **localtime** — symlinked to UTC by default
- **initramfs.conf** — policy file required by `mkinitrd`
- **Limine config** — `/boot/limine.conf` + `/boot/praxis/limine.conf` with correct `root=UUID=`
- **systemd-boot entries** — `/boot/loader/` with correct kernel options
- **BOOTX64.EFI** — copied to `/boot/EFI/BOOT/`

### New `praxis-disk` command

`praxis-disk <device> <target>` handles the full disk setup sequence:
wipe → GPT partition → `mkfs.vfat` (boot) → `mkfs.ext4` (root) → `mkdir -p` → mount.
Supports `--boot-size`, `--dry-run`.

### `mkfs.ext4` in standard ISO

BusyBox's `mke2fs` is now wrapped as `mkfs.ext4` in the standard live ISO.
The wrapper strips the unsupported `-t` flag automatically, so `mkfs.ext4 -L ROOT /dev/vda2` works.

### `praxis-install` subcommand syntax

`praxis-install --hostname <name> deploy rootfs <target>` is now accepted
alongside the standard `praxis-install --hostname <name> <target>` form.

### `praxis-postinstall` — repair mode

`praxis-postinstall <target>` now actively fixes missing files (machine-id, locale.conf,
localtime, initramfs.conf, fstab) rather than only reporting status.

### `praxis-chroot` — cleanup safety

Cleanup trap is now registered before bind mounts so partial mount failures
are always cleaned up on exit.

### `praxis-fetch` — built-in display

`praxis-fetch` now has a built-in fetch display (logo + sysinfo side-by-side)
when `fastfetch` is not installed, as in the standard live ISO.

### Other fixes

- `targetcheck` usage string corrected
- `nano` removed from `live-tools.manifest` (not a BusyBox applet; `vi` is available)
- `preflight` checks `mkfs.ext4` and `praxis-disk` as optional tools
- Version: 1.5.0, codename Bedrock

---

## v1.2 — Stratum

Package repo and PAX identifier hardening release.

### Praxis Package Repository

Praxis now has a native package system alongside the pacman bootstrap layer.

**Package format:** `.prx` — gzip-compressed tar containing `PKGINFO` metadata
and a `data/` filesystem tree. Full spec in `docs/pkg-format.md`.

**Index format:** `INDEX.gz` — tab-delimited, one package per line:
`id\tversion\tdesc\tfilename`

**Repository configuration:** `/etc/praxis/repos.conf` — ini-style blocks with
`name`, `url`, `enabled`, and `signed` fields. Three repos ship by default:
`praxis-core`, `praxis-extra`, `praxis-community`.

**`praxis-pkg` tool:**
- `praxis-pkg sync` — fetch and update all repo indexes
- `praxis-pkg list [repo]` — list available packages
- `praxis-pkg info <id>` — show package metadata
- `praxis-pkg search <term>` — search names and descriptions
- `praxis-pkg install <id> [<id>...]` — install packages
- `praxis-pkg remove <id> [<id>...]` — remove packages
- `praxis-pkg repos` — list configured repos

### PAX — Reverse-Domain Package Identifiers

Package identifiers in PAX are now reverse-domain dotted paths, not strings.
This is a breaking change from any files using `install package "name"`.

**Old (rejected):**
```pax
install package "firefox"
install package "neovim"
```

**New (required):**
```pax
install package org.mozilla.firefox
install package dev.praxis.neovim
```

**Namespace conventions:**
- `dev.praxis.*` — Praxis native packages
- `org.*`, `com.*`, `io.*`, `net.*` — upstream/community packages

**Bundles remain quoted strings** since they are Praxis-internal groupings:
```pax
install bundle "essentials"
install bundle "developer"
```

**PAX interpreter** updated: unresolved dotted paths now self-stringify as
their literal text rather than resolving to `null`. This is what makes
`install package dev.praxis.firefox` work — the path doesn't match any runtime
state object so it becomes the string `"dev.praxis.firefox"`.

**All example files updated** to use reverse-domain identifiers.

---

## v1.1 — Axiom

PAX introduction release. The language, the spec, and the interpreter.

### PAX Language — v1.1

PAX is Praxis's domain-specific language for system intent. It is not a
general scripting language. It has no closures, no generics, no dynamic
dispatch. You write every step. Nothing runs unless you wrote it.

**All files use `.pax`.** Sub-extensions (`.pkg.pax`, `.profile.pax`,
`.boot.pax`) are removed. Every PAX file is simply `name.pax`.

**New types:**
- `int` — 64-bit signed integer literals
- `list` — `[ a, b, "c" ]`
- String interpolation — `"installing {config.package}"`

**New binding forms:**
- `let name = value` — immutable binding
- `var name = value` — mutable binding
- `define NAME = value` — file-level constant, visible everywhere

**New conditions:** `!=`, `not`, `and`, `or`

**New statements:** `each item in list { }`, `include "file.pax"`, `on error { }`

**New actions (30+):**
- Output: `log`, `warn`, `fail`
- Control: `require`, `assert`
- Install: `install bundle`, `install desktop`
- System: `set hostname`, `set locale`, `set timezone`, `set keymap`, `set password for`
- Files: `write`, `append`, `mkdir`, `copy`, `move`, `symlink`, `delete`, `fetch`
- Execution: `exec`
- Mount: `mount`, `umount`
- Disk: `format`
- Services: `service enable/start/stop/disable/restart`
- Users: `user create`, `user add-group`, `user set-password`
- Groups: `group create`
- Network: `net enable`, `net configure`
- Boot: `bootloader install`, `bootloader entry`, `initramfs build`

**New block kinds:** `disk`, `partition`, `source`, `network`, `user`, `service`

**New runtime state objects:** `disk.*`, `exec.*`, `fetch.*`, `file.*`,
`net.*`, `user.*`, `initramfs.*`

**New example files:**
- `full-install.pax` — complete install: disk, packages, users, boot
- `disk-setup.pax` — explicit disk partition and format flow
- `user-setup.pax` — user and group creation
- `service-config.pax` — service enable and configuration

**Interpreter (C#):** handles all v1.1 language features in simulation mode.
Actions print what they would do; state objects update accordingly. Use it to
validate PAX files before running them on a real target.

---

## v1 — Bedrock

### Install Chain

Complete rewrite of the install path. No wizard. No automation beyond what is strictly required.

**Stages:**

1. `praxis-install --hostname <name> <target>` — deploys rootfs, stamps `rootfs`
2. User writes `/etc/fstab` manually from `blkid` output
3. `mkinitrd <target>` — builds initramfs and copies kernel, stamps `initrd`
4. `praxis-chroot <target>` — binds virtual filesystems and drops into target shell; user configures passwd, localtime, locale; stamps `chroot` on clean exit
5. User writes boot entries manually (`loader.conf`, `entries/praxis.conf`, EFI)
6. `targetcheck <target>` — verifies all required artifacts and that chroot was completed

Each stage gates on the previous. Skipping any step causes the next command to refuse to run.

### Removed Tools

- `praxis-genfstab` — deleted. User writes fstab manually.
- `praxis-bootsetup` — deleted. User writes boot entries manually.

### Renamed Tools

- `praxis-preflight` → `preflight`
- `praxis-mkinitrd` → `mkinitrd`
- `praxis-target-check` → `targetcheck`

### New Tools

- `praxis-chroot` — arch-chroot equivalent. Binds proc/sys/dev/run, enters target shell, stamps install stage on exit.

### Boot

- Live environment drops directly to `/bin/sh` via setsid. No hostname setup, no branding on boot, no guided prompt.
- `motd` reduced to `Praxis`.

### targetcheck

- Now reads and displays `install-stage`.
- Hard fails if stage is not `chroot` — enforces that `praxis-chroot` was run before declaring the install complete.
- Warns on missing `/etc/localtime` and `/etc/locale.conf`.

### mkinitrd

- Stage check updated: requires `rootfs` (not `fstab`, since `praxis-genfstab` is gone).
- Requires `/etc/fstab` to exist in the target before proceeding.

### Documentation

- `INSTALL.md` — rewritten for the full manual flow.
- `COMMANDS.md` — updated for new tool names and stage list.
- `README.md` — updated philosophy, install block, and tool references.
- `praxis-help` — updated in-system stage list and tool names.
