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

run_target_sh() {
  chroot "$target_root" /bin/sh -c "$1"
}

refresh_desktop_caches() {
  printf 'Refreshing desktop runtime state in target ...\n'

  if [[ -x "$target_root/usr/local/bin/praxis-desktop-fix" ]]; then
    chroot "$target_root" /usr/local/bin/praxis-desktop-fix "$desktop"
    return 0
  fi

  run_target_sh 'if command -v systemd-sysusers >/dev/null 2>&1; then systemd-sysusers || true; fi'
  run_target_sh 'if command -v systemd-tmpfiles >/dev/null 2>&1; then systemd-tmpfiles --create || true; fi'
  run_target_sh 'if command -v dbus-uuidgen >/dev/null 2>&1; then dbus-uuidgen --ensure=/etc/machine-id || true; fi'
  run_target_sh 'if command -v glib-compile-schemas >/dev/null 2>&1 && [ -d /usr/share/glib-2.0/schemas ]; then glib-compile-schemas /usr/share/glib-2.0/schemas; fi'
  run_target_sh 'if command -v gdk-pixbuf-query-loaders >/dev/null 2>&1; then gdk-pixbuf-query-loaders --update-cache; fi'
  run_target_sh 'if command -v update-mime-database >/dev/null 2>&1 && [ -d /usr/share/mime ]; then update-mime-database /usr/share/mime; fi'
  run_target_sh 'if command -v gtk-update-icon-cache >/dev/null 2>&1; then for _icon_dir in /usr/share/icons/*; do [ -f "$_icon_dir/index.theme" ] || continue; gtk-update-icon-cache -q -t -f "$_icon_dir" >/dev/null 2>&1 || true; done; fi'
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

for tool in qemu-img qemu-nbd sfdisk partprobe mkfs.vfat mkfs.ext4 blkid mount umount chroot; do
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
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export DESKTOP_SESSION=xfce
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/root}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

if command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
elif command -v dbus-daemon >/dev/null 2>&1; then
    _dbus_info="$(dbus-daemon --session --fork --print-address --print-pid 2>/dev/null || true)"
    export DBUS_SESSION_BUS_ADDRESS="$(printf '%s\n' "${_dbus_info}" | sed -n '1p')"
    export DBUS_SESSION_BUS_PID="$(printf '%s\n' "${_dbus_info}" | sed -n '2p')"
fi

xfconfd >/tmp/xfconfd.log 2>&1 &
sleep 1
xfsettingsd >/tmp/xfsettingsd.log 2>&1 &
if command -v xsetroot >/dev/null 2>&1; then
    xsetroot -solid '#061424' >/tmp/xsetroot.log 2>&1 || true
fi
xfwm4 --replace >/tmp/xfwm4.log 2>&1 &
XFWM_PID=$!
sleep 1
if command -v xfce4-panel >/dev/null 2>&1; then
    xfce4-panel --disable-wm-check >/tmp/xfce4-panel.log 2>&1 &
fi
sleep 1
if ! pgrep -x xfce4-panel >/dev/null 2>&1 && command -v tint2 >/dev/null 2>&1; then
    if [ -r /root/.config/tint2/tint2rc ]; then
        tint2 -c /root/.config/tint2/tint2rc >/tmp/tint2.log 2>&1 &
    else
        tint2 >/tmp/tint2.log 2>&1 &
    fi
fi
xfdesktop >/tmp/xfdesktop.log 2>&1 &
sleep 1
if command -v xsetroot >/dev/null 2>&1; then
    xsetroot -solid '#061424' >/tmp/xsetroot.log 2>&1 || true
fi
thunar --daemon >/tmp/thunar.log 2>&1 &
if command -v xfce4-terminal >/dev/null 2>&1; then
    xfce4-terminal >/tmp/xfce4-terminal.log 2>&1 &
fi

wait "${XFWM_PID}"
EOF
      ;;
    mate)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session mate-session
fi
exec mate-session
EOF
      ;;
    lxqt)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session startlxqt
fi
exec startlxqt
EOF
      ;;
    i3)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session i3
fi
exec i3
EOF
      ;;
    openbox)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session openbox-session
fi
exec openbox-session
EOF
      ;;
    plasma)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session startplasma-x11
fi
exec startplasma-x11
EOF
      ;;
    budgie)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
export XDG_CURRENT_DESKTOP=Budgie:GNOME
export XDG_SESSION_DESKTOP=budgie-desktop
export DESKTOP_SESSION=budgie-desktop
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session startbudgielabwc
fi
exec startbudgielabwc
EOF
      ;;
    gnome)
      cat > "$target_root/root/.xinitrc" <<'EOF'
export NO_AT_BRIDGE=1
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
  refresh_desktop_caches

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
mkdir -p "$target_root/boot/limine"
cat > "$target_root/boot/limine/limine.conf" <<EOF
# Praxis - Limine bootloader configuration (Limine 12.x)
timeout: 4
default_entry: 1
serial: yes

/Praxis
protocol: linux
path: boot():/praxis/vmlinuz
module_path: boot():/praxis/initramfs.cpio.gz
cmdline: root=UUID=$root_uuid rdinit=/init praxis.live=0 loglevel=3
EOF
cp "$target_root/boot/limine/limine.conf" "$target_root/boot/limine.conf"
cp "$target_root/boot/limine/limine.conf" "$target_root/boot/EFI/BOOT/limine.conf"

if [[ -f "$source_root/usr/share/praxis/boot/BOOTX64.EFI" ]]; then
  cp "$source_root/usr/share/praxis/boot/BOOTX64.EFI" "$target_root/boot/EFI/BOOT/BOOTX64.EFI"
fi

"$repo_root/installer/targetcheck" "$target_root"
sync

printf '\nQEMU disk staged at %s\n' "$disk_file"
printf 'Next: make qemu-installed\n'
