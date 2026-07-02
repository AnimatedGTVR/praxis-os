#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/scripts/check-contract.sh"
sh -n "$repo_root/installer/praxis-contract"

target="$tmpdir/target"
"$repo_root/scripts/build-rootfs.sh" "$target" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-choice" emit --kernel stock --init busybox --bundle essentials > "$target/etc/praxis/system.choice"

mkdir -p "$target/boot/loader/entries"
cat > "$target/boot/loader/entries/praxis.conf" <<'EOF'
title   Praxis
linux   /praxis/vmlinuz
initrd  /praxis/initramfs.cpio.gz
options root=UUID=deadbeef rdinit=/init praxis.live=0 loglevel=3
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
INSTALL_COMPLETE=yes
EOF
(
  cd "$target"
  find . -type f \
    ! -path './etc/praxis/rootfs.sha256' \
    -print0 |
    sort -z |
    xargs -0 sha256sum > etc/praxis/rootfs.sha256
)

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-contract" export "$target" > "$tmpdir/praxis.contract"

grep -qx 'PRAXIS_CONTRACT_V1' "$tmpdir/praxis.contract"
grep -q '^choice|kernel|stock$' "$tmpdir/praxis.contract"
grep -q '^file|/etc/praxis/system.choice|present|' "$tmpdir/praxis.contract"

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-contract" inspect "$tmpdir/praxis.contract" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-contract" verify "$tmpdir/praxis.contract" "$target" >/dev/null

printf 'mutated\n' >> "$target/etc/praxis/system.choice"
if PRAXIS_LIB_ROOT="$repo_root/installer/lib" "$repo_root/installer/praxis-contract" verify "$tmpdir/praxis.contract" "$target" >/dev/null 2>&1; then
  printf 'contract verify unexpectedly passed after mutation\n' >&2
  exit 1
fi

printf 'Contract check passed.\n'
