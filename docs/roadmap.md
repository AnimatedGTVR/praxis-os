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
- the `busybox` init choice's `REQUIRED_FILES`/`REQUIRED_DIRS` and the
  base-system manifest now reflect the real runit-style supervise tree
  instead of the pre-revival `/init`-only boot path
- `docs/v2.md`'s Init Rule documents what BusyBox init actually does:
  the `runsvdir` handoff, how a service directory's `run` script is
  supervised, and how to add a new service
- a real service enable/disable catalog following runit's own
  convention: `/etc/sv/<name>/` holds every known service definition,
  `/etc/service/<name>` is a symlink to it only when enabled, and
  `praxis-sv list`/`status`/`enable`/`disable` (with `--root` support
  for installed targets) manages that state
- `make check` / `make v1-check` / `make v2-check` as layered validation
  gates, all exercised against real QEMU boots, not just static checks

## In Progress

- stand up a real `pkg.praxis.dev`-equivalent repo host so
  `praxis-pkg sync`/`install` have somewhere real to fetch from; today
  `repos.conf` points at a placeholder domain and only the offline paths
  (`install-local`, `inspect`, `validate-*`) work
- build out `.prx` packages for Praxis's own tools and small utilities —
  `.prx` is intentionally not trying to replace the pacman-driven
  desktop/bundle path (`config/packages/*.list`), see `docs/pkg-format.md`

## Next

- richer kernel/init profile build mechanics per `docs/v2.md`
- reproducible image generation and recovery workflow hardening
  (`Milestone 3` scope from the pre-revival plan; still applicable)

## Explicitly Not Doing

- PAX, or any system-intent language layer. Removed; will not return.
  Praxis stays shell-first — explicit commands and inspectable state,
  not a scripting or declarative layer on top of the install path.
