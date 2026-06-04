#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
disk_file="${1:-"$repo_root/build/praxis.qcow2"}"
source_root="${2:-"$repo_root/build/rootfs"}"
owner_uid="${SUDO_UID:-}"
owner_gid="${SUDO_GID:-}"
target_root=""
nbd_dev=""

disconnect_nbd() {
  local dev="$1"

  qemu-nbd --disconnect "$dev" >/dev/null 2>&1 || true
  sleep 0.5
}

cleanup() {
  set +e
  if [[ -n "$target_root" ]]; then
    umount "$target_root" 2>/dev/null
    rmdir "$target_root" 2>/dev/null
  fi
  if [[ -n "$nbd_dev" ]]; then
    disconnect_nbd "$nbd_dev"
  fi
  if [[ -n "$owner_uid" && -n "$owner_gid" && -e "$disk_file" ]]; then
    chown "$owner_uid:$owner_gid" "$disk_file" 2>/dev/null
  fi
}
trap cleanup EXIT

if [[ "${EUID}" -ne 0 ]]; then
  exec sudo env \
    SUDO_UID="$(id -u)" \
    SUDO_GID="$(id -g)" \
    "$0" "$disk_file" "$source_root"
fi

for tool in qemu-nbd mount umount findmnt; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

[[ -f "$disk_file" ]] || { echo "missing QEMU disk: $disk_file" >&2; exit 1; }
[[ -f "$source_root/usr/share/praxis/boot/BOOTX64.EFI" ]] || {
  echo "missing fallback EFI source: $source_root/usr/share/praxis/boot/BOOTX64.EFI" >&2
  exit 1
}

modprobe nbd max_part=8 2>/dev/null || true

for candidate in /dev/nbd{0..15}; do
  [[ -b "$candidate" ]] || continue
  if qemu-nbd --connect "$candidate" "$disk_file" >/dev/null 2>&1; then
    nbd_dev="$candidate"
    break
  fi
done

[[ -n "$nbd_dev" ]] || { echo "could not attach $disk_file to a free nbd device" >&2; exit 1; }

partprobe "$nbd_dev" 2>/dev/null || true
udevadm settle 2>/dev/null || sleep 1

boot_part="${nbd_dev}p1"
[[ -b "$boot_part" ]] || { echo "missing ESP partition: $boot_part" >&2; exit 1; }

target_root="$(mktemp -d /mnt/praxis-esp.XXXXXX)"
mount "$boot_part" "$target_root"

fstype="$(findmnt -n -o FSTYPE --target "$target_root" 2>/dev/null || true)"
case "$fstype" in
  vfat|fat|fat16|fat32|msdos) ;;
  *) echo "partition 1 is not a FAT ESP, got: ${fstype:-unknown}" >&2; exit 1 ;;
esac

root_part="${nbd_dev}p2"
root_uuid="$(blkid -s UUID -o value "$root_part" 2>/dev/null || true)"

mkdir -p "$target_root/EFI/BOOT"
cp "$source_root/usr/share/praxis/boot/BOOTX64.EFI" "$target_root/EFI/BOOT/BOOTX64.EFI"

limine_cmdline="rdinit=/init praxis.live=0 loglevel=3 console=tty0"
if [[ -n "$root_uuid" ]]; then
  limine_cmdline="root=UUID=${root_uuid} ${limine_cmdline}"
fi

cat > "$target_root/EFI/BOOT/limine.conf" <<EOF
# Praxis - Limine bootloader configuration (Limine 12.x)
timeout: 4
default_entry: 1
serial: yes

/Praxis
protocol: linux
path: boot():/praxis/vmlinuz
module_path: boot():/praxis/initramfs.cpio.gz
cmdline: ${limine_cmdline}
EOF

mkdir -p "$target_root/boot/limine"
cp "$target_root/EFI/BOOT/limine.conf" "$target_root/boot/limine/limine.conf"
cp "$target_root/EFI/BOOT/limine.conf" "$target_root/boot/limine.conf"
cp "$target_root/EFI/BOOT/limine.conf" "$target_root/limine.conf"

sync
umount "$target_root"
rmdir "$target_root" 2>/dev/null || true
target_root=""
disconnect_nbd "$nbd_dev"
nbd_dev=""

printf 'Repaired QEMU ESP: BOOTX64.EFI + limine.conf (root UUID: %s)\n' "${root_uuid:-unknown}"
