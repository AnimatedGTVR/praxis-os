# Praxis Commands

## Install Stages

```bash
praxis-disk /dev/vda /mnt/praxis        # partition, format, and mount (or use fdisk manually)
praxis-install --hostname <name> /mnt/praxis  # stage 1: deploy rootfs + write all config
mkinitrd /mnt/praxis                    # stage 2: build initramfs + copy kernel to /boot/praxis/
praxis-chroot /mnt/praxis               # stage 3: configure inside target (passwd, etc.)
targetcheck /mnt/praxis                 # verify all stages complete
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
praxis-postinstall <target>
```

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
praxis-pkg remove <id> [<id>...]
praxis-pkg repos
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
praxis-help pax
praxis-help first-boot
praxis-help troubleshooting
```

Local docs: `/usr/share/doc/praxis/`
