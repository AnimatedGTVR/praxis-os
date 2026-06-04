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

- the hostname matches the install choice
- the kernel and release info look correct
- the Praxis prompt and branding are present

## Installed Packages

If you installed a desktop profile or software bundles:

```bash
cat /etc/praxis/packages.selected
praxis-desktop list
```

## Network

```bash
praxis-netcheck
```

In QEMU, make sure the virtual NIC is attached before debugging Praxis itself.

## Boot Metadata

```bash
ls /boot/praxis
cat /boot/loader/entries/praxis.conf
```

## Local Docs

Praxis keeps local docs in the installed system:

```text
/usr/share/doc/praxis/
```

Useful files:

- `INSTALL.md`
- `COMMANDS.md`
- `QEMU.md`
- `PACKAGES.md`
- `TROUBLESHOOTING.md`
- `DOC.md` — single-file reference for everything
