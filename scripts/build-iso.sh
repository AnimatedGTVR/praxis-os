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
mkdir -p "$iso_stage/boot/limine"

cp "$kernel_image" "$iso_stage/vmlinuz"
cp "$initramfs_path" "$iso_stage/initramfs.cpio.gz"
# Copy config to all paths Limine 12.x searches, in priority order:
# /boot/limine/limine.conf (first), /boot/limine.conf, /EFI/BOOT/limine.conf, /limine.conf (last)
cp "$repo_root/boot/limine.conf" "$iso_stage/boot/limine/limine.conf"
cp "$repo_root/boot/limine.conf" "$iso_stage/boot/limine.conf"
cp "$repo_root/boot/limine.conf" "$iso_stage/EFI/BOOT/limine.conf"
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
cp "$limine_dir/limine-bios.sys" "$iso_stage/boot/limine/limine-bios.sys"
cp "$limine_dir/limine-bios-cd.bin" "$iso_stage/limine-bios-cd.bin"

if [[ -f "$limine_dir/limine-uefi-cd.bin" ]]; then
  cp "$limine_dir/limine-uefi-cd.bin" "$iso_stage/limine-uefi-cd.bin"
fi

if [[ -f "$limine_dir/BOOTX64.EFI" ]]; then
  cp "$limine_dir/BOOTX64.EFI" "$iso_stage/EFI/BOOT/BOOTX64.EFI"
fi

"$repo_root/scripts/build-metadata.sh" \
  "$iso_stage/praxis-build-info" \
  "$kernel_image" \
  "$initramfs_path"

(
  cd "$iso_stage"
  find . -type f \
    ! -path './praxis-stage.sha256' \
    -print0 |
    sort -z |
    xargs -0 sha256sum > praxis-stage.sha256
)

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
  if ! [[ "$SOURCE_DATE_EPOCH" =~ ^[0-9]+$ ]]; then
    echo "SOURCE_DATE_EPOCH must be an integer epoch value" >&2
    exit 1
  fi
  # xorriso derives its ISO9660 PVD and per-file timestamps from
  # SOURCE_DATE_EPOCH automatically (see xorrisofs(1)), but only for files
  # whose own mtime already matches; normalize the staging tree first so
  # two builds from identical inputs produce byte-identical output.
  find "$iso_stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
fi

if ! command -v xorriso >/dev/null 2>&1; then
  echo "missing required tool: xorriso" >&2
  exit 1
fi

efi_boot_args=()
if [[ -f "$iso_stage/limine-uefi-cd.bin" ]]; then
  efi_boot_args=(--efi-boot limine-uefi-cd.bin -efi-boot-part --efi-boot-image)
fi

xorriso -as mkisofs \
  -quiet \
  -R \
  -r \
  -J \
  -b limine-bios-cd.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  "${efi_boot_args[@]}" \
  -o "$iso_file" \
  "$iso_stage"

limine bios-install "$iso_file"

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
  command -v python3 >/dev/null 2>&1 || {
    echo "missing required tool: python3 (needed to normalize the MBR disk signature for SOURCE_DATE_EPOCH)" >&2
    exit 1
  }
  # limine bios-install writes a fresh MBR disk signature (4 bytes at the
  # standard offset 440) derived from the current wall clock, with no flag
  # to override it. That alone makes two otherwise-identical builds differ,
  # so replace it with a value deterministically derived from
  # SOURCE_DATE_EPOCH. The signature is cosmetic for boot (verified via a
  # real QEMU smoke boot with a patched ISO); this only affects
  # reproducibility, not bootability.
  python3 - "$iso_file" "$SOURCE_DATE_EPOCH" <<'PY'
import struct
import sys

iso_path, epoch = sys.argv[1], int(sys.argv[2])
with open(iso_path, "r+b") as f:
    f.seek(440)
    f.write(struct.pack("<I", epoch & 0xFFFFFFFF))
PY
fi

"$repo_root/scripts/build-metadata.sh" \
  "$iso_file.build-info" \
  "$iso_file" \
  "$kernel_image" \
  "$initramfs_path"
sha256sum "$iso_file" > "$iso_file.sha256"

printf 'Built Praxis ISO at %s\n' "$iso_file"
