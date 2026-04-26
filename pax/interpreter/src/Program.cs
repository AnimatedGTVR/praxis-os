using System.Text;

namespace Praxis.Pax;

internal static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("usage: pax-interpreter <file.pax>");
            return 1;
        }

        var filePath = args[0];
        if (!File.Exists(filePath))
        {
            Console.Error.WriteLine($"missing PAX file: {filePath}");
            return 1;
        }

        try
        {
            var source = File.ReadAllText(filePath);
            var header = PaxHeader.Parse(source);
            var lexer = new Lexer(header.Body, header.BodyStartLine);
            var tokens = lexer.Tokenize();
            var parser = new Parser(tokens);
            var document = parser.ParseDocument(header);
            var interpreter = new PaxInterpreter();
            interpreter.Execute(document);
            return 0;
        }
        catch (PaxException ex)
        {
            Console.Error.WriteLine($"pax: {ex.Message}");
            return 1;
        }
    }
}

internal sealed record PaxHeader(string Raw, string Label, string Body, int BodyStartLine)
{
    public static PaxHeader Parse(string source)
    {
        var lines = source.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        var headerIndex = -1;

        for (var index = 0; index < lines.Length; index++)
        {
            if (string.IsNullOrWhiteSpace(lines[index]))
            {
                continue;
            }

            headerIndex = index;
            break;
        }

        if (headerIndex < 0)
        {
            throw new PaxException("missing Praxis header");
        }

        var headerLine = lines[headerIndex].Trim();
        const string prefix = "[.Praxis Config - ";
        const string suffix = " .praxis.pax./]";

        if (!headerLine.StartsWith(prefix, StringComparison.Ordinal) ||
            !headerLine.EndsWith(suffix, StringComparison.Ordinal))
        {
            throw new PaxException("invalid Praxis header; expected '[.Praxis Config - <label> .praxis.pax./]'");
        }

        var label = headerLine[prefix.Length..^suffix.Length].Trim();
        if (string.IsNullOrWhiteSpace(label))
        {
            throw new PaxException("Praxis header label cannot be empty");
        }

        var body = string.Join('\n', lines.Skip(headerIndex + 1));
        return new PaxHeader(headerLine, label, body, headerIndex + 2);
    }
}

// Lexer

internal enum TokenType
{
    Identifier,
    String,
    Assign,
    EqualsEquals,
    Dot,
    LBrace,
    RBrace,
    NewLine,
    EndOfFile
}

internal readonly record struct Token(TokenType Type, string Text, int Line, int Column);

internal sealed class Lexer
{
    private readonly string _source;
    private readonly List<Token> _tokens = new();
    private int _index;
    private int _line;
    private int _column = 1;

    public Lexer(string source, int startLine = 1)
    {
        _source = source;
        _line = startLine;
    }

    public List<Token> Tokenize()
    {
        while (!IsAtEnd())
        {
            var current = Current();

            if (current == ' ' || current == '\t')
            {
                Advance();
                continue;
            }

            if (current == '\r')
            {
                Advance();
                continue;
            }

            if (current == '\n')
            {
                AddToken(TokenType.NewLine, "\n");
                AdvanceLine();
                continue;
            }

            if (current == '#')
            {
                SkipComment();
                continue;
            }

            if (current == '{')
            {
                AddToken(TokenType.LBrace, "{");
                Advance();
                continue;
            }

            if (current == '}')
            {
                AddToken(TokenType.RBrace, "}");
                Advance();
                continue;
            }

            if (current == '.')
            {
                AddToken(TokenType.Dot, ".");
                Advance();
                continue;
            }

            if (current == '=')
            {
                if (Peek() == '=')
                {
                    AddToken(TokenType.EqualsEquals, "==");
                    Advance();
                    Advance();
                }
                else
                {
                    AddToken(TokenType.Assign, "=");
                    Advance();
                }

                continue;
            }

            if (current == '"')
            {
                ReadString();
                continue;
            }

            if (IsIdentifierStart(current))
            {
                ReadIdentifier();
                continue;
            }

            throw Error($"unexpected character '{current}'");
        }

        _tokens.Add(new Token(TokenType.EndOfFile, string.Empty, _line, _column));
        return _tokens;
    }

