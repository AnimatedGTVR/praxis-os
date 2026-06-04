# PAX Language Specification — v1.1

PAX is the domain-specific language for Praxis.

It is not a general-purpose scripting language. It has no closures, no
inheritance, no generics, and no dynamic dispatch. It is a system intent
language: you describe what must happen to a machine and PAX executes it in
explicit, ordered steps.

The design philosophy is direct: Praxis is Arch on crack; PAX is Nix on meth.
Every step is written out. Nothing is inferred. Nothing is hidden. If you want
a package installed, you write `install package`. If you want a user created,
you write `user create`. If you want a service enabled, you write
`service enable`. There is no shorthand, no magic block, no convention that
acts on your behalf without a written instruction.

The documentation is long because PAX can do a lot. Read it.

---

## 1. File Format

All PAX files use the `.pax` extension. There are no sub-extensions. A file
named `setup.pax` is a PAX file. A file named `setup.profile.pax` is not a
valid PAX file; the interpreter will reject it because the `.pax` token appears
in the middle of the name rather than at the end.

Files must be UTF-8. Line endings may be LF or CRLF; the interpreter
normalizes them to LF before parsing.

Every PAX file must begin with a Praxis header line before any code.

### 1.1 Required Header

The first non-blank line of every PAX file must be exactly:

```text
[.Praxis Config - <label> .praxis.pax./]
```

Rules:

- The brackets, dots, and keywords are literal and required.
- `<label>` is free text describing the file's purpose. It must not be empty.
- The header is metadata. It is parsed before the body and is not executable.
- If the header is missing or malformed, the interpreter stops with an error
  before executing any statement.

Examples:

```text
[.Praxis Config - full-install config .praxis.pax./]
[.Praxis Config - disk layout for workstation .praxis.pax./]
[.Praxis Config - hardware validation .praxis.pax./]
[.Praxis Config - user and group setup .praxis.pax./]
```

---

## 2. Lexical Rules

### 2.1 Whitespace

Spaces and tabs are ignored between tokens. Blank lines are ignored. Newlines
terminate statements; they are not interchangeable with spaces.

### 2.2 Comments

Comments begin with `#` and run to the end of the line. They may appear
anywhere a token boundary is valid.

```pax
# This entire line is a comment.
install package org.mozilla.firefox  # This comment follows a statement.
```

### 2.3 Identifiers

Identifiers begin with a letter or underscore, followed by any combination of
letters, digits, underscores, and hyphens.

```text
valid:    name   my-thing   _internal   pkg2
invalid:  2pkg   my.thing   -bad
```

Identifiers are case-sensitive. `Hardware` and `hardware` are different names.

### 2.4 Keywords

The following identifiers are reserved and may not be used as variable names:

```text
and        append     assert     at         bootloader
by         check      compile    config     content
copy       define     delete     desktop    disk
each       enable     exec       fail       false
fetch      for        format     from       group
hardware   if         in         include    initramfs
install    let        log        mkdir      mount
move       net        network    not        null
on         or         package    partition  print
profile    reboot     require    service    set
source     start      stop       symlink    system
to         true       umount     user       warn
write
```

### 2.5 String Literals

Strings are enclosed in double quotes. Escape sequences:

