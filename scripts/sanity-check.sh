#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/scripts/build-rootfs.sh"
bash -n "$repo_root/scripts/build-metadata.sh"
bash -n "$repo_root/scripts/build-kernel.sh"
bash -n "$repo_root/scripts/build-userspace.sh"
bash -n "$repo_root/scripts/build-s6.sh"
bash -n "$repo_root/scripts/build-initramfs.sh"
bash -n "$repo_root/scripts/build-iso.sh"
bash -n "$repo_root/scripts/check-rootfs-owned.sh"
bash -n "$repo_root/scripts/check-contract.sh"
bash -n "$repo_root/scripts/check-pkg-format.sh"
bash -n "$repo_root/scripts/check-init-profiles.sh"
bash -n "$repo_root/scripts/check-kernel-profiles.sh"
bash -n "$repo_root/scripts/check-manifests.sh"
bash -n "$repo_root/scripts/check-reproducible.sh"
bash -n "$repo_root/scripts/check-seeds.sh"
bash -n "$repo_root/scripts/check-target-audit.sh"
bash -n "$repo_root/scripts/create-qemu-disk.sh"
bash -n "$repo_root/scripts/qemu-chroot.sh"
bash -n "$repo_root/scripts/repair-qemu-esp.sh"
bash -n "$repo_root/scripts/dev-install.sh"
bash -n "$repo_root/scripts/run-qemu-installed.sh"
bash -n "$repo_root/scripts/run-qemu.sh"
bash -n "$repo_root/scripts/sanity-check.sh"

sh -n "$repo_root/boot/init"
sh -n "$repo_root/rootfs/etc/sv/shell/run"
sh -n "$repo_root/rootfs/etc/sv/shell/console"
sh -n "$repo_root/rootfs/etc/sv/udev/run"
sh -n "$repo_root/installer/lib/common.sh"
sh -n "$repo_root/installer/praxis-banner"
sh -n "$repo_root/installer/praxis-fetch"
sh -n "$repo_root/installer/praxis-help"
sh -n "$repo_root/installer/praxis-status"
sh -n "$repo_root/installer/praxis-lsblk"
sh -n "$repo_root/installer/preflight"
sh -n "$repo_root/installer/praxis-disk-report"
sh -n "$repo_root/installer/praxis-disk"
sh -n "$repo_root/installer/praxis-netcheck"
sh -n "$repo_root/installer/praxis-support"
sh -n "$repo_root/installer/praxis-recover"
sh -n "$repo_root/installer/praxis-postinstall"
sh -n "$repo_root/installer/praxis-install"
sh -n "$repo_root/installer/mkinitrd"
sh -n "$repo_root/installer/praxis-chroot"
sh -n "$repo_root/installer/praxis-pkg"
sh -n "$repo_root/installer/praxis-packages"
sh -n "$repo_root/installer/praxis-desktop"
sh -n "$repo_root/installer/praxis-desktop-fix"
sh -n "$repo_root/installer/praxis-choice"
sh -n "$repo_root/installer/praxis-contract"
sh -n "$repo_root/installer/praxis-manifest"
sh -n "$repo_root/installer/praxis-provenance"
sh -n "$repo_root/installer/praxis-seed"
sh -n "$repo_root/installer/praxis-sv"
sh -n "$repo_root/installer/targetcheck"
sh -n "$repo_root/installer/praxis-live"
sh -n "$repo_root/installer/praxis-dev-install"