    private void ReadIdentifier()
    {
        var start = _index;
        var line = _line;
        var column = _column;

        while (!IsAtEnd() && IsIdentifierPart(Current()))
        {
            Advance();
        }

        var text = _source[start.._index];
        _tokens.Add(new Token(TokenType.Identifier, text, line, column));
    }

    private void ReadString()
    {
        var line = _line;
        var column = _column;
        Advance();

        var builder = new StringBuilder();
        while (!IsAtEnd() && Current() != '"')
        {
            var current = Current();
            if (current == '\\')
            {
                Advance();
                if (IsAtEnd())
                {
                    throw Error("unterminated string escape");
                }

                var escaped = Current();
                builder.Append(escaped switch
                {
                    '"' => '"',
                    '\\' => '\\',
                    'n' => '\n',
                    't' => '\t',
                    _ => escaped
                });
                Advance();
                continue;
            }

            if (current == '\n')
            {
                throw Error("unterminated string");
            }

            builder.Append(current);
            Advance();
        }

        if (IsAtEnd())
        {
            throw Error("unterminated string");
        }

        Advance();
        _tokens.Add(new Token(TokenType.String, builder.ToString(), line, column));
    }

    private void SkipComment()
    {
        while (!IsAtEnd() && Current() != '\n')
        {
            Advance();
        }
    }

    private char Current()
    {
        return _source[_index];
    }

    private char Peek()
    {
        var next = _index + 1;
        if (next >= _source.Length)
        {
            return '\0';
        }

        return _source[next];
    }

    private bool IsAtEnd()
    {
        return _index >= _source.Length;
    }

    private void Advance()
    {
        _index++;
        _column++;
    }

    private void AdvanceLine()
    {
        _index++;
        _line++;
        _column = 1;
    }

    private void AddToken(TokenType type, string text)
    {
        _tokens.Add(new Token(type, text, _line, _column));
    }

    private static bool IsIdentifierStart(char value)
    {
        return char.IsLetter(value) || value == '_';
    }

    private static bool IsIdentifierPart(char value)
    {
        return char.IsLetterOrDigit(value) || value == '_' || value == '-';
    }

    private PaxException Error(string message)
    {
        return new PaxException($"{message} at line {_line}, column {_column}");
    }
}

// Parser

internal sealed class Parser
{
    private readonly List<Token> _tokens;
    private int _index;

    public Parser(List<Token> tokens)
    {
        _tokens = tokens;
    }

    public Document ParseDocument(PaxHeader header)
    {
        var statements = new List<Statement>();
        SkipNewLines();

        while (!Check(TokenType.EndOfFile))
        {
            statements.Add(ParseStatement());
            SkipNewLines();
        }

        return new Document(header, statements);
    }

    private Statement ParseStatement()
    {
        if (IsIdentifier("if"))
        {
            return new Statement(
                StatementKind.If,
                If: ParseIf());
        }

        if (LooksLikeBlock())
        {
            return new Statement(
                StatementKind.Block,
                Block: ParseBlock());
        }

        if (Check(TokenType.Identifier) &&
            CheckNext(TokenType.Assign))
        {
            return new Statement(
                StatementKind.Assignment,
                Assignment: ParseAssignment());
        }

        return new Statement(
            StatementKind.Action,
            Action: ParseAction());
    }

    private AssignmentNode ParseAssignment()
    {
        var name = ConsumeIdentifier("expected assignment name").Text;
        Consume(TokenType.Assign, "expected '=' after assignment name");
        var value = ParseExpression();
        RequireBoundary();
        return new AssignmentNode(name, value);
    }

    private BlockNode ParseBlock()
    {
        var kind = ConsumeIdentifier("expected block kind").Text;
        var label = Consume(TokenType.String, "expected block label").Text;
        SkipNewLines();
        Consume(TokenType.LBrace, "expected '{' after block label");

        var body = new List<Statement>();
        SkipNewLines();
        while (!Check(TokenType.RBrace))
        {
            if (Check(TokenType.EndOfFile))
            {
                throw Error("unterminated block");
            }

            body.Add(ParseStatement());
            SkipNewLines();
        }

        Consume(TokenType.RBrace, "expected '}' after block body");
        return new BlockNode(kind, label, body);
    }

