# Installing Praxis

No wizard. No automounter. You choose the layout, mount the target, and run
the install commands.

## Boot the Live Environment

In QEMU:

```bash
make iso
make qemu-install
```

On real hardware: write `build/praxis.iso` to a USB drive and boot it.

## Partition and Format

### Option A — praxis-disk (recommended)

```bash
praxis-disk /dev/vda /mnt/praxis
```

Wipes the disk, creates a GPT with a 512M EFI system partition and a root
partition, formats both (`vfat` + `ext4`), and mounts everything at
`/mnt/praxis` and `/mnt/praxis/boot`. Supports `--boot-size <size>` and
`--dry-run`.

### Option B — Manual

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

Format and mount:

```bash
mkfs.vfat -F32 -n BOOT /dev/vda1
mkfs.ext4 -L ROOT /dev/vda2

mkdir -p /mnt/praxis
mount /dev/vda2 /mnt/praxis
mkdir -p /mnt/praxis/boot
mount /dev/vda1 /mnt/praxis/boot
```

The EFI partition must be mounted at `<target>/boot` before you install.

## Stage 1: Deploy Rootfs

```bash
praxis-install --hostname <name> /mnt/praxis
```

Copies the live rootfs to the target. Requires `--hostname`. Requires both
partitions mounted with `/boot` as vfat. Stamps `install-stage: rootfs`.

`praxis-install` writes the following automatically — you can review and
override any of them afterward:

| File | Content |
|------|---------|
| `/etc/fstab` | UUID mounts for `/` and `/boot` from the live mounts |
| `/etc/machine-id` | Random 32-hex-char ID |
| `/etc/locale.conf` | `LANG=en_US.UTF-8` |
| `/etc/localtime` | Symlink to `/usr/share/zoneinfo/UTC` |
| `/etc/praxis/initramfs.conf` | Initramfs policy required by `mkinitrd` |
| `/boot/EFI/BOOT/BOOTX64.EFI` | Limine UEFI fallback binary |
| `/boot/limine.conf` + `/boot/limine/limine.conf` + `/boot/EFI/BOOT/limine.conf` | Limine bootloader config |
| `/boot/loader/loader.conf` + `/boot/loader/entries/praxis.conf` | systemd-boot entries |

## Override Defaults (Optional)

**Timezone** (if not UTC):

```bash
ln -sf /usr/share/zoneinfo/Region/City /mnt/praxis/etc/localtime
```

**Locale** (if not en_US.UTF-8):

```bash
printf 'LANG=xx_XX.UTF-8\n' > /mnt/praxis/etc/locale.conf
```

**Verify fstab** — auto-generated from live mounts, should be correct:

```bash
cat /mnt/praxis/etc/fstab
blkid
```

## Stage 2: Build Initramfs

```bash
mkinitrd /mnt/praxis
```

Packs the initramfs and copies the kernel to `/boot/praxis/`. Requires stage 1
and a UUID fstab for both `/` and `/boot`. Stamps `install-stage: initrd`.

## Stage 3: Configure Inside the Target

```bash
praxis-chroot /mnt/praxis
```

Binds `/proc`, `/sys`, `/dev`, `/run` and drops you into a shell in the target.
At minimum, set a root password:

```sh
passwd
exit
```

`praxis-chroot` stamps `install-stage: chroot` on clean exit.

## Verify

```bash
targetcheck /mnt/praxis
```

Fails if the chroot stage, kernel, initramfs, fstab UUIDs, boot entries, Limine
config, locale, localtime, or machine-id is absent or invalid.

## Unmount and Reboot

```bash
sync
umount /mnt/praxis/boot
umount /mnt/praxis
```

In QEMU:

```bash
make qemu-installed
```

On real hardware: remove the live USB and reboot.
