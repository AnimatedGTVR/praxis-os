#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
seed_dir="$repo_root/config/seeds"
allowed_ops='^(mkdir|write|append|touch)[[:space:]]+/'

for seed in base workstation recovery v2-half; do
  seed_path="$seed_dir/$seed.seed"
  [[ -f "$seed_path" ]] || { printf 'missing seed: %s\n' "$seed_path" >&2; exit 1; }
  [[ -s "$seed_path" ]] || { printf 'empty seed: %s\n' "$seed_path" >&2; exit 1; }

  grep -Eq "^write /etc/praxis/seed-profile $seed$" "$seed_path" || {
    printf 'seed missing profile marker: %s\n' "$seed_path" >&2
    exit 1
  }

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%%#*}"
    line="$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$line" ]] || continue
    if [[ ! "$line" =~ $allowed_ops ]]; then
      printf 'invalid seed operation in %s: %s\n' "$seed_path" "$line" >&2
      exit 1
    fi
    if [[ "$line" == *'/../'* || "$line" == *' /..'* ]]; then
      printf 'seed path must not contain .. in %s: %s\n' "$seed_path" "$line" >&2
      exit 1
    fi
  done < "$seed_path"
done

printf 'Seed check passed.\n'