    private IfNode ParseIf()
    {
        ConsumeIdentifier("expected 'if'");
        var left = ParseExpression();
        Consume(TokenType.EqualsEquals, "expected '==' in condition");
        var right = ParseExpression();
        SkipNewLines();
        Consume(TokenType.LBrace, "expected '{' after condition");

        var body = new List<Statement>();
        SkipNewLines();
        while (!Check(TokenType.RBrace))
        {
            if (Check(TokenType.EndOfFile))
            {
                throw Error("unterminated if block");
            }

            body.Add(ParseStatement());
            SkipNewLines();
        }

        Consume(TokenType.RBrace, "expected '}' after if block");
        return new IfNode(left, right, body);
    }

    private ActionNode ParseAction()
    {
        var verb = ConsumeIdentifier("expected action verb").Text;

        switch (verb)
        {
            case "print":
            {
                var argument = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, null, argument);
            }
            case "stop":
                RequireBoundary();
                return new ActionNode(verb, null, null);
            case "check":
            {
                var subject = ConsumeIdentifier("expected subject after 'check'").Text;
                RequireBoundary();
                return new ActionNode(verb, subject, null);
            }
            case "install":
            case "compile":
            case "enable":
            case "reboot":
            {
                var subject = ConsumeIdentifier($"expected subject after '{verb}'").Text;
                var argument = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, subject, argument);
            }
            default:
                throw Error($"unknown action '{verb}'");
        }
    }

    private Expression ParseExpression()
    {
        if (Check(TokenType.String))
        {
            return new Expression(ExpressionKind.String, Advance().Text, false, null);
        }

        if (!Check(TokenType.Identifier))
        {
            throw Error("expected value");
        }

        var first = Advance().Text;
        if (first == "true")
        {
            return new Expression(ExpressionKind.Boolean, first, true, null);
        }

        if (first == "false")
        {
            return new Expression(ExpressionKind.Boolean, first, false, null);
        }

        var path = new List<string> { first };
        while (Match(TokenType.Dot))
        {
            path.Add(ConsumeIdentifier("expected path segment after '.'").Text);
        }

        if (path.Count == 1)
        {
            return new Expression(ExpressionKind.Symbol, first, false, path);
        }

        return new Expression(ExpressionKind.Path, string.Join('.', path), false, path);
    }

    private void RequireBoundary()
    {
        if (Match(TokenType.NewLine))
        {
            SkipNewLines();
            return;
        }

        if (Check(TokenType.EndOfFile) || Check(TokenType.RBrace))
        {
            return;
        }

        throw Error("expected end of statement");
    }

    private void SkipNewLines()
    {
        while (Match(TokenType.NewLine))
        {
        }
    }

    private Token Consume(TokenType type, string message)
    {
        if (Check(type))
        {
            return Advance();
        }

        throw Error(message);
    }

    private Token ConsumeIdentifier(string message)
    {
        if (Check(TokenType.Identifier))
        {
            return Advance();
        }

        throw Error(message);
    }

    private bool IsIdentifier(string text)
    {
        return Check(TokenType.Identifier) && Current().Text == text;
    }

    private bool Match(TokenType type)
    {
        if (!Check(type))
        {
            return false;
        }

        Advance();
        return true;
    }

    private bool Check(TokenType type)
    {
        return Current().Type == type;
    }

    private bool CheckNext(TokenType type)
    {
        return Peek(1).Type == type;
    }

    private bool LooksLikeBlock()
    {
        if (!Check(TokenType.Identifier) || !CheckNext(TokenType.String))
        {
            return false;
        }

        var offset = 2;
        while (Peek(offset).Type == TokenType.NewLine)
        {
            offset++;
        }

        return Peek(offset).Type == TokenType.LBrace;
    }

    private Token Advance()
    {
        var token = Current();
        if (!Check(TokenType.EndOfFile))
        {
            _index++;
        }

        return token;
    }

    private Token Current()
    {
        return Peek(0);
    }

    private Token Peek(int offset)
    {
        var position = _index + offset;
        if (position >= _tokens.Count)
        {
            return _tokens[^1];
        }

        return _tokens[position];
    }

    private PaxException Error(string message)
    {
        var token = Current();
        return new PaxException($"{message} at line {token.Line}, column {token.Column}");
    }
}

