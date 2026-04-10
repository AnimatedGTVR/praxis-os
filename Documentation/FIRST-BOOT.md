# First Boot

After Praxis boots from the installed disk for the first time, verify the base
system before you start customizing it.

## First Checks

```bash
hostname
praxis-fetch
praxis-status
```

Confirm:

- the hostname is the one you chose during install
- the kernel and release info look correct
- the shell prompt and Praxis branding are present
- the package layer shows as ready in `praxis-status`

If you installed a desktop profile or software bundles:

```bash
cat /etc/praxis/packages.selected
praxis-desktop list
```

## Network

```bash
praxis-netcheck
```

If you are in a VM, make sure the virtual NIC is attached and the network path
is active before debugging Praxis itself.

## Boot Metadata

If the installed target is still mounted somewhere for inspection:

```bash
praxis-target-check /mnt/praxis
```

Otherwise, inspect the installed boot path directly:

```bash
ls /boot/praxis
cat /boot/loader/loader.conf
```

## Local Docs

Praxis keeps local docs in the installed system too:

```text
/usr/share/doc/praxis
```

Useful files:

- `README.md`
- `INSTALL.md`
- `QEMU.md`
- `COMMANDS.md`
- `PACKAGES.md`
- `TROUBLESHOOTING.md`