| Sequence | Meaning          |
|----------|------------------|
| `\"`     | literal `"`      |
| `\\`     | literal `\`      |
| `\n`     | newline          |
| `\t`     | tab              |

Strings may not span multiple lines. Use `\n` for embedded newlines.

String interpolation is written with `{path}` inside a double-quoted string:

```pax
log "Installing {config.package} on {system.hostname}"
```

The interpolated segment is any dotted path resolvable in the current scope.

### 2.6 Integer Literals

Integers are decimal sequences with an optional leading `-` sign.

```text
0    42    -10    1024
```

Integers fit in a 64-bit signed range. Overflow is a parse-time error.

### 2.7 List Literals

Lists are written with square brackets and comma-separated values:

```pax
packages = [ "firefox", "neovim", "git" ]
targets  = [ web, database, cache ]
sizes    = [ 512, 1024, 4096 ]
```

Lists may contain strings, integers, booleans, symbols, and paths. Mixed-type
lists are allowed. Trailing commas are permitted.

---

## 3. Type System

PAX has six types:

| Type    | Example                | Notes                          |
|---------|------------------------|--------------------------------|
| string  | `"hello"`              | UTF-8 text                     |
| int     | `42`                   | 64-bit signed integer          |
| bool    | `true` / `false`       | Literal keywords               |
| symbol  | `xfce`                 | Unquoted bare word; not a path |
| path    | `config.desktop`       | Dotted identifier chain        |
| list    | `[ "a", "b" ]`         | Ordered sequence of values     |

`null` is the value of any unset or missing path lookup. It is not a type that
can be written in source; it is what you get when a path resolves to nothing.

Symbols and strings are distinct. `xfce` is a symbol; `"xfce"` is a string.
Conditions compare them by their text content, so `desktop == xfce` and
`desktop == "xfce"` produce the same result. Prefer symbols for well-known
names and strings for user-provided values or paths.

---

## 4. Expressions

An expression is any value that appears on the right-hand side of an
assignment, inside a condition, or as an action argument.

Forms:

```pax
"a string"              # string literal
42                      # integer literal
true                    # boolean literal
false                   # boolean literal
xfce                    # symbol
config.desktop          # dotted path
[ "a", "b", "c" ]      # list literal
"installed {pkg.name}"  # interpolated string
```

Arithmetic is not supported in v1.1. All numeric comparisons are equality only.
Concatenation of strings is not supported as an expression; use interpolation
instead.

---

## 5. Statements

PAX has eight statement forms. They execute in order, top to bottom, with no
lookahead, no speculative execution, and no parallelism.

### 5.1 `let` — Immutable Binding

```pax
let name = value
```

Binds `name` to `value` in the current scope. The binding cannot be
reassigned. Attempting to `let` the same name twice in the same scope is an
error.

```pax
let target   = "/mnt/praxis"
let desktop  = xfce
let packages = [ org.mozilla.firefox, dev.praxis.git, dev.praxis.htop ]
```

Use `let` for values that must not change.

### 5.2 `var` — Mutable Binding

```pax
var name = value
```

Same as `let` but the name may be reassigned with another `var` statement.

```pax
var status = idle
var status = running   # allowed; reassigns
```

### 5.3 `define` — File-Level Constant

```pax
define NAME = value
```

`define` creates a constant visible anywhere in the file regardless of where
the statement appears. By convention constants are written in ALL_CAPS.
Constants cannot be shadowed inside blocks.

```pax
define ROOT = "/mnt/praxis"
define BOOT = "/mnt/praxis/boot"
define HOSTNAME = "praxisbox"
```

### 5.4 Assignment (Bare)

```pax
name = value
```

Inside a block body, bare assignment is allowed without `let` or `var`. The
assigned name is local to that block and becomes a field on the block's result
object.

```pax
config "myconfig"
{
    package = "firefox"
    desktop = xfce
}
```

Outside a block, bare assignment is equivalent to `var`.

### 5.5 Block

```pax
kind "label"
{
    statements...
}
```

A block groups a set of assignments and statements under a named kind. The
result is an object stored in the current scope under the block's kind name.
Fields assigned inside the block become properties on that object.

```pax
config "install"
{
    target  = "/mnt/praxis"
    desktop = plasma
    locale  = "en_US.UTF-8"
}

# Access via kind.field
install package config.target
set locale config.locale
```

See Section 8 for the full list of block kinds.

### 5.6 `if` — Conditional

```pax
if condition
{
    statements...
}
```

Executes the body if the condition is true. See Section 6 for condition forms.

```pax
if install.status == finished
{
    log "Install complete."
}

if hardware.status != good
{
    fail "Hardware check failed before install."
}
```

### 5.7 `each` — Iteration

```pax
each item in list
{
    statements...
}
```

Iterates over every element of a list. The loop variable `item` is bound for
each iteration. It may be any identifier.

```pax
let packages = [ org.mozilla.firefox, dev.praxis.neovim, dev.praxis.git, dev.praxis.htop ]

