# Praxis Package Format — .prx

## Overview

Praxis native packages use the `.prx` format. A `.prx` file is a gzip-compressed
tar archive containing a metadata file and a filesystem tree.

Package identifiers follow reverse-domain notation:

```
tld.organization.packagename
```

Examples:

```
dev.praxis.neovim
dev.praxis.kitty
org.mozilla.firefox
org.videolan.vlc
org.gnome.nautilus
io.github.alacritty
```

`dev.praxis.*` is the Praxis native namespace. Third-party packages use the
upstream organization's domain reversed.

---

## Archive Layout

```
package.prx (gzip-compressed tar)
├── PKGINFO          metadata file
└── data/            filesystem tree root
    ├── usr/
    │   ├── bin/
    │   ├── lib/
    │   └── share/
    └── etc/
```

The `data/` tree is unpacked directly into the install root. Paths inside
`data/` are relative to `/`.

---

## PKGINFO Format

`PKGINFO` is a key=value text file, one field per line. Lines beginning with
`#` are comments.

Required fields:

```
id       = dev.praxis.neovim
version  = 0.10.0-1
desc     = Hyperextensible text editor
arch     = x86_64
```

Optional fields:

```
url      = https://neovim.io
license  = Apache-2.0
size     = 8192000
deps     = dev.praxis.luajit dev.praxis.tree-sitter
build    = 2026-05-22
```

`deps` is a space-separated list of reverse-domain package identifiers. The
installer resolves and installs dependencies before unpacking the package.

---

## Index Format

Each repository serves an `INDEX.gz` file at its root. The index is a
gzip-compressed tab-delimited text file, one package per line:

```
<id>\t<version>\t<description>\t<filename>
```

Example:

```
dev.praxis.neovim\t0.10.0-1\tHyperextensible text editor\tdev.praxis.neovim-0.10.0-1.prx
dev.praxis.kitty\t0.35.2-1\tGPU-accelerated terminal\tdev.praxis.kitty-0.35.2-1.prx
org.mozilla.firefox\t126.0-1\tFirefox web browser\torg.mozilla.firefox-126.0-1.prx
org.videolan.vlc\t3.0.21-1\tMedia player\torg.videolan.vlc-3.0.21-1.prx
```

Fields:

| Field    | Description                               |
|----------|-------------------------------------------|
| id       | Reverse-domain package identifier         |
| version  | Package version string                    |
| desc     | One-line description                      |
| filename | Filename of the `.prx` file in this repo  |

---

## Repository Layout

```
https://pkg.praxis.dev/core/
├── INDEX.gz          tab-delimited index
├── INDEX.gz.sig      GPG signature (required for signed repos)
└── dev.praxis.neovim-0.10.0-1.prx
└── dev.praxis.kitty-0.35.2-1.prx
└── ...
```

---

## Repository Configuration

Repos are configured in `/etc/praxis/repos.conf`:

```
[repo]
name    = praxis-core
url     = https://pkg.praxis.dev/core
enabled = yes
signed  = yes

[repo]
name    = praxis-extra
url     = https://pkg.praxis.dev/extra
enabled = yes
signed  = yes

[repo]
name    = praxis-community
url     = https://pkg.praxis.dev/community
enabled = yes
signed  = no
```

Fields:

| Field   | Values   | Description                        |
|---------|----------|------------------------------------|
| name    | string   | Short label used in output         |
| url     | URL      | Base URL of the repo root          |
| enabled | yes / no | Whether to include this repo       |
| signed  | yes / no | Require GPG signature on INDEX.gz  |

---

## praxis-pkg Tool

```bash
praxis-pkg sync                     # fetch/update all repo indexes
praxis-pkg list                     # list all available packages
praxis-pkg list praxis-core         # list packages from one repo
praxis-pkg info dev.praxis.neovim   # show package info
praxis-pkg search editor            # search by name or description
praxis-pkg install dev.praxis.neovim org.mozilla.firefox
praxis-pkg remove dev.praxis.neovim
praxis-pkg repos                    # list configured repos
```

---

## PAX Integration

In PAX files, install packages using their reverse-domain identifier directly —
no quotes:

```pax
install package dev.praxis.neovim
install package org.mozilla.firefox
install package org.videolan.vlc
```

Quoted strings are not valid for package identifiers. The identifier is a bare
dotted path in PAX syntax, not a string literal.

To iterate over a list of packages:

```pax
let apps = [ dev.praxis.neovim, org.mozilla.firefox, dev.praxis.kitty ]

each pkg in apps
{
    install package pkg
}
```
