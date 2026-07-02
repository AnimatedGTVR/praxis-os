#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_dir="$repo_root/config/manifests"
package_dir="$repo_root/config/packages"

[[ -f "$manifest_dir/base-system.manifest" ]] || {
  printf 'missing base-system manifest\n' >&2
  exit 1
}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  [[ -z "$raw_line" || "$raw_line" == \#* ]] && continue

  IFS='|' read -r record item_type item_path owner note extra <<< "$raw_line"
  if [[ -n "${extra:-}" || "$record" != "path" ]]; then
    printf 'invalid manifest record: %s\n' "$raw_line" >&2
    exit 1
  fi
  case "$item_type" in
    file|dir|link) ;;
    *)
      printf 'invalid manifest type: %s\n' "$raw_line" >&2
      exit 1
      ;;
  esac
  [[ "$item_path" == /* ]] || {
    printf 'manifest path must be absolute: %s\n' "$raw_line" >&2
    exit 1
  }
  [[ "$item_path" != *'/../'* && "$item_path" != */.. ]] || {
    printf 'manifest path must not contain ..: %s\n' "$raw_line" >&2
    exit 1
  }
  case "$owner" in
    praxis|operator|external) ;;
    *)
      printf 'invalid manifest owner: %s\n' "$raw_line" >&2
      exit 1
      ;;
  esac
  [[ -n "$note" ]] || {
    printf 'manifest note must not be empty: %s\n' "$raw_line" >&2
    exit 1
  }
done < "$manifest_dir/base-system.manifest"

cut -d '|' -f 3 "$manifest_dir/base-system.manifest" |
  sed '/^$/d; /^#/d' |
  sort |
  uniq -d |
  while IFS= read -r duplicate_path; do
    printf 'duplicate manifest path: %s\n' "$duplicate_path" >&2
    exit 1
  done

find "$package_dir" -type f -name '*.list' -print | sort | while IFS= read -r list_file; do
  [[ -s "$list_file" ]] || {
    printf 'empty package list: %s\n' "$list_file" >&2
    exit 1
  }

  clean_lines="$(sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$list_file")"
  [[ -n "$clean_lines" ]] || {
    printf 'package list has no package entries: %s\n' "$list_file" >&2
    exit 1
  }

  while IFS= read -r package_name; do
    [[ "$package_name" =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || {
      printf 'invalid package token in %s: %s\n' "$list_file" "$package_name" >&2
      exit 1
    }
  done <<< "$clean_lines"

  duplicate="$(printf '%s\n' "$clean_lines" | sort | uniq -d | head -n 1)"
  [[ -z "$duplicate" ]] || {
    printf 'duplicate package in %s: %s\n' "$list_file" "$duplicate" >&2
    exit 1
  }
done

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-manifest" list >/dev/null

PRAXIS_LIB_ROOT="$repo_root/installer/lib" \
  PRAXIS_CONFIG_ROOT="$repo_root/config" \
  "$repo_root/installer/praxis-manifest" show base-system >/dev/null

printf 'Manifest check passed.\n'
