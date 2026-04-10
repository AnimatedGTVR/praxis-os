# Boot Notes

Praxis owns its own live boot flow.

The current scaffold boots a Linux kernel with a Praxis initramfs. That
initramfs immediately hands control to the Praxis live shell and the local
Praxis toolset.

The boot directory currently contains:

- `init`: the initramfs entrypoint
- `limine.conf`: a prototype bootloader configuration for local ISO experimentation

The long-term goal is not "boot whatever another distro boots." The goal is for Praxis to own the kernel packaging, rootfs layout, init flow, and installer behavior end to end.
