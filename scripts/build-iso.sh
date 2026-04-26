#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
initramfs_path="${1:-"$repo_root/build/praxis-initramfs.cpio.gz"}"
iso_stage="${2:-"$repo_root/build/iso"}"
iso_file="${3:-"$repo_root/build/praxis.iso"}"

pick_kernel_image() {
  if [[ -n "${KERNEL_IMAGE:-}" && -f "${KERNEL_IMAGE}" ]]; then
    printf '%s\n' "${KERNEL_IMAGE}"
    return 0
  fi

  if [[ -f "$repo_root/kernel/bzImage" ]]; then
    printf '%s\n' "$repo_root/kernel/bzImage"
    return 0
  fi

  if [[ "${PRAXIS_ALLOW_HOST_KERNEL:-0}" == "1" ]]; then
    local host_kernel="/lib/modules/$(uname -r)/vmlinuz"
    if [[ -f "$host_kernel" ]]; then
      printf '%s\n' "$host_kernel"
      return 0
    fi
  fi

  return 1
}

if [[ ! -f "$initramfs_path" ]]; then
  echo "missing initramfs: $initramfs_path" >&2
  exit 1
fi

kernel_image="$(pick_kernel_image || true)"
if [[ -z "${kernel_image:-}" ]]; then
  echo "missing kernel image; run make kernel, place one at kernel/bzImage, or set KERNEL_IMAGE" >&2
  exit 1
fi

rm -rf "$iso_stage"
mkdir -p "$iso_stage/EFI/BOOT"

cp "$kernel_image" "$iso_stage/vmlinuz"
cp "$initramfs_path" "$iso_stage/initramfs.cpio.gz"
cp "$repo_root/boot/limine.conf" "$iso_stage/limine.conf"

if [[ "${PRAXIS_ALLOW_HOST_KERNEL:-0}" == "1" && "$kernel_image" == "/lib/modules/$(uname -r)/vmlinuz" ]]; then
  printf 'Using host kernel fallback: %s\n' "$kernel_image"
fi

if ! command -v limine >/dev/null 2>&1; then
  echo "missing required tool: limine" >&2
  exit 1
fi

limine_dir="${LIMINE_DIR:-$(limine --print-datadir 2>/dev/null || true)}"
if [[ -z "$limine_dir" || ! -d "$limine_dir" ]]; then
  echo "missing limine data directory" >&2
  exit 1
fi

if [[ ! -f "$limine_dir/limine-bios.sys" || ! -f "$limine_dir/limine-bios-cd.bin" ]]; then
  echo "missing required BIOS limine files" >&2
  exit 1
fi

cp "$limine_dir/limine-bios.sys" "$iso_stage/limine-bios.sys"
cp "$limine_dir/limine-bios-cd.bin" "$iso_stage/limine-bios-cd.bin"

if [[ -f "$limine_dir/limine-uefi-cd.bin" ]]; then
  cp "$limine_dir/limine-uefi-cd.bin" "$iso_stage/limine-uefi-cd.bin"
fi

if [[ -f "$limine_dir/BOOTX64.EFI" ]]; then
  cp "$limine_dir/BOOTX64.EFI" "$iso_stage/EFI/BOOT/BOOTX64.EFI"
fi

if command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs \
    -quiet \
    -R \
    -r \
    -J \
    -b limine-bios-cd.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e EFI/BOOT/BOOTX64.EFI \
    -no-emul-boot \
    -o "$iso_file" \
    "$iso_stage"
elif command -v mkisofs >/dev/null 2>&1; then
  mkisofs \
    -quiet \
    -R \
    -r \
    -J \
    -b limine-bios-cd.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e EFI/BOOT/BOOTX64.EFI \
    -no-emul-boot \
    -o "$iso_file" \
    "$iso_stage"
else
  echo "missing required tool: xorriso or mkisofs" >&2
  exit 1
fi

limine bios-install "$iso_file"

printf 'Built Praxis ISO at %s\n' "$iso_file"
