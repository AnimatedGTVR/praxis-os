# Kernel Ownership

Praxis is an independent distro.

That means the kernel is not treated as an inherited implementation detail from some parent distribution. The long-term expectation is:

- Praxis ships its own kernel artifact here
- Praxis owns its kernel config choices
- Praxis owns the relationship between kernel, initramfs, and rootfs

For now, the ISO build helper can fall back to the host kernel at `/lib/modules/$(uname -r)/vmlinuz` so the repository can already exercise its live environment and initramfs flow during development.

That fallback is temporary and explicitly a development convenience, not the project identity.
