#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$repo_root/installer/praxis-pkg"

mkdir -p "$tmpdir/pkg/data/usr/share/praxis/packages"
cat > "$tmpdir/pkg/PKGINFO" <<'EOF'
id = dev.praxis.sample
version = 1.0.0-1
desc = Praxis sample package
arch = any
deps = dev.praxis.base
EOF
printf 'sample\n' > "$tmpdir/pkg/data/usr/share/praxis/packages/sample.txt"

tar -C "$tmpdir/pkg" -czf "$tmpdir/dev.praxis.sample-1.0.0-1.prx" PKGINFO data

"$repo_root/installer/praxis-pkg" validate-pkginfo "$tmpdir/pkg/PKGINFO" >/dev/null
"$repo_root/installer/praxis-pkg" inspect "$tmpdir/dev.praxis.sample-1.0.0-1.prx" >/dev/null
mkdir -p "$tmpdir/target"
"$repo_root/installer/praxis-pkg" install-local --root "$tmpdir/target" "$tmpdir/dev.praxis.sample-1.0.0-1.prx" >/dev/null 2>/dev/null
test -f "$tmpdir/target/usr/share/praxis/packages/sample.txt"
test -f "$tmpdir/target/var/lib/praxis-pkg/installed/dev.praxis.sample.PKGINFO"
test -f "$tmpdir/target/var/lib/praxis-pkg/installed/dev.praxis.sample.files"
test -f "$tmpdir/target/var/lib/praxis-pkg/installed/dev.praxis.sample.install"
grep -qx '/usr/share/praxis/packages/sample.txt' "$tmpdir/target/var/lib/praxis-pkg/installed/dev.praxis.sample.files"

if "$repo_root/installer/praxis-pkg" install-local --root / "$tmpdir/dev.praxis.sample-1.0.0-1.prx" >/dev/null 2>&1; then
  printf 'install-local unexpectedly accepted /\n' >&2
  exit 1
fi

printf 'dev.praxis.sample\t1.0.0-1\tPraxis sample package\tdev.praxis.sample-1.0.0-1.prx\n' > "$tmpdir/INDEX"
gzip -n -c "$tmpdir/INDEX" > "$tmpdir/INDEX.gz"
"$repo_root/installer/praxis-pkg" validate-index "$tmpdir/INDEX" >/dev/null
"$repo_root/installer/praxis-pkg" validate-index "$tmpdir/INDEX.gz" >/dev/null

cat > "$tmpdir/bad.PKGINFO" <<'EOF'
id = sample
version = nope
desc = Bad package
arch = x86_64
EOF
if "$repo_root/installer/praxis-pkg" validate-pkginfo "$tmpdir/bad.PKGINFO" >/dev/null 2>&1; then
  printf 'bad PKGINFO unexpectedly passed\n' >&2
  exit 1
fi

printf 'dev.praxis.sample\t1.0.0-1\tduplicate\tdev.praxis.sample-1.0.0-1.prx\n' >> "$tmpdir/INDEX"
if "$repo_root/installer/praxis-pkg" validate-index "$tmpdir/INDEX" >/dev/null 2>&1; then
  printf 'bad INDEX unexpectedly passed\n' >&2
  exit 1
fi

printf 'Package format check passed.\n'
