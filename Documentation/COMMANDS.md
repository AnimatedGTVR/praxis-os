# Praxis Commands

## Install Stages

```bash
praxis-disk /dev/vda /mnt/praxis        # partition, format, and mount (or use fdisk manually)
praxis-install --hostname <name> /mnt/praxis  # stage 1: deploy rootfs + write all config
mkinitrd /mnt/praxis                    # stage 2: build initramfs + copy kernel to /boot/praxis/
praxis-chroot /mnt/praxis               # stage 3: configure inside target (passwd, etc.)
targetcheck /mnt/praxis                 # verify all stages complete
targetcheck --strict /mnt/praxis        # require v2 audit evidence
```

Each stage gates on the previous. Skipping a stage causes the next to fail.

`praxis-install` writes fstab, machine-id, locale defaults, initramfs policy,
Limine config, BOOTX64.EFI, and systemd-boot entries automatically. Review
and override any of these before running `mkinitrd`.

## Live Toolkit

```bash
preflight [<target>]
praxis-status
praxis-disk-report
praxis-netcheck
praxis-support
praxis-recover <target>
praxis-choice list
praxis-choice emit --kernel <name> --init <name> [--bundle <name>]
praxis-choice validate /mnt/praxis/etc/praxis/system.choice
praxis-choice boot-entry /mnt/praxis/etc/praxis/system.choice
praxis-contract export /mnt/praxis > praxis.contract
praxis-contract inspect praxis.contract
praxis-contract verify praxis.contract /mnt/praxis
praxis-manifest list
praxis-manifest show base-system
praxis-manifest verify base-system /mnt/praxis
praxis-provenance /mnt/praxis
praxis-provenance verify /mnt/praxis
targetcheck --strict /mnt/praxis
praxis-postinstall <target>
praxis-seed list
praxis-seed show <name>
praxis-seed [--dry-run] [--seed <file|name>] <target>
praxis-sv list
praxis-sv status [--root <target>]
praxis-sv enable [--root <target>] <name>
praxis-sv disable [--root <target>] <name>
```

## Kernel Profiles

```bash
make kernel PROFILE=stock
make kernel PROFILE=tiny
make kernel PROFILE=hardened
make check-init-profiles
```

Kernel profile fragments live in `kernel/profiles/` and are staged into
`/usr/share/praxis/kernel/profiles/` for inspection.
Fragments use explicit `CONFIG_NAME=y`, `CONFIG_NAME=m`, or `CONFIG_NAME=n`
lines. Bare symbols are rejected.

Init profiles live in `config/choices/init/` and declare `RDINIT`,
`REQUIRED_FILES`, and `REQUIRED_DIRS`.

## Branding

```bash
praxis-fetch
praxis-fetch --text
fastfetch
```

## Packages

```bash
praxis-packages list
praxis-packages show desktop <name>
praxis-packages show bundle <name>
praxis-desktop list
```

## Native Package Manager

```bash
praxis-pkg sync
praxis-pkg list [repo]
praxis-pkg info <id>
praxis-pkg search <term>
praxis-pkg install <id> [<id>...]
praxis-pkg install-local --root /mnt/praxis package.prx
praxis-pkg remove <id> [<id>...]
praxis-pkg repos
praxis-pkg validate-pkginfo PKGINFO
praxis-pkg validate-index INDEX.gz
praxis-pkg inspect package.prx
```

Package identifiers use reverse-domain notation: `dev.praxis.neovim`,
`org.mozilla.firefox`.

## Docs

```bash
praxis-help
praxis-help install
praxis-help qemu
praxis-help commands
praxis-help packages
praxis-help docs
praxis-help first-boot
praxis-help troubleshooting
```

Local docs: `/usr/share/doc/praxis/`