each pkg in packages
{
    install package pkg
}
```

`each` works on any list value. Iterating over a non-list is a runtime error.

### 5.8 `include` — File Inclusion

```pax
include "path/to/file.pax"
```

Parses and executes the target file inline at the point of the `include`
statement. The included file must have a valid Praxis header. Definitions and
bindings from the included file are visible after the `include` line.

Circular includes are detected and cause an error.

```pax
include "base-config.pax"
include "user-setup.pax"
```

---

## 6. Conditions

Conditions appear in `if` statements and `require`/`assert` actions.

### 6.1 Equality

```pax
if left == right { }
```

Both sides are expressions. Values are compared by their string representation
after path resolution. `null == null` is true.

### 6.2 Inequality

```pax
if left != right { }
```

True when the values are not equal.

### 6.3 `not`

```pax
if not condition { }
```

Negates the condition. `not` applies to the next simple condition only.

```pax
if not hardware.status == bad
{
    log "Hardware is acceptable."
}
```

### 6.4 `and`

```pax
if conditionA and conditionB { }
```

Both conditions must be true. Evaluated left to right. Short-circuits on the
first false condition.

```pax
if hardware.status == good and disk.status == ready
{
    install package dev.praxis.base-devel
}
```

### 6.5 `or`

```pax
if conditionA or conditionB { }
```

At least one condition must be true. Evaluated left to right. Short-circuits on
the first true condition.

```pax
if install.status == finished or install.status == skipped
{
    log "Proceeding after install stage."
}
```

### 6.6 Compound Conditions

`and` and `or` may be chained. `not` may appear before any term. There is no
grouping with parentheses in v1.1; conditions evaluate strictly left-to-right.

```pax
if hardware.status == good and not disk.status == error and net.status == up
{
    log "All gates passed."
}
```

---

## 7. Actions

Actions are imperative verbs. They execute immediately and may update runtime
state objects. Every action ends at a newline or end of file.

### 7.1 Output Actions

#### `print`

```pax
print value
```

Writes the value to standard output with no prefix.

```pax
print "Install complete."
print config.desktop
```

#### `log`

```pax
log value
```

Writes the value to standard output with a `[log]` prefix.

```pax
log "Starting disk setup."
log "Target: {config.target}"
```

#### `warn`

```pax
warn value
```

Writes the value to standard error with a `[warn]` prefix. Execution continues.

```pax
warn "Network not configured. Skipping online package sync."
```

#### `fail`

```pax
fail value
```

Writes the value to standard error with a `[fail]` prefix and stops execution
immediately. Unlike `stop`, `fail` sets the exit code to a failure value.

```pax
fail "Disk {config.device} not found. Cannot continue."
```

### 7.2 Control Actions

#### `stop`

```pax
stop
```

Stops execution cleanly. No further statements are executed. Exit code is
success.

```pax
if hardware.status == bad
{
    print "Stopping before install."
    stop
}
```

#### `require`

```pax
require condition
```

If the condition is false, fails with a generic message and stops execution.
Use `assert` when you want a custom message.

```pax
require hardware.status == good
require install.status != error
```

#### `assert`

```pax
assert condition "message"
```

If the condition is false, fails with the given message and stops execution.

```pax
assert hardware.status == good "Hardware check must pass before install."
assert disk.status == ready "Disk must be partitioned and formatted first."
```

### 7.3 Package Identifiers

PAX uses reverse-domain identifiers for packages. This is not optional.

A package identifier is a dotted name of at least two segments:

```text
tld.organization.packagename
```

Examples:

```text
dev.praxis.neovim
dev.praxis.kitty
dev.praxis.base-devel
org.mozilla.firefox
org.videolan.vlc
org.gnome.file-roller
org.gnome.nautilus
com.github.neovim
io.github.alacritty
```

The first segment is the top-level domain of the publishing organization.
`dev.praxis.*` is the Praxis native namespace. Third-party packages use their
upstream organization's domain reversed.

Package identifiers are bare dotted paths in PAX syntax. They are not strings.
Writing `install package "firefox"` is a syntax error in PAX. You must write
the full identifier: `install package org.mozilla.firefox`.

If you store a package identifier in a binding, assign it as a bare path:

```pax
let browser = org.mozilla.firefox
install package browser
```

Not as a string:

```pax
let browser = "org.mozilla.firefox"   # wrong — this is a string, not an identifier
```

### 7.4 Package Actions

#### `install package`

```pax
install package tld.org.name
install package path
```

Installs a package by its reverse-domain identifier. Updates `install.status`,
`install.package`.

```pax
install package org.mozilla.firefox
install package dev.praxis.neovim
install package config.browser
```

#### `install bundle`

```pax
install bundle "name"
```

Installs a named Praxis package bundle (essentials, developer, internet, etc.).
Bundles are Praxis-internal groupings, not individual packages, so they use
quoted string names.

```pax
install bundle "essentials"
install bundle "developer"
```

#### `install desktop`

```pax
install desktop name
```

Installs a desktop profile (xfce, plasma, gnome, etc.).

```pax
install desktop xfce
install desktop config.desktop
```

#### `compile package`

```pax
compile package tld.org.name
compile package path
```

Runs the Praxis source-build path for a package. Updates `compile.status`.

```pax
compile package dev.praxis.mesa-git
compile package package.source
```

### 7.4 Desktop Actions

#### `enable desktop`

```pax
enable desktop name
```

Marks the desktop for autologin on next boot. Updates `desktop.status`,
`desktop.current`.

```pax
enable desktop xfce
enable desktop config.desktop
```

#### `start desktop`

```pax
start desktop name
```

Starts the desktop session immediately (from a running system context).

```pax
start desktop xfce
```

### 7.5 System Configuration Actions

#### `set hostname`

```pax
set hostname "name"
```

Writes the hostname to `/etc/hostname` and updates `/etc/hosts`.

```pax
set hostname "praxisbox"
set hostname config.hostname
```

#### `set locale`

```pax
set locale "lang"
```

Writes the locale to `/etc/locale.conf`.

```pax
set locale "en_US.UTF-8"
```

#### `set timezone`

```pax
set timezone "zone"
```

Sets the timezone by symlinking the appropriate zoneinfo file to
`/etc/localtime`.

```pax
set timezone "America/New_York"
set timezone "UTC"
```

#### `set keymap`

```pax
set keymap "layout"
```

Writes the keymap to `/etc/vconsole.conf`.

```pax
set keymap "us"
set keymap "uk"
```

#### `set password for`

```pax
set password for "user"
```

Prompts for a password and sets it for the named user.

```pax
set password for "root"
set password for "alice"
```

### 7.6 File Actions

#### `write`

```pax
write "path" content "value"
```

Writes the string value to the file at path. Creates the file and any missing
parent directories. Overwrites if it exists. Updates `file.status`, `file.path`.

```pax
write "/etc/locale.conf" content "LANG=en_US.UTF-8\n"
write "/etc/hostname" content config.hostname
```

#### `append`

```pax
append "path" content "value"
```

Appends the value to the file at path. Creates the file if it does not exist.

```pax
append "/etc/fstab" content "UUID=deadbeef / ext4 defaults 0 1\n"
```

#### `mkdir`

```pax
mkdir "path"
```

Creates a directory and all missing parent directories.

```pax
mkdir "/mnt/praxis/boot/loader/entries"
mkdir "/mnt/praxis/home/alice"
```

#### `copy`

```pax
copy "source" to "dest"
```

Copies a file or directory. Overwrites the destination if it exists.

```pax
copy "/usr/share/praxis/boot/BOOTX64.EFI" to "/mnt/praxis/boot/EFI/BOOT/BOOTX64.EFI"
```

#### `move`

```pax
move "source" to "dest"
```

Moves a file or directory.

```pax
move "/tmp/praxis-pkg.tar.gz" to "/var/cache/praxis/pkg.tar.gz"
```

#### `symlink`

```pax
symlink "target" to "path"
```

Creates a symbolic link at `path` pointing to `target`.

```pax
symlink "/usr/share/zoneinfo/America/New_York" to "/etc/localtime"
```

#### `delete`

```pax
delete "path"
```

Deletes a file or directory. Deleting a non-existent path is not an error.

```pax
delete "/tmp/praxis-setup.pax"
```

#### `fetch`

```pax
fetch "url" to "path"
```

Downloads the URL to the given path. Updates `fetch.status`.

```pax
fetch "https://praxis-os.example/pkg/base.tar.gz" to "/tmp/base.tar.gz"
```

### 7.7 Execution Action

#### `exec`

```pax
exec "command"
```

Runs the command string through the system shell. Updates `exec.status`,
`exec.code`, and `exec.output`. If the command exits non-zero, `exec.status`
is set to `failed`; execution of PAX continues unless you check.

```pax
exec "pacman-key --init"
exec "pacman-key --populate"
exec "locale-gen"
```

### 7.8 Mount Actions

#### `mount`

```pax
mount "device" at "path"
```

Mounts a block device at the given path. Updates `mount.status`.

```pax
mount "/dev/vda2" at "/mnt/praxis"
mount "/dev/vda1" at "/mnt/praxis/boot"
```

#### `umount`

```pax
umount "path"
```

Unmounts the filesystem at the given path.

```pax
umount "/mnt/praxis/boot"
umount "/mnt/praxis"
```

### 7.9 Disk Actions

#### `format`

```pax
format "device" as fstype
```

Formats the block device as the given filesystem type. Supported types:
`vfat`, `ext4`, `btrfs`, `xfs`, `swap`.

```pax
format "/dev/vda1" as vfat
format "/dev/vda2" as ext4
```

### 7.10 Service Actions

All service actions target the system service manager (systemd or compatible).

#### `service enable`

```pax
service enable "name"
```

Enables the named service to start on boot.

```pax
service enable "NetworkManager"
service enable "sshd"
```

#### `service start`

```pax
service start "name"
```

Starts the named service immediately.

```pax
service start "NetworkManager"
```

#### `service stop`

```pax
service stop "name"
```

Stops the named service.

```pax
service stop "sshd"
```

#### `service disable`

```pax
service disable "name"
```

Disables the named service so it does not start on boot.

```pax
service disable "bluetooth"
```

#### `service restart`

```pax
service restart "name"
```

Stops then starts the named service.

```pax
service restart "NetworkManager"
```

### 7.11 User and Group Actions

#### `user create`

```pax
user create "name"
```

Creates a new system user. Updates `user.status`, `user.name`.

```pax
user create "alice"
user create config.username
```

#### `user add-group`

```pax
user add-group "user" "group"
```

Adds the user to the named group.

```pax
user add-group "alice" "wheel"
user add-group "alice" "audio"
user add-group "alice" "video"
```

#### `user set-password`

```pax
user set-password "name"
```

Prompts for a password and sets it for the named user.

```pax
user set-password "alice"
```

#### `group create`

```pax
group create "name"
```

Creates a new group.

```pax
group create "praxis"
group create "builders"
```

### 7.12 Network Actions

#### `net enable`

```pax
net enable "iface"
```

Brings up the named network interface.

```pax
net enable "eth0"
net enable "enp2s0"
```

#### `net configure`

```pax
net configure "iface"
{
    method = dhcp
    dns    = "1.1.1.1"
}
```

Configures the named interface using the options in the block. Options:
`method` (`dhcp` or `static`), `address`, `netmask`, `gateway`, `dns`.

### 7.13 Boot Actions

#### `bootloader install`

```pax
bootloader install limine
bootloader install systemd-boot
```

Installs the named bootloader to the EFI system partition. Updates
`bootloader.status`.

```pax
bootloader install limine
```

#### `bootloader entry`

```pax
bootloader entry "name"
{
    title  = "Praxis"
    linux  = "/praxis/vmlinuz"
    initrd = "/praxis/initramfs.cpio.gz"
    options = "root=UUID=deadbeef rdinit=/init praxis.live=0"
}
```

Writes a boot entry. Fields map directly to the systemd-boot entry format.

#### `initramfs build`

```pax
initramfs build "target"
```

Runs `mkinitrd` for the given target path. Updates `initramfs.status`.

```pax
initramfs build "/mnt/praxis"
```

### 7.14 Hardware Action

#### `check hardware`

```pax
check hardware
```

Runs the hardware probe. Updates `hardware.status`, `hardware.arch`,
`hardware.ram`, `hardware.cpu`, `hardware.cores`.

```pax
check hardware

