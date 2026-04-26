#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$repo_root/scripts/check-rootfs-owned.sh"
"$repo_root/scripts/sanity-check.sh"

QEMU_MODE=smoke QEMU_UI=nographic "$repo_root/scripts/run-qemu.sh" "$repo_root/build/praxis.iso"

printf 'Praxis v1 check passed.\n'
