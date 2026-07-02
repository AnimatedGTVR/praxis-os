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

printf 'Reproducible build check passed.\n'
