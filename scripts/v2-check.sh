#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/scripts/v2-check.sh"
bash -n "$repo_root/scripts/v2-half-check.sh"
bash -n "$repo_root/scripts/check-contract.sh"
bash -n "$repo_root/scripts/check-pkg-format.sh"
bash -n "$repo_root/scripts/check-init-profiles.sh"
bash -n "$repo_root/scripts/check-kernel-profiles.sh"
bash -n "$repo_root/scripts/check-manifests.sh"
bash -n "$repo_root/scripts/check-reproducible.sh"
bash -n "$repo_root/scripts/check-seeds.sh"
bash -n "$repo_root/scripts/check-target-audit.sh"
sh -n "$repo_root/installer/praxis-choice"
sh -n "$repo_root/installer/praxis-manifest"
sh -n "$repo_root/installer/praxis-provenance"
sh -n "$repo_root/installer/praxis-seed"
sh -n "$repo_root/installer/praxis-recover"

"$repo_root/scripts/v2-half-check.sh" >/dev/null
"$repo_root/scripts/check-contract.sh" >/dev/null
"$repo_root/scripts/check-pkg-format.sh" >/dev/null
"$repo_root/scripts/check-init-profiles.sh" >/dev/null
"$repo_root/scripts/check-kernel-profiles.sh" >/dev/null
"$repo_root/scripts/check-manifests.sh" >/dev/null
"$repo_root/scripts/check-reproducible.sh" >/dev/null
"$repo_root/scripts/check-seeds.sh" >/dev/null
"$repo_root/scripts/check-target-audit.sh" >/dev/null

for file in \
  "$repo_root/docs/v2.md" \
  "$repo_root/config/choices/kernel/stock.conf" \
  "$repo_root/config/choices/kernel/tiny.conf" \
  "$repo_root/config/choices/kernel/hardened.conf" \
  "$repo_root/config/choices/init/busybox.conf" \
  "$repo_root/config/choices/init/s6.conf" \
  "$repo_root/config/choices/init/systemd.conf" \
  "$repo_root/config/manifests/base-system.manifest" \
  "$repo_root/config/seeds/base.seed" \
  "$repo_root/config/seeds/workstation.seed" \
  "$repo_root/config/seeds/recovery.seed" \
  "$repo_root/config/seeds/v2-half.seed"
do
  test -f "$file"
done

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" emit --kernel hardened --init s6 --bundle essentials > "$tmpdir/system.choice"

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" validate "$tmpdir/system.choice" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" boot-entry "$tmpdir/system.choice" > "$tmpdir/praxis.conf"

grep -qx 'KERNEL_PROFILE=hardened' "$tmpdir/system.choice"
grep -qx 'KERNEL_CONFIG_FRAGMENT=/usr/share/praxis/kernel/profiles/hardened.fragment' "$tmpdir/system.choice"
grep -qx 'INIT_CHOICE=s6' "$tmpdir/system.choice"
grep -qx 'INIT_RDINIT=/sbin/s6-svscan' "$tmpdir/system.choice"
grep -qx 'INIT_REQUIRED_FILES=/sbin/s6-svscan' "$tmpdir/system.choice"
grep -qx 'INIT_REQUIRED_DIRS=/etc/s6,/service' "$tmpdir/system.choice"
grep -q 'rdinit=/sbin/s6-svscan' "$tmpdir/praxis.conf"

mkdir -p "$tmpdir/target/etc/praxis"
cp "$tmpdir/system.choice" "$tmpdir/target/etc/praxis/system.choice"

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-recover" "$tmpdir/target" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-manifest" list >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-manifest" show base-system >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-seed" list >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-seed" show recovery >/dev/null

mkdir -p "$tmpdir/seed-target"
PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-seed" --seed recovery "$tmpdir/seed-target" >/dev/null

grep -qx 'recovery' "$tmpdir/seed-target/etc/praxis/seed-profile"

mkdir -p \
  "$tmpdir/target-ok/etc/praxis" \
  "$tmpdir/target-ok/usr/share/praxis" \
  "$tmpdir/target-ok/usr/share/praxis/kernel/profiles" \
  "$tmpdir/target-ok/etc/s6" \
  "$tmpdir/target-ok/service" \
  "$tmpdir/target-ok/sbin" \
  "$tmpdir/target-ok/boot/praxis" \
  "$tmpdir/target-ok/boot/loader/entries" \
  "$tmpdir/target-ok/boot/EFI/BOOT"
cp "$tmpdir/system.choice" "$tmpdir/target-ok/etc/praxis/system.choice"
cp -a "$repo_root/config/choices" "$tmpdir/target-ok/etc/praxis/choices"
cp -a "$repo_root/config/packages" "$tmpdir/target-ok/etc/praxis/packages"
printf 'kernel\n' > "$tmpdir/target-ok/usr/share/praxis/vmlinuz"
printf 'fragment\n' > "$tmpdir/target-ok/usr/share/praxis/kernel/profiles/hardened.fragment"
printf 'kernel\n' > "$tmpdir/target-ok/boot/praxis/vmlinuz"
printf 'initramfs\n' > "$tmpdir/target-ok/boot/praxis/initramfs.cpio.gz"
printf 'init\n' > "$tmpdir/target-ok/sbin/s6-svscan"
printf 'default praxis\n' > "$tmpdir/target-ok/boot/loader/loader.conf"
cat > "$tmpdir/target-ok/boot/loader/entries/praxis.conf" <<'EOF'
title   Praxis
linux   /praxis/vmlinuz
initrd  /praxis/initramfs.cpio.gz
options root=UUID=deadbeef rdinit=/sbin/s6-svscan praxis.live=0 loglevel=3
EOF
printf 'UUID=deadbeef / ext4 defaults 0 1\nUUID=feedface /boot vfat defaults 0 2\n' > "$tmpdir/target-ok/etc/fstab"
cat > "$tmpdir/target-ok/etc/praxis/initramfs.conf" <<'EOF'
INITRAMFS_FORMAT=newc
INITRAMFS_COMPRESSION=gzip
INITRAMFS_OWNER=manual
EOF
cat > "$tmpdir/target-ok/etc/praxis/packages.selected" <<'EOF'
DESKTOP=none
BUNDLES=essentials
EXTRA=none
INSTALLED=base
EOF
printf 'chroot\n' > "$tmpdir/target-ok/etc/praxis/install-stage"
printf 'praxis\n' > "$tmpdir/target-ok/etc/hostname"
cat > "$tmpdir/target-ok/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 praxis
EOF
ln -s /usr/share/zoneinfo/UTC "$tmpdir/target-ok/etc/localtime"
printf 'LANG=en_US.UTF-8\n' > "$tmpdir/target-ok/etc/locale.conf"
printf '00000000000040008000000000000003\n' > "$tmpdir/target-ok/etc/machine-id"
printf 'limine\n' > "$tmpdir/target-ok/boot/limine.conf"
printf 'efi\n' > "$tmpdir/target-ok/boot/EFI/BOOT/BOOTX64.EFI"
printf 'limine\n' > "$tmpdir/target-ok/boot/praxis/limine.conf"

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/targetcheck" "$tmpdir/target-ok" >/dev/null

printf 'Praxis v2 check passed.\n'
