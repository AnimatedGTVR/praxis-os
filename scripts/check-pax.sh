#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pax_root="$repo_root/pax"
examples_root="$pax_root/examples"

required_examples=(
  "packageinstall-config.pax"
  "liveboot-config.boot.pax"
  "workstation-config.profile.pax"
  "core-packages.profile.pax"
  "source-pkg.pkg.pax"
  "ricing-desktop.profile.pax"
  "hardware-check.pax"
  "core-system-config.pax"
)

stale_examples=(
  "sourcepkg-config.pkg.pax"
  "sourceforge.pkg.pax"
  "default-packages.profile.pax"
  "default-source.pkg.pax"
  "default-desktop.profile.pax"
  "default-hardware.pax"
  "default-system-config.pax"
)

for example in "${required_examples[@]}"; do
  test -f "$examples_root/$example"
done

for stale in "${stale_examples[@]}"; do
  test ! -e "$examples_root/$stale"
done

while IFS= read -r pax_file; do
  header_line="$(awk 'NF { print; exit }' "$pax_file")"
  if [[ ! "$header_line" =~ ^\[\.Praxis\ Config\ -\ .+\ \.praxis\.pax\./\]$ ]]; then
    printf 'invalid Praxis header in %s\n' "$pax_file" >&2
    exit 1
  fi
done < <(find "$examples_root" -maxdepth 1 -type f -name '*.pax' | sort)

for doc_file in "$repo_root/pax/README.md" "$repo_root/Documentation/DOC.md"; do
  while IFS= read -r referenced; do
    example_path="${repo_root}/${referenced}"
    test -f "$example_path"
  done < <(rg -o 'pax/examples/[A-Za-z0-9._-]+\.pax' "$doc_file" | sort -u)
done

printf 'PAX sanity check passed.\n'
