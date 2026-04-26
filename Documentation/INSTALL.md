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

Write `/mnt/praxis/etc/fstab` yourself. Minimum:

```text
UUID=<root-uuid>  /      ext4  defaults  0  1
UUID=<boot-uuid>  /boot  vfat  defaults  0  2
```

`mkinitrd` will not run without a fstab in the target.

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
exit
```

`praxis-chroot` stamps `install-stage: chroot` on clean exit. `targetcheck` will refuse to pass if you skip this step.

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
options rdinit=/init praxis.live=0 loglevel=3
```

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

Fails if chroot was skipped, kernel or initramfs is missing, boot entries are absent, or fstab was not written.

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
