# Troubleshooting

Praxis stays shell-first, so the quickest fix path is usually to inspect the
current state directly.

## Quick Commands

```bash
praxis-preflight
praxis-status
praxis-disk-report
praxis-netcheck
praxis-support
```

## Common Install Problems

### Target Root Is Not Mounted

If `praxis-install` says the target is not mounted, check:

```bash
findmnt /mnt/praxis
findmnt /mnt/praxis/boot
```

Mount the root partition at `/mnt/praxis` and the EFI system partition at
`/mnt/praxis/boot`.

### Target Check Fails

Run:

```bash
praxis-target-check /mnt/praxis
```

That will tell you whether the kernel, initramfs, loader entry, hostname, fstab,
and install metadata are present.

### Package Or Desktop Profile Install Fails

Run:

```bash
praxis-packages list
cat /mnt/praxis/etc/praxis/packages.selected
tail -n 50 /mnt/praxis/var/log/pacman.log
```

If the package layer fails, the two most common reasons are:

- the live environment does not have working network access
- the package name or desktop profile is not valid

You can inspect the available package sets with:

```bash
praxis-packages show desktop xfce
praxis-packages show bundle developer
```

### Network Looks Broken

Run:

```bash
praxis-netcheck
ip -o link show
ip -o -4 addr show
```

In QEMU, networking problems are often VM configuration problems rather than
Praxis problems.

### Need Logs or a Report

Run:

```bash
praxis-support
```

That writes a compressed bundle to `/tmp` with kernel messages, block-device
state, network info, release files, and Praxis metadata.
