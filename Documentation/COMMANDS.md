# Praxis Commands

## Install Stages

```bash
praxis-install --hostname <name> <target>   # stage 1: deploy rootfs
  # write /etc/fstab manually (blkid, editor)
mkinitrd <target>                           # stage 2: build initramfs + kernel
praxis-chroot <target>                      # stage 3: configure inside target
  # write boot entries manually
targetcheck <target>                        # verify
```

Each stage gates on the previous. Skipping a stage causes the next to fail.

## Live Toolkit

```bash
praxis-status
preflight [<target>]
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
