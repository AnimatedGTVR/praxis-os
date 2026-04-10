#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/scripts/build-rootfs.sh"
bash -n "$repo_root/scripts/build-initramfs.sh"
bash -n "$repo_root/scripts/build-iso.sh"
bash -n "$repo_root/scripts/create-qemu-disk.sh"
bash -n "$repo_root/scripts/dev-install.sh"
bash -n "$repo_root/scripts/run-qemu-installed.sh"
bash -n "$repo_root/scripts/run-qemu.sh"
bash -n "$repo_root/scripts/sanity-check.sh"

sh -n "$repo_root/boot/init"
sh -n "$repo_root/installer/lib/common.sh"
sh -n "$repo_root/installer/praxis-banner"
sh -n "$repo_root/installer/praxis-fetch"
sh -n "$repo_root/installer/praxis-help"
sh -n "$repo_root/installer/praxis-status"
sh -n "$repo_root/installer/praxis-preflight"
sh -n "$repo_root/installer/praxis-disk-report"
sh -n "$repo_root/installer/praxis-netcheck"
sh -n "$repo_root/installer/praxis-support"
sh -n "$repo_root/installer/praxis-postinstall"
sh -n "$repo_root/installer/praxis-install"
sh -n "$repo_root/installer/praxis-packages"
sh -n "$repo_root/installer/praxis-desktop"
sh -n "$repo_root/installer/praxis-target-check"
sh -n "$repo_root/installer/praxis-live"
sh -n "$repo_root/installer/praxis-dev-install"

"$repo_root/scripts/build-rootfs.sh" "$tmpdir/rootfs"

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  PRAXIS_SHELL="/bin/true" \
  "$repo_root/installer/praxis-live" >/dev/null

env \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  PRAXIS_BRANDING_ROOT="$repo_root/branding/fastfetch" \
  "$repo_root/installer/praxis-banner" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-help" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_PACKAGE_ROOT="$repo_root/config/packages" \
  "$repo_root/installer/praxis-packages" list >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-desktop" list >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-status" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-preflight" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-disk-report" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-netcheck" 127.0.0.1 >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SUPPORT_OUT="$tmpdir/praxis-support.tar.gz" \
  "$repo_root/installer/praxis-support" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-postinstall" >/dev/null

env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SOURCE_ROOT="$tmpdir/rootfs" \
  PRAXIS_ALLOW_UNMOUNTED_TARGET=1 \
  PRAXIS_SKIP_BOOTCTL=1 \
  PRAXIS_SKIP_PACKAGE_INSTALL=1 \
  "$repo_root/installer/praxis-install" --hostname praxistest --desktop xfce --bundle developer --packages firefox,vlc "$tmpdir/live-root-packages" >/dev/null
env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SOURCE_ROOT="$tmpdir/rootfs" \
  PRAXIS_ALLOW_UNMOUNTED_TARGET=1 \
  PRAXIS_SKIP_BOOTCTL=1 \
  "$repo_root/installer/praxis-install" --hostname praxistest "$tmpdir/live-root" >/dev/null
env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-target-check" "$tmpdir/live-root" >/dev/null
env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SOURCE_ROOT="$tmpdir/rootfs" \
  PRAXIS_SKIP_BOOTCTL=1 \
  "$repo_root/installer/praxis-dev-install" "$tmpdir/live-dev-root" >/dev/null
env \
  PRAXIS_STAGE_DIR="$tmpdir/dev-stage" \
  PRAXIS_SKIP_BOOTCTL=1 \
  "$repo_root/scripts/dev-install.sh" "$tmpdir/dev-root" >/dev/null