"$repo_root/scripts/build-rootfs.sh" "$tmpdir/rootfs"
"$repo_root/scripts/check-rootfs-owned.sh" "$tmpdir/rootfs" >/dev/null
"$repo_root/scripts/check-contract.sh" >/dev/null
"$repo_root/scripts/check-pkg-format.sh" >/dev/null
"$repo_root/scripts/check-init-profiles.sh" >/dev/null
"$repo_root/scripts/check-kernel-profiles.sh" >/dev/null
"$repo_root/scripts/check-manifests.sh" >/dev/null
"$repo_root/scripts/check-reproducible.sh" >/dev/null
"$repo_root/scripts/check-seeds.sh" >/dev/null
"$repo_root/scripts/check-target-audit.sh" >/dev/null

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
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-help" v2 >/dev/null

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
  PRAXIS_REPOS_CONF="$repo_root/rootfs/etc/praxis/repos.conf" \
  "$repo_root/installer/praxis-pkg" repos >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" list >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-manifest" list >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-manifest" show base-system >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$tmpdir/rootfs/etc/praxis" \
  "$repo_root/installer/praxis-manifest" verify base-system "$tmpdir/rootfs" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-provenance" "$tmpdir/rootfs" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-provenance" verify "$tmpdir/rootfs" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" emit --kernel tiny --init busybox --bundle essentials >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" emit --kernel tiny --init busybox --bundle essentials > "$tmpdir/system.choice"

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" validate "$tmpdir/system.choice" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" boot-entry "$tmpdir/system.choice" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-status" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/preflight" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-disk-report" >/dev/null
env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-disk" /dev/vda /mnt/praxis --dry-run >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-seed" list >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-seed" show base >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-seed" --dry-run --seed "$repo_root/config/seeds/v2-half.seed" "$tmpdir/rootfs" >/dev/null

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
  "$repo_root/installer/praxis-recover" "$tmpdir/rootfs" >/dev/null

env \
  PATH="/bin:/usr/bin:$repo_root/installer" \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-postinstall" "$tmpdir/rootfs" >/dev/null

env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SOURCE_ROOT="$tmpdir/rootfs" \
  PRAXIS_ALLOW_UNMOUNTED_TARGET=1 \
  PRAXIS_SKIP_BOOT_FSTYPE_CHECK=1 \
  "$repo_root/installer/praxis-install" --hostname praxistest "$tmpdir/live-root" >/dev/null
printf '# stub fstab\nUUID=deadbeef / ext4 defaults 0 1\nUUID=feedface /boot vfat defaults 0 2\n' > "$tmpdir/live-root/etc/fstab"
cat > "$tmpdir/live-root/etc/praxis/initramfs.conf" <<EOF
INITRAMFS_FORMAT=newc
INITRAMFS_COMPRESSION=gzip
INITRAMFS_OWNER=manual
EOF
env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SOURCE_ROOT="$tmpdir/rootfs" \
  PRAXIS_ALLOW_UNMOUNTED_TARGET=1 \
  "$repo_root/installer/mkinitrd" "$tmpdir/live-root" >/dev/null
mkdir -p "$tmpdir/live-root/boot/loader/entries" "$tmpdir/live-root/boot/EFI/BOOT"
printf 'default praxis\ntimeout 4\n' > "$tmpdir/live-root/boot/loader/loader.conf"
printf 'title   Praxis\nlinux   /praxis/vmlinuz\ninitrd  /praxis/initramfs.cpio.gz\noptions root=UUID=deadbeef rdinit=/init praxis.live=0\n' \
  > "$tmpdir/live-root/boot/loader/entries/praxis.conf"
printf '# stub\n' > "$tmpdir/live-root/boot/limine.conf"
cp "$tmpdir/rootfs/usr/share/praxis/boot/BOOTX64.EFI" "$tmpdir/live-root/boot/EFI/BOOT/BOOTX64.EFI"
printf 'chroot\n' > "$tmpdir/live-root/etc/praxis/install-stage"
ln -sf /usr/share/zoneinfo/UTC "$tmpdir/live-root/etc/localtime"
printf 'LANG=en_US.UTF-8\n' > "$tmpdir/live-root/etc/locale.conf"
printf '00000000000040008000000000000003\n' > "$tmpdir/live-root/etc/machine-id"
env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/targetcheck" "$tmpdir/live-root" >/dev/null

