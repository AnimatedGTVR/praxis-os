# Praxis Changelog

## v1 — Initial Release

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
