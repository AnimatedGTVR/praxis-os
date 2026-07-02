# PAX Language Specification - v2

PAX v2 is the hard version of PAX. This document is the v2 contract.

It is not trying to become a friendlier Nix. It borrows from Nix where Nix is
strong: named inputs, reproducible references, and values that can be inspected
before execution. It borrows from C++, C#, and Python where they are strong:
typed declarations, namespaces, ordered statements, readable control flow, and
the ability to say exactly what happens next.

The result is not declarative system configuration. PAX v2 is a typed execution
ledger for operating on a machine.

## Core Rule

```text
Declare nothing you do not bind.
Do nothing you do not verify.
Assume nothing the machine has not reported.
```

Declarations describe named intent. Actions touch the machine. State reports
what actually happened.

Those three worlds must not collapse into each other.

## Language Shape

PAX v2 should feel familiar without becoming easy:

- C-family braces for scopes and blocks.
- C#-style namespaces and typed records for structure.
- Python-like statement readability.
- Nix-like pinned inputs and package identity.
- Shell-like honesty about commands, files, disks, mounts, and services.

The language should be difficult because it requires precision, not because it
is vague.

## Namespaces

PAX v1 lets declarations and runtime state share names like `disk` and
`hardware`. PAX v2 splits them.

```pax
disk.main              # declared disk object
partition.root         # declared partition object
package.browser        # declared package binding
state.disk.last_format # runtime report from the disk executor
state.mount."/mnt"     # runtime report from the mount table
```

No declaration may overwrite runtime state. No runtime action may overwrite a
declaration.

## Types

PAX v2 should have explicit domain types:

```text
Disk
Partition
Filesystem
Mountpoint
Package
Bundle
Desktop
Service
Path
Url
Command
Bool
Int
String
Symbol
List<T>
```

Additional domain types may be added only when they make machine intent more
precise. They must not hide an operation.

Package identifiers are not strings and not accidental unresolved paths. They
are package IDs.

```pax
Package browser = pkg org.mozilla.firefox
Package editor  = pkg dev.praxis.neovim
Bundle base     = bundle "essentials"
```

Typos should fail during validation whenever possible. If a package identifier
is unknown, the language should say that plainly instead of treating it like a
normal dotted path.

## Binding Rules

PAX v2 should be strict about names:

```pax
const Path TARGET = "/mnt/praxis"
let Package browser = pkg org.mozilla.firefox
var Symbol phase = pending
```

Rules:

- `const` is file-level and cannot be shadowed.
- `let` is immutable in the current scope.
- `var` is mutable and should be rare.
- Bare top-level assignment is invalid.
- Field assignment is only valid inside declaration blocks.

## Declarations

Declarations bind names. They do not perform actions.

```pax
declare Disk main {
    device = "/dev/vda"
    table = gpt
}

declare Partition root {
    disk = disk.main
    number = 2
    start = "513MiB"
    end = "100%"
    type = linux-filesystem
}
```

A declaration may be complicated, but it is still inert. It only becomes real
when an action uses it.

Required declaration kinds for v2:

```text
Disk       device, table
Partition  disk, number, start, end, type
User       name, shell, home, groups
Service    name, enable
BootEntry  title, linux, initrd, options
Seed       name, ledger
```

Declaration fields are not optional unless the declaration kind explicitly
says they are optional.

## Actions

Actions are verbs. Actions execute.

```pax
write gpt to disk.main
create partition.root
format partition.root as ext4
mount partition.root at TARGET
install package browser
service enable "sshd"
```

Action names should map to real machine operations. PAX should prefer an ugly
truthful verb over a pretty abstraction.

Required action families for v2:

```text
check hardware
write gpt to disk.name
create partition.name
commit partition table disk.name
format partition.name as filesystem
mkdir path
mount partition.name at path
umount path
install package package
install bundle bundle
install desktop desktop
set hostname value
set locale value
set timezone value
set keymap value
write file path content value
exec command command
user create value
user add-group user group
user set-password user
set password for user
service enable value
service disable value
service start value
service stop value
initramfs build target
bootloader install loader
bootloader entry name { fields }
seed apply seed.name to target
recover target
```

Actions that can destroy data or alter bootability are dangerous actions.
Dangerous actions must be followed by an assertion before the next dangerous
action.

## Verification

Every dangerous action should naturally pair with a check.

```pax
format partition.root as ext4
assert state.disk.last_format == partition.root "root format did not complete"

mount partition.root at TARGET
assert state.mount.TARGET == mounted "root partition is not mounted"
```

PAX v2 should make verification feel normal, almost ceremonial. The point is
not to save lines. The point is to make the operator look at the result.

Required dangerous actions:

```text
write gpt
create partition
commit partition table
format
mount
umount
install package
install bundle
install desktop
write file
exec command
user create
user add-group
user set-password
set password
service enable
service disable
service start
service stop
initramfs build
bootloader install
bootloader entry
seed apply
recover
```

The v2 checker must reject a PAX v2 example that chains dangerous actions
without an assertion between them.

## Control Flow

PAX v2 can keep normal readable control flow:

```pax
if state.hardware.status != good {
    fail "hardware gate failed"
}

for pkg in workstation_packages {
    install package pkg
    assert state.package.last_install == pkg "package install did not land"
}
```

No implicit parallelism. No hidden dependency solver. If a future executor can
plan or dry-run, it still reports the ordered actions it intends to run.

`if`, `for`, `require`, `assert`, `fail`, and `log` are part of v2. `while`,
function definitions, classes, lambdas, imports with side effects, and hidden
dependency solving are not.

## Inputs

Nix has strong input discipline. PAX v2 should steal that part without copying
Nix's object-tree style.

```pax
input praxis-core from git "https://git.praxis.dev/core.git" at "v2.0.0"
input desktop-pkgs from git "https://git.praxis.dev/desktops.git" at "main"
```

Inputs name sources. They do not install anything.

Inputs must be pinned for release builds. An unpinned input is valid only for
local development and must be reported by the checker.

## File Contract

Every PAX v2 file still uses the Praxis header:

```text
[.Praxis Config - <label> .praxis.pax./]
```

The label must contain `v2` for v2 files until the v1 language is retired or
the interpreter gains a real version field.

## Interpreter Contract

The current v2 interpreter is allowed to be simulated. It must still enforce:

- valid header
- typed bindings
- known declaration kinds
- required declaration fields
- no unresolved dotted paths except package IDs introduced with `pkg`
- assertion and require evaluation
- ordered execution
- no target mutation outside the interpreter's explicit action set

Real execution can arrive later. Silent inference cannot.

## What PAX v2 Is Not

PAX v2 is not this:

```pax
disk.main.content.partition.root.content.filesystem.mountpoint = "/"
```

That is the Nix/Disko style: describe a tree and let the tool infer the
procedure.

PAX v2 should force this instead:

```pax
write gpt to disk.main
create partition.root
format partition.root as ext4
mount partition.root at TARGET
assert state.mount.TARGET == mounted "root partition is not mounted"
```

This is harder. It is also more honest.

## North Star

PAX v2 should read like a program, validate like a typed config, and execute
like a shell transcript with memory.

The user should never wonder whether a line merely described the machine or
changed it. The grammar should make that obvious.
