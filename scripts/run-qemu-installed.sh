#!/usr/bin/env bash

set -euo pipefail

disk_file="${1:-}"
repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
memory="${MEMORY:-2048}"
cpus="${CPUS:-2}"
disk_format="${QEMU_DISK_FORMAT:-qcow2}"
vars_file="${PRAXIS_QEMU_OVMF_VARS_FILE:-}"
reset_vars="${PRAXIS_QEMU_RESET_VARS:-1}"
disk_bus="${QEMU_DISK_BUS:-virtio}"

find_ovmf_code() {
  local candidate

  for candidate in \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF_CODE.fd
  do
    [[ -f "$candidate" ]] && printf '%s\n' "$candidate" && return 0
  done

  return 1
}

find_ovmf_vars_template() {
  local candidate

  for candidate in \
    /usr/share/edk2/x64/OVMF_VARS.4m.fd \
    /usr/share/edk2/x64/OVMF_VARS.fd \
    /usr/share/OVMF/OVMF_VARS.fd
  do
    [[ -f "$candidate" ]] && printf '%s\n' "$candidate" && return 0
  done

  return 1
}

if [[ -z "$disk_file" ]]; then
  echo "usage: $0 <disk-file>" >&2
  exit 1
fi

if [[ ! -f "$disk_file" ]]; then
  echo "missing QEMU disk: $disk_file" >&2
  exit 1
fi

if [[ ! -r "$disk_file" && "${EUID}" -ne 0 ]]; then
  sudo chown "$(id -u):$(id -g)" "$disk_file"
fi

if [[ ! -r "$disk_file" ]]; then
  echo "QEMU disk is not readable: $disk_file" >&2
  exit 1
fi

if [[ "${PRAXIS_QEMU_REPAIR_ESP:-1}" == "1" ]]; then
  "$repo_root/scripts/repair-qemu-esp.sh" "$disk_file" "$repo_root/build/rootfs"
fi

if [[ "${EUID}" -eq 0 && -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" && -e "$disk_file" ]]; then
  chown "$SUDO_UID:$SUDO_GID" "$disk_file" 2>/dev/null || true
fi

command -v qemu-system-x86_64 >/dev/null 2>&1 || {
  echo "missing required tool: qemu-system-x86_64" >&2
  exit 1
}

ovmf_code="$(find_ovmf_code || true)"
if [[ -z "$ovmf_code" ]]; then
  echo "missing required UEFI firmware: OVMF_CODE.fd" >&2
  exit 1
fi

ovmf_vars_template="$(find_ovmf_vars_template || true)"
if [[ -z "$ovmf_vars_template" ]]; then
  echo "missing required UEFI firmware vars template: OVMF_VARS.fd" >&2
  exit 1
fi

if [[ -z "$vars_file" ]]; then
  vars_file="$(dirname "$disk_file")/$(basename "${disk_file%.*}")-OVMF_VARS.fd"
fi

mkdir -p "$(dirname "$vars_file")"
if [[ "$reset_vars" == "1" ]]; then
  rm -f "$vars_file"
fi
if [[ ! -f "$vars_file" ]]; then
  cp "$ovmf_vars_template" "$vars_file"
fi

disk_args=()
case "$disk_bus" in
  virtio)
    disk_args=(
      -drive "if=none,id=praxisdisk,file=$disk_file,format=$disk_format"
      -device virtio-blk-pci,drive=praxisdisk,bootindex=1
    )
    ;;
  ide)
    disk_args=(
      -drive "if=none,id=praxisdisk,file=$disk_file,format=$disk_format"
      -device ide-hd,drive=praxisdisk,bootindex=1
    )
    ;;
  *)
    echo "unsupported QEMU_DISK_BUS: $disk_bus" >&2
    exit 1
    ;;
esac

input_args=(
  -device qemu-xhci,id=xhci
  -device usb-kbd,bus=xhci.0
  -device usb-tablet,bus=xhci.0
)

kvm_args=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  kvm_args=(-enable-kvm)
fi

vga_type="${QEMU_VGA:-virtio}"

ui="${QEMU_UI:-gtk}"
case "$ui" in
  gtk)
    ui_args=(-display gtk -serial none -monitor none)
    ;;
  sdl)
    ui_args=(-display sdl -serial none -monitor none)
    ;;
  *)
    echo "installed-disk boot supports QEMU_UI=gtk or QEMU_UI=sdl" >&2
    exit 1
    ;;
esac

if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  echo "QEMU graphical mode needs a graphical session." >&2
  exit 1
fi

extra_args=()
if [[ -n "${QEMU_EXTRA_ARGS:-}" ]]; then
  read -r -a extra_args <<< "${QEMU_EXTRA_ARGS}"
fi

exec qemu-system-x86_64 \
  "${kvm_args[@]}" \
  -m "$memory" \
  -smp "$cpus" \
  -vga "$vga_type" \
  "${ui_args[@]}" \
  -no-reboot \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$vars_file" \
  "${disk_args[@]}" \
  "${input_args[@]}" \
  "${extra_args[@]}"
