# Praxis Roadmap

## Milestone 0

- establish the repo layout
- define the distro identity
- ship the shell-first live environment and install command
- stage a rootfs and initramfs cleanly
- make `make iso` and `make qemu` the default workflow

## Milestone 1

- ship a Praxis-owned kernel artifact in `kernel/`
- replace the host-kernel development fallback
- make the live image boot reliably in QEMU
- tighten the installed-system boot story beyond the current systemd-boot entry generation
- ship local docs and a stable help path inside the live image

## Milestone 2

- expand the live environment toolset
- add real system-seeding mechanics without hiding the install path
- make the first release feel complete without turning Praxis into a black box

## Milestone 3

- formalize package and base-system manifests
- add reproducible image generation
- define recovery behavior and post-install workflows
