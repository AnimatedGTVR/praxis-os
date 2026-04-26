#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
kernel_dir="$repo_root/kernel"
source_dir_override="${KERNEL_SOURCE_DIR:-}"
build_dir_override="${KERNEL_BUILD_DIR:-}"
artifact_path="${KERNEL_ARTIFACT:-$kernel_dir/bzImage}"
requested_version="${KERNEL_VERSION:-latest}"
kernel_arch="${KERNEL_MAKE_ARCH:-x86}"
kernel_config="${KERNEL_CONFIG:-$kernel_dir/config}"
kernel_config_fragment="${KERNEL_CONFIG_FRAGMENT:-$kernel_dir/config.fragment}"
jobs="${KERNEL_JOBS:-$(nproc 2>/dev/null || printf '1')}"

require_tool() {
  local tool_name="$1"

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "missing required kernel build tool: $tool_name" >&2
    exit 1
  fi
}

resolve_kernel_version() {
  if [[ "$requested_version" != "latest" ]]; then
    printf '%s\n' "$requested_version"
    return 0
  fi

  require_tool python3

  python3 - <<'PY'
import json
import urllib.request

with urllib.request.urlopen("https://www.kernel.org/releases.json", timeout=30) as response:
    releases = json.load(response)["releases"]

for release in releases:
    if release.get("moniker") == "stable":
        print(release["version"])
        break
else:
    raise SystemExit("could not resolve latest stable kernel from kernel.org")
PY
}

kernel_major_series() {
  local version="$1"
  local major="${version%%.*}"

  printf 'v%s.x\n' "$major"
}

fetch_kernel_source() {
  local version="$1"
  local series
  local tarball
  local tarball_path
  local url

  series="$(kernel_major_series "$version")"
  tarball="linux-$version.tar.xz"
  tarball_path="$repo_root/build/kernel/$tarball"
  url="https://cdn.kernel.org/pub/linux/kernel/$series/$tarball"

  mkdir -p "$repo_root/build/kernel"

  if [[ ! -f "$tarball_path" ]]; then
    printf 'Fetching Linux %s from %s\n' "$version" "$url"
    require_tool curl
    curl -fL "$url" -o "$tarball_path"
  fi

  if [[ ! -d "$source_dir" || ! -f "$source_dir/Makefile" ]]; then
    rm -rf "$source_dir"
    mkdir -p "$(dirname "$source_dir")"
    require_tool tar
    tar -xJf "$tarball_path" -C "$(dirname "$source_dir")"
    if [[ "$(dirname "$source_dir")/linux-$version" != "$source_dir" ]]; then
      mv "$(dirname "$source_dir")/linux-$version" "$source_dir"
    fi
  fi
}

enable_kernel_option() {
  local option="$1"

  "$source_dir/scripts/config" --file "$build_dir/.config" --enable "$option"
}

for tool in make gcc perl awk sed xz flex bison bc; do
  require_tool "$tool"
done

kernel_version="$(resolve_kernel_version)"
source_dir="${source_dir_override:-$repo_root/build/kernel/source/linux-$kernel_version}"
build_dir="${build_dir_override:-$repo_root/build/kernel/build/linux-$kernel_version}"
fetch_kernel_source "$kernel_version"

mkdir -p "$build_dir" "$kernel_dir"

if [[ -f "$kernel_config" ]]; then
  install -Dm644 "$kernel_config" "$build_dir/.config"
  make -C "$source_dir" O="$build_dir" ARCH="$kernel_arch" olddefconfig
else
  make -C "$source_dir" O="$build_dir" ARCH="$kernel_arch" defconfig
fi

if [[ -f "$kernel_config_fragment" ]]; then
  while read -r config_line; do
    [[ -n "$config_line" ]] || continue
    [[ "$config_line" =~ ^# ]] && continue
    enable_kernel_option "$config_line"
  done < "$kernel_config_fragment"
  make -C "$source_dir" O="$build_dir" ARCH="$kernel_arch" olddefconfig
fi

make -C "$source_dir" O="$build_dir" ARCH="$kernel_arch" -j"$jobs" bzImage

install -Dm644 "$build_dir/arch/x86/boot/bzImage" "$artifact_path"
printf '%s\n' "$kernel_version" > "$kernel_dir/VERSION"

printf 'Built Praxis kernel %s at %s\n' "$kernel_version" "$artifact_path"
