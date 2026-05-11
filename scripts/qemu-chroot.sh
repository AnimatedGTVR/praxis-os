#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
disk_file="${1:-"$repo_root/build/praxis.qcow2"}"
disk_size="${2:-16G}"
source_root="${3:-"$repo_root/build/rootfs"}"
hostname="${PRAXIS_QEMU_HOSTNAME:-praxisvm}"
reset_disk="${PRAXIS_QEMU_CHROOT_RESET:-1}"
desktop="${PRAXIS_QEMU_DESKTOP:-}"
desktop="${desktop,,}"
skip_chroot="${PRAXIS_QEMU_SKIP_CHROOT:-0}"
owner_uid="${SUDO_UID:-}"
owner_gid="${SUDO_GID:-}"
target_root=""
nbd_dev=""

disconnect_nbd() {
  local dev="$1"

  qemu-nbd --disconnect "$dev" >/dev/null 2>&1 || true
  sleep 0.5
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

cleanup() {
  set +e
  if [[ -n "$target_root" ]]; then
    umount "$target_root/run" 2>/dev/null
    umount "$target_root/dev/pts" 2>/dev/null
    umount "$target_root/dev" 2>/dev/null
    umount "$target_root/sys" 2>/dev/null
    umount "$target_root/proc" 2>/dev/null
    umount "$target_root/boot" 2>/dev/null
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
    PRAXIS_QEMU_HOSTNAME="$hostname" \
    PRAXIS_QEMU_CHROOT_RESET="$reset_disk" \
    PRAXIS_QEMU_DESKTOP="$desktop" \
    PRAXIS_QEMU_SKIP_CHROOT="$skip_chroot" \
    SUDO_UID="$(id -u)" \
    SUDO_GID="$(id -g)" \
    "$0" "$disk_file" "$disk_size" "$source_root"
fi

for tool in qemu-img qemu-nbd sfdisk partprobe mkfs.vfat mkfs.ext4 blkid mount umount; do
  require_tool "$tool"
done

if [[ ! -d "$source_root" ]]; then
  echo "missing staged rootfs: $source_root" >&2
  echo "run make rootfs first" >&2
  exit 1
fi

mkdir -p "$(dirname "$disk_file")"
if [[ "$reset_disk" == "1" ]]; then
  rm -f "$disk_file"
fi
if [[ ! -f "$disk_file" ]]; then
  qemu-img create -f qcow2 "$disk_file" "$disk_size" >/dev/null
fi

modprobe nbd max_part=8 2>/dev/null || true

for candidate in /dev/nbd{0..15}; do
  [[ -b "$candidate" ]] || continue
  if qemu-nbd --connect "$candidate" "$disk_file" >/dev/null 2>&1; then
    nbd_dev="$candidate"
    break
  fi
done

if [[ -z "$nbd_dev" ]]; then
  echo "could not attach $disk_file to a free nbd device" >&2
  exit 1
fi

sfdisk "$nbd_dev" >/dev/null <<'EOF'
label: gpt
size=512M,type=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
type=0fc63daf-8483-4772-8e79-3d69d8477de4
EOF

partprobe "$nbd_dev" || true
udevadm settle 2>/dev/null || sleep 1

boot_part="${nbd_dev}p1"
root_part="${nbd_dev}p2"
for _ in {1..20}; do
  [[ -b "$boot_part" && -b "$root_part" ]] && break
  sleep 0.2
done

[[ -b "$boot_part" ]] || { echo "missing boot partition: $boot_part" >&2; exit 1; }
[[ -b "$root_part" ]] || { echo "missing root partition: $root_part" >&2; exit 1; }

mkfs.vfat -F32 -n PRAXISBOOT "$boot_part" >/dev/null
mkfs.ext4 -F -L PRAXISROOT "$root_part" >/dev/null

target_root="$(mktemp -d /mnt/praxis-qemu.XXXXXX)"
mount "$root_part" "$target_root"
mkdir -p "$target_root/boot"
mount "$boot_part" "$target_root/boot"

env \
  PRAXIS_SOURCE_ROOT="$source_root" \
  "$repo_root/installer/praxis-install" --hostname "$hostname" "$target_root"

root_uuid="$(blkid -s UUID -o value "$root_part")"
boot_uuid="$(blkid -s UUID -o value "$boot_part")"

cat > "$target_root/etc/fstab" <<EOF
UUID=$root_uuid / ext4 defaults 0 1
UUID=$boot_uuid /boot vfat umask=0077 0 2
EOF

cat > "$target_root/etc/praxis/initramfs.conf" <<'EOF'
INITRAMFS_FORMAT=newc
INITRAMFS_COMPRESSION=gzip
INITRAMFS_OWNER=manual
INITRAMFS_ROOT=disk
EOF

if [[ -f /usr/share/zoneinfo/America/New_York ]]; then
  cp /usr/share/zoneinfo/America/New_York "$target_root/etc/localtime"
else
  printf 'UTC\n' > "$target_root/etc/localtime"
fi
printf 'LANG=en_US.UTF-8\n' > "$target_root/etc/locale.conf"
tr -d '-' </proc/sys/kernel/random/uuid > "$target_root/etc/machine-id"

if [[ -n "$desktop" ]]; then
  env \
    PRAXIS_PACKAGE_ROOT="$repo_root/config/packages" \
    PRAXIS_PACMAN_DISABLE_HOOKS=1 \
    "$repo_root/installer/praxis-packages" install \
      --target "$target_root" \
      --desktop "$desktop" \
      --bundle essentials

  mkdir -p "$target_root/etc/praxis"
  cat > "$target_root/etc/praxis/desktop-session" <<EOF
DESKTOP=$desktop
AUTOLOGIN=root
EOF

  case "$desktop" in
    xfce)
      printf 'exec startxfce4\n' > "$target_root/root/.xinitrc"
      ;;
    mate)
      printf 'exec mate-session\n' > "$target_root/root/.xinitrc"
      ;;
    lxqt)
      printf 'exec startlxqt\n' > "$target_root/root/.xinitrc"
      ;;
    i3)
      printf 'exec i3\n' > "$target_root/root/.xinitrc"
      ;;
    openbox)
      printf 'exec openbox-session\n' > "$target_root/root/.xinitrc"
      ;;
    plasma)
      printf 'exec startplasma-x11\n' > "$target_root/root/.xinitrc"
      ;;
    budgie)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export XDG_CURRENT_DESKTOP=Budgie:GNOME
