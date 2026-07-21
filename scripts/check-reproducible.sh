#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/scripts/build-metadata.sh"
sh -n "$repo_root/installer/praxis-provenance"

SOURCE_DATE_EPOCH=1700000000 \
  "$repo_root/scripts/build-metadata.sh" "$tmpdir/build-info" "$repo_root/README.md"

grep -qx 'BUILD_EPOCH=1700000000' "$tmpdir/build-info"
grep -qx 'BUILD_DATE=2023-11-14T22:13:20Z' "$tmpdir/build-info"
grep -Eq '^BUILD_GIT_COMMIT=' "$tmpdir/build-info"
grep -Eq '^BUILD_ARTIFACT_1_SHA256=[0-9a-f]{64}$' "$tmpdir/build-info"

mkdir -p "$tmpdir/root/etc/praxis" "$tmpdir/root/usr/share/praxis"
printf 'praxis\n' > "$tmpdir/root/usr/share/praxis/test-file"
(
  cd "$tmpdir/root"
  find usr/share/praxis -type f -print0 | sort -z | xargs -0 sha256sum > etc/praxis/rootfs.sha256
)
cp "$tmpdir/build-info" "$tmpdir/root/etc/praxis/build-info"

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-provenance" "$tmpdir/root" >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  "$repo_root/installer/praxis-provenance" verify "$tmpdir/root" >/dev/null

bash -n "$repo_root/scripts/build-iso.sh"

if command -v xorriso >/dev/null 2>&1 && command -v limine >/dev/null 2>&1; then
  printf 'test\n' > "$tmpdir/vmlinuz"
  printf 'test\n' > "$tmpdir/initramfs.cpio.gz"

  build_test_iso() {
    local out="$1"
    KERNEL_IMAGE="$tmpdir/vmlinuz" \
      SOURCE_DATE_EPOCH=1700000000 \
      "$repo_root/scripts/build-iso.sh" \
        "$tmpdir/initramfs.cpio.gz" \
        "$tmpdir/iso-stage-$out" \
        "$tmpdir/$out.iso" >/dev/null
  }

  build_test_iso a
  sleep 2
  build_test_iso b

  a_sum="$(sha256sum "$tmpdir/a.iso" | cut -d' ' -f1)"
  b_sum="$(sha256sum "$tmpdir/b.iso" | cut -d' ' -f1)"
  if [[ "$a_sum" != "$b_sum" ]]; then
    printf 'ISO build is not reproducible under SOURCE_DATE_EPOCH: %s != %s\n' "$a_sum" "$b_sum" >&2
    exit 1
  fi
else
  printf 'skipping ISO reproducibility check: xorriso and/or limine not installed\n' >&2
fi

printf 'Reproducible build check passed.\n'
