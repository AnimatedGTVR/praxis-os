#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target_root="${1:-${TARGET:-}}"
stage_dir="${PRAXIS_STAGE_DIR:-"$repo_root/build/rootfs"}"

if [[ -z "$target_root" ]]; then
  echo "usage: $0 <target-root>" >&2
  echo "example: sudo make dev-install TARGET=/mnt/praxis-dev" >&2
  exit 1
fi

"$repo_root/scripts/build-rootfs.sh" "$stage_dir"

env \
  PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_SOURCE_ROOT="$stage_dir" \
  PRAXIS_ALLOW_UNMOUNTED_TARGET="${PRAXIS_ALLOW_UNMOUNTED_TARGET:-1}" \
  PRAXIS_SKIP_BOOTCTL="${PRAXIS_SKIP_BOOTCTL:-1}" \
  PRAXIS_INSTALL_MODE=developer \
  PRAXIS_INSTALL_ENTRY_NAME=praxis-dev \
  PRAXIS_INSTALL_TITLE="Praxis Developer" \
  "$repo_root/installer/praxis-install" "$target_root"
