#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
userspace_dir="$repo_root/userspace/s6"
build_root="${S6_BUILD_ROOT:-$repo_root/build/s6}"
jobs="${S6_JOBS:-$(nproc 2>/dev/null || printf '1')}"

skalibs_version="${SKALIBS_VERSION:-2.15.1.0}"
execline_version="${EXECLINE_VERSION:-2.9.9.2}"
s6_version="${S6_VERSION:-2.15.1.0}"

require_tool() {
  local tool_name="$1"

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "missing required s6 build tool: $tool_name" >&2
    exit 1
  fi
}

for tool in make gcc curl tar; do
  require_tool "$tool"
done

stage_dir="$build_root/stage"
rm -rf "$stage_dir"
mkdir -p "$stage_dir" "$build_root/source" "$userspace_dir"

fetch_and_extract() {
  local project="$1" version="$2"
  local tarball="$build_root/source/$project-$version.tar.gz"
  local url="https://github.com/skarnet/$project/archive/refs/tags/v$version.tar.gz"
  local source_dir="$build_root/source/$project-$version"

  if [[ ! -f "$tarball" ]]; then
    printf 'Fetching %s %s from %s\n' "$project" "$version" "$url" >&2
    curl -fL "$url" -o "$tarball"
  fi

  if [[ ! -d "$source_dir" || ! -f "$source_dir/configure" ]]; then
    rm -rf "$source_dir"
    tar -xzf "$tarball" -C "$build_root/source"
  fi

  printf '%s\n' "$source_dir"
}

build_skarnet_project() {
  local source_dir="$1"
  shift
  local extra_configure_args=("$@")

  (
    cd "$source_dir"
    make distclean >/dev/null 2>&1 || true
    ./configure \
      --prefix="$stage_dir" \
      --disable-shared \
      --enable-static-libc \
      --enable-all-pic \
      "${extra_configure_args[@]}"
    make -j"$jobs"
    make install
  )
}

skalibs_source="$(fetch_and_extract skalibs "$skalibs_version")"
build_skarnet_project "$skalibs_source"

execline_source="$(fetch_and_extract execline "$execline_version")"
build_skarnet_project "$execline_source" \
  --with-include="$stage_dir/include" \
  --with-lib="$stage_dir/lib"

s6_source="$(fetch_and_extract s6 "$s6_version")"
build_skarnet_project "$s6_source" \
  --with-include="$stage_dir/include" \
  --with-lib="$stage_dir/lib" \
  --with-sysdeps="$stage_dir/lib/skalibs/sysdeps"

rm -rf "$userspace_dir"
mkdir -p "$userspace_dir/bin"
for binary in "$stage_dir/bin/"*; do
  [[ -f "$binary" ]] || continue
  strip -s "$binary" 2>/dev/null || true
  install -Dm755 "$binary" "$userspace_dir/bin/$(basename "$binary")"
done

{
  printf 'skalibs=%s\n' "$skalibs_version"
  printf 'execline=%s\n' "$execline_version"
  printf 's6=%s\n' "$s6_version"
} > "$userspace_dir/VERSIONS"

printf 'Built Praxis s6 (skalibs %s, execline %s, s6 %s) at %s\n' \
  "$skalibs_version" "$execline_version" "$s6_version" "$userspace_dir/bin"
