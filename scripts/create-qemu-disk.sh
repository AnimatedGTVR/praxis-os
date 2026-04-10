#!/usr/bin/env bash

set -euo pipefail

disk_file="${1:-}"
disk_size="${2:-16G}"

if [[ -z "$disk_file" ]]; then
  echo "usage: $0 <disk-file> [size]" >&2
  exit 1
fi

command -v qemu-img >/dev/null 2>&1 || {
  echo "missing required tool: qemu-img" >&2
  exit 1
}

mkdir -p "$(dirname "$disk_file")"

if [[ -f "$disk_file" ]]; then
  printf 'QEMU disk already exists at %s\n' "$disk_file"
  exit 0
fi

qemu-img create -f qcow2 "$disk_file" "$disk_size" >/dev/null
printf 'Created Praxis QEMU disk at %s (%s)\n' "$disk_file" "$disk_size"
