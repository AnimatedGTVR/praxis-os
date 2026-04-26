# Userspace Ownership

Praxis owns its first userspace artifact here.

Build the base userspace with:

```bash
make userspace
```

That writes:

```text
userspace/busybox
userspace/BUSYBOX_VERSION
```

`scripts/build-rootfs.sh` installs that BusyBox into `/bin/busybox` and creates
applet links for the shell and core utilities. By default, the rootfs builder no
longer copies host core utilities, host shared libraries, pacman metadata,
resolver config, or certificate bundles.

Host-provided tools can still be vendored deliberately for compatibility work:

```bash
PRAXIS_ALLOW_HOST_TOOLS=1 make rootfs
```

That path is useful while package management, disk tooling, and desktop install
support are being replaced with Praxis-owned builds. It is not the default base
OS path.
