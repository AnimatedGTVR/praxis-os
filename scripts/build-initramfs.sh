#!/usr/bin/env bash

set -euo pipefail

stage_dir="${1:-}"
output_path="${2:-}"

if [[ -z "$stage_dir" || -z "$output_path" ]]; then
  echo "usage: $0 <stage-dir> <output-path>" >&2
  exit 1
fi

if [[ ! -d "$stage_dir" ]]; then
  echo "missing stage directory: $stage_dir" >&2
  exit 1
fi

command -v gzip >/dev/null 2>&1 || { echo "missing required tool: gzip" >&2; exit 1; }

mkdir -p "$(dirname "$output_path")"

if command -v cpio >/dev/null 2>&1; then
  (
    cd "$stage_dir"
    find . -print0 \
      | sort -z \
      | cpio --quiet --null -o -H newc \
      | gzip -n -9
  ) > "$output_path"
elif command -v bsdtar >/dev/null 2>&1; then
  bsdtar -C "$stage_dir" --format=newc -cf - . | gzip -n -9 > "$output_path"
else
  echo "missing required tool: cpio or bsdtar" >&2
  exit 1
fi

printf 'Built Praxis initramfs at %s\n' "$output_path"
