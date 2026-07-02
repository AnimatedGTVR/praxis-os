# PAX

PAX is the typed execution language for Praxis.

PAX v2 is not a friendlier Nix and not a shell script with prettier syntax. It
is an execution ledger: declarations bind named intent, actions touch the
machine, and assertions prove the last dangerous thing actually happened.

The rule is blunt:

```text
Declare nothing you do not bind.
Do nothing you do not verify.
Assume nothing the machine has not reported.
```

---

## Layout

```text
pax/
  spec/PAX.md           legacy v1 specification
  spec/PAX-V2.md        PAX v2 language contract
  examples/             example .pax files
  interpreter/          C# interpreter
  tests/v2-invalid/     examples that must fail v2 validation
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

For v2 files, the label must contain `v2` until PAX grows a real version field:

```text
[.Praxis Config - full install v2 .praxis.pax./]
```

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
| `full-install-v2.pax` | PAX v2 typed execution-ledger sketch |

---

## Interpreter

The interpreter is a C# console application.

```bash
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/packageinstall-config.pax
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/full-install.pax
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/hardware-check.pax
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- --v2 pax/examples/full-install-v2.pax
```

## PAX v2 Shape

PAX v2 separates three worlds:

```pax
declare Disk main { ... }       # declaration: named intent
format partition.root as ext4   # action: touches the machine
assert state.disk.last_format == partition.root "root format failed"
```

Declarations do not execute. Actions execute. Runtime state lives under
`state.*` and cannot be overwritten by declarations.

Core v2 binding forms:

```pax
const Path TARGET = "/mnt/praxis"
let Package browser = pkg org.mozilla.firefox
var Symbol phase = pending
```

Package identifiers are introduced with `pkg`. They are not strings and not
ordinary unresolved dotted paths.

```pax
let Package editor = pkg dev.praxis.neovim
install package editor
assert state.package.last_install == editor "editor install did not land"
```

Dangerous actions must be followed by an assertion before the next dangerous
action. This is intentional. PAX v2 should read like a program, validate like a
typed config, and execute like a shell transcript with memory.

## V2 Strictness

`scripts/check-pax-v2.sh` validates v2 examples and requires every fixture in
`pax/tests/v2-invalid/` to fail. Those fixtures document the sharp edges: v2
headers are mandatory, dangerous actions need assertions between them, `Path`
values must be absolute, dotted paths must be declared or introduced with
`pkg`, and binding types are closed.

Requires a .NET SDK.

---

## Language Summary

Full v2 specification: `pax/spec/PAX-V2.md`

**Domain types:** `Disk`, `Partition`, `Filesystem`, `Mountpoint`,
`Package`, `Bundle`, `Desktop`, `Service`, `Path`, `Url`, `Command`, `Bool`,
`Int`, `String`, `Symbol`, and `List<T>`.

**Binding:** `const`, `let`, and `var`. Bare top-level assignment is invalid.

**Declarations:** `declare Disk`, `declare Partition`, `declare User`,
`declare Service`, `declare BootEntry`, and `declare Seed`.

**Control flow:** `if`, `for`, `require`, `assert`, `fail`, and `log`.

**Action families:** disk table writes, partition creation, formatting,
mounting, package/bundle/desktop install, user creation, service changes,
file writes, explicit commands, initramfs build, bootloader install, seed
apply, and recovery.

Legacy v1 syntax remains documented in `pax/spec/PAX.md`, but new examples and
checks should target PAX v2.
