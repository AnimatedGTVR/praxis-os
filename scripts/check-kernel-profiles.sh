#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
choice_dir="$repo_root/config/choices/kernel"
profile_dir="$repo_root/kernel/profiles"

for profile in stock tiny hardened; do
  choice_file="$choice_dir/$profile.conf"
  profile_file="$profile_dir/$profile.fragment"

  [[ -f "$choice_file" ]] || { printf 'missing kernel choice: %s\n' "$choice_file" >&2; exit 1; }
  [[ -f "$profile_file" ]] || { printf 'missing kernel profile fragment: %s\n' "$profile_file" >&2; exit 1; }
  [[ -s "$profile_file" ]] || { printf 'empty kernel profile fragment: %s\n' "$profile_file" >&2; exit 1; }

  grep -qx "NAME=$profile" "$choice_file" || {
    printf 'kernel choice NAME mismatch: %s\n' "$choice_file" >&2
    exit 1
  }

  grep -qx "CONFIG_FRAGMENT=/usr/share/praxis/kernel/profiles/$profile.fragment" "$choice_file" || {
    printf 'kernel choice CONFIG_FRAGMENT mismatch: %s\n' "$choice_file" >&2
    exit 1
  }

  while IFS= read -r option; do
    [[ -n "$option" ]] || continue
    [[ "$option" =~ ^# ]] && continue
    if [[ ! "$option" =~ ^CONFIG_[A-Z0-9_]+=(y|m|n)$ ]]; then
      printf 'invalid kernel option in %s: %s\n' "$profile_file" "$option" >&2
      exit 1
    fi
  done < "$profile_file"
done

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cat > "$tmpdir/bad.fragment" <<'EOF'
VT
CONFIG_GOOD=y
CONFIG_BAD=maybe
EOF
if awk '
  /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
  $0 !~ /^CONFIG_[A-Z0-9_]+=(y|m|n)$/ { bad = 1 }
  END { exit bad ? 0 : 1 }
' "$tmpdir/bad.fragment"; then
  :
else
  printf 'kernel profile negative fixture did not detect bad syntax\n' >&2
  exit 1
fi

printf 'Kernel profile check passed.\n'
