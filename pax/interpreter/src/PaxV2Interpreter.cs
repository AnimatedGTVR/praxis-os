using System.Text.RegularExpressions;

namespace Praxis.Pax;

internal sealed class PaxV2Interpreter
{
    private readonly Dictionary<string, object?> _consts = new(StringComparer.Ordinal);
    private readonly Dictionary<string, object?> _lets = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Decl> _decls = new(StringComparer.Ordinal);
    private readonly V2Map _state = new();
    private string? _pendingDangerousAction;
    private int _pendingDangerousLine;
    private bool _stopped;

    public void Execute(PaxHeader header)
    {
        SeedState();
        var lines = LoadLines(header.Body, header.BodyStartLine);
        RunBlock(lines, 0, lines.Count);
    }

    private void SeedState()
    {
        SetState("state.hardware.status", "unknown");
        SetState("state.disk.table_committed", false);
        SetState("state.package.status", "idle");
        SetState("state.initramfs.status", "idle");
        SetState("state.bootloader.status", "idle");
    }

    private int RunBlock(List<V2Line> lines, int start, int end)
    {
        var i = start;
        while (i < end)
        {
            if (_stopped) return i;
            var line = lines[i].Text;

            if (line.StartsWith("const ", StringComparison.Ordinal) ||
                line.StartsWith("let ", StringComparison.Ordinal))
            {
                RunBinding(line, lines[i].Number);
                i++;
                continue;
            }

            if (line.StartsWith("input ", StringComparison.Ordinal))
            {
                Console.WriteLine($"[input] {line["input ".Length..]}");
                i++;
                continue;
            }

            if (line.StartsWith("declare ", StringComparison.Ordinal))
            {
                i = RunDeclaration(lines, i);
                continue;
            }

            if (line.StartsWith("for ", StringComparison.Ordinal))
            {
                i = RunFor(lines, i);
                continue;
            }

            if (line.StartsWith("if ", StringComparison.Ordinal))
            {
                i = RunIf(lines, i);
                continue;
            }

            if (line.StartsWith("bootloader entry ", StringComparison.Ordinal))
            {
                i = RunBootEntry(lines, i);
                continue;
            }

            RunStatement(line, lines[i].Number);
            i++;
        }

        return i;
    }

    private void RunBinding(string line, int number)
    {
        var match = Regex.Match(line, @"^(const|let)\s+(.+?)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$");
        if (!match.Success) throw Error(number, "invalid typed binding");

        var kind = match.Groups[1].Value;
        var type = match.Groups[2].Value;
        var name = match.Groups[3].Value;
        var expr = match.Groups[4].Value;
        var table = kind == "const" ? _consts : _lets;

        if (_consts.ContainsKey(name) || _lets.ContainsKey(name))
            throw Error(number, $"name already bound: {name}");

        var value = EvalTyped(type, expr, number);
        ValidateType(type, value, number);
        table[name] = value;
    }

    private object? EvalTyped(string type, string expr, int number)
    {
        if (type.StartsWith("List<", StringComparison.Ordinal))
        {
            if (!expr.StartsWith("[", StringComparison.Ordinal) || !expr.EndsWith("]", StringComparison.Ordinal))
                throw Error(number, "list binding must use [ ... ]");
            var inner = expr[1..^1].Trim();
            if (string.IsNullOrWhiteSpace(inner)) return new List<object?>();
            return SplitComma(inner)
                .Select(item => item.Trim())
                .Where(item => item.Length > 0)
                .Select(item => EvalExpr(item, number))
                .ToList();
        }

        return EvalExpr(expr.Trim(), number);
    }

