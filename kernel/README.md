# Kernel Ownership

Praxis is an independent distro.

That means the kernel is not treated as an inherited implementation detail from some parent distribution. The long-term expectation is:

- Praxis ships its own kernel artifact here as `kernel/bzImage`
- Praxis owns its kernel config choices
- Praxis owns the relationship between kernel, initramfs, and rootfs

Build the Praxis kernel artifact with:

```bash
make kernel
make kernel PROFILE=tiny
make kernel PROFILE=hardened
```

By default, `make kernel` downloads the latest stable Linux release from kernel.org, builds an x86 `bzImage`, and writes:

```text
kernel/bzImage
kernel/VERSION
kernel/config.fragment
```

You can pin a release with:

```bash
KERNEL_VERSION=6.19.11 make kernel
```

If `kernel/config` exists, the build uses it and runs `olddefconfig`. Otherwise it starts from the upstream x86 `defconfig`. The build then applies `kernel/config.fragment` for Praxis-specific requirements, including framebuffer console support for graphical QEMU and EFI boots.

The normal `make iso` path depends on `kernel/bzImage`, so Praxis no longer silently builds the live image from another operating system's kernel. A host kernel can still be used deliberately for emergency local development by setting `PRAXIS_ALLOW_HOST_KERNEL=1`.

## Praxis v2 Kernel Profiles

Praxis v2 exposes kernel policy choices through:

```text
config/choices/kernel/
```

Those files point to build fragments in:

```text
kernel/profiles/
```

`make kernel PROFILE=<name>` applies the selected fragment and records the
profile in `kernel/PROFILE`. `praxis-choice show kernel <name>` prints the
policy, and `praxis-choice emit ...` can include it in a `system.choice`
skeleton. The operator still owns the selected profile, artifact, config, and
boot entry.

Profile fragments are explicit kernel config policy lines:

```text
CONFIG_VT=y
CONFIG_VIRTIO_NET=y
CONFIG_EXAMPLE=m
CONFIG_UNUSED=n
```

Bare symbols are rejected. `make check-kernel-profiles` validates the profile
catalog before build time. A successful kernel build also writes:

- `kernel/PROFILE.applied` — selected profile, source/build dirs, and applied options
- `kernel/build-info` — build provenance and artifact hashes