# mkinitrd with INITRAMFS_ROOT=disk (praxis-install's real default) and a
# TARGET_ROOT nested inside SOURCE_ROOT: the exclude list must protect the
# growing output archive at its real nested path, not just a top-level
# ./boot guess. Regression test for a real bug where the archive recursed
# into its own output and grew without bound in exactly this scenario.
mkdir -p "$tmpdir/disk-source/usr/share/praxis" "$tmpdir/disk-source/mnt/nested-target/etc/praxis"
# An unrelated ./boot directory elsewhere in the source tree, to prove the
# exclude targets only the nested target's own boot/, not any directory
# named "boot" anywhere in the tree (bsdtar's --exclude matches by
# basename at any depth for a bare pattern like "./boot").
mkdir -p "$tmpdir/disk-source/unrelated/boot"
printf 'should survive\n' > "$tmpdir/disk-source/unrelated/boot/keep-me.txt"
printf 'fake-kernel\n' > "$tmpdir/disk-source/usr/share/praxis/vmlinuz"
head -c 2000000 /dev/urandom > "$tmpdir/disk-source/filler.bin"
printf 'UUID=deadbeef / ext4 defaults 0 1\nUUID=feedface /boot vfat defaults 0 2\n' \
  > "$tmpdir/disk-source/mnt/nested-target/etc/fstab"
cat > "$tmpdir/disk-source/mnt/nested-target/etc/praxis/initramfs.conf" <<EOF
INITRAMFS_FORMAT=newc
INITRAMFS_COMPRESSION=gzip
INITRAMFS_OWNER=manual
INITRAMFS_ROOT=disk
EOF
printf 'rootfs\n' > "$tmpdir/disk-source/mnt/nested-target/etc/praxis/install-stage"
timeout 30 env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_ALLOW_UNMOUNTED_TARGET=1 \
  PRAXIS_SOURCE_ROOT="$tmpdir/disk-source" \
  PRAXIS_INSTALL_KERNEL="$tmpdir/disk-source/usr/share/praxis/vmlinuz" \
  "$repo_root/installer/mkinitrd" "$tmpdir/disk-source/mnt/nested-target" >/dev/null
nested_initramfs_size="$(stat -c '%s' "$tmpdir/disk-source/mnt/nested-target/boot/praxis/initramfs.cpio.gz")"
if [ "$nested_initramfs_size" -gt 10000000 ]; then
  printf 'mkinitrd disk-mode nested-target archive is %s bytes, expected well under 10MB -- likely recursed into its own output\n' "$nested_initramfs_size" >&2
  exit 1
fi
if ! (cd "$tmpdir" && gzip -dc "disk-source/mnt/nested-target/boot/praxis/initramfs.cpio.gz" | cpio -it 2>/dev/null | grep -q 'unrelated/boot/keep-me.txt'); then
  printf 'mkinitrd disk-mode archive dropped an unrelated ./boot directory elsewhere in the source tree -- exclude is over-matching by basename instead of the real nested target path\n' >&2
  exit 1
fi

env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SOURCE_ROOT="$tmpdir/rootfs" \
  PRAXIS_SKIP_BOOTCTL=1 \
  "$repo_root/installer/praxis-dev-install" "$tmpdir/live-dev-root" >/dev/null
env \
  PRAXIS_STAGE_DIR="$tmpdir/dev-stage" \
  PRAXIS_ALLOW_HOST_KERNEL=1 \
  PRAXIS_SKIP_BOOTCTL=1 \
  "$repo_root/scripts/dev-install.sh" "$tmpdir/dev-root" >/dev/null