if hardware.status == bad
{
    fail "Hardware probe failed."
}
```

### 7.15 Reboot Action

#### `reboot`

```pax
reboot
reboot target "name"
```

Without an argument, reboots the machine immediately. With `target`, requests a
reboot into the named boot entry.

```pax
reboot
reboot target "praxis"
```

---

## 8. Block Kinds

Blocks group related assignments. The block result is stored as an object in
the current scope under the block's kind name.

### 8.1 `config`

General-purpose configuration block. Becomes `config` in scope.

```pax
config "install"
{
    target   = "/mnt/praxis"
    hostname = "praxisbox"
    desktop  = xfce
    locale   = "en_US.UTF-8"
    timezone = "UTC"
}
```

### 8.2 `package`

Defines a package or source build. Becomes `package` in scope.

```pax
package "mesa-git"
{
    source       = "mesa-git"
    compile      = true
    compile_mode = source
    optimize     = true
}
```

### 8.3 `profile`

An install preset. Becomes `profile` in scope.

```pax
profile "workstation"
{
    desktop  = plasma
    browser  = "firefox"
    editor   = "neovim"
    terminal = "kitty"
    media    = "vlc"
}
```

### 8.4 `disk`

Describes a disk layout. Becomes `disk` in scope.

```pax
disk "main"
{
    device    = "/dev/vda"
    table     = gpt
    boot_size = "512M"
    root_size = remaining
}
```

### 8.5 `partition`

Defines a single partition within a disk layout. Becomes `partition` in scope.

```pax
partition "boot"
{
    device = "/dev/vda1"
    type   = efi
    format = vfat
    mount  = "/mnt/praxis/boot"
}

