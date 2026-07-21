SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

BUILD_DIR := build
ROOTFS_STAGE := $(BUILD_DIR)/rootfs
INITRAMFS := $(BUILD_DIR)/praxis-initramfs.cpio.gz
ISO_STAGE := $(BUILD_DIR)/iso
ISO_FILE := $(BUILD_DIR)/praxis.iso
KERNEL_IMAGE := kernel/bzImage
BUSYBOX := userspace/busybox
S6_SVSCAN := userspace/s6/bin/s6-svscan
QEMU_DISK_FILE := $(BUILD_DIR)/praxis.qcow2
QEMU_DISK_SIZE ?= 16G

.PHONY: help kernel userspace s6 rootfs initramfs iso iso-full rootfs-full initramfs-full qemu QEMU qmec qemc qemu-disk qemu-chroot qemu-full qemu-install qemu-installed smoke dev-install check check-contract check-owned check-pkg-format check-init-profiles check-kernel-profiles check-manifests check-reproducible check-seeds check-target-audit v1-check v2-half-check v2-check clean

help:
	@echo "Praxis"
	@echo
	@echo "Targets:"
	@echo "  make rootfs     Stage the Praxis root filesystem"
	@echo "  make kernel PROFILE=stock|tiny|hardened Build the Praxis kernel artifact"
	@echo "  make userspace  Build the Praxis BusyBox userspace"
	@echo "  make s6         Build the s6 init toolset (skalibs+execline+s6, static)"
	@echo "  make initramfs  Build the Praxis initramfs"
	@echo "  make iso        Build the Praxis ISO"
	@echo "  make iso-full   Build the Praxis ISO with host tools vendored in"
	@echo "  make qemu       Boot the generated ISO in a QEMU window"
	@echo "  make qemu-disk  Create the default QEMU disk image"
	@echo "  make qemu-chroot Stage the QEMU disk and enter praxis-chroot"
	@echo "  make qemu-full DESKTOP=xfce Stage a desktop QEMU disk and boot it"
	@echo "  make qemu-full-xfce Stage an XFCE QEMU disk and boot it"
	@echo "  make qemu-install Boot the ISO with the default QEMU disk attached"
	@echo "  make qemu-installed Boot the installed QEMU disk with UEFI"
	@echo "  make QEMU       Alias for qemu"
	@echo "  make qmec       Alias for qemu"
	@echo "  make qemc       Alias for qemu"
	@echo "  make smoke      Verify Praxis reaches the shell prompt in QEMU"
	@echo "  make dev-install TARGET=/mnt/praxis-dev"
	@echo "  make check      Run shell and staging sanity checks"
	@echo "  make check-contract Validate contract export/inspect/verify"
	@echo "  make check-owned Verify the default rootfs uses Praxis-owned artifacts"
	@echo "  make check-pkg-format Validate .prx metadata and index rules"
	@echo "  make check-init-profiles Validate init choice/profile wiring"
	@echo "  make check-kernel-profiles Validate kernel choice/profile wiring"
	@echo "  make check-manifests Validate base-system and package manifests"
	@echo "  make check-reproducible Validate provenance and reproducible metadata"
	@echo "  make check-seeds Validate Praxis seed ledgers"
	@echo "  make check-target-audit Validate strict targetcheck behavior"
	@echo "  make v1-check   Run owned-rootfs, sanity, and smoke boot checks"
	@echo "  make v2-half-check Validate the Praxis v2-half contract"
	@echo "  make v2-check   Validate most of the Praxis v2 contract"
	@echo "  make clean      Remove build artifacts"

kernel: $(KERNEL_IMAGE)

$(KERNEL_IMAGE): scripts/build-kernel.sh kernel/config.fragment kernel/profiles/stock.fragment kernel/profiles/tiny.fragment kernel/profiles/hardened.fragment
	@./scripts/build-kernel.sh

userspace: $(BUSYBOX)

$(BUSYBOX):
	@./scripts/build-userspace.sh

s6: $(S6_SVSCAN)

$(S6_SVSCAN):
	@./scripts/build-s6.sh

