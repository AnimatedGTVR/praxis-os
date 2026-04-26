# Praxis Architecture

Praxis is structured around one design rule: the distro should make its runtime,
install flow, and documentation easy to inspect.

## Layers

### Boot

`boot/` owns the first meaningful user-facing behavior. The initramfs entrypoint mounts the minimum runtime filesystems and immediately hands control to the Praxis live shell.

### Root Filesystem

`rootfs/` contains the base tree that becomes the live initramfs environment. This is where Praxis runtime files, release metadata, and command entrypoints are staged. The default rootfs uses the repo-built static BusyBox artifact from `userspace/` for `/bin/sh` and core applets instead of copying host core utilities.

### Installer Experience

`installer/` defines the user contract:

- `praxis-banner` makes the live shell unmistakably Praxis.
- `praxis-help` provides a built-in quick-start guide and local doc entrypoint.
- `praxis-status`, `praxis-preflight`, `praxis-disk-report`, `praxis-netcheck`, and `praxis-support` make the live environment inspectable without leaving the shell.
- `praxis-install` installs the current Praxis environment onto a mounted target root and writes boot artifacts.
- `praxis-live` prints the live-environment overview and drops you into the shell.
- `praxis-dev-install` copies the live Praxis environment onto a mounted target root for fast developer installs.

### Manifests

`config/` separates distro identity, live-tool manifests, and runtime metadata from script logic.

### Kernel Ownership

Praxis is an independent distro, so the kernel is considered Praxis-owned. `make kernel` builds an upstream Linux `bzImage` into `kernel/bzImage`, and the normal ISO path depends on that artifact. A host kernel fallback exists only when `PRAXIS_ALLOW_HOST_KERNEL=1` is set explicitly for local development.

### Userspace Ownership

`make userspace` builds an upstream BusyBox release into `userspace/busybox`. `make rootfs` installs that artifact and creates BusyBox applet links by default. Host tools and host metadata are only vendored when `PRAXIS_ALLOW_HOST_TOOLS=1` is set.

### Verification

The primary local workflow is:

- `make iso`
- `make qemu`
- `make smoke`

`make qemu` is the interactive QEMU boot path. `make smoke` is the headless verification path that waits for Praxis to reach the shell prompt.

## Why The Shell-First Path Matters

Praxis is not trying to hide the system behind a large installer UI.

The contract is simple:

- Praxis boots
- Praxis gives you the shell, the docs, and the install command
- Praxis lets you inspect the pieces before you write the system
- Praxis keeps the base understandable while it grows