partition "root"
{
    device = "/dev/vda2"
    type   = linux
    format = ext4
    mount  = "/mnt/praxis"
}
```

### 8.6 `hardware`

Declares hardware requirements. Becomes `hardware` in scope.

```pax
hardware "minimum"
{
    arch  = x86_64
    ram   = 512
    cores = 1
}
```

### 8.7 `boot`

Describes a boot configuration. Becomes `boot` in scope.

```pax
boot "praxis"
{
    loader  = limine
    desktop = xfce
    timeout = 4
}
```

### 8.8 `source`

Defines a source build job. Becomes `source` in scope.

```pax
source "mesa-custom"
{
    repo     = "https://gitlab.freedesktop.org/mesa/mesa.git"
    branch   = "main"
    build    = meson
    optimize = true
}
```

### 8.9 `network`

Describes a network interface configuration. Becomes `network` in scope.

```pax
network "primary"
{
    iface   = "eth0"
    method  = dhcp
    dns     = "1.1.1.1"
    dns2    = "9.9.9.9"
}
```

### 8.10 `user`

Defines a user to create. Becomes `user` in scope.

```pax
user "alice"
{
    shell  = "/bin/bash"
    home   = "/home/alice"
    groups = [ "wheel", "audio", "video" ]
}
```

### 8.11 `service`

Describes a service configuration. Becomes `service` in scope.

```pax
service "sshd"
{
    enable  = true
    start   = true
}
```

---

## 9. Runtime State

PAX maintains a set of built-in state objects updated by actions. These are
always available via dotted path lookups.

### 9.1 `hardware`

Updated by `check hardware`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `hardware.status`   | symbol | `unknown`, `good`, `bad`           |
| `hardware.arch`     | string | CPU architecture (e.g. `x86_64`)  |
| `hardware.ram`      | int    | Total RAM in MiB                   |
| `hardware.cpu`      | string | CPU model name                     |
| `hardware.cores`    | int    | Number of logical CPU cores        |

### 9.2 `install`

Updated by `install` actions.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `install.status`    | symbol | `idle`, `finished`, `failed`       |
| `install.target`    | string | What was installed (package, etc.) |
| `install.package`   | string | Package name                       |

### 9.3 `compile`

Updated by `compile package`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `compile.status`    | symbol | `idle`, `finished`, `failed`       |
| `compile.package`   | string | Package name                       |
| `compile.mode`      | symbol | `source`, `binary`                 |

### 9.4 `desktop`

Updated by `enable desktop`, `install desktop`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `desktop.status`    | symbol | `disabled`, `enabled`              |
| `desktop.current`   | string | Active desktop name                |

### 9.5 `disk`

Updated by `mount`, `format`, `umount`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `disk.status`       | symbol | `idle`, `mounted`, `formatted`     |
| `disk.device`       | string | Last affected device               |
| `disk.mount`        | string | Last mount point                   |

### 9.6 `exec`

Updated by `exec`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `exec.status`       | symbol | `idle`, `finished`, `failed`       |
| `exec.code`         | int    | Last exit code                     |
| `exec.output`       | string | Last command output                |

### 9.7 `fetch`

Updated by `fetch`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `fetch.status`      | symbol | `idle`, `finished`, `failed`       |
| `fetch.url`         | string | Last fetched URL                   |
| `fetch.path`        | string | Destination path                   |

### 9.8 `file`

Updated by `write`, `append`, `copy`, `move`, `delete`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `file.status`       | symbol | `idle`, `written`, `failed`        |
| `file.path`         | string | Last affected path                 |

### 9.9 `net`

Updated by `net enable`, `net configure`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `net.status`        | symbol | `down`, `up`, `failed`             |
| `net.iface`         | string | Last configured interface          |

### 9.10 `user`

Updated by `user create`, `user add-group`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `user.status`       | symbol | `idle`, `created`, `failed`        |
| `user.name`         | string | Last created user name             |

### 9.11 `boot`

Updated by `bootloader install`, `reboot`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `boot.status`       | symbol | `idle`, `installed`, `rebooting`   |

### 9.12 `initramfs`

Updated by `initramfs build`.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `initramfs.status`  | symbol | `idle`, `built`, `failed`          |
| `initramfs.target`  | string | Target path                        |

### 9.13 `pax`

Always available. Set from the file header.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `pax.header`        | string | Full raw header line               |
| `pax.label`         | string | The label from the header          |

### 9.14 `system`

Available when the interpreter can read system information.

| Path                | Type   | Description                        |
|---------------------|--------|------------------------------------|
| `system.hostname`   | string | Current hostname                   |
| `system.arch`       | string | CPU architecture                   |
| `system.kernel`     | string | Kernel version string              |

---

## 10. Scope Rules

PAX has two scopes: file scope and block scope.

**File scope** is the default. `let`, `var`, `define`, bare assignment, and
block results all live here unless they appear inside a block body.

**Block scope** applies inside `{ }` bodies. Assignments inside a block are
fields on that block's result object, not variables in the enclosing scope.

```pax
let desktop = xfce       # file scope; accessible as desktop anywhere

