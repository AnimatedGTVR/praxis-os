SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

BUILD_DIR := build
ROOTFS_STAGE := $(BUILD_DIR)/rootfs
INITRAMFS := $(BUILD_DIR)/praxis-initramfs.cpio.gz
ISO_STAGE := $(BUILD_DIR)/iso
ISO_FILE := $(BUILD_DIR)/praxis.iso
QEMU_DISK_FILE := $(BUILD_DIR)/praxis.qcow2
QEMU_DISK_SIZE ?= 16G

.PHONY: help rootfs initramfs iso qemu QEMU qmec qemc qemu-disk qemu-install qemu-installed smoke dev-install check clean

help:
	@echo "Praxis"
	@echo
	@echo "Targets:"
	@echo "  make rootfs     Stage the Praxis root filesystem"
	@echo "  make initramfs  Build the Praxis initramfs"
	@echo "  make iso        Build the Praxis ISO"
	@echo "  make qemu       Boot the generated ISO in a QEMU window"
	@echo "  make qemu-disk  Create the default QEMU disk image"
	@echo "  make qemu-install Boot the ISO with the default QEMU disk attached"
	@echo "  make qemu-installed Boot the installed QEMU disk with UEFI"
	@echo "  make QEMU       Alias for qemu"
	@echo "  make qmec       Alias for qemu"
	@echo "  make qemc       Alias for qemu"
	@echo "  make smoke      Verify Praxis reaches the shell prompt in QEMU"
	@echo "  make dev-install TARGET=/mnt/praxis-dev"
	@echo "  make check      Run shell and staging sanity checks"
	@echo "  make clean      Remove build artifacts"

rootfs:
	@./scripts/build-rootfs.sh "$(ROOTFS_STAGE)"

initramfs: rootfs
	@./scripts/build-initramfs.sh "$(ROOTFS_STAGE)" "$(INITRAMFS)"

iso: initramfs
	@./scripts/build-iso.sh "$(INITRAMFS)" "$(ISO_STAGE)" "$(ISO_FILE)"

qemu: iso
	@./scripts/run-qemu.sh "$(ISO_FILE)"

QEMU: qemu

qmec: qemu

qemc: qemu

qemu-disk:
	@./scripts/create-qemu-disk.sh "$(QEMU_DISK_FILE)" "$(QEMU_DISK_SIZE)"

qemu-install: iso qemu-disk
	@QEMU_EXTRA_ARGS="-drive file=$(QEMU_DISK_FILE),if=virtio,format=qcow2" ./scripts/run-qemu.sh "$(ISO_FILE)"

qemu-installed: qemu-disk
	@./scripts/run-qemu-installed.sh "$(QEMU_DISK_FILE)"

smoke: iso
	@QEMU_MODE=smoke QEMU_UI=nographic ./scripts/run-qemu.sh "$(ISO_FILE)"

dev-install:
	@./scripts/dev-install.sh "$(TARGET)"

check:
	@./scripts/sanity-check.sh

clean:
	rm -rf "$(BUILD_DIR)"