    private void ValidateType(string type, object? value, int number)
    {
        if (type.StartsWith("List<", StringComparison.Ordinal))
        {
            if (value is not List<object?>) throw Error(number, $"expected {type}");
            return;
        }

        switch (type)
        {
            case "Path":
                if (value is not string path || !path.StartsWith("/", StringComparison.Ordinal))
                    throw Error(number, "Path values must be absolute strings");
                break;
            case "String":
            case "Symbol":
            case "Package":
            case "Bundle":
            case "Desktop":
            case "Service":
            case "Command":
            case "Url":
                if (value is not string) throw Error(number, $"expected {type}");
                break;
            case "Bool":
                if (value is not bool) throw Error(number, "expected Bool");
                break;
            case "Int":
                if (value is not int) throw Error(number, "expected Int");
                break;
            default:
                throw Error(number, $"unknown type: {type}");
        }
    }

    private int RunDeclaration(List<V2Line> lines, int start)
    {
        var header = lines[start];
        var match = Regex.Match(header.Text, @"^declare\s+([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{$");
        if (!match.Success) throw Error(header.Number, "invalid declaration header");

        var type = match.Groups[1].Value;
        var name = match.Groups[2].Value;
        var id = $"{TypeNamespace(type)}.{name}";
        if (_decls.ContainsKey(id)) throw Error(header.Number, $"declaration already exists: {id}");

        var fields = new Dictionary<string, object?>(StringComparer.Ordinal);
        var i = start + 1;
        for (; i < lines.Count; i++)
        {
            if (lines[i].Text == "}") break;
            var field = Regex.Match(lines[i].Text, @"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$");
            if (!field.Success) throw Error(lines[i].Number, "invalid declaration field");
            fields[field.Groups[1].Value] = EvalExpr(field.Groups[2].Value.Trim(), lines[i].Number);
        }

        if (i >= lines.Count) throw Error(header.Number, "unterminated declaration");
        ValidateDeclaration(type, fields, header.Number);
        _decls[id] = new Decl(type, id, fields);
        Console.WriteLine($"[declare] {type} {id}");
        return i + 1;
    }

    private void ValidateDeclaration(string type, Dictionary<string, object?> fields, int number)
    {
        switch (type)
        {
            case "Disk":
                RequireFields(fields, number, "device", "table");
                break;
            case "Partition":
                RequireFields(fields, number, "disk", "number", "start", "end", "type");
                break;
            default:
                throw Error(number, $"unknown declaration type: {type}");
        }
    }

    private static void RequireFields(Dictionary<string, object?> fields, int number, params string[] names)
    {
        foreach (var name in names)
            if (!fields.ContainsKey(name))
                throw new PaxException($"missing required declaration field '{name}' at line {number}");
    }

    private int RunFor(List<V2Line> lines, int start)
    {
        var header = lines[start];
        var match = Regex.Match(header.Text, @"^for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{$");
        if (!match.Success) throw Error(header.Number, "invalid for loop");

        var itemName = match.Groups[1].Value;
        var listName = match.Groups[2].Value;
        var bodyStart = start + 1;
        var bodyEnd = FindClosingBrace(lines, bodyStart, header.Number);

        var value = ResolveName(listName);
        if (value is not List<object?> items) throw Error(header.Number, $"for expects list: {listName}");

        var hadExisting = _lets.TryGetValue(itemName, out var previous);
        foreach (var item in items)
        {
            _lets[itemName] = item;
            RunBlock(lines, bodyStart, bodyEnd);
        }

        if (hadExisting) _lets[itemName] = previous;
        else _lets.Remove(itemName);

        return bodyEnd + 1;
    }

    private int RunIf(List<V2Line> lines, int start)
    {
        var header = lines[start];
        var match = Regex.Match(header.Text, "^if\\s+(.+?)\\s*(==|!=)\\s*(.+?)\\s*\\{$");
        if (!match.Success) throw Error(header.Number, "invalid if condition");
        var bodyStart = start + 1;
        var bodyEnd = FindClosingBrace(lines, bodyStart, header.Number);

        if (EvalComparison(match.Groups[1].Value, match.Groups[2].Value, match.Groups[3].Value, header.Number))
            RunBlock(lines, bodyStart, bodyEnd);

        return bodyEnd + 1;
    }

