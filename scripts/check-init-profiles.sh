#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
init_dir="$repo_root/config/choices/init"

for profile in busybox s6 systemd; do
  profile_file="$init_dir/$profile.conf"
  [[ -f "$profile_file" ]] || { printf 'missing init profile: %s\n' "$profile_file" >&2; exit 1; }

  grep -qx "NAME=$profile" "$profile_file" || {
    printf 'init profile NAME mismatch: %s\n' "$profile_file" >&2
    exit 1
  }

  for key in TITLE RDINIT REQUIRED_FILES REQUIRED_DIRS DESCRIPTION; do
    grep -Eq "^$key=.+" "$profile_file" || {
      printf 'init profile missing %s: %s\n' "$key" "$profile_file" >&2
      exit 1
    }
  done

  rdinit="$(sed -n 's/^RDINIT=//p' "$profile_file" | sed -n '1p')"
  [[ "$rdinit" == /* ]] || {
    printf 'RDINIT must be absolute in %s: %s\n' "$profile_file" "$rdinit" >&2
    exit 1
  }

  for key in REQUIRED_FILES REQUIRED_DIRS; do
    value="$(sed -n "s/^$key=//p" "$profile_file" | sed -n '1p')"
    IFS=',' read -r -a paths <<< "$value"
    for path in "${paths[@]}"; do
      [[ -n "$path" ]] || {
        printf '%s has empty path in %s\n' "$key" "$profile_file" >&2
        exit 1
      }
      [[ "$path" == /* ]] || {
        printf '%s path must be absolute in %s: %s\n' "$key" "$profile_file" "$path" >&2
        exit 1
      }
      [[ "$path" != *'/../'* && "$path" != */.. ]] || {
        printf '%s path must not contain .. in %s: %s\n' "$key" "$profile_file" "$path" >&2
        exit 1
      }
    done
  done
done

printf 'Init profile check passed.\n'