config "setup"
{
    target = "/mnt/praxis"  # block scope; accessible as config.target
}

install package config.target  # config is in file scope; .target is its field
```

`define` is always file scope regardless of where it appears. Using a `define`
name inside a block refers to the file-scope constant.

Loop variables in `each` are local to the loop body and do not persist after
the loop.

---

## 11. Error Handling

By default, any runtime error stops execution and exits with a failure code.

The `on error` block catches errors from actions in its scope:

```pax
on error
{
    warn "Something failed."
    log "exec.status: {exec.status}"
}

exec "some-risky-command"
```

`on error` does not catch `fail`, `stop`, or `require`/`assert` failures.
Those are explicit termination requests, not errors.

Only one `on error` block is active at a time. A new `on error` block replaces
the previous one.

---

## 12. Grammar

Formal grammar in EBNF-like notation.

```text
file        = header { statement }

header      = "[.Praxis Config - " LABEL " .praxis.pax./]"

statement   = let_stmt
            | var_stmt
            | define_stmt
            | assignment
            | block
            | if_stmt
            | each_stmt
            | include_stmt
            | on_error_stmt
            | action

let_stmt    = "let" IDENT "=" expression
var_stmt    = "var" IDENT "=" expression
define_stmt = "define" IDENT "=" expression
assignment  = IDENT "=" expression
block       = IDENT STRING "{" { statement } "}"

