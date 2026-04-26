#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
stage_dir="${1:-"$repo_root/build/rootfs"}"
tools_manifest="$repo_root/config/live-tools.manifest"
busybox_path="${BUSYBOX:-$repo_root/userspace/busybox}"
skipped_host_tools=()

pick_kernel_image() {
  if [[ -n "${KERNEL_IMAGE:-}" && -f "${KERNEL_IMAGE}" ]]; then
    printf '%s\n' "${KERNEL_IMAGE}"
    return 0
  fi

  if [[ -f "$repo_root/kernel/bzImage" ]]; then
    printf '%s\n' "$repo_root/kernel/bzImage"
    return 0
  fi

  if [[ "${PRAXIS_ALLOW_HOST_KERNEL:-0}" == "1" ]]; then
    local host_kernel="/lib/modules/$(uname -r)/vmlinuz"
    if [[ -f "$host_kernel" ]]; then
      printf '%s\n' "$host_kernel"
      return 0
    fi
  fi

  return 1
}

copy_library() {
  local source_path="$1"
  local real_path

  [[ -e "$source_path" ]] || return 0

  real_path="$(readlink -f "$source_path")"
  install -Dm755 "$real_path" "$stage_dir$real_path"

  if [[ "$source_path" != "$real_path" ]]; then
    mkdir -p "$stage_dir$(dirname "$source_path")"
    ln -snf "$real_path" "$stage_dir$source_path"
  fi
}

copy_binary() {
  local source_path="$1"
  local dest_path="${2:-$1}"
  local real_path
  local dep

  real_path="$(readlink -f "$source_path")"
  install -Dm755 "$real_path" "$stage_dir$dest_path"

  while read -r dep; do
    [[ -n "$dep" ]] || continue
    copy_library "$dep"
  done < <(ldd "$real_path" 2>/dev/null | awk '{for (i = 1; i <= NF; ++i) if ($i ~ /^\//) print $i}' | sort -u)
}

busybox_has_applet() {
  local applet="$1"

  "$busybox_path" --list 2>/dev/null | grep -qx "$applet"
}

install_busybox() {
  if [[ ! -x "$busybox_path" ]]; then
    echo "missing Praxis BusyBox artifact; run make userspace or set BUSYBOX" >&2
    exit 1
  fi

  install -Dm755 "$busybox_path" "$stage_dir/bin/busybox"
  while read -r applet_name; do
    [[ -n "$applet_name" ]] || continue
    ln -snf busybox "$stage_dir/bin/$applet_name"
  done < <("$busybox_path" --list)
  ln -snf busybox "$stage_dir/bin/sh"
}

find_limine_dir() {
  if [[ -n "${LIMINE_DIR:-}" && -d "$LIMINE_DIR" ]]; then
    printf '%s\n' "$LIMINE_DIR"
    return 0
  fi

  if command -v limine >/dev/null 2>&1; then
    limine --print-datadir 2>/dev/null || true
  fi
}

rm -rf "$stage_dir"
mkdir -p \
  "$stage_dir/bin" \
  "$stage_dir/dev/pts" \
  "$stage_dir/etc/pacman.d" \
  "$stage_dir/etc/praxis" \
  "$stage_dir/etc/praxis/packages" \
  "$stage_dir/proc" \
  "$stage_dir/root" \
  "$stage_dir/run" \
  "$stage_dir/sys" \
  "$stage_dir/tmp" \
  "$stage_dir/usr/local/bin" \
  "$stage_dir/usr/local/lib/praxis" \
  "$stage_dir/usr/share/doc/praxis" \
  "$stage_dir/usr/share/doc/praxis/pax/examples" \
  "$stage_dir/usr/share/doc/praxis/pax/spec" \
  "$stage_dir/usr/share/libalpm" \
  "$stage_dir/usr/share/pacman" \
  "$stage_dir/usr/share/praxis/boot" \
  "$stage_dir/usr/share/praxis/branding/fastfetch" \
  "$stage_dir/usr/share/praxis" \
  "$stage_dir/var/cache/pacman/pkg" \
  "$stage_dir/var/lib/pacman" \
  "$stage_dir/var/log"

cp -a "$repo_root/rootfs/." "$stage_dir/"
cp "$repo_root/boot/init" "$stage_dir/init"