// AST

internal enum StatementKind
{
    Assignment,
    Block,
    If,
    Action
}

internal enum ExpressionKind
{
    String,
    Boolean,
    Symbol,
    Path
}

internal sealed record Document(PaxHeader Header, List<Statement> Statements);
internal sealed record Statement(
    StatementKind Kind,
    AssignmentNode? Assignment = null,
    BlockNode? Block = null,
    IfNode? If = null,
    ActionNode? Action = null);
internal sealed record AssignmentNode(string Name, Expression Value);
internal sealed record BlockNode(string Kind, string Label, List<Statement> Body);
internal sealed record IfNode(Expression Left, Expression Right, List<Statement> Body);
internal sealed record ActionNode(string Verb, string? Subject, Expression? Argument);
internal sealed record Expression(ExpressionKind Kind, string Text, bool BoolValue, List<string>? Path);

// Interpreter

internal sealed class PaxInterpreter
{
    private readonly Dictionary<string, object?> _globals = new(StringComparer.Ordinal);
    private bool _stopRequested;

    public PaxInterpreter()
    {
        _globals["hardware"] = StatusObject("unknown");
        _globals["install"] = StatusObject("idle");
        _globals["compile"] = StatusObject("idle");
        _globals["desktop"] = StatusObject("disabled");
        _globals["boot"] = StatusObject("idle");
    }

