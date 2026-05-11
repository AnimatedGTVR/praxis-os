# Installing Praxis

No wizard. No partitioner. No defaults. You do each step yourself.

## Boot

Build the ISO and boot it:

```bash
make qemu-install
```

The live environment drops to a shell. No prompt. No menu.

## Partition

```bash
lsblk
fdisk /dev/vda
```

Required layout: one EFI system partition (512M), one root partition.

```text
g        new GPT partition table
n 1      first partition, +512M
t 1      type: 1 (EFI System)
n 2      second partition, remaining space
w        write
```

## Format

```bash
mkfs.vfat -F32 -n BOOT /dev/vda1
mkfs.ext4 -L ROOT /dev/vda2
```

## Mount

```bash
mount /dev/vda2 /mnt/praxis
mkdir -p /mnt/praxis/boot
mount /dev/vda1 /mnt/praxis/boot
```

The EFI partition must be mounted at `<target>/boot` before you install.

## Stage 1: Deploy rootfs

```bash
praxis-install --hostname <name> /mnt/praxis
```

Copies the live rootfs to the target. Requires `--hostname`. Requires both partitions mounted and `/boot` to be vfat. Stamps `install-stage: rootfs`.

## Write fstab

Get UUIDs:

```bash
blkid
```

Write `/mnt/praxis/etc/fstab` yourself. Device paths and labels are not enough;
Praxis requires UUID mounts for both `/` and `/boot`.

```text
UUID=<root-uuid>  /      ext4  defaults  0  1
UUID=<boot-uuid>  /boot  vfat  defaults  0  2
```

`mkinitrd` will not run unless the target fstab mounts both `/` and `/boot` by
UUID.

## Write initramfs policy

Write `/mnt/praxis/etc/praxis/initramfs.conf` yourself:

```text
INITRAMFS_FORMAT=newc
INITRAMFS_COMPRESSION=gzip
INITRAMFS_OWNER=manual
INITRAMFS_ROOT=disk
```

`mkinitrd` refuses to run unless this policy file exists and matches the
supported initramfs format. `INITRAMFS_ROOT=disk` builds a small initramfs that
mounts the real root filesystem from `root=UUID=...`; use `target` only when
you intentionally want the whole target packed into the initramfs.

## Stage 2: Build initramfs

```bash
mkinitrd /mnt/praxis
```

Packs the target rootfs into a cpio initramfs and copies the kernel. Requires stage 1 and a written fstab. Stamps `install-stage: initrd`.

## Stage 3: Configure inside the target

```bash
praxis-chroot /mnt/praxis
```

Binds `/proc`, `/sys`, `/dev`, `/run` and drops you into a shell inside the target. Do at minimum:

```sh
passwd
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf
head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > /etc/machine-id
exit
```

`praxis-chroot` stamps `install-stage: chroot` on clean exit. `targetcheck` will refuse to pass if you skip this step, leave `/etc/localtime` missing, leave `/etc/locale.conf` missing, or leave `/etc/machine-id` missing or invalid.

## Write boot entries

After chroot exits, write the bootloader configuration manually.

Create directories:

```bash
mkdir -p /mnt/praxis/boot/loader/entries
```

Write `/mnt/praxis/boot/loader/loader.conf`:

```text
default praxis
timeout 4
```

Write `/mnt/praxis/boot/loader/entries/praxis.conf`:

```text
title   Praxis
linux   /praxis/vmlinuz
initrd  /praxis/initramfs.cpio.gz
options root=UUID=<root-uuid> rdinit=/init praxis.live=0 loglevel=3
```

The boot entry must name the root filesystem by UUID and must include
`rdinit=/init` and `praxis.live=0`. The `root=UUID=...` value must exactly
match the root UUID in `/mnt/praxis/etc/fstab`.

Install a bootloader. With `bootctl`:

```bash
bootctl --esp-path=/mnt/praxis/boot install
```

Or copy the Limine EFI fallback:

```bash
mkdir -p /mnt/praxis/boot/EFI/BOOT
cp /usr/share/praxis/boot/BOOTX64.EFI /mnt/praxis/boot/EFI/BOOT/BOOTX64.EFI
```

If using Limine, write `/mnt/praxis/boot/limine.conf` as well.

## Verify

```bash
targetcheck /mnt/praxis
```

Fails if chroot was skipped, kernel or initramfs is missing, boot entries are absent, fstab lacks UUID mounts, the boot root UUID does not match fstab, boot options are incomplete, initramfs policy is missing, localtime is missing, locale configuration is missing, or machine-id is invalid.

## Unmount and reboot

```bash
sync
umount /mnt/praxis/boot
umount /mnt/praxis
```

In QEMU:

```bash
make qemu-installed
```