    private int RunBootEntry(List<V2Line> lines, int start)
    {
        var header = lines[start];
        var match = Regex.Match(header.Text, "^bootloader entry\\s+(.+)\\s*\\{$");
        if (!match.Success) throw Error(header.Number, "invalid bootloader entry");
        MarkDangerous(header.Text, header.Number);
        var label = Stringify(EvalExpr(match.Groups[1].Value.Trim(), header.Number));
        var end = FindClosingBrace(lines, start + 1, header.Number);

        Console.WriteLine($"[bootloader] entry {label}");
        SetState("state.bootloader.last_entry", label);
        return end + 1;
    }

    private void RunStatement(string line, int number)
    {
        if (line == "check hardware")
        {
            Console.WriteLine("[check] hardware -> good");
            SetState("state.hardware.status", "good");
            SetState("state.hardware.arch", "x86_64");
            return;
        }

        if (line.StartsWith("assert ", StringComparison.Ordinal))
        {
            RunAssert(line, number);
            return;
        }

        if (line.StartsWith("require ", StringComparison.Ordinal))
        {
            RunRequire(line, number);
            return;
        }

        if (line.StartsWith("fail ", StringComparison.Ordinal))
        {
            Console.Error.WriteLine($"[fail] {Stringify(EvalExpr(line["fail ".Length..].Trim(), number))}");
            _stopped = true;
            throw Error(number, "execution stopped by fail");
        }

        if (line.StartsWith("write gpt to ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var disk = EvalExpr(line["write gpt to ".Length..].Trim(), number);
            Console.WriteLine($"[write] gpt to {disk}");
            SetState("state.disk.last_table", disk);
            return;
        }

        if (line.StartsWith("create ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var obj = EvalExpr(line["create ".Length..].Trim(), number);
            Console.WriteLine($"[create] {obj}");
            if (Stringify(obj).StartsWith("partition.", StringComparison.Ordinal))
                SetState("state.disk.last_partition", obj);
            return;
        }

        if (line == "commit partition table disk.main" || line.StartsWith("commit partition table ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var target = line["commit partition table ".Length..].Trim();
            Console.WriteLine($"[commit] partition table {target}");
            SetState("state.disk.table_committed", true);
            return;
        }

        var format = Regex.Match(line, @"^format\s+(.+?)\s+as\s+(.+)$");
        if (format.Success)
        {
            MarkDangerous(line, number);
            var target = EvalExpr(format.Groups[1].Value.Trim(), number);
            var fs = EvalExpr(format.Groups[2].Value.Trim(), number);
            Console.WriteLine($"[format] {target} as {fs}");
            SetState("state.disk.last_format", target);
            SetState("state.disk.last_filesystem", fs);
            return;
        }

        if (line.StartsWith("mkdir ", StringComparison.Ordinal))
        {
            var path = EvalExpr(line["mkdir ".Length..].Trim(), number);
            Console.WriteLine($"[mkdir] {path}");
            SetState("state.file.last_mkdir", path);
            return;
        }

        var mount = Regex.Match(line, @"^mount\s+(.+?)\s+at\s+(.+)$");
        if (mount.Success)
        {
            MarkDangerous(line, number);
            var target = EvalExpr(mount.Groups[1].Value.Trim(), number);
            var path = Stringify(EvalExpr(mount.Groups[2].Value.Trim(), number));
            Console.WriteLine($"[mount] {target} at {path}");
            SetMapValue("state.mount", path, "mounted");
            return;
        }

        if (line.StartsWith("install bundle ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var bundle = EvalExpr(line["install bundle ".Length..].Trim(), number);
            Console.WriteLine($"[install] bundle {bundle}");
            SetState("state.package.last_bundle", bundle);
            return;
        }

        if (line.StartsWith("install package ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var package = EvalExpr(line["install package ".Length..].Trim(), number);
            Console.WriteLine($"[install] package {package}");
            SetState("state.package.last_install", package);
            return;
        }

        if (line.StartsWith("install desktop ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var desktop = EvalExpr(line["install desktop ".Length..].Trim(), number);
            Console.WriteLine($"[install] desktop {desktop}");
            SetState("state.desktop.current", desktop);
            return;
        }

        if (line.StartsWith("set password for ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var user = EvalExpr(line["set password for ".Length..].Trim(), number);
            Console.WriteLine($"[set] password for {user}");
            SetState("state.user.last_password", user);
            return;
        }

        var set = Regex.Match(line, @"^set\s+([A-Za-z-]+)\s+(.+)$");
        if (set.Success)
        {
            var key = set.Groups[1].Value;
            var value = EvalExpr(set.Groups[2].Value.Trim(), number);
            Console.WriteLine($"[set] {key} {value}");
            if (key is "hostname" or "locale" or "timezone" or "keymap")
                SetState($"state.system.{key}", value);
            return;
        }

        var writeFile = Regex.Match(line, "^write file\\s+(.+?)\\s+content\\s+(.+)$");
        if (writeFile.Success)
        {
            MarkDangerous(line, number);
            var path = EvalExpr(writeFile.Groups[1].Value.Trim(), number);
            Console.WriteLine($"[write] {path}");
            SetState("state.file.last_write", path);
            return;
        }

        if (line.StartsWith("exec command ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var command = EvalExpr(line["exec command ".Length..].Trim(), number);
            Console.WriteLine($"[exec] {command}");
            SetState("state.exec.code", 0);
            return;
        }

        if (line.StartsWith("user create ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var user = EvalExpr(line["user create ".Length..].Trim(), number);
            Console.WriteLine($"[user] create {user}");
            SetState("state.user.last_create", user);
            return;
        }

        if (line.StartsWith("user add-group ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var parts = SplitWords(line["user add-group ".Length..], number, 2);
            var user = EvalExpr(parts[0], number);
            var group = EvalExpr(parts[1], number);
            Console.WriteLine($"[user] add-group {user} {group}");
            SetState("state.user.last_group", group);
            return;
        }

        if (line.StartsWith("user set-password ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var user = EvalExpr(line["user set-password ".Length..].Trim(), number);
            Console.WriteLine($"[user] set-password {user}");
            SetState("state.user.last_password", user);
            return;
        }

        if (line.StartsWith("service enable ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var service = EvalExpr(line["service enable ".Length..].Trim(), number);
            Console.WriteLine($"[service] enable {service}");
            SetState("state.service.last_enable", service);
            return;
        }

        if (line.StartsWith("initramfs build ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var target = EvalExpr(line["initramfs build ".Length..].Trim(), number);
            Console.WriteLine($"[initramfs] build {target}");
            SetState("state.initramfs.status", "built");
            return;
        }

        if (line.StartsWith("bootloader install ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var loader = EvalExpr(line["bootloader install ".Length..].Trim(), number);
            Console.WriteLine($"[bootloader] install {loader}");
            SetState("state.bootloader.status", "installed");
            return;
        }

        if (line.StartsWith("umount ", StringComparison.Ordinal))
        {
            MarkDangerous(line, number);
            var path = Stringify(EvalExpr(line["umount ".Length..].Trim(), number));
            Console.WriteLine($"[umount] {path}");
            SetMapValue("state.mount", path, "unmounted");
            return;
        }

        if (line.StartsWith("log ", StringComparison.Ordinal))
        {
            Console.WriteLine($"[log] {Stringify(EvalExpr(line["log ".Length..].Trim(), number))}");
            return;
        }

        throw Error(number, $"unsupported v2 statement: {line}");
    }

    private void RunAssert(string line, int number)
    {
        var match = Regex.Match(line, "^assert\\s+(.+?)\\s*(==|!=)\\s*(.+?)\\s+\"(.*)\"$");
        if (!match.Success) throw Error(number, "invalid assertion");

        var ok = EvalComparison(match.Groups[1].Value, match.Groups[2].Value, match.Groups[3].Value, number);
        if (!ok) throw Error(number, $"assertion failed: {match.Groups[4].Value}");
        ClearDangerous();
        Console.WriteLine($"[assert] {match.Groups[1].Value.Trim()} {match.Groups[2].Value} {match.Groups[3].Value.Trim()}");
    }

    private void MarkDangerous(string line, int number)
    {
        if (_pendingDangerousAction is not null)
            throw Error(number, $"dangerous action requires assertion after line {_pendingDangerousLine}: {_pendingDangerousAction}");
        _pendingDangerousAction = line;
        _pendingDangerousLine = number;
    }

    private void ClearDangerous()
    {
        _pendingDangerousAction = null;
        _pendingDangerousLine = 0;
    }

    private void RunRequire(string line, int number)
    {
        var match = Regex.Match(line, "^require\\s+(.+?)\\s*(==|!=)\\s*(.+)$");
        if (!match.Success) throw Error(number, "invalid require condition");
        if (!EvalComparison(match.Groups[1].Value, match.Groups[2].Value, match.Groups[3].Value, number))
            throw Error(number, "require condition not met");
        Console.WriteLine($"[require] {match.Groups[1].Value.Trim()} {match.Groups[2].Value} {match.Groups[3].Value.Trim()}");
    }

    private bool EvalComparison(string leftExpr, string op, string rightExpr, int number)
    {
        var left = EvalExpr(leftExpr.Trim(), number);
        var right = EvalExpr(rightExpr.Trim(), number);
        var equal = ValuesEqual(left, right);
        return op == "==" ? equal : !equal;
    }

    private object? EvalExpr(string expr, int number)
    {
        expr = expr.Trim().TrimEnd(',');
        if (expr.StartsWith("\"", StringComparison.Ordinal) && expr.EndsWith("\"", StringComparison.Ordinal))
            return Regex.Unescape(expr[1..^1]);
        if (expr.StartsWith("pkg ", StringComparison.Ordinal))
            return expr["pkg ".Length..].Trim();
        if (expr.StartsWith("bundle ", StringComparison.Ordinal))
            return expr["bundle ".Length..].Trim().Trim('"');
        if (expr == "true") return true;
        if (expr == "false") return false;
        if (int.TryParse(expr, out var intValue)) return intValue;

        if (expr.StartsWith("state.", StringComparison.Ordinal))
            return ResolveState(expr, number);

        if (_consts.TryGetValue(expr, out var c)) return c;
        if (_lets.TryGetValue(expr, out var l)) return l;
        if (_decls.TryGetValue(expr, out var d)) return d.Id;

        if (expr.Contains('.', StringComparison.Ordinal))
        {
            if (_decls.ContainsKey(expr)) return expr;
            throw Error(number, $"unknown path: {expr}");
        }

        return expr;
    }

    private static string[] SplitWords(string text, int number, int expected)
    {
        var parts = new List<string>();
        var current = "";
        var inString = false;
        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (c == '"' && (i == 0 || text[i - 1] != '\\')) inString = !inString;
            if (char.IsWhiteSpace(c) && !inString)
            {
                if (current.Length > 0) { parts.Add(current); current = ""; }
                continue;
            }
            current += c;
        }
        if (current.Length > 0) parts.Add(current);
        if (parts.Count != expected) throw Error(number, $"expected {expected} arguments");
        return parts.ToArray();
    }

    private object? ResolveState(string path, int number)
    {
        var parts = path.Split('.');
        object? current = _state;
        for (var i = 1; i < parts.Length; i++)
        {
            var part = parts[i];
            if (i == 2 && parts[1] == "mount")
                part = Stringify(ResolveNameOrSelf(part));

            if (current is V2Map map && map.TryGetValue(part, out var next))
            {
                current = next;
                continue;
            }
            throw Error(number, $"unknown state path: {path}");
        }
        return current;
    }

    private object? ResolveName(string name)
    {
        if (_lets.TryGetValue(name, out var l)) return l;
        if (_consts.TryGetValue(name, out var c)) return c;
        return null;
    }

    private object? ResolveNameOrSelf(string name) => ResolveName(name) ?? name;

    private void SetState(string path, object? value)
    {
        var parts = path.Split('.');
        var current = _state;
        for (var i = 1; i < parts.Length - 1; i++)
        {
            if (current.TryGetValue(parts[i], out var next) && next is V2Map existing)
            {
                current = existing;
                continue;
            }
            var created = new V2Map();
            current[parts[i]] = created;
            current = created;
        }
        current[parts[^1]] = value;
    }

    private void SetMapValue(string mapPath, string key, object? value)
    {
        var parts = mapPath.Split('.');
        var current = _state;
        for (var i = 1; i < parts.Length; i++)
        {
            if (current.TryGetValue(parts[i], out var next) && next is V2Map existing)
            {
                current = existing;
                continue;
            }
            var created = new V2Map();
            current[parts[i]] = created;
            current = created;
        }
        current[key] = value;
    }

    private static List<V2Line> LoadLines(string body, int startLine)
    {
        var result = new List<V2Line>();
        var raw = body.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        for (var i = 0; i < raw.Length; i++)
        {
            var line = StripComment(raw[i]).Trim();
            if (string.IsNullOrWhiteSpace(line)) continue;
            result.Add(new V2Line(line, startLine + i));
        }
        return MergeMultilineLists(result);
    }

    private static List<V2Line> MergeMultilineLists(List<V2Line> lines)
    {
        var merged = new List<V2Line>();
        for (var i = 0; i < lines.Count; i++)
        {
            var line = lines[i];
            if (!line.Text.Contains("[", StringComparison.Ordinal) || line.Text.Contains("]", StringComparison.Ordinal))
            {
                merged.Add(line);
                continue;
            }

            var text = line.Text;
            while (!text.Contains("]", StringComparison.Ordinal) && i + 1 < lines.Count)
            {
                i++;
                text += " " + lines[i].Text;
            }
            merged.Add(line with { Text = text });
        }
        return merged;
    }

    private static string StripComment(string line)
    {
        var inString = false;
        for (var i = 0; i < line.Length; i++)
        {
            if (line[i] == '"' && (i == 0 || line[i - 1] != '\\')) inString = !inString;
            if (line[i] == '#' && !inString) return line[..i];
        }
        return line;
    }

    private static IEnumerable<string> SplitComma(string text)
    {
        var inString = false;
        var start = 0;
        for (var i = 0; i < text.Length; i++)
        {
            if (text[i] == '"' && (i == 0 || text[i - 1] != '\\')) inString = !inString;
            if (text[i] != ',' || inString) continue;
            yield return text[start..i];
            start = i + 1;
        }
        yield return text[start..];
    }

    private static int FindClosingBrace(List<V2Line> lines, int start, int openingLine)
    {
        var depth = 1;
        for (var i = start; i < lines.Count; i++)
        {
            if (lines[i].Text.EndsWith("{", StringComparison.Ordinal)) depth++;
            if (lines[i].Text == "}") depth--;
            if (depth == 0) return i;
        }
        throw new PaxException($"unterminated block opened at line {openingLine}");
    }

    private static string TypeNamespace(string type) => type.ToLowerInvariant() switch
    {
        "disk" => "disk",
        "partition" => "partition",
        _ => type.ToLowerInvariant()
    };

    private static bool ValuesEqual(object? left, object? right)
        => string.Equals(Stringify(left), Stringify(right), StringComparison.Ordinal);

    private static string Stringify(object? value) => value switch
    {
        null => "null",
        bool b => b ? "true" : "false",
        int i => i.ToString(),
        Decl d => d.Id,
        _ => value.ToString() ?? string.Empty
    };

    private static PaxException Error(int line, string message) => new($"{message} at line {line}");

    private sealed record Decl(string Type, string Id, Dictionary<string, object?> Fields);
    private sealed record V2Line(string Text, int Number);
    private sealed class V2Map : Dictionary<string, object?>
    {
        public V2Map() : base(StringComparer.Ordinal) { }
    }
}
