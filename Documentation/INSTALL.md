# Installing Praxis

Praxis is shell-first. It does not partition disks for you, but it does ship the
install command, the target validator, and local docs in the live image.

From the `praxis#` prompt, start with:

```bash
praxis-help
praxis-preflight
praxis-help install
```

If you are testing locally, the fastest full loop is usually:

```bash
cd /home/animated/Praxis
make iso
make qemu-install
```

Install inside the VM, then boot the installed target with:

```bash
make qemu-installed
```

## Build and Boot the ISO

From the repo:

```bash
cd /home/animated/Praxis
make iso
make qemu
```

For headless verification:

```bash
cd /home/animated/Praxis
make smoke
```

For install testing with a writable VM disk attached:

```bash
cd /home/animated/Praxis
make qemu-install
```

## Example Disk Layout

This example assumes:

- `/dev/sda1` is the EFI system partition
- `/dev/sda2` is the Praxis root partition

Adjust the device names to match your machine.

## Partition and Format

Inside the live shell:

```bash
praxis# lsblk
praxis# praxis-disk-report
praxis# fdisk /dev/sda
praxis# mkfs.fat -F 32 /dev/sda1
praxis# mkfs.ext4 /dev/sda2
```

## Mount the Target

```bash
praxis# mkdir -p /mnt/praxis
praxis# mount /dev/sda2 /mnt/praxis
praxis# mkdir -p /mnt/praxis/boot
praxis# mount /dev/sda1 /mnt/praxis/boot
```

Praxis expects the EFI system partition to be mounted at `/mnt/praxis/boot` when you install.

## Inspect Desktop Profiles and Bundles

Before you install, you can inspect the available software sets:

```bash
praxis-packages list
praxis-packages show desktop xfce
praxis-packages show bundle developer
```

## Install Praxis

```bash
praxis# praxis-install --hostname praxisbox --desktop xfce --bundle internet /mnt/praxis
```

That install writes:

- `/mnt/praxis/boot/praxis/vmlinuz`
- `/mnt/praxis/boot/praxis/initramfs.cpio.gz`
- `/mnt/praxis/boot/loader/entries/praxis.conf`
- `/mnt/praxis/etc/fstab`
- `/mnt/praxis/etc/praxis/install`
- `/mnt/praxis/etc/hostname`
- `/mnt/praxis/etc/hosts`
- `/mnt/praxis/boot/loader/loader.conf`
- `/mnt/praxis/boot/praxis/README.txt`

If you want more than the shell-first base image, combine desktop profiles,
bundles, and package names:

```bash
praxis# praxis-install \
  --hostname praxisbox \
  --desktop xfce \
  --bundle essentials \
  --bundle developer \
  --packages firefox,vlc \
  /mnt/praxis
```

Current desktop profiles include:

- `gnome`
- `plasma`
- `xfce`
- `budgie`
- `mate`
- `lxqt`
- `i3`
- `openbox`

Current install bundles include:

- `developer`
- `internet`
- `media`
- `essentials`
- `fonts`

If `bootctl` is available and `/mnt/praxis/boot` is the mounted EFI system partition, Praxis also attempts a systemd-boot install.

The installed target keeps the hostname you set at install time, the Praxis Fastfetch profile, and the `praxis-fetch` command.
It also keeps the local Praxis docs in `/usr/share/doc/praxis`.

## Verify the Target

```bash
praxis# praxis-target-check /mnt/praxis
praxis# cat /mnt/praxis/etc/fstab
praxis# cat /mnt/praxis/etc/hostname
praxis# cat /mnt/praxis/boot/loader/entries/praxis.conf
praxis# ls /mnt/praxis/boot/praxis
praxis# cat /mnt/praxis/etc/praxis/packages.selected
```

`praxis-target-check` is the quickest sanity pass. It verifies the kernel, initramfs, loader entry, loader config, install metadata, and optional boot artifacts before you reboot.

If you want to confirm the branding payload and hostname landed too:

```bash
praxis# ls /mnt/praxis/etc/xdg/fastfetch
```

## Finish

```bash
praxis# praxis-postinstall /mnt/praxis
praxis# sync
praxis# umount /mnt/praxis/boot
praxis# umount /mnt/praxis
```

Reboot, boot the installed entry, and Praxis should come back up as the same shell-first base distro on disk.

In the default VM workflow, that means:

```bash
make qemu-installed
```

## Developer Install

For a fast directory-target developer install:

```bash
praxis# praxis-dev-install /mnt/praxis-dev
```

That path is useful for testing installs quickly without insisting on a mounted target filesystem.

## Package Notes

The first-version Praxis package layer uses `pacman` repositories. Praxis still
keeps its own live image, install command, and target layout, but software and
desktop profiles are installed through `pacman` and then folded back into the
installed Praxis image.