    public void Execute(Document document)
    {
        _globals["pax"] = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["header"] = document.Header.Raw,
            ["label"] = document.Header.Label
        };
        ExecuteStatements(document.Statements, _globals);
    }

    private void ExecuteStatements(List<Statement> statements, Dictionary<string, object?> scope)
    {
        foreach (var statement in statements)
        {
            if (_stopRequested)
            {
                return;
            }

            ExecuteStatement(statement, scope);
        }
    }

    private void ExecuteStatement(Statement statement, Dictionary<string, object?> scope)
    {
        switch (statement.Kind)
        {
            case StatementKind.Assignment:
                ExecuteAssignment(statement.Assignment!, scope);
                break;
            case StatementKind.Block:
                ExecuteBlock(statement.Block!, scope);
                break;
            case StatementKind.If:
                ExecuteIf(statement.If!, scope);
                break;
            case StatementKind.Action:
                ExecuteAction(statement.Action!, scope);
                break;
            default:
                throw new PaxException($"unsupported statement kind: {statement.Kind}");
        }
    }

    private void ExecuteAssignment(AssignmentNode assignment, Dictionary<string, object?> scope)
    {
        scope[assignment.Name] = Evaluate(assignment.Value, scope);
    }

    private void ExecuteBlock(BlockNode block, Dictionary<string, object?> scope)
    {
        var nested = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["label"] = block.Label,
            ["kind"] = block.Kind
        };

        ExecuteStatements(block.Body, nested);
        scope[block.Kind] = nested;
    }

    private void ExecuteIf(IfNode ifNode, Dictionary<string, object?> scope)
    {
        var left = Evaluate(ifNode.Left, scope);
        var right = Evaluate(ifNode.Right, scope);

        if (ValuesEqual(left, right))
        {
            ExecuteStatements(ifNode.Body, scope);
        }
    }

    private void ExecuteAction(ActionNode action, Dictionary<string, object?> scope)
    {
        switch (action.Verb)
        {
            case "print":
                Console.WriteLine(Stringify(Evaluate(action.Argument!, scope)));
                break;
            case "stop":
                _stopRequested = true;
                break;
            case "check":
                ExecuteCheck(action, scope);
                break;
            case "install":
                ExecuteInstall(action, scope);
                break;
            case "compile":
                ExecuteCompile(action, scope);
                break;
            case "enable":
                ExecuteEnable(action, scope);
                break;
            case "reboot":
                ExecuteReboot(action, scope);
                break;
            default:
                throw new PaxException($"unsupported action: {action.Verb}");
        }
    }

    private void ExecuteCheck(ActionNode action, Dictionary<string, object?> scope)
    {
        if (action.Subject != "hardware")
        {
            throw new PaxException($"unsupported check target: {action.Subject}");
        }

        scope["hardware"] = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["status"] = "good",
            ["mode"] = "simulated",
            ["detail"] = "hardware probe passed"
        };

        Console.WriteLine("[check] hardware -> good");
    }

    private void ExecuteInstall(ActionNode action, Dictionary<string, object?> scope)
    {
        if (action.Subject != "package")
        {
            throw new PaxException($"unsupported install target: {action.Subject}");
        }

        var packageName = Stringify(Evaluate(action.Argument!, scope));
        scope["install"] = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["status"] = "finished",
            ["target"] = "package",
            ["package"] = packageName,
            ["mode"] = "simulated"
        };

        Console.WriteLine($"[install] package {packageName}");
    }

    private void ExecuteCompile(ActionNode action, Dictionary<string, object?> scope)
    {
        if (action.Subject != "package")
        {
            throw new PaxException($"unsupported compile target: {action.Subject}");
        }

        var packageName = Stringify(Evaluate(action.Argument!, scope));
        scope["compile"] = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["status"] = "finished",
            ["target"] = "package",
            ["package"] = packageName,
            ["mode"] = "simulated"
        };

        Console.WriteLine($"[compile] package {packageName}");
    }

    private void ExecuteEnable(ActionNode action, Dictionary<string, object?> scope)
    {
        if (action.Subject != "desktop")
        {
            throw new PaxException($"unsupported enable target: {action.Subject}");
        }

        var desktopName = Stringify(Evaluate(action.Argument!, scope));
        scope["desktop"] = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["status"] = "enabled",
            ["current"] = desktopName
        };

        Console.WriteLine($"[enable] desktop {desktopName}");
    }

    private void ExecuteReboot(ActionNode action, Dictionary<string, object?> scope)
    {
        var target = Stringify(Evaluate(action.Argument!, scope));
        scope["boot"] = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["status"] = "reboot-requested",
            ["subject"] = action.Subject ?? "target",
            ["target"] = target
        };

        Console.WriteLine($"[reboot] {action.Subject} {target}");
    }

    private object? Evaluate(Expression expression, Dictionary<string, object?> scope)
    {
        return expression.Kind switch
        {
            ExpressionKind.String => expression.Text,
            ExpressionKind.Boolean => expression.BoolValue,
            ExpressionKind.Symbol => expression.Text,
            ExpressionKind.Path => ResolvePath(expression.Path!, scope),
            _ => throw new PaxException($"unsupported expression kind: {expression.Kind}")
        };
    }

    private object? ResolvePath(List<string> path, Dictionary<string, object?> scope)
    {
        if (path.Count == 0)
        {
            return null;
        }

        object? current = null;
        if (scope.TryGetValue(path[0], out var localValue))
        {
            current = localValue;
        }
        else if (_globals.TryGetValue(path[0], out var globalValue))
        {
            current = globalValue;
        }

        for (var index = 1; index < path.Count; index++)
        {
            if (current is Dictionary<string, object?> map &&
                map.TryGetValue(path[index], out var next))
            {
                current = next;
                continue;
            }

            return null;
        }

        return current;
    }

    private static bool ValuesEqual(object? left, object? right)
    {
        if (left is bool leftBool && right is bool rightBool)
        {
            return leftBool == rightBool;
        }

        return string.Equals(Stringify(left), Stringify(right), StringComparison.Ordinal);
    }

    private static Dictionary<string, object?> StatusObject(string status)
    {
        return new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["status"] = status
        };
    }

    private static string Stringify(object? value)
    {
        return value switch
        {
            null => "null",
            bool boolValue => boolValue ? "true" : "false",
            Dictionary<string, object?> map => "{" + string.Join(", ", map.Select(kvp => $"{kvp.Key}={Stringify(kvp.Value)}")) + "}",
            _ => value.ToString() ?? string.Empty
        };
    }
}

internal sealed class PaxException : Exception
{
    public PaxException(string message)
        : base(message)
    {
    }
}
