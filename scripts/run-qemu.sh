#!/usr/bin/env bash

set -euo pipefail

iso_file="${1:-}"
mode="${QEMU_MODE:-interactive}"
timeout_seconds="${QEMU_TIMEOUT:-25}"
memory="${MEMORY:-2048}"
cpus="${CPUS:-2}"
artifact_dir="$(dirname "${iso_file:-.}")"
kernel_file="${PRAXIS_QEMU_KERNEL:-$artifact_dir/iso/vmlinuz}"
initramfs_file="${PRAXIS_QEMU_INITRAMFS:-$artifact_dir/iso/initramfs.cpio.gz}"
serial_cmdline="${PRAXIS_QEMU_SERIAL_CMDLINE:-rdinit=/init praxis.live=1 console=ttyS0,115200 loglevel=7}"

if [[ -n "${QEMU_UI:-}" ]]; then
  ui="${QEMU_UI}"
elif [[ "$mode" == "smoke" ]]; then
  ui="nographic"
else
  ui="gtk"
fi

if [[ -z "$iso_file" ]]; then
  echo "usage: $0 <iso-file>" >&2
  exit 1
fi

if [[ ! -f "$iso_file" ]]; then
  echo "missing ISO: $iso_file" >&2
  exit 1
fi

command -v qemu-system-x86_64 >/dev/null 2>&1 || {
  echo "missing required tool: qemu-system-x86_64" >&2
  exit 1
}

kvm_args=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  kvm_args=(-enable-kvm)
fi

ui_args=()
case "$ui" in
  nographic)
    ui_args=(-nographic -monitor none)
    ;;
  stdio)
    ui_args=(-display none -serial stdio -monitor none)
    ;;
  gtk)
    ui_args=(-display gtk -serial none -monitor none)
    ;;
  sdl)
    ui_args=(-display sdl -serial none -monitor none)
    ;;
  *)
    echo "unsupported QEMU_UI: $ui" >&2
    exit 1
    ;;
esac

if [[ "$ui" == "gtk" || "$ui" == "sdl" ]] && [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  echo "QEMU graphical mode needs a graphical session. Use QEMU_UI=nographic make qemu or make smoke." >&2
  exit 1
fi

extra_args=()
if [[ -n "${QEMU_EXTRA_ARGS:-}" ]]; then
  read -r -a extra_args <<< "${QEMU_EXTRA_ARGS}"
fi

base_qemu_cmd=(
  qemu-system-x86_64
  "${kvm_args[@]}"
  -m "$memory"
  -smp "$cpus"
  "${ui_args[@]}"
  -no-reboot
  "${extra_args[@]}"
)

if [[ "$mode" == "smoke" || "$ui" == "nographic" || "$ui" == "stdio" ]]; then
  if [[ ! -f "$kernel_file" ]]; then
    echo "missing QEMU kernel artifact: $kernel_file" >&2
    exit 1
  fi

  if [[ ! -f "$initramfs_file" ]]; then
    echo "missing QEMU initramfs artifact: $initramfs_file" >&2
    exit 1
  fi

  qemu_cmd=(
    "${base_qemu_cmd[@]}"
    -kernel "$kernel_file"
    -initrd "$initramfs_file"
    -append "$serial_cmdline"
  )
else
  qemu_cmd=(
    "${base_qemu_cmd[@]}"
    -boot d
    -cdrom "$iso_file"
  )
fi

if [[ "$mode" == "smoke" ]]; then
  command -v timeout >/dev/null 2>&1 || {
    echo "missing required tool for smoke mode: timeout" >&2
    exit 1
  }

  log_file="$(mktemp)"
  trap 'rm -f "$log_file"' EXIT

  set +e
  timeout "${timeout_seconds}s" "${qemu_cmd[@]}" >"$log_file" 2>&1
  status=$?
  set -e

  cat "$log_file"

  if grep -Eq 'praxis#|Praxis shell ready' "$log_file"; then
    printf 'Praxis smoke boot passed.\n'
    exit 0
  fi

  if [[ $status -eq 124 ]]; then
    echo "QEMU smoke timed out before Praxis reached the shell prompt." >&2
  fi
  exit 1
fi

exec "${qemu_cmd[@]}"
