#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
userspace_dir="$repo_root/userspace"
source_dir_override="${BUSYBOX_SOURCE_DIR:-}"
build_dir_override="${BUSYBOX_BUILD_DIR:-}"
artifact_path="${BUSYBOX_ARTIFACT:-$userspace_dir/busybox}"
requested_version="${BUSYBOX_VERSION:-latest}"
jobs="${BUSYBOX_JOBS:-$(nproc 2>/dev/null || printf '1')}"

require_tool() {
  local tool_name="$1"

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "missing required userspace build tool: $tool_name" >&2
    exit 1
  fi
}

resolve_busybox_version() {
  if [[ "$requested_version" != "latest" ]]; then
    printf '%s\n' "$requested_version"
    return 0
  fi

  require_tool python3

  python3 - <<'PY'
import re
import urllib.request

def version_key(value):
    return tuple(int(part) for part in value.split("."))

with urllib.request.urlopen("https://busybox.net/downloads/", timeout=30) as response:
    html = response.read().decode("utf-8", errors="replace")

versions = sorted(
    {match for match in re.findall(r"busybox-([0-9]+\.[0-9]+\.[0-9]+)\.tar\.bz2", html)},
    key=version_key,
)

if not versions:
    raise SystemExit("could not resolve latest BusyBox release")

print(versions[-1])
PY
}

fetch_busybox_source() {
  local version="$1"
  local tarball="busybox-$version.tar.bz2"
  local tarball_path="$repo_root/build/userspace/$tarball"
  local url="https://busybox.net/downloads/$tarball"

  mkdir -p "$repo_root/build/userspace"

  if [[ ! -f "$tarball_path" ]]; then
    printf 'Fetching BusyBox %s from %s\n' "$version" "$url"
    require_tool curl
    curl -fL "$url" -o "$tarball_path"
  fi

  if [[ ! -d "$source_dir" || ! -f "$source_dir/Makefile" ]]; then
    rm -rf "$source_dir"
    mkdir -p "$(dirname "$source_dir")"
    require_tool tar
    tar -xjf "$tarball_path" -C "$(dirname "$source_dir")"
    if [[ "$(dirname "$source_dir")/busybox-$version" != "$source_dir" ]]; then
      mv "$(dirname "$source_dir")/busybox-$version" "$source_dir"
    fi
  fi
}

for tool in make gcc awk sed bzip2; do
  require_tool "$tool"
done

busybox_version="$(resolve_busybox_version)"
source_dir="${source_dir_override:-$repo_root/build/userspace/source/busybox-$busybox_version}"
build_dir="${build_dir_override:-$repo_root/build/userspace/build/busybox-$busybox_version}"
fetch_busybox_source "$busybox_version"

mkdir -p "$build_dir" "$userspace_dir"

make -C "$source_dir" O="$build_dir" defconfig
sed -i \
  -e 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' \
  -e 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' \
  -e 's/^CONFIG_FEATURE_TC_INGRESS=y$/# CONFIG_FEATURE_TC_INGRESS is not set/' \
  "$build_dir/.config"
set +o pipefail
yes "" | make -C "$source_dir" O="$build_dir" oldconfig
oldconfig_status=$?
set -o pipefail
if [[ "$oldconfig_status" -ne 0 && "$oldconfig_status" -ne 141 ]]; then
  exit "$oldconfig_status"
fi
make -C "$source_dir" O="$build_dir" -j"$jobs" busybox

install -Dm755 "$build_dir/busybox" "$artifact_path"
printf '%s\n' "$busybox_version" > "$userspace_dir/BUSYBOX_VERSION"

printf 'Built Praxis BusyBox %s at %s\n' "$busybox_version" "$artifact_path"
