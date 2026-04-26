#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
stage_dir="${1:-}"
tmpdir=""

cleanup() {
  if [[ -n "$tmpdir" ]]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

fail() {
  printf 'owned rootfs check failed: %s\n' "$*" >&2
  exit 1
}

if [[ -z "$stage_dir" ]]; then
  tmpdir="$(mktemp -d)"
  stage_dir="$tmpdir/rootfs"
  "$repo_root/scripts/build-rootfs.sh" "$stage_dir" >/dev/null
fi

[[ -d "$stage_dir" ]] || fail "missing rootfs stage: $stage_dir"
[[ -x "$stage_dir/bin/busybox" ]] || fail "missing static Praxis BusyBox at /bin/busybox"
[[ -L "$stage_dir/bin/sh" ]] || fail "missing /bin/sh BusyBox symlink"
[[ -f "$stage_dir/usr/share/praxis/vmlinuz" ]] || fail "missing Praxis kernel image"
[[ -f "$stage_dir/usr/share/praxis/boot/BOOTX64.EFI" ]] || fail "missing Limine UEFI boot artifact"

case "$(readlink "$stage_dir/bin/sh")" in
  busybox) ;;
  *) fail "/bin/sh should point to busybox with a relative symlink" ;;
esac

if find "$stage_dir/bin" -maxdepth 1 -type l -lname '/*' | grep -q .; then
  find "$stage_dir/bin" -maxdepth 1 -type l -lname '/*' -print >&2
  fail "absolute symlinks found in /bin"
fi

if find "$stage_dir" -xdev -type l -lname "$repo_root/*" | grep -q .; then
  find "$stage_dir" -xdev -type l -lname "$repo_root/*" -print >&2
  fail "rootfs symlinks point back into the build checkout"
fi

[[ ! -e "$stage_dir/bin/bash" ]] || fail "host bash is present in default rootfs"
[[ ! -e "$stage_dir/usr/bin/pacman" ]] || fail "host pacman is present in default rootfs"
[[ ! -e "$stage_dir/etc/pacman.conf" ]] || fail "host pacman.conf is present in default rootfs"
[[ ! -s "$stage_dir/etc/pacman.d/mirrorlist" ]] || fail "host pacman mirrorlist is present in default rootfs"

if command -v ldd >/dev/null 2>&1; then
  if ldd "$stage_dir/bin/busybox" 2>&1 | grep -vq 'not a dynamic executable'; then
    ldd "$stage_dir/bin/busybox" >&2 || true
    fail "Praxis BusyBox must be static"
  fi
fi

printf 'Praxis owned rootfs check passed.\n'