test -f "$tmpdir/rootfs/init"
test -f "$tmpdir/rootfs/bin/bash"
test -L "$tmpdir/rootfs/bin/sh"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-banner"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-fetch"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-help"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-status"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-preflight"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-disk-report"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-netcheck"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-support"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-postinstall"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-install"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-packages"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-desktop"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-target-check"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-live"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-dev-install"
test -f "$tmpdir/rootfs/etc/praxis/praxis.env"
test -f "$tmpdir/rootfs/etc/praxis/live-tools.manifest"
test -d "$tmpdir/rootfs/etc/praxis/packages/desktops"
test -d "$tmpdir/rootfs/etc/praxis/packages/bundles"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/README.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/INSTALL.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/QEMU.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/COMMANDS.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/FIRST-BOOT.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/TROUBLESHOOTING.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/PACKAGES.md"
test -f "$tmpdir/rootfs/etc/pacman.conf"
test -f "$tmpdir/rootfs/etc/pacman.d/mirrorlist"
test -f "$tmpdir/rootfs/usr/share/praxis/branding/fastfetch/praxis.txt"
test -f "$tmpdir/rootfs/usr/share/praxis/branding/fastfetch/praxis-text.txt"
test -f "$tmpdir/rootfs/etc/hostname"
test -f "$tmpdir/rootfs/etc/os-release"
test -f "$tmpdir/rootfs/etc/xdg/fastfetch/config.jsonc"
test -f "$tmpdir/rootfs/usr/share/praxis/vmlinuz"
test ! -e "$tmpdir/rootfs/usr/local/bin/praxis-harder-than-hell"
test ! -e "$tmpdir/rootfs/usr/local/bin/praxis-wiki"
test -f "$tmpdir/live-dev-root/usr/local/bin/praxis-live"
test -f "$tmpdir/live-root-packages/usr/local/bin/praxis-live"
test -f "$tmpdir/live-root-packages/etc/praxis/install"
test -f "$tmpdir/live-root-packages/etc/praxis/packages.selected"
grep -q '^DESKTOP=xfce$' "$tmpdir/live-root-packages/etc/praxis/packages.selected"
grep -q '^BUNDLES=developer$' "$tmpdir/live-root-packages/etc/praxis/packages.selected"
test -f "$tmpdir/live-root/usr/local/bin/praxis-live"
test -f "$tmpdir/live-root/boot/praxis/vmlinuz"
test -f "$tmpdir/live-root/boot/praxis/initramfs.cpio.gz"
test -f "$tmpdir/live-root/boot/praxis/limine.conf"
test -f "$tmpdir/live-root/boot/praxis/README.txt"
test -f "$tmpdir/live-root/boot/loader/loader.conf"
test -f "$tmpdir/live-root/boot/loader/entries/praxis.conf"
test -f "$tmpdir/live-root/etc/praxis/install"
test -f "$tmpdir/live-root/etc/hostname"
test -f "$tmpdir/live-root/etc/hosts"
grep -qx 'praxistest' "$tmpdir/live-root/etc/hostname"
grep -Eq '^127\.0\.1\.1[[:space:]]+praxistest$' "$tmpdir/live-root/etc/hosts"
test -f "$tmpdir/live-dev-root/boot/praxis/vmlinuz"
test -f "$tmpdir/live-dev-root/boot/praxis/initramfs.cpio.gz"
test -f "$tmpdir/live-dev-root/boot/praxis/limine.conf"
test -f "$tmpdir/live-dev-root/boot/praxis/README.txt"
test -f "$tmpdir/live-dev-root/boot/loader/loader.conf"
test -f "$tmpdir/live-dev-root/boot/loader/entries/praxis-dev.conf"
test -f "$tmpdir/live-dev-root/etc/praxis/dev-install"
test -f "$tmpdir/dev-root/usr/local/bin/praxis-live"
test -f "$tmpdir/dev-root/boot/praxis/vmlinuz"
test -f "$tmpdir/dev-root/boot/praxis/initramfs.cpio.gz"
test -f "$tmpdir/dev-root/boot/praxis/limine.conf"
test -f "$tmpdir/dev-root/boot/praxis/README.txt"
test -f "$tmpdir/dev-root/boot/loader/loader.conf"
test -f "$tmpdir/dev-root/boot/loader/entries/praxis-dev.conf"
test -f "$tmpdir/dev-root/etc/praxis/dev-install"

printf 'Praxis sanity check passed.\n'
