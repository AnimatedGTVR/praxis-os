#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:-}"
shift || true

if [[ -z "$output_path" ]]; then
  echo "usage: $0 <output-path> [artifact ...]" >&2
  exit 1
fi

build_epoch="${SOURCE_DATE_EPOCH:-$(date -u +%s)}"
if ! [[ "$build_epoch" =~ ^[0-9]+$ ]]; then
  echo "SOURCE_DATE_EPOCH must be an integer epoch value" >&2
  exit 1
fi

build_date="$(date -u -d "@$build_epoch" +%Y-%m-%dT%H:%M:%SZ)"
git_commit="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null || printf 'unknown')"
git_dirty="unknown"
if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$repo_root" diff --quiet --ignore-submodules -- &&
      git -C "$repo_root" diff --cached --quiet --ignore-submodules --; then
    git_dirty="0"
  else
    git_dirty="1"
  fi
fi

mkdir -p "$(dirname -- "$output_path")"

{
  printf 'BUILD_EPOCH=%s\n' "$build_epoch"
  printf 'BUILD_DATE=%s\n' "$build_date"
  printf 'BUILD_SOURCE=%s\n' "$repo_root"
  printf 'BUILD_GIT_COMMIT=%s\n' "$git_commit"
  printf 'BUILD_GIT_DIRTY=%s\n' "$git_dirty"
  printf 'BUILD_REPRODUCIBLE_HINT=export SOURCE_DATE_EPOCH=%s\n' "$build_epoch"
  printf 'BUILD_ARTIFACT_COUNT=%s\n' "$#"
  artifact_index=0
  for artifact_path in "$@"; do
    artifact_index=$((artifact_index + 1))
    if [[ -f "$artifact_path" ]]; then
      artifact_sum="$(sha256sum "$artifact_path" | awk '{print $1}')"
      printf 'BUILD_ARTIFACT_%s=%s\n' "$artifact_index" "$artifact_path"
      printf 'BUILD_ARTIFACT_%s_SHA256=%s\n' "$artifact_index" "$artifact_sum"
    else
      printf 'BUILD_ARTIFACT_%s=%s\n' "$artifact_index" "$artifact_path"
      printf 'BUILD_ARTIFACT_%s_SHA256=missing\n' "$artifact_index"
    fi
  done
} > "$output_path"
