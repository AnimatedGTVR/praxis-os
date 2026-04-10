# Packages and Desktop Profiles

Praxis can stage extra software into the installed image while you install it.

The current first-version package layer uses `pacman` repositories for software
selection, but the install flow stays Praxis-owned:

- you still boot the Praxis live image
- you still mount the target yourself
- you still run `praxis-install`
- Praxis folds the selected packages back into the installed boot image

## List What Is Available

Inside Praxis:

```bash
praxis-packages list
praxis-packages list desktops
praxis-packages list bundles
```

To inspect a single profile:

```bash
praxis-packages show desktop xfce
praxis-packages show bundle developer
```

## Desktop Profiles

Current desktop profiles:

- `gnome`
- `plasma`
- `xfce`
- `budgie`
- `mate`
- `lxqt`
- `i3`
- `openbox`

Example install:

```bash
praxis-install --hostname praxisbox --desktop xfce /mnt/praxis
```

## Bundles

Current install bundles:

- `developer`
- `internet`
- `media`
- `essentials`
- `fonts`

Example install:

```bash
praxis-install --hostname praxisbox --bundle developer --bundle internet /mnt/praxis
```

## Extra Packages

You can also add package names directly:

```bash
praxis-install --hostname praxisbox --packages firefox,vlc,git /mnt/praxis
```

That can be combined with a desktop profile and bundles:

```bash
praxis-install \
  --hostname praxisbox \
  --desktop xfce \
  --bundle essentials \
  --bundle developer \
  --packages firefox,vlc \
  /mnt/praxis
```

## Apply Packages To An Existing Target

If you already have a mounted Praxis target root and boot partition, you can add
packages to it and rebuild the target image contents:

```bash
praxis-packages install --target /mnt/praxis --desktop xfce --bundle internet
```

After that, rebuild the target install image:

```bash
praxis-install --hostname praxisbox /mnt/praxis
```

The simplest path is still to pick the desktop and packages during the initial
`praxis-install`.

## Launching An Installed Desktop

If you install a desktop profile that includes `xorg-xinit`, you can try
starting it from the Praxis shell with:

```bash
praxis-desktop list
praxis-desktop start xfce
```

That is a first-version shell-first desktop path, not a full display-manager
workflow yet.
