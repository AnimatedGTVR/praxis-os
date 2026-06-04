# PAX

PAX is the domain-specific language for Praxis.

Praxis is Arch on crack. PAX is Nix on meth.

It is not a scripting language. It is a system intent language. You describe
every step explicitly — what to partition, what to format, what to install,
what to configure, what to enable. Nothing is inferred. Nothing runs unless you
wrote it.

---

## Layout

```text
pax/
  spec/PAX.md           full language specification
  examples/             example .pax files
  interpreter/          C# interpreter
```

---

## All Files Use .pax

Every PAX file ends in `.pax`. There are no sub-extensions. A file named
`setup.pax` is correct. A file named `setup.profile.pax` is not valid PAX.

---

## Required Header

Every PAX file must begin with:

```text
[.Praxis Config - <label> .praxis.pax./]
```

The label is free text describing the file's purpose. It must not be empty.
The interpreter stops before executing any statement if the header is missing
or malformed.

---

## Example Files

| File | Description |
|------|-------------|
| `packageinstall-config.pax` | Reference example from the spec |
| `hardware-check.pax` | Hardware probe and gate |
| `core-system-config.pax` | Base system config with hardware gate |
| `core-packages.pax` | Core package profile |
| `workstation-config.pax` | Desktop + software workstation preset |
| `ricing-desktop.pax` | Desktop theming and ricing setup |
| `liveboot-config.pax` | Live boot hardware gate and desktop start |
| `source-pkg.pax` | Source build workflow |
| `full-install.pax` | Complete install: disk, packages, users, boot |
| `disk-setup.pax` | Disk partitioning and formatting |
| `user-setup.pax` | User and group creation |
| `service-config.pax` | Service enable and configuration |

---

## Interpreter

The interpreter is a C# console application.

```bash
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/packageinstall-config.pax
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/full-install.pax
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/hardware-check.pax
```

Requires a .NET SDK.

---

## Language Summary

Full specification: `pax/spec/PAX.md`

**Types:** string, int, bool, symbol, path, list

**Binding:**
```pax
let   name = value     # immutable
var   name = value     # mutable
define NAME = value    # file-level constant
```

**Conditions:** `==`, `!=`, `not`, `and`, `or`

**Iteration:**
```pax
each pkg in packages
{
    install package pkg
}
```

**Package identifiers** use reverse-domain notation — not strings:
```pax
install package dev.praxis.neovim       # Praxis native
install package org.mozilla.firefox     # upstream/community
install package org.videolan.vlc
```
Bundles use quoted strings: `install bundle "essentials"`

**Key actions:** `install`, `compile`, `enable`, `set`, `write`, `exec`,
`mount`, `format`, `service`, `user`, `group`, `bootloader`, `initramfs`,
`fetch`, `copy`, `symlink`, `require`, `assert`, `log`, `warn`, `fail`

**Runtime state:** `hardware.*`, `install.*`, `compile.*`, `desktop.*`,
`disk.*`, `exec.*`, `fetch.*`, `file.*`, `net.*`, `user.*`, `boot.*`,
`initramfs.*`, `pax.*`