cp "$repo_root/installer/lib/common.sh" "$stage_dir/usr/local/lib/praxis/common.sh"
cp "$repo_root/installer/praxis-banner" "$stage_dir/usr/local/bin/praxis-banner"
cp "$repo_root/installer/praxis-fetch" "$stage_dir/usr/local/bin/praxis-fetch"
cp "$repo_root/installer/praxis-help" "$stage_dir/usr/local/bin/praxis-help"
cp "$repo_root/installer/praxis-status" "$stage_dir/usr/local/bin/praxis-status"
cp "$repo_root/installer/praxis-lsblk" "$stage_dir/usr/local/bin/praxis-lsblk"
cp "$repo_root/installer/preflight" "$stage_dir/usr/local/bin/preflight"
cp "$repo_root/installer/praxis-disk-report" "$stage_dir/usr/local/bin/praxis-disk-report"
cp "$repo_root/installer/praxis-netcheck" "$stage_dir/usr/local/bin/praxis-netcheck"
cp "$repo_root/installer/praxis-support" "$stage_dir/usr/local/bin/praxis-support"
cp "$repo_root/installer/praxis-postinstall" "$stage_dir/usr/local/bin/praxis-postinstall"
cp "$repo_root/installer/praxis-install" "$stage_dir/usr/local/bin/praxis-install"
cp "$repo_root/installer/mkinitrd" "$stage_dir/usr/local/bin/mkinitrd"
cp "$repo_root/installer/praxis-chroot" "$stage_dir/usr/local/bin/praxis-chroot"
cp "$repo_root/installer/praxis-packages" "$stage_dir/usr/local/bin/praxis-packages"
cp "$repo_root/installer/praxis-desktop" "$stage_dir/usr/local/bin/praxis-desktop"
cp "$repo_root/installer/targetcheck" "$stage_dir/usr/local/bin/targetcheck"
cp "$repo_root/installer/praxis-live" "$stage_dir/usr/local/bin/praxis-live"
cp "$repo_root/installer/praxis-dev-install" "$stage_dir/usr/local/bin/praxis-dev-install"
ln -snf praxis-lsblk "$stage_dir/usr/local/bin/lsblk"

cp "$repo_root/config/praxis.env" "$stage_dir/etc/praxis/praxis.env"
cp "$repo_root/config/base.manifest" "$stage_dir/etc/praxis/base.manifest"
cp "$repo_root/config/live-tools.manifest" "$stage_dir/etc/praxis/live-tools.manifest"
cp -a "$repo_root/config/packages/." "$stage_dir/etc/praxis/packages/"
cp "$repo_root/README.md" "$stage_dir/usr/share/doc/praxis/README.md"
cp "$repo_root/Documentation/DOC.md" "$stage_dir/usr/share/doc/praxis/DOC.md"
cp "$repo_root/Documentation/INSTALL.md" "$stage_dir/usr/share/doc/praxis/INSTALL.md"
cp "$repo_root/Documentation/QEMU.md" "$stage_dir/usr/share/doc/praxis/QEMU.md"
cp "$repo_root/Documentation/COMMANDS.md" "$stage_dir/usr/share/doc/praxis/COMMANDS.md"
cp "$repo_root/Documentation/FIRST-BOOT.md" "$stage_dir/usr/share/doc/praxis/FIRST-BOOT.md"
cp "$repo_root/Documentation/TROUBLESHOOTING.md" "$stage_dir/usr/share/doc/praxis/TROUBLESHOOTING.md"
if [[ -f "$repo_root/Documentation/PACKAGES.md" ]]; then
  cp "$repo_root/Documentation/PACKAGES.md" "$stage_dir/usr/share/doc/praxis/PACKAGES.md"
fi
cp "$repo_root/pax/README.md" "$stage_dir/usr/share/doc/praxis/pax/README.md"
cp "$repo_root/pax/spec/PAX.md" "$stage_dir/usr/share/doc/praxis/PAX.md"
cp "$repo_root/pax/spec/PAX.md" "$stage_dir/usr/share/doc/praxis/pax/spec/PAX.md"
cp -a "$repo_root/pax/examples/." "$stage_dir/usr/share/doc/praxis/pax/examples/"
cp "$repo_root/branding/fastfetch/praxis.txt" "$stage_dir/usr/share/praxis/branding/fastfetch/praxis.txt"
cp "$repo_root/branding/fastfetch/praxis-text.txt" "$stage_dir/usr/share/praxis/branding/fastfetch/praxis-text.txt"

if [[ "${PRAXIS_ALLOW_HOST_TOOLS:-0}" == "1" ]]; then
  if [[ -f /etc/pacman.conf ]]; then
    install -Dm644 /etc/pacman.conf "$stage_dir/etc/pacman.conf"
  fi

  if [[ -f /etc/pacman.d/mirrorlist ]]; then
    install -Dm644 /etc/pacman.d/mirrorlist "$stage_dir/etc/pacman.d/mirrorlist"
  fi

  if [[ -d /etc/pacman.d/gnupg ]]; then
    mkdir -p "$stage_dir/etc/pacman.d/gnupg"
    while IFS= read -r -d '' key_file; do
      install -Dm644 "$key_file" "$stage_dir/etc/pacman.d/gnupg/$(basename "$key_file")"
    done < <(find /etc/pacman.d/gnupg -maxdepth 1 -type f -readable -print0 2>/dev/null)
  fi

  if [[ -d /usr/share/pacman ]]; then
    cp -a /usr/share/pacman/. "$stage_dir/usr/share/pacman/"
  fi

  if [[ -d /usr/share/libalpm ]]; then
    cp -a /usr/share/libalpm/. "$stage_dir/usr/share/libalpm/"
  fi
