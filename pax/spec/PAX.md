# PAX Language Specification

PAX is a domain-specific language for Praxis.

It is not a general programming language. It is meant for system intent:

- package installation
- source compilation workflows
- system configuration
- hardware checks
- boot and desktop setup
- installer logic

PAX keeps the surface small and readable. It should feel like operating system
instructions, not application code.

## Core Style

- every file starts with a Praxis header line
- blocks use `{ }`
- assignment uses `=`
- equality tests use `==`
- comments begin with `#`
- strings use double quotes
- booleans are `true` and `false`
- bare words like `xfce`, `source`, `bad`, and `finished` are symbols

## File Roles

- `.pax`: general config and install logic
- `.pkg.pax`: package definitions
- `.profile.pax`: install presets and role-based setups
- `.boot.pax`: boot-time logic and hardware gates

## Required File Header

Every PAX file must begin with this header form:

```text
[.Praxis Config - <file name or file purpose> .praxis.pax./]
```

Examples:

```text
[.Praxis Config - packageinstall-config .praxis.pax./]
[.Praxis Config - source-pkg package definition .praxis.pax./]
[.Praxis Config - liveboot-config boot logic .praxis.pax./]
```

Rules:

- it must be the first non-empty line in the file
- it is metadata, not executable PAX code
- the text in the middle should describe the config name or its use
- if the header is missing, the interpreter stops before parsing

## Value Model

PAX supports four value forms:

1. strings
2. booleans
3. symbols
4. dotted paths

Examples:

```pax
desktop = xfce
compile_mode = source
dev_installer = false
package = "xfce-base/xfce4-meta"
selected = config.package
```

### Symbols

Unquoted words are symbols. They are literal atoms.

Variable lookups use dotted paths.

```pax
desktop = xfce
if install.status == finished
{
    print "Install complete."
}
```

## Named Blocks

Named blocks are the main structural unit.

```pax
package "xfce"
{
    source = "xfce-base/xfce4-meta"
    compile = true
}
```

Execution rule:

- a block runs its inner assignments and statements
- the resulting data becomes available under the block kind
- the most recent top-level `config` block becomes `config`
- the most recent top-level `package` block becomes `package`

That makes dotted lookups simple:

```pax
install package config.package
enable desktop config.desktop
```

## Conditions

PAX only supports direct equality conditions.

```pax
if hardware.status == bad
{
    print "Hardware failed"
    stop
}
```

There are no loops, functions, classes, or user-defined operators.

## Actions

Actions use plain verbs instead of function syntax.

Supported first-version actions:

```pax
check hardware
install package "xfce-base/xfce4-meta"
compile package "xfce-base/xfce4-meta"
enable desktop xfce
reboot target desktop
print "done"
stop
```

### Built-in Runtime State

Actions update a small set of runtime state objects:

- `hardware.status`
- `install.status`
- `compile.status`
- `desktop.status`
- `boot.status`

Example:

```pax
install package config.package

if install.status == finished
{
    print "Install completed."
}
```

## Grammar

This is the practical first-version grammar:

```text
file        = header { statement }

header      = "[.Praxis Config - " TEXT " .praxis.pax./]"

statement   = assignment
            | block
            | if_block
            | action

assignment  = IDENT "=" value

block       = IDENT STRING "{" { statement } "}"

if_block    = "if" value "==" value "{" { statement } "}"

action      = "print" value
            | "stop"
            | "check" IDENT
            | "install" IDENT value
            | "compile" IDENT value
            | "enable" IDENT value
            | "reboot" IDENT value

value       = STRING
            | BOOLEAN
            | SYMBOL
            | PATH

PATH        = IDENT { "." IDENT }
SYMBOL      = IDENT
BOOLEAN     = "true" | "false"
```

## Example

This file is valid PAX and is the reference behavior for the first interpreter:

```pax
[.Praxis Config - packageinstall-config .praxis.pax./]

config "packageinstall-config"
{
    package = "xfce-base/xfce4-meta"
    desktop = xfce
    compile_mode = source
}

check hardware

if hardware.status == bad
{
    print "Hardware failed."
    stop
}

install package config.package
compile package config.package
enable desktop config.desktop

if install.status == finished
{
    print "[XFCE] Installed!"
}
```

## First-Version Limits

PAX intentionally does not include:

- loops
- functions
- arithmetic
- arrays
- user-defined types
- shell escapes
- pipelines

The point is to describe system work, not become another general scripting
language.
