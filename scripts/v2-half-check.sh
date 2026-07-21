#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/scripts/v2-half-check.sh"
sh -n "$repo_root/installer/praxis-seed"
sh -n "$repo_root/installer/praxis-choice"
sh -n "$repo_root/installer/praxis-manifest"
sh -n "$repo_root/installer/praxis-provenance"
sh -n "$repo_root/installer/praxis-recover"

test -f "$repo_root/docs/v2.md"
test -f "$repo_root/config/seeds/v2-half.seed"
test -f "$repo_root/config/manifests/base-system.manifest"
test -f "$repo_root/config/choices/kernel/tiny.conf"
test -f "$repo_root/config/choices/init/busybox.conf"
"$repo_root/scripts/check-init-profiles.sh" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" list >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" emit --kernel tiny --init busybox --bundle essentials > "$tmpdir/system.choice"

grep -qx 'KERNEL_PROFILE=tiny' "$tmpdir/system.choice"
grep -qx 'INIT_CHOICE=busybox' "$tmpdir/system.choice"
grep -qx 'INIT_REQUIRED_FILES=/init,/bin/busybox' "$tmpdir/system.choice"
grep -qx 'INIT_REQUIRED_DIRS=/etc' "$tmpdir/system.choice"
grep -qx 'PACKAGE_BUNDLES=essentials' "$tmpdir/system.choice"

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-seed" --dry-run --seed "$repo_root/config/seeds/v2-half.seed" "$tmpdir" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-recover" "$tmpdir" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-seed" --seed "$repo_root/config/seeds/v2-half.seed" "$tmpdir" >/dev/null

test -f "$tmpdir/etc/praxis/seed-profile"
grep -qx 'v2-half' "$tmpdir/etc/praxis/seed-profile"
test -f "$tmpdir/etc/praxis/seed-contract"
grep -qx 'explicit-ledger' "$tmpdir/etc/praxis/seed-contract"
test -f "$tmpdir/var/lib/praxis/seed-stage"
grep -qx 'v2-half' "$tmpdir/var/lib/praxis/seed-stage"
grep -q 'Praxis v2-half seed applied.' "$tmpdir/etc/motd"

"$repo_root/scripts/check-pkg-format.sh" >/dev/null
"$repo_root/scripts/check-manifests.sh" >/dev/null
"$repo_root/scripts/check-reproducible.sh" >/dev/null
"$repo_root/scripts/check-seeds.sh" >/dev/null

printf 'Praxis v2-half check passed.\n'