fi

kernel_image="$(pick_kernel_image || true)"
if [[ -z "${kernel_image:-}" ]]; then
  echo "missing kernel image; run make kernel, place one at kernel/bzImage, or set KERNEL_IMAGE" >&2
  exit 1
fi
cp "$kernel_image" "$stage_dir/usr/share/praxis/vmlinuz"
cp "$repo_root/boot/limine.conf" "$stage_dir/usr/share/praxis/limine.conf"

limine_dir="$(find_limine_dir || true)"
if [[ -n "$limine_dir" && -f "$limine_dir/BOOTX64.EFI" ]]; then
  install -Dm644 "$limine_dir/BOOTX64.EFI" "$stage_dir/usr/share/praxis/boot/BOOTX64.EFI"
else
  printf 'Limine BOOTX64.EFI not found; installed targets will need another EFI bootloader.\n' >&2
fi

install_busybox

while read -r tool_name; do
  [[ -n "$tool_name" ]] || continue
  [[ "$tool_name" =~ ^# ]] && continue
  if busybox_has_applet "$tool_name"; then
    continue
  fi
  if [[ "${PRAXIS_ALLOW_HOST_TOOLS:-0}" != "1" ]]; then
    skipped_host_tools+=("$tool_name")
    continue
  fi
  tool_path="$(command -v "$tool_name" || true)"
  if [[ -z "$tool_path" ]]; then
    echo "missing required live tool: $tool_name" >&2
    exit 1
  fi
  copy_binary "$tool_path"
done < "$tools_manifest"

if [[ "${#skipped_host_tools[@]}" -gt 0 ]]; then
  printf 'Skipped host compatibility tools: %s\n' "${skipped_host_tools[*]}" >&2
  printf 'Set PRAXIS_ALLOW_HOST_TOOLS=1 to vendor them into the live image.\n' >&2
fi

for extra_lib in /usr/lib/libnss_files.so.2 /usr/lib/libnss_dns.so.2 /usr/lib/libresolv.so.2; do
  [[ "${PRAXIS_ALLOW_HOST_TOOLS:-0}" == "1" ]] || continue
  copy_library "$extra_lib"
done

if [[ "${PRAXIS_ALLOW_HOST_TOOLS:-0}" == "1" && -f /etc/resolv.conf ]]; then
  install -Dm644 /etc/resolv.conf "$stage_dir/etc/resolv.conf"
fi

if [[ "${PRAXIS_ALLOW_HOST_TOOLS:-0}" == "1" && -f /etc/ssl/certs/ca-certificates.crt ]]; then
  install -Dm644 /etc/ssl/certs/ca-certificates.crt "$stage_dir/etc/ssl/certs/ca-certificates.crt"
fi

chmod +x \
  "$stage_dir/init" \
  "$stage_dir/usr/local/lib/praxis/common.sh" \
  "$stage_dir/usr/local/bin/praxis-banner" \
  "$stage_dir/usr/local/bin/praxis-fetch" \
  "$stage_dir/usr/local/bin/praxis-help" \
  "$stage_dir/usr/local/bin/praxis-status" \
  "$stage_dir/usr/local/bin/praxis-lsblk" \
  "$stage_dir/usr/local/bin/preflight" \
  "$stage_dir/usr/local/bin/praxis-disk-report" \
  "$stage_dir/usr/local/bin/praxis-netcheck" \
  "$stage_dir/usr/local/bin/praxis-support" \
  "$stage_dir/usr/local/bin/praxis-postinstall" \
  "$stage_dir/usr/local/bin/praxis-install" \
  "$stage_dir/usr/local/bin/mkinitrd" \
  "$stage_dir/usr/local/bin/praxis-chroot" \
  "$stage_dir/usr/local/bin/praxis-packages" \
  "$stage_dir/usr/local/bin/praxis-desktop" \
  "$stage_dir/usr/local/bin/targetcheck" \
  "$stage_dir/usr/local/bin/praxis-live" \
  "$stage_dir/usr/local/bin/praxis-dev-install"

cat > "$stage_dir/etc/praxis/build-info" <<EOF
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_SOURCE=$repo_root
EOF

printf 'Staged Praxis rootfs at %s\n' "$stage_dir"