test -f "$tmpdir/rootfs/init"
test -x "$tmpdir/rootfs/etc/sv/shell/run"
test -x "$tmpdir/rootfs/etc/sv/udev/run"
test -L "$tmpdir/rootfs/etc/service/shell"
test -L "$tmpdir/rootfs/etc/service/udev"
[ "$(readlink "$tmpdir/rootfs/etc/service/shell")" = "../sv/shell" ]
[ "$(readlink "$tmpdir/rootfs/etc/service/udev")" = "../sv/udev" ]
test -f "$tmpdir/rootfs/bin/busybox"
test -L "$tmpdir/rootfs/bin/sh"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-banner"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-fetch"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-help"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-status"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-lsblk"
test -L "$tmpdir/rootfs/usr/local/bin/lsblk"
test -f "$tmpdir/rootfs/usr/local/bin/preflight"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-disk-report"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-disk"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-netcheck"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-support"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-recover"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-postinstall"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-install"
test -f "$tmpdir/rootfs/usr/local/bin/mkinitrd"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-chroot"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-pkg"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-packages"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-desktop"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-desktop-fix"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-choice"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-contract"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-manifest"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-provenance"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-seed"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-sv"
test -f "$tmpdir/rootfs/usr/local/bin/targetcheck"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-live"
test -f "$tmpdir/rootfs/usr/local/bin/praxis-dev-install"
test -f "$tmpdir/rootfs/etc/praxis/praxis.env"
test -f "$tmpdir/rootfs/etc/praxis/build-info"
test -f "$tmpdir/rootfs/etc/praxis/live-tools.manifest"
test -f "$tmpdir/rootfs/etc/praxis/repos.conf"
test -f "$tmpdir/rootfs/etc/praxis/rootfs.sha256"
test -f "$tmpdir/rootfs/etc/praxis/choices/kernel/tiny.conf"
test -f "$tmpdir/rootfs/etc/praxis/choices/init/busybox.conf"
grep -qx 'REQUIRED_FILES=/init,/bin/busybox,/etc/service/shell/run' "$tmpdir/rootfs/etc/praxis/choices/init/busybox.conf"
test -f "$tmpdir/rootfs/etc/praxis/manifests/base-system.manifest"
test -d "$tmpdir/rootfs/etc/praxis/packages/desktops"
test -d "$tmpdir/rootfs/etc/praxis/packages/bundles"
test -f "$tmpdir/rootfs/etc/praxis/seeds/base.seed"
test -f "$tmpdir/rootfs/etc/praxis/seeds/workstation.seed"
test -f "$tmpdir/rootfs/etc/praxis/seeds/recovery.seed"
test -f "$tmpdir/rootfs/etc/praxis/seeds/v2-half.seed"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/README.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/DOC.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/INSTALL.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/QEMU.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/COMMANDS.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/FIRST-BOOT.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/TROUBLESHOOTING.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/PACKAGES.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/PKG-FORMAT.md"
test -f "$tmpdir/rootfs/usr/share/doc/praxis/V2.md"
test -f "$tmpdir/rootfs/bin/mount"
test -f "$tmpdir/rootfs/bin/grep"
test -f "$tmpdir/rootfs/bin/tar"
test -f "$tmpdir/rootfs/usr/share/praxis/branding/fastfetch/praxis.txt"
test -f "$tmpdir/rootfs/usr/share/praxis/branding/fastfetch/praxis-text.txt"
test -f "$tmpdir/rootfs/usr/share/praxis/boot/BOOTX64.EFI"
test -f "$tmpdir/rootfs/etc/hostname"
test -f "$tmpdir/rootfs/etc/os-release"
test -f "$tmpdir/rootfs/etc/xdg/fastfetch/config.jsonc"
test -f "$tmpdir/rootfs/usr/share/praxis/vmlinuz"
test -f "$tmpdir/rootfs/usr/share/praxis/kernel/config.fragment"
test -f "$tmpdir/rootfs/usr/share/praxis/kernel/profiles/stock.fragment"
test -f "$tmpdir/rootfs/usr/share/praxis/kernel/profiles/tiny.fragment"
test -f "$tmpdir/rootfs/usr/share/praxis/kernel/profiles/hardened.fragment"
grep -qx 'CONFIG_VT=y' "$tmpdir/rootfs/usr/share/praxis/kernel/profiles/stock.fragment"
test ! -e "$tmpdir/rootfs/usr/local/bin/praxis-harder-than-hell"
test ! -e "$tmpdir/rootfs/usr/local/bin/praxis-wiki"
test -f "$tmpdir/live-dev-root/usr/local/bin/praxis-live"
test -f "$tmpdir/live-root/usr/local/bin/praxis-live"
test -f "$tmpdir/live-root/boot/praxis/vmlinuz"
test -f "$tmpdir/live-root/boot/praxis/initramfs.cpio.gz"
test -f "$tmpdir/live-root/boot/limine.conf"
test -f "$tmpdir/live-root/boot/EFI/BOOT/BOOTX64.EFI"
test -f "$tmpdir/live-root/boot/loader/loader.conf"
test -f "$tmpdir/live-root/boot/loader/entries/praxis.conf"
test -f "$tmpdir/live-root/etc/praxis/install"
test -f "$tmpdir/live-root/etc/praxis/install-stage"
test -f "$tmpdir/live-root/etc/hostname"
test -f "$tmpdir/live-root/etc/hosts"
test -f "$tmpdir/live-root/etc/fstab"
grep -qx 'praxistest' "$tmpdir/live-root/etc/hostname"
grep -Eq '^127\.0\.1\.1[[:space:]]+praxistest$' "$tmpdir/live-root/etc/hosts"
test -f "$tmpdir/live-dev-root/boot/praxis/vmlinuz"
test -f "$tmpdir/live-dev-root/boot/praxis/initramfs.cpio.gz"
test -f "$tmpdir/live-dev-root/boot/praxis/limine.conf"
test -f "$tmpdir/live-dev-root/boot/limine.conf"
test -f "$tmpdir/live-dev-root/boot/EFI/BOOT/BOOTX64.EFI"
test -f "$tmpdir/live-dev-root/boot/praxis/README.txt"
test -f "$tmpdir/live-dev-root/boot/loader/loader.conf"
test -f "$tmpdir/live-dev-root/boot/loader/entries/praxis-dev.conf"
test -f "$tmpdir/live-dev-root/etc/praxis/dev-install"
test -f "$tmpdir/dev-root/usr/local/bin/praxis-live"
test -f "$tmpdir/dev-root/boot/praxis/vmlinuz"
test -f "$tmpdir/dev-root/boot/praxis/initramfs.cpio.gz"
test -f "$tmpdir/dev-root/boot/praxis/limine.conf"
test -f "$tmpdir/dev-root/boot/limine.conf"
test -f "$tmpdir/dev-root/boot/EFI/BOOT/BOOTX64.EFI"
test -f "$tmpdir/dev-root/boot/praxis/README.txt"
test -f "$tmpdir/dev-root/boot/loader/loader.conf"
test -f "$tmpdir/dev-root/boot/loader/entries/praxis-dev.conf"
test -f "$tmpdir/dev-root/etc/praxis/dev-install"

