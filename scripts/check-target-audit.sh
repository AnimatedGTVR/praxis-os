#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/installer/targetcheck"

target="$tmpdir/target"
"$repo_root/scripts/build-rootfs.sh" "$target" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" emit --kernel stock --init busybox --bundle essentials > "$target/etc/praxis/system.choice"

mkdir -p \
  "$target/boot/praxis" \
  "$target/boot/loader/entries" \
  "$target/boot/EFI/BOOT"

cp "$target/usr/share/praxis/vmlinuz" "$target/boot/praxis/vmlinuz"
printf 'initramfs\n' > "$target/boot/praxis/initramfs.cpio.gz"
printf 'default praxis\n' > "$target/boot/loader/loader.conf"
cat > "$target/boot/loader/entries/praxis.conf" <<'EOF'
title   Praxis
linux   /praxis/vmlinuz
initrd  /praxis/initramfs.cpio.gz
options root=UUID=deadbeef rdinit=/init praxis.live=0 loglevel=3
EOF
printf 'UUID=deadbeef / ext4 defaults 0 1\nUUID=feedface /boot vfat defaults 0 2\n' > "$target/etc/fstab"
cat > "$target/etc/praxis/initramfs.conf" <<'EOF'
INITRAMFS_FORMAT=newc
INITRAMFS_COMPRESSION=gzip
INITRAMFS_OWNER=manual
EOF
cat > "$target/etc/praxis/packages.selected" <<'EOF'
DESKTOP=none
BUNDLES=essentials
EXTRA=none
INSTALLED=base
EOF
cat > "$target/etc/praxis/install" <<'EOF'
INSTALL_MODE=manual
INSTALL_HOSTNAME=praxis
INSTALL_ENTRY=praxis
INSTALL_DESKTOP=none
INSTALL_BUNDLES=essentials
INSTALL_PACKAGES=none
SYSTEMD_BOOT_ENTRY=manual
SYSTEMD_BOOT_INSTALLED=manual
LIMINE_CONFIG=present
LIMINE_UEFI=present
INSTALL_COMPLETE=yes
EOF
printf 'chroot\n' > "$target/etc/praxis/install-stage"
printf 'praxis\n' > "$target/etc/hostname"
cat > "$target/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 praxis
EOF
ln -snf /usr/share/zoneinfo/UTC "$target/etc/localtime"
printf 'LANG=en_US.UTF-8\n' > "$target/etc/locale.conf"
printf '00000000000040008000000000000003\n' > "$target/etc/machine-id"
printf 'limine\n' > "$target/boot/limine.conf"
printf 'limine\n' > "$target/boot/praxis/limine.conf"
printf 'efi\n' > "$target/boot/EFI/BOOT/BOOTX64.EFI"

(
  cd "$target"
  find . -type f \
    ! -path './etc/praxis/rootfs.sha256' \
    -print0 |
    sort -z |
    xargs -0 sha256sum > etc/praxis/rootfs.sha256
)

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/targetcheck" --strict "$target" >/dev/null

bad_missing_provenance="$tmpdir/bad-missing-provenance"
cp -a "$target" "$bad_missing_provenance"
rm -f "$bad_missing_provenance/etc/praxis/build-info"
if PRAXIS_LIB_ROOT="$repo_root/installer/lib" "$repo_root/installer/targetcheck" --strict "$bad_missing_provenance" >/dev/null 2>&1; then
  printf 'strict targetcheck unexpectedly passed without build-info\n' >&2
  exit 1
fi

bad_rdinit="$tmpdir/bad-rdinit"
cp -a "$target" "$bad_rdinit"
sed -i 's#rdinit=/init#rdinit=/bin/sh#' "$bad_rdinit/boot/loader/entries/praxis.conf"
if PRAXIS_LIB_ROOT="$repo_root/installer/lib" "$repo_root/installer/targetcheck" --strict "$bad_rdinit" >/dev/null 2>&1; then
  printf 'strict targetcheck unexpectedly passed with bad rdinit\n' >&2
  exit 1
fi

bad_manifest="$tmpdir/bad-manifest"
cp -a "$target" "$bad_manifest"
rm -f "$bad_manifest/usr/local/bin/praxis-pkg"
(
  cd "$bad_manifest"
  find . -type f \
    ! -path './etc/praxis/rootfs.sha256' \
    -print0 |
    sort -z |
    xargs -0 sha256sum > etc/praxis/rootfs.sha256
)
if PRAXIS_LIB_ROOT="$repo_root/installer/lib" "$repo_root/installer/targetcheck" --strict "$bad_manifest" >/dev/null 2>&1; then
  printf 'strict targetcheck unexpectedly passed with missing manifest file\n' >&2
  exit 1
fi

printf 'Target audit check passed.\n'
