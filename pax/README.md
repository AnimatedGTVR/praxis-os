# PAX

PAX is the planned domain-specific language for Praxis.

This folder contains:

- `spec/PAX.md`: the language rules
- `examples/`: example `.pax` files
- `interpreter/`: a small C# interpreter for the first version

## Layout

```text
pax/
  spec/
  examples/
  interpreter/
```

## Example Files

- `packageinstall-config.pax`
- `workstation-config.profile.pax`
- `liveboot-config.boot.pax`
- `core-packages.profile.pax`
- `source-pkg.pkg.pax`
- `ricing-desktop.profile.pax`
- `hardware-check.pax`
- `core-system-config.pax`

## Starter Set

Praxis now includes a small PAX starter set:

- `core-packages.profile.pax` for common application installs
- `source-pkg.pkg.pax` for source-build workflows through the Praxis source-pkg path
- `ricing-desktop.profile.pax` for desktop and ricing setup
- `hardware-check.pax` for hardware readiness checks
- `core-system-config.pax` for a general base-system path

## Required Header

Every PAX file must begin with a Praxis header line:

```text
[.Praxis Config - <file purpose or config name> .praxis.pax./]
```

Example:

```text
[.Praxis Config - packageinstall-config .praxis.pax./]
```

## Interpreter

The interpreter is a small split-by-section C# console app:

- Lexer
- Parser
- AST
- Interpreter

Expected usage when a .NET SDK is present:

```bash
dotnet run --project pax/interpreter/PaxInterpreter.csproj -- pax/examples/packageinstall-config.pax
```