export XDG_SESSION_DESKTOP=budgie-desktop
export DESKTOP_SESSION=budgie-desktop
exec startbudgielabwc
EOF
      ;;
    gnome)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export DESKTOP_SESSION=gnome
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session gnome-session
fi
exec gnome-session
EOF
      ;;
  esac
  chmod +x "$target_root/root/.xinitrc"

  cat >> "$target_root/etc/motd" <<EOF

Praxis desktop profile installed: $desktop
Try: startx
EOF
fi

env \
  PRAXIS_SOURCE_ROOT="$source_root" \
  "$repo_root/installer/mkinitrd" "$target_root"

if [[ "$skip_chroot" != "1" ]]; then
  printf '\nEntering Praxis target chroot at %s\n' "$target_root"
  printf 'Required test config is already written. Optional: run passwd, inspect, then exit.\n\n'

  "$repo_root/installer/praxis-chroot" "$target_root"
else
  printf 'chroot\n' > "$target_root/etc/praxis/install-stage"
fi

mkdir -p "$target_root/boot/loader/entries" "$target_root/boot/EFI/BOOT"
cat > "$target_root/boot/loader/loader.conf" <<'EOF'
default praxis
timeout 4
EOF
cat > "$target_root/boot/loader/entries/praxis.conf" <<EOF
title   Praxis
linux   /praxis/vmlinuz
initrd  /praxis/initramfs.cpio.gz
options root=UUID=$root_uuid rdinit=/init praxis.live=0 loglevel=3
EOF
cat > "$target_root/boot/limine.conf" <<EOF
timeout: 4
default_entry: 1

/Praxis
protocol: linux
path: boot():/praxis/vmlinuz
module_path: boot():/praxis/initramfs.cpio.gz
cmdline: root=UUID=$root_uuid rdinit=/init praxis.live=0 loglevel=3
EOF

if [[ -f "$source_root/usr/share/praxis/boot/BOOTX64.EFI" ]]; then
  cp "$source_root/usr/share/praxis/boot/BOOTX64.EFI" "$target_root/boot/EFI/BOOT/BOOTX64.EFI"
fi

"$repo_root/installer/targetcheck" "$target_root"
sync

printf '\nQEMU disk staged at %s\n' "$disk_file"
printf 'Next: make qemu-installed\n'
