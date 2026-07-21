# Praxis Roadmap

Praxis is being rebuilt as a lightweight, minimal Linux distribution
inspired by the philosophy of Alpine Linux and Void Linux, while keeping
its own identity. This roadmap reflects that direction, not the earlier
PAX-era plan.

## Shipped

- shell-first live environment with an explicit multi-stage install
- a Praxis-owned kernel artifact in `kernel/` (profile-selectable: stock,
  tiny, hardened)
- a Praxis-owned static BusyBox userspace artifact in `userspace/`
- `make iso` / `make qemu` / `make smoke` as the default build and boot
  workflow
- a Limine removable-UEFI fallback for installed targets
- local docs and a stable `praxis-help` path inside the live image
- hard choice catalogs (`praxis-choice`), seed ledgers (`praxis-seed`),
  base-system manifests (`praxis-manifest`), build provenance
  (`praxis-provenance`), and portable contracts (`praxis-contract`)
- `praxis-pkg`: a native `.prx` binary package manager (reverse-domain
  identifiers, gzip-tar archives, tab-delimited repo indexes) with real
  dependency resolution on install and real tracked-file removal on
  uninstall
- a runit-style supervise tree for PID 1: `boot/init` mounts pseudo
  filesystems and handles the initramfs-to-installed-root switch, then
  hands off to BusyBox `runsvdir` over `/etc/service`
- `udev` as its own supervised background service, split out of the
  shell's boot-time logic; desktop autostart stays inline in the
  `shell` service since it is inherently console-exclusive with the
  shell itself
- `make check` / `make v1-check` / `make v2-check` as layered validation
  gates, all exercised against real QEMU boots, not just static checks

## In Progress

- expand the default `.prx` repository content beyond the current
  test/reference packages

## Next

- decide and document the default init/service catalog operators are
  expected to enable (mirroring the existing kernel/init choice catalog
  pattern already used for kernel profiles)
- richer kernel/init profile build mechanics per `docs/v2.md`
- reproducible image generation and recovery workflow hardening
  (`Milestone 3` scope from the pre-revival plan; still applicable)

## Explicitly Not Doing

- PAX, or any system-intent language layer. Removed; will not return.
  Praxis stays shell-first — explicit commands and inspectable state,
  not a scripting or declarative layer on top of the install path.