# s6 is opt-in (make s6 / PRAXIS_ENABLE_S6=1) and not built by default, so
# only exercise the real staging path when the artifact already exists --
# this still catches real regressions in install_s6 on any machine that has
# built it at least once, without forcing every `make check` run to build
# skalibs+execline+s6 from source.
if [ -x "$repo_root/userspace/s6/bin/s6-svscan" ]; then
  s6_tmpdir="$(mktemp -d)"
  PRAXIS_ENABLE_S6=1 "$repo_root/scripts/build-rootfs.sh" "$s6_tmpdir/rootfs-s6" >/dev/null
  test -x "$s6_tmpdir/rootfs-s6/sbin/s6-svscan"
  test -x "$s6_tmpdir/rootfs-s6/sbin/s6-supervise"
  test -x "$s6_tmpdir/rootfs-s6/etc/s6/rc-init"
  test -d "$s6_tmpdir/rootfs-s6/service"
  grep -qx 'exec /sbin/s6-svscan /service' "$s6_tmpdir/rootfs-s6/etc/s6/rc-init"
  grep -qx 'export PATH=/sbin:/bin' "$s6_tmpdir/rootfs-s6/etc/s6/rc-init"
  rm -rf "$s6_tmpdir"
fi

printf 'Praxis sanity check passed.\n'