rootfs: kernel userspace
	@./scripts/build-rootfs.sh "$(ROOTFS_STAGE)"

initramfs: rootfs
	@./scripts/build-initramfs.sh "$(ROOTFS_STAGE)" "$(INITRAMFS)"

iso: kernel initramfs
	@./scripts/build-iso.sh "$(INITRAMFS)" "$(ISO_STAGE)" "$(ISO_FILE)"

FULL_ROOTFS_STAGE := $(BUILD_DIR)/rootfs-full
FULL_INITRAMFS    := $(BUILD_DIR)/praxis-initramfs-full.cpio.gz
FULL_ISO_FILE     := $(BUILD_DIR)/praxis-full.iso
FULL_ISO_STAGE    := $(BUILD_DIR)/iso-full

rootfs-full: kernel userspace
	@PRAXIS_ALLOW_HOST_TOOLS=1 ./scripts/build-rootfs.sh "$(FULL_ROOTFS_STAGE)"

initramfs-full: rootfs-full
	@./scripts/build-initramfs.sh "$(FULL_ROOTFS_STAGE)" "$(FULL_INITRAMFS)"

iso-full: kernel initramfs-full
	@./scripts/build-iso.sh "$(FULL_INITRAMFS)" "$(FULL_ISO_STAGE)" "$(FULL_ISO_FILE)"

qemu: iso
	@./scripts/run-qemu.sh "$(ISO_FILE)"

QEMU: qemu

qmec: qemu

qemc: qemu

qemu-disk:
	@./scripts/create-qemu-disk.sh "$(QEMU_DISK_FILE)" "$(QEMU_DISK_SIZE)"

qemu-chroot: iso
	@./scripts/qemu-chroot.sh "$(QEMU_DISK_FILE)" "$(QEMU_DISK_SIZE)" "$(ROOTFS_STAGE)"

qemu-full: iso
	@[ -n "$(DESKTOP)" ] || { echo "usage: make qemu-full DESKTOP=xfce"; exit 1; }
	@PRAXIS_QEMU_DESKTOP="$(DESKTOP)" PRAXIS_QEMU_SKIP_CHROOT=1 ./scripts/qemu-chroot.sh "$(QEMU_DISK_FILE)" "$(QEMU_DISK_SIZE)" "$(ROOTFS_STAGE)"
	@$(MAKE) qemu-installed

qemu-full-%: iso
	@PRAXIS_QEMU_DESKTOP="$*" PRAXIS_QEMU_SKIP_CHROOT=1 ./scripts/qemu-chroot.sh "$(QEMU_DISK_FILE)" "$(QEMU_DISK_SIZE)" "$(ROOTFS_STAGE)"
	@$(MAKE) qemu-installed

qemu-install: iso qemu-disk
	@QEMU_EXTRA_ARGS="-drive file=$(QEMU_DISK_FILE),if=virtio,format=qcow2" ./scripts/run-qemu.sh "$(ISO_FILE)"

qemu-installed: qemu-disk
	@./scripts/run-qemu-installed.sh "$(QEMU_DISK_FILE)"

smoke: iso
	@QEMU_MODE=smoke QEMU_UI=nographic ./scripts/run-qemu.sh "$(ISO_FILE)"

dev-install: kernel
	@./scripts/dev-install.sh "$(TARGET)"

check:
	@./scripts/sanity-check.sh

check-contract:
	@./scripts/check-contract.sh

check-owned:
	@./scripts/check-rootfs-owned.sh

check-pkg-format:
	@./scripts/check-pkg-format.sh

check-init-profiles:
	@./scripts/check-init-profiles.sh

check-kernel-profiles:
	@./scripts/check-kernel-profiles.sh

check-manifests:
	@./scripts/check-manifests.sh

check-reproducible:
	@./scripts/check-reproducible.sh

check-seeds:
	@./scripts/check-seeds.sh

check-target-audit:
	@./scripts/check-target-audit.sh

v1-check: iso
	@./scripts/v1-check.sh

v2-half-check:
	@./scripts/v2-half-check.sh

v2-check:
	@./scripts/v2-check.sh

clean:
	rm -rf "$(BUILD_DIR)"
