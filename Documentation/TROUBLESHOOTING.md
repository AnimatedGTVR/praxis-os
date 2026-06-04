# Troubleshooting

Praxis stays shell-first, so the quickest fix path is usually to inspect the
current state directly.

## Quick Commands

```bash
preflight
praxis-status
praxis-disk-report
praxis-netcheck
praxis-support
```

## Common Install Problems

### Target Root Is Not Mounted

```bash
findmnt /mnt/praxis
findmnt /mnt/praxis/boot
```

Mount the root partition at `/mnt/praxis` and the EFI system partition at
`/mnt/praxis/boot`. Or use `praxis-disk /dev/vda /mnt/praxis` to do
everything in one step.

### Target Check Fails

```bash
targetcheck /mnt/praxis
```

That checks the kernel, initramfs, initramfs policy, Limine config, loader
entry, hostname, UUID fstab, root UUID consistency, localtime, locale.conf,
machine-id, boot options, and install metadata. Read the output line by line
and fix whatever shows as missing or wrong.

### Package or Desktop Install Fails

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

In QEMU, networking problems are usually VM configuration problems rather than
Praxis problems.

### Need Logs or a Report

```bash
praxis-support
```

Writes a compressed bundle to `/tmp` with kernel messages, block-device state,
network info, release files, and Praxis metadata.

## Boot Problems

### Limine Shows "[config file not found]"

Limine found the bootloader binary but could not find `limine.conf`. It
searches the following paths on the boot volume (ESP):

- `/boot/limine/limine.conf` (highest priority)
- `/boot/limine.conf`
- `/limine/limine.conf`
- `/limine.conf`
- `/EFI/BOOT/limine.conf` (UEFI only — checked relative to the EFI binary)

`praxis-install` and `mkinitrd` write config to all of these automatically.
If config is still missing, re-run `praxis-install` or `targetcheck` to see
what is absent.

In QEMU, `make qemu-installed` runs `repair-qemu-esp.sh` on every boot which
also writes the config. If the error persists, the disk may not have been
staged correctly — run `make qemu-full` to rebuild from scratch.

### Limine Fails to Open Kernel

```
PANIC: linux: Failed to open kernel with path 'boot():/praxis/vmlinuz'
```

`boot():/praxis/vmlinuz` refers to `/praxis/vmlinuz` on the ESP. This file is
placed there by `mkinitrd`. If it is missing:

- In QEMU: the disk was never staged with `mkinitrd`. Run `make qemu-full`
  (which includes `mkinitrd`) then `make qemu-installed`.
- On real hardware: re-run `mkinitrd /mnt/praxis` while the ESP is still
  mounted and the target is intact.

### System Panics or Fails to Find Root

Kernel found but init fails or root is not mounted:

- Check the `root=UUID=...` cmdline matches the root partition UUID:
  ```bash
  cat /boot/loader/entries/praxis.conf
  blkid /dev/vda2
  ```
- Check `rdinit=/init` and `praxis.live=0` are in the cmdline.
- Check `/etc/fstab` has a UUID entry for `/`.

## QEMU-Specific

### make qemu-installed Boots but Kernel Is Missing

`make qemu-installed` calls `repair-qemu-esp.sh` which only writes the Limine
config and `BOOTX64.EFI` — it does **not** copy the kernel or initramfs. The
kernel is placed on the ESP only when `mkinitrd` runs during `make qemu-chroot`
or `make qemu-full`.

Fix:

```bash
make qemu-full
make qemu-installed
```

### OVMF Variables Stale

If the UEFI boot order is wrong after disk changes:

```bash
PRAXIS_QEMU_RESET_VARS=1 make qemu-installed
```

That copies a fresh OVMF vars template before booting.
