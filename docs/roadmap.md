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
- `make iso` is actually reproducible under `SOURCE_DATE_EPOCH`, not just
  documented as such — fixed two real gaps (ISO staging tree mtimes,
  `limine bios-install`'s wall-clock MBR disk signature) found by
  diffing two real builds byte-for-byte, with `make check-reproducible`
  now asserting it via a real double build rather than only exercising
  `build-metadata.sh` in isolation
- fixed a real bug in `mkinitrd`'s `INITRAMFS_ROOT=disk` mode (the
  default `praxis-install` actually uses): its exclude patterns never
  accounted for `TARGET_ROOT` being nested inside `SOURCE_ROOT` at a
  path other than `/boot`, found by running it against a realistic
  disk-mode install scenario rather than trusting the code by
  inspection — every real installed system was at risk of a bloated or
  self-referential initramfs
- `praxis-recover`'s manual recovery ledger got the same real-target
  audit treatment: cross-referenced every field `targetcheck` can flag
  against what the ledger actually suggests, found and filled 6 real
  gaps (`/etc/praxis/install`, hostname, hosts, machine-id,
  locale.conf, localtime) by running both tools against a real broken
  target end to end
- `s6` is a real, working alternate init choice, not just a catalog
  entry — `make s6` builds statically-linked skalibs/execline/s6 from
  source, `PRAXIS_ENABLE_S6=1` stages it opt-in. Fixed two real bugs
  found only by actually booting it in QEMU: `s6-svscan` requires an
  explicit `scandir` argument that bare `RDINIT=/sbin/s6-svscan` could
  never supply, and the supervise tree needs `PATH` set or every
  service fails to spawn. `systemd` stays a documented-unsupported
  placeholder in the catalog — building a real systemd userspace is
  out of scope for Praxis's minimal identity in a way s6 is not

## In Progress

- stand up a real `pkg.praxis.dev`-equivalent repo host so
  `praxis-pkg sync`/`install` have somewhere real to fetch from; today
  `repos.conf` points at a placeholder domain and only the offline paths
  (`install-local`, `inspect`, `validate-*`) work
- build out `.prx` packages for Praxis's own tools and small utilities —
  `.prx` is intentionally not trying to replace the pacman-driven
  desktop/bundle path (`config/packages/*.list`), see `docs/pkg-format.md`

## Next

- the `mkinitrd` disk-mode fix was verified with synthetic scenarios
  (real binary, real nested-target layout) but not yet with a real
  privileged QEMU disk install (`make qemu-full`/`qemu-chroot.sh`,
  which needs sudo for loop-mount setup); worth a follow-up real
  disk-install run to confirm end to end
- `s6` now genuinely builds and boots (`make s6`,
  `PRAXIS_ENABLE_S6=1`), but hasn't gone through the same real disk
  install path as the default BusyBox init — worth confirming
  `praxis-choice emit --init s6` + `mkinitrd` + a real QEMU disk boot
  all agree, the same way BusyBox's boot path already has

## Explicitly Not Doing

- PAX, or any system-intent language layer. Removed; will not return.
  Praxis stays shell-first — explicit commands and inspectable state,
  not a scripting or declarative layer on top of the install path.