if_stmt     = "if" condition "{" { statement } "}"
each_stmt   = "each" IDENT "in" expression "{" { statement } "}"
include_stmt= "include" STRING
on_error    = "on" "error" "{" { statement } "}"

condition   = simple_cond { ("and" | "or") simple_cond }
simple_cond = ["not"] expression ("==" | "!=") expression

action      = print_action
            | log_action
            | warn_action
            | fail_action
            | stop_action
            | require_action
            | assert_action
            | install_action
            | compile_action
            | enable_action
            | start_action
            | set_action
            | write_action
            | append_action
            | mkdir_action
            | copy_action
            | move_action
            | symlink_action
            | delete_action
            | fetch_action
            | exec_action
            | mount_action
            | umount_action
            | format_action
            | service_action
            | user_action
            | group_action
            | net_action
            | bootloader_action
            | initramfs_action
            | check_action
            | reboot_action

print_action      = "print" expression
log_action        = "log" expression
warn_action       = "warn" expression
fail_action       = "fail" expression
stop_action       = "stop"
require_action    = "require" condition
assert_action     = "assert" condition STRING
install_action    = "install" ("package"|"bundle"|"desktop") expression
compile_action    = "compile" "package" expression
enable_action     = "enable" "desktop" expression
start_action      = "start" "desktop" expression
set_action        = "set" ("hostname"|"locale"|"timezone"|"keymap") expression
                  | "set" "password" "for" expression
write_action      = "write" expression "content" expression
append_action     = "append" expression "content" expression
mkdir_action      = "mkdir" expression
copy_action       = "copy" expression "to" expression
move_action       = "move" expression "to" expression
symlink_action    = "symlink" expression "to" expression
delete_action     = "delete" expression
fetch_action      = "fetch" expression "to" expression
exec_action       = "exec" expression
mount_action      = "mount" expression "at" expression
umount_action     = "umount" expression
format_action     = "format" expression "as" IDENT
service_action    = "service" ("enable"|"start"|"stop"|"disable"|"restart") expression
user_action       = "user" ("create"|"set-password") expression
                  | "user" "add-group" expression expression
group_action      = "group" "create" expression
net_action        = "net" "enable" expression
                  | "net" "configure" expression "{" { assignment } "}"
bootloader_action = "bootloader" "install" IDENT
                  | "bootloader" "entry" STRING "{" { assignment } "}"
initramfs_action  = "initramfs" "build" expression
check_action      = "check" "hardware"
reboot_action     = "reboot"
                  | "reboot" "target" expression

expression  = STRING | INTEGER | BOOLEAN | list | path | symbol
list        = "[" [ expression { "," expression } [","] ] "]"
path        = IDENT { "." IDENT }
symbol      = IDENT
```

---

## 13. Full Example

This file is a complete Praxis install run in PAX. It partitions a disk,
formats it, mounts it, deploys the rootfs, writes configuration, installs a
desktop, configures a user, sets the bootloader, and verifies the result.

```pax
[.Praxis Config - full workstation install .praxis.pax./]

# ── Constants ────────────────────────────────────────────────────────────────

define DEVICE   = "/dev/vda"
define TARGET   = "/mnt/praxis"
define BOOT     = "/mnt/praxis/boot"
define HOSTNAME = "praxisbox"
define LOCALE   = "en_US.UTF-8"
define TIMEZONE = "America/New_York"

# ── Hardware gate ─────────────────────────────────────────────────────────────

check hardware

assert hardware.status == good "Hardware check must pass before install."
log "Hardware: {hardware.arch}, {hardware.ram}MiB RAM, {hardware.cores} cores"

# ── Disk layout ───────────────────────────────────────────────────────────────

disk "main"
{
    device    = DEVICE
    table     = gpt
    boot_size = "512M"
    root_size = remaining
}

format "/dev/vda1" as vfat
format "/dev/vda2" as ext4

mkdir TARGET
mkdir BOOT
mount "/dev/vda2" at TARGET
mount "/dev/vda1" at BOOT

log "Disk mounted at {TARGET}"

# ── Rootfs deploy ─────────────────────────────────────────────────────────────

config "install"
{
    target   = TARGET
    hostname = HOSTNAME
    desktop  = plasma
    locale   = LOCALE
    timezone = TIMEZONE
}

install package "base-devel"
install bundle "essentials"
install desktop config.desktop

assert install.status == finished "Base install must complete before configuration."

# ── System configuration ──────────────────────────────────────────────────────

set hostname config.hostname
set locale config.locale
set timezone config.timezone
set keymap "us"

symlink "/usr/share/zoneinfo/{config.timezone}" to "/etc/localtime"

write "/etc/locale.conf" content "LANG={config.locale}\n"

exec "locale-gen"

# ── User setup ────────────────────────────────────────────────────────────────

user create "alice"
user add-group "alice" "wheel"
user add-group "alice" "audio"
user add-group "alice" "video"
user set-password "alice"
set password for "root"

# ── Services ──────────────────────────────────────────────────────────────────

service enable "NetworkManager"
service enable "sshd"

# ── Initramfs and boot ────────────────────────────────────────────────────────

initramfs build TARGET

assert initramfs.status == built "Initramfs must build before bootloader install."

bootloader install limine

bootloader entry "praxis"
{
    title   = "Praxis"
    linux   = "/praxis/vmlinuz"
    initrd  = "/praxis/initramfs.cpio.gz"
    options = "root=UUID=auto rdinit=/init praxis.live=0 loglevel=3"
}

# ── Finish ────────────────────────────────────────────────────────────────────

umount BOOT
umount TARGET

log "Install complete. Boot with: make qemu-installed"
```
