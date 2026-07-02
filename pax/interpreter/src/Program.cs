using System.Text;
using System.Text.RegularExpressions;

namespace Praxis.Pax;

internal static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("usage: pax-interpreter [--v2] <file.pax>");
            return 1;
        }

        var forceV2 = args[0] == "--v2";
        var filePath = forceV2 ? args.ElementAtOrDefault(1) : args[0];
        if (filePath is null)
        {
            Console.Error.WriteLine("usage: pax-interpreter [--v2] <file.pax>");
            return 1;
        }

        if (!File.Exists(filePath))
        {
            Console.Error.WriteLine($"missing PAX file: {filePath}");
            return 1;
        }

        try
        {
            var source = File.ReadAllText(filePath);
            var header = PaxHeader.Parse(source);
            if (forceV2 || header.Label.Contains("v2", StringComparison.OrdinalIgnoreCase))
            {
                var interpreterV2 = new PaxV2Interpreter();
                interpreterV2.Execute(header);
                return 0;
            }

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

// ── Header ────────────────────────────────────────────────────────────────────

internal sealed record PaxHeader(string Raw, string Label, string Body, int BodyStartLine)
{
    public static PaxHeader Parse(string source)
    {
        var lines = source.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        var headerIndex = -1;

        for (var index = 0; index < lines.Length; index++)
        {
            if (string.IsNullOrWhiteSpace(lines[index])) continue;
            headerIndex = index;
            break;
        }

        if (headerIndex < 0) throw new PaxException("missing Praxis header");

        var headerLine = lines[headerIndex].Trim();
        const string prefix = "[.Praxis Config - ";
        const string suffix = " .praxis.pax./]";

        if (!headerLine.StartsWith(prefix, StringComparison.Ordinal) ||
            !headerLine.EndsWith(suffix, StringComparison.Ordinal))
            throw new PaxException("invalid Praxis header; expected '[.Praxis Config - <label> .praxis.pax./]'");

        var label = headerLine[prefix.Length..^suffix.Length].Trim();
        if (string.IsNullOrWhiteSpace(label))
            throw new PaxException("Praxis header label cannot be empty");

        var body = string.Join('\n', lines.Skip(headerIndex + 1));
        return new PaxHeader(headerLine, label, body, headerIndex + 2);
    }
}

// ── Tokens ────────────────────────────────────────────────────────────────────

internal enum TokenType
{
    Identifier,
    String,
    Integer,
    Assign,
    EqualsEquals,
    NotEquals,
    Dot,
    Comma,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    NewLine,
    EndOfFile
}

internal readonly record struct Token(TokenType Type, string Text, int Line, int Column);

// ── Lexer ─────────────────────────────────────────────────────────────────────

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

            if (current is ' ' or '\t') { Advance(); continue; }
            if (current == '\r') { Advance(); continue; }
            if (current == '\n') { AddToken(TokenType.NewLine, "\n"); AdvanceLine(); continue; }
            if (current == '#') { SkipComment(); continue; }
            if (current == '{') { AddToken(TokenType.LBrace, "{"); Advance(); continue; }
            if (current == '}') { AddToken(TokenType.RBrace, "}"); Advance(); continue; }
            if (current == '[') { AddToken(TokenType.LBracket, "["); Advance(); continue; }
            if (current == ']') { AddToken(TokenType.RBracket, "]"); Advance(); continue; }
            if (current == ',') { AddToken(TokenType.Comma, ","); Advance(); continue; }
            if (current == '.') { AddToken(TokenType.Dot, "."); Advance(); continue; }

            if (current == '=')
            {
                if (Peek() == '=') { AddToken(TokenType.EqualsEquals, "=="); Advance(); Advance(); }
                else { AddToken(TokenType.Assign, "="); Advance(); }
                continue;
            }

            if (current == '!' && Peek() == '=')
            {
                AddToken(TokenType.NotEquals, "!=");
                Advance(); Advance();
                continue;
            }

            if (current == '"') { ReadString(); continue; }

            if (current == '-' && char.IsDigit(Peek()))
            {
                ReadInteger();
                continue;
            }

            if (char.IsDigit(current)) { ReadInteger(); continue; }

            if (IsIdentifierStart(current)) { ReadIdentifier(); continue; }

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
        while (!IsAtEnd() && IsIdentifierPart(Current())) Advance();
        _tokens.Add(new Token(TokenType.Identifier, _source[start.._index], line, column));
    }

    private void ReadInteger()
    {
        var start = _index;
        var line = _line;
        var column = _column;
        if (Current() == '-') Advance();
        while (!IsAtEnd() && char.IsDigit(Current())) Advance();
        _tokens.Add(new Token(TokenType.Integer, _source[start.._index], line, column));
    }

    private void ReadString()
    {
        var line = _line;
        var column = _column;
        Advance();
        var builder = new StringBuilder();
        while (!IsAtEnd() && Current() != '"')
        {
            var c = Current();
            if (c == '\\')
            {
                Advance();
                if (IsAtEnd()) throw Error("unterminated string escape");
                builder.Append(Current() switch { '"' => '"', '\\' => '\\', 'n' => '\n', 't' => '\t', var x => x });
                Advance();
                continue;
            }
            if (c == '\n') throw Error("unterminated string");
            builder.Append(c);
            Advance();
        }
        if (IsAtEnd()) throw Error("unterminated string");
        Advance();
        _tokens.Add(new Token(TokenType.String, builder.ToString(), line, column));
    }

    private void SkipComment()
    {
        while (!IsAtEnd() && Current() != '\n') Advance();
    }

    private char Current() => _source[_index];
    private char Peek() { var n = _index + 1; return n >= _source.Length ? '\0' : _source[n]; }
    private bool IsAtEnd() => _index >= _source.Length;
    private void Advance() { _index++; _column++; }
    private void AdvanceLine() { _index++; _line++; _column = 1; }
    private void AddToken(TokenType type, string text) => _tokens.Add(new Token(type, text, _line, _column));
    private static bool IsIdentifierStart(char v) => char.IsLetter(v) || v == '_';
    private static bool IsIdentifierPart(char v) => char.IsLetterOrDigit(v) || v == '_' || v == '-';
    private PaxException Error(string message) => new($"{message} at line {_line}, column {_column}");
}

// ── AST ───────────────────────────────────────────────────────────────────────

internal enum StatementKind { Let, Var, Define, Assignment, Block, If, Each, Include, OnError, Action }
internal enum ExpressionKind { String, Integer, Boolean, Symbol, Path, List }
internal enum CondOp { Eq, Ne }
internal enum LogicOp { And, Or }

internal sealed record Document(PaxHeader Header, List<Statement> Statements);

internal sealed record Statement(
    StatementKind Kind,
    string? Name = null,
    Expression? Value = null,
    BlockNode? Block = null,
    IfNode? If = null,
    EachNode? Each = null,
    string? IncludePath = null,
    List<Statement>? OnErrorBody = null,
    ActionNode? Action = null);

internal sealed record BlockNode(string Kind, string Label, List<Statement> Body);

internal sealed record IfNode(Condition Cond, List<Statement> Body);

internal sealed record EachNode(string Item, Expression List, List<Statement> Body);

internal sealed record ActionNode(string Verb, string? Subject, Expression? Arg1, Expression? Arg2, List<(string Key, Expression Val)>? Fields = null);

internal sealed record Expression(ExpressionKind Kind, string Text, bool BoolValue, long IntValue, List<string>? Path, List<Expression>? Items);

internal sealed record Condition(Expression Left, CondOp Op, Expression Right, bool Negated, LogicOp? NextLogic, Condition? Next);

// ── Parser ────────────────────────────────────────────────────────────────────

internal sealed class Parser
{
    private readonly List<Token> _tokens;
    private int _index;

    public Parser(List<Token> tokens) => _tokens = tokens;

    public Document ParseDocument(PaxHeader header)
    {
        var stmts = new List<Statement>();
        SkipNewLines();
        while (!Check(TokenType.EndOfFile)) { stmts.Add(ParseStatement()); SkipNewLines(); }
        return new Document(header, stmts);
    }

    private Statement ParseStatement()
    {
        if (IsIdent("let"))
        {
            Advance();
            var name = ConsumeIdent("expected name after 'let'").Text;
            Consume(TokenType.Assign, "expected '='");
            var val = ParseExpression();
            RequireBoundary();
            return new Statement(StatementKind.Let, Name: name, Value: val);
        }

        if (IsIdent("var"))
        {
            Advance();
            var name = ConsumeIdent("expected name after 'var'").Text;
            Consume(TokenType.Assign, "expected '='");
            var val = ParseExpression();
            RequireBoundary();
            return new Statement(StatementKind.Var, Name: name, Value: val);
        }

        if (IsIdent("define"))
        {
            Advance();
            var name = ConsumeIdent("expected name after 'define'").Text;
            Consume(TokenType.Assign, "expected '='");
            var val = ParseExpression();
            RequireBoundary();
            return new Statement(StatementKind.Define, Name: name, Value: val);
        }

        if (IsIdent("if")) return new Statement(StatementKind.If, If: ParseIf());

        if (IsIdent("each")) return new Statement(StatementKind.Each, Each: ParseEach());

        if (IsIdent("include"))
        {
            Advance();
            var path = Consume(TokenType.String, "expected path string after 'include'").Text;
            RequireBoundary();
            return new Statement(StatementKind.Include, IncludePath: path);
        }

        if (IsIdent("on") && PeekIdent(1, "error")) return new Statement(StatementKind.OnError, OnErrorBody: ParseOnError());

        if (LooksLikeBlock()) return new Statement(StatementKind.Block, Block: ParseBlock());

        if (Check(TokenType.Identifier) && CheckAt(1, TokenType.Assign))
        {
            var name = Advance().Text;
            Advance();
            var val = ParseExpression();
            RequireBoundary();
            return new Statement(StatementKind.Assignment, Name: name, Value: val);
        }

        return new Statement(StatementKind.Action, Action: ParseAction());
    }

    private BlockNode ParseBlock()
    {
        var kind = ConsumeIdent("expected block kind").Text;
        var label = Consume(TokenType.String, "expected block label").Text;
        SkipNewLines();
        Consume(TokenType.LBrace, "expected '{'");
        var body = ParseBody();
        Consume(TokenType.RBrace, "expected '}'");
        return new BlockNode(kind, label, body);
    }

    private IfNode ParseIf()
    {
        ConsumeIdent("expected 'if'");
        var cond = ParseCondition();
        SkipNewLines();
        Consume(TokenType.LBrace, "expected '{'");
        var body = ParseBody();
        Consume(TokenType.RBrace, "expected '}'");
        return new IfNode(cond, body);
    }

    private EachNode ParseEach()
    {
        ConsumeIdent("expected 'each'");
        var item = ConsumeIdent("expected loop variable").Text;
        if (!IsIdent("in")) throw Error("expected 'in' after loop variable");
        Advance();
        var list = ParseExpression();
        SkipNewLines();
        Consume(TokenType.LBrace, "expected '{'");
        var body = ParseBody();
        Consume(TokenType.RBrace, "expected '}'");
        return new EachNode(item, list, body);
    }

    private List<Statement> ParseOnError()
    {
        Advance(); // on
        Advance(); // error
        SkipNewLines();
        Consume(TokenType.LBrace, "expected '{'");
        var body = ParseBody();
        Consume(TokenType.RBrace, "expected '}'");
        return body;
    }

    private List<Statement> ParseBody()
    {
        var body = new List<Statement>();
        SkipNewLines();
        while (!Check(TokenType.RBrace))
        {
            if (Check(TokenType.EndOfFile)) throw Error("unterminated block");
            body.Add(ParseStatement());
            SkipNewLines();
        }
        return body;
    }

    private Condition ParseCondition()
    {
        var negated = false;
        if (IsIdent("not")) { Advance(); negated = true; }
        var left = ParseExpression();
        CondOp op;
        if (Match(TokenType.EqualsEquals)) op = CondOp.Eq;
        else if (Match(TokenType.NotEquals)) op = CondOp.Ne;
        else throw Error("expected '==' or '!=' in condition");
        var right = ParseExpression();

        LogicOp? logic = null;
        Condition? next = null;
        if (IsIdent("and")) { Advance(); logic = LogicOp.And; next = ParseCondition(); }
        else if (IsIdent("or")) { Advance(); logic = LogicOp.Or; next = ParseCondition(); }

        return new Condition(left, op, right, negated, logic, next);
    }

    private ActionNode ParseAction()
    {
        var verb = ConsumeIdent("expected action verb").Text;

        switch (verb)
        {
            case "print": case "log": case "warn": case "fail":
            {
                var arg = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, null, arg, null);
            }
            case "stop": case "reboot" when !IsIdent("target"):
                RequireBoundary();
                return new ActionNode(verb, null, null, null);

            case "reboot":
            {
                if (IsIdent("target")) { Advance(); var arg = ParseExpression(); RequireBoundary(); return new ActionNode(verb, "target", arg, null); }
                RequireBoundary();
                return new ActionNode(verb, null, null, null);
            }

            case "require":
            {
                var cond = ParseConditionAsExpression();
                RequireBoundary();
                return new ActionNode(verb, null, cond, null);
            }

            case "assert":
            {
                var cond = ParseConditionAsExpression();
                var msg = Consume(TokenType.String, "expected message string after condition").Text;
                RequireBoundary();
                return new ActionNode(verb, null, cond, StringExpr(msg));
            }

            case "check":
            {
                var subject = ConsumeIdent("expected subject after 'check'").Text;
                RequireBoundary();
                return new ActionNode(verb, subject, null, null);
            }

            case "install":
            {
                var subject = ConsumeIdent("expected install target").Text;
                var arg = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, subject, arg, null);
            }

            case "compile": case "enable": case "start":
            {
                var subject = ConsumeIdent($"expected subject after '{verb}'").Text;
                var arg = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, subject, arg, null);
            }

            case "each":
                throw Error("'each' is a statement, not an action");

            case "set":
            {
                var subject = ConsumeIdent("expected set target").Text;
                if (subject == "password")
                {
                    if (!IsIdent("for")) throw Error("expected 'for' after 'set password'");
                    Advance();
                    var arg = ParseExpression();
                    RequireBoundary();
                    return new ActionNode(verb, "password-for", arg, null);
                }
                var val = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, subject, val, null);
            }

            case "write": case "append":
            {
                var path = ParseExpression();
                if (!IsIdent("content")) throw Error("expected 'content' keyword");
                Advance();
                var content = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, null, path, content);
            }

            case "copy": case "move": case "symlink":
            {
                var src = ParseExpression();
                if (!IsIdent("to")) throw Error($"expected 'to' after {verb} source");
                Advance();
                var dest = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, null, src, dest);
            }

            case "fetch":
            {
                var url = ParseExpression();
                if (!IsIdent("to")) throw Error("expected 'to' after fetch url");
                Advance();
                var dest = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, null, url, dest);
            }

            case "mkdir": case "delete": case "exec": case "umount":
            {
                var arg = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, null, arg, null);
            }

            case "mount":
            {
                var dev = ParseExpression();
                if (!IsIdent("at")) throw Error("expected 'at' after mount device");
                Advance();
                var pt = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, null, dev, pt);
            }

            case "format":
            {
                var dev = ParseExpression();
                if (!IsIdent("as")) throw Error("expected 'as' after format device");
                Advance();
                var fs = ConsumeIdent("expected filesystem type").Text;
                RequireBoundary();
                return new ActionNode(verb, null, dev, StringExpr(fs));
            }

            case "service":
            {
                var sub = ConsumeIdent("expected service sub-command").Text;
                var name = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, sub, name, null);
            }

            case "user":
            {
                var sub = ConsumeIdent("expected user sub-command").Text;
                if (sub == "add-group")
                {
                    var u = ParseExpression();
                    var g = ParseExpression();
                    RequireBoundary();
                    return new ActionNode(verb, sub, u, g);
                }
                var arg = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, sub, arg, null);
            }

            case "group":
            {
                var sub = ConsumeIdent("expected group sub-command").Text;
                var name = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, sub, name, null);
            }

            case "net":
            {
                var sub = ConsumeIdent("expected net sub-command").Text;
                var iface = ParseExpression();
                if (sub == "configure")
                {
                    SkipNewLines();
                    Consume(TokenType.LBrace, "expected '{'");
                    var fields = new List<(string, Expression)>();
                    SkipNewLines();
                    while (!Check(TokenType.RBrace))
                    {
                        var k = ConsumeIdent("expected field name").Text;
                        Consume(TokenType.Assign, "expected '='");
                        var v = ParseExpression();
                        RequireBoundary();
                        fields.Add((k, v));
                    }
                    Consume(TokenType.RBrace, "expected '}'");
                    return new ActionNode(verb, sub, iface, null, fields);
                }
                RequireBoundary();
                return new ActionNode(verb, sub, iface, null);
            }

            case "bootloader":
            {
                var sub = ConsumeIdent("expected bootloader sub-command").Text;
                if (sub == "entry")
                {
                    var label = Consume(TokenType.String, "expected entry name").Text;
                    SkipNewLines();
                    Consume(TokenType.LBrace, "expected '{'");
                    var fields = new List<(string, Expression)>();
                    SkipNewLines();
                    while (!Check(TokenType.RBrace))
                    {
                        var k = ConsumeIdent("expected field").Text;
                        Consume(TokenType.Assign, "expected '='");
                        var v = ParseExpression();
                        RequireBoundary();
                        fields.Add((k, v));
                    }
                    Consume(TokenType.RBrace, "expected '}'");
                    return new ActionNode(verb, sub, StringExpr(label), null, fields);
                }
                var loader = ConsumeIdent("expected bootloader name").Text;
                RequireBoundary();
                return new ActionNode(verb, sub, StringExpr(loader), null);
            }

            case "initramfs":
            {
                var sub = ConsumeIdent("expected initramfs sub-command").Text;
                var arg = ParseExpression();
                RequireBoundary();
                return new ActionNode(verb, sub, arg, null);
            }

            default:
                throw Error($"unknown action '{verb}'");
        }
    }

    private Expression ParseConditionAsExpression()
    {
        // Represent condition as a synthetic expression for require/assert
        // We parse and encode it as a string for the interpreter to re-evaluate
        var negated = false;
        if (IsIdent("not")) { Advance(); negated = true; }
        var left = ParseExpression();
        CondOp op;
        if (Match(TokenType.EqualsEquals)) op = CondOp.Eq;
        else if (Match(TokenType.NotEquals)) op = CondOp.Ne;
        else throw Error("expected '==' or '!=' in condition");
        var right = ParseExpression();
        // Pack as a special "condition" expression list: [negated, left, op, right]
        var items = new List<Expression>
        {
            BoolExpr(negated),
            left,
            StringExpr(op == CondOp.Eq ? "==" : "!="),
            right
        };
        return new Expression(ExpressionKind.List, "__condition__", false, 0, null, items);
    }

    private Expression ParseExpression()
    {
        if (Check(TokenType.String)) return new Expression(ExpressionKind.String, Advance().Text, false, 0, null, null);
        if (Check(TokenType.Integer)) { var t = Advance(); return new Expression(ExpressionKind.Integer, t.Text, false, long.Parse(t.Text), null, null); }

        if (Check(TokenType.LBracket))
        {
            Advance();
            var items = new List<Expression>();
            SkipNewLines();
            while (!Check(TokenType.RBracket) && !Check(TokenType.EndOfFile))
            {
                items.Add(ParseExpression());
                SkipNewLines();
                if (!Match(TokenType.Comma)) break;
                SkipNewLines();
            }
            Consume(TokenType.RBracket, "expected ']'");
            return new Expression(ExpressionKind.List, "[]", false, 0, null, items);
        }

        if (!Check(TokenType.Identifier)) throw Error("expected value");

        var first = Advance().Text;
        if (first == "true") return new Expression(ExpressionKind.Boolean, "true", true, 0, null, null);
        if (first == "false") return new Expression(ExpressionKind.Boolean, "false", false, 0, null, null);
        if (first == "null") return new Expression(ExpressionKind.Symbol, "null", false, 0, null, null);

        var path = new List<string> { first };
        while (Match(TokenType.Dot)) path.Add(ConsumeIdent("expected path segment after '.'").Text);
        return path.Count == 1
            ? new Expression(ExpressionKind.Symbol, first, false, 0, path, null)
            : new Expression(ExpressionKind.Path, string.Join('.', path), false, 0, path, null);
    }

    private static Expression StringExpr(string v) => new(ExpressionKind.String, v, false, 0, null, null);
    private static Expression BoolExpr(bool v) => new(ExpressionKind.Boolean, v ? "true" : "false", v, 0, null, null);

    private void RequireBoundary()
    {
        if (Match(TokenType.NewLine)) { SkipNewLines(); return; }
        if (Check(TokenType.EndOfFile) || Check(TokenType.RBrace)) return;
        throw Error("expected end of statement");
    }

    private void SkipNewLines() { while (Match(TokenType.NewLine)) { } }

    private Token Consume(TokenType type, string message) => Check(type) ? Advance() : throw Error(message);
    private Token ConsumeIdent(string message) => Check(TokenType.Identifier) ? Advance() : throw Error(message);
    private bool IsIdent(string text) => Check(TokenType.Identifier) && Current().Text == text;
    private bool PeekIdent(int offset, string text) => CheckAt(offset, TokenType.Identifier) && Peek(offset).Text == text;
    private bool Match(TokenType type) { if (!Check(type)) return false; Advance(); return true; }
    private bool Check(TokenType type) => Current().Type == type;
    private bool CheckAt(int offset, TokenType type) => Peek(offset).Type == type;

    private bool LooksLikeBlock()
    {
        if (!Check(TokenType.Identifier) || !CheckAt(1, TokenType.String)) return false;
        var offset = 2;
        while (Peek(offset).Type == TokenType.NewLine) offset++;
        return Peek(offset).Type == TokenType.LBracket ? false : Peek(offset).Type == TokenType.LBrace;
    }

    private Token Advance() { var t = Current(); if (!Check(TokenType.EndOfFile)) _index++; return t; }
    private Token Current() => Peek(0);
    private Token Peek(int offset) { var pos = _index + offset; return pos >= _tokens.Count ? _tokens[^1] : _tokens[pos]; }
    private PaxException Error(string message) { var t = Current(); return new PaxException($"{message} at line {t.Line}, column {t.Column}"); }
}

// ── Interpreter ───────────────────────────────────────────────────────────────

internal sealed class PaxInterpreter
{
    private readonly Dictionary<string, object?> _globals = new(StringComparer.Ordinal);
    private readonly Dictionary<string, object?> _defines = new(StringComparer.Ordinal);
    private List<Statement>? _onErrorHandler;
    private bool _stopRequested;

    public PaxInterpreter()
    {
        _globals["hardware"] = Status("unknown");
        _globals["install"]  = Status("idle");
        _globals["compile"]  = Status("idle");
        _globals["desktop"]  = Status("disabled");
        _globals["boot"]     = Status("idle");
        _globals["disk"]     = Status("idle");
        _globals["exec"]     = Status("idle");
        _globals["fetch"]    = Status("idle");
        _globals["file"]     = Status("idle");
        _globals["net"]      = Status("down");
        _globals["user"]     = Status("idle");
        _globals["initramfs"] = Status("idle");
    }

    public void Execute(Document document)
    {
        _globals["pax"] = new Dict { ["header"] = document.Header.Raw, ["label"] = document.Header.Label };
        RunStatements(document.Statements, _globals);
    }

    private void RunStatements(List<Statement> stmts, Dict scope)
    {
        foreach (var stmt in stmts)
        {
            if (_stopRequested) return;
            try { RunStatement(stmt, scope); }
            catch (PaxException) when (_onErrorHandler is not null)
            {
                var handler = _onErrorHandler;
                _onErrorHandler = null;
                RunStatements(handler, scope);
            }
        }
    }

    private void RunStatement(Statement stmt, Dict scope)
    {
        switch (stmt.Kind)
        {
            case StatementKind.Let:
            case StatementKind.Var:
            case StatementKind.Assignment:
                scope[stmt.Name!] = Eval(stmt.Value!, scope);
                break;

            case StatementKind.Define:
                _defines[stmt.Name!] = Eval(stmt.Value!, scope);
                scope[stmt.Name!] = _defines[stmt.Name!];
                break;

            case StatementKind.Block:
                RunBlock(stmt.Block!, scope);
                break;

            case StatementKind.If:
                RunIf(stmt.If!, scope);
                break;

            case StatementKind.Each:
                RunEach(stmt.Each!, scope);
                break;

            case StatementKind.Include:
                Console.Error.WriteLine($"[warn] include '{stmt.IncludePath}' not yet resolved by this interpreter");
                break;

            case StatementKind.OnError:
                _onErrorHandler = stmt.OnErrorBody;
                break;

            case StatementKind.Action:
                RunAction(stmt.Action!, scope);
                break;
        }
    }

    private void RunBlock(BlockNode block, Dict scope)
    {
        var nested = new Dict { ["label"] = block.Label, ["kind"] = block.Kind };
        RunStatements(block.Body, nested);
        scope[block.Kind] = nested;
    }

    private void RunIf(IfNode ifNode, Dict scope)
    {
        if (EvalCondition(ifNode.Cond, scope)) RunStatements(ifNode.Body, scope);
    }

    private void RunEach(EachNode each, Dict scope)
    {
        var listVal = Eval(each.List, scope);
        if (listVal is not List<object?> items)
            throw new PaxException($"'each' expects a list, got: {Stringify(listVal)}");
        foreach (var item in items)
        {
            if (_stopRequested) return;
            var loopScope = new Dict(scope) { [each.Item] = item };
            RunStatements(each.Body, loopScope);
        }
    }

    private bool EvalCondition(Condition cond, Dict scope)
    {
        var left = Eval(cond.Left, scope);
        var right = Eval(cond.Right, scope);
        var match = cond.Op == CondOp.Eq ? ValuesEqual(left, right) : !ValuesEqual(left, right);
        var result = cond.Negated ? !match : match;

        if (cond.NextLogic is null) return result;
        var next = EvalCondition(cond.Next!, scope);
        return cond.NextLogic == LogicOp.And ? result && next : result || next;
    }

    private bool EvalConditionExpr(Expression condExpr, Dict scope)
    {
        if (condExpr.Kind != ExpressionKind.List || condExpr.Text != "__condition__")
            throw new PaxException("expected a condition expression");
        var items = condExpr.Items!;
        var negated = items[0].BoolValue;
        var left = Eval(items[1], scope);
        var op = items[2].Text;
        var right = Eval(items[3], scope);
        var match = op == "==" ? ValuesEqual(left, right) : !ValuesEqual(left, right);
        return negated ? !match : match;
    }

    private void RunAction(ActionNode action, Dict scope)
    {
        switch (action.Verb)
        {
            case "print":
                Console.WriteLine(Interpolate(Stringify(Eval(action.Arg1!, scope)), scope));
                break;

            case "log":
                Console.WriteLine($"[log] {Interpolate(Stringify(Eval(action.Arg1!, scope)), scope)}");
                break;

            case "warn":
                Console.Error.WriteLine($"[warn] {Interpolate(Stringify(Eval(action.Arg1!, scope)), scope)}");
                break;

            case "fail":
                Console.Error.WriteLine($"[fail] {Interpolate(Stringify(Eval(action.Arg1!, scope)), scope)}");
                _stopRequested = true;
                throw new PaxException("execution stopped by fail");

            case "stop":
                _stopRequested = true;
                break;

            case "require":
            {
                if (!EvalConditionExpr(action.Arg1!, scope))
                    throw new PaxException("require condition not met");
                break;
            }

            case "assert":
            {
                if (!EvalConditionExpr(action.Arg1!, scope))
                {
                    var msg = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                    throw new PaxException($"assertion failed: {msg}");
                }
                break;
            }

            case "check" when action.Subject == "hardware":
                _globals["hardware"] = new Dict
                {
                    ["status"] = "good",
                    ["arch"]   = "x86_64",
                    ["ram"]    = "4096",
                    ["cpu"]    = "simulated",
                    ["cores"]  = "4",
                    ["mode"]   = "simulated"
                };
                Console.WriteLine("[check] hardware -> good");
                break;

            case "install":
            {
                var target = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[install] {action.Subject} {target}");
                _globals["install"] = new Dict { ["status"] = "finished", ["target"] = action.Subject ?? "", ["package"] = target };
                break;
            }

            case "compile":
            {
                var pkg = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[compile] {action.Subject} {pkg}");
                _globals["compile"] = new Dict { ["status"] = "finished", ["package"] = pkg };
                break;
            }

            case "enable" when action.Subject == "desktop":
            {
                var name = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[enable] desktop {name}");
                _globals["desktop"] = new Dict { ["status"] = "enabled", ["current"] = name };
                break;
            }

            case "start" when action.Subject == "desktop":
            {
                var name = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[start] desktop {name}");
                break;
            }

            case "set":
                RunSet(action, scope);
                break;

            case "write":
            {
                var path = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var content = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[write] {path}");
                _globals["file"] = new Dict { ["status"] = "written", ["path"] = path };
                break;
            }

            case "append":
            {
                var path = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var content = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[append] {path}");
                _globals["file"] = new Dict { ["status"] = "written", ["path"] = path };
                break;
            }

            case "mkdir":
            {
                var path = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[mkdir] {path}");
                break;
            }

            case "copy":
            {
                var src  = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var dest = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[copy] {src} -> {dest}");
                break;
            }

            case "move":
            {
                var src  = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var dest = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[move] {src} -> {dest}");
                break;
            }

            case "symlink":
            {
                var target = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var link   = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[symlink] {link} -> {target}");
                break;
            }

            case "delete":
            {
                var path = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[delete] {path}");
                break;
            }

            case "fetch":
            {
                var url  = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var dest = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[fetch] {url} -> {dest}");
                _globals["fetch"] = new Dict { ["status"] = "finished", ["url"] = url, ["path"] = dest };
                break;
            }

            case "exec":
            {
                var cmd = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[exec] {cmd}");
                _globals["exec"] = new Dict { ["status"] = "finished", ["code"] = "0", ["output"] = "" };
                break;
            }

            case "mount":
            {
                var dev = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var pt  = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[mount] {dev} at {pt}");
                _globals["disk"] = new Dict { ["status"] = "mounted", ["device"] = dev, ["mount"] = pt };
                break;
            }

            case "umount":
            {
                var path = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[umount] {path}");
                break;
            }

            case "format":
            {
                var dev = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                var fs  = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                Console.WriteLine($"[format] {dev} as {fs}");
                _globals["disk"] = new Dict { ["status"] = "formatted", ["device"] = dev };
                break;
            }

            case "service":
            {
                var name = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[service] {action.Subject} {name}");
                break;
            }

            case "user":
            {
                var name = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                if (action.Subject == "add-group")
                {
                    var group = Interpolate(Stringify(Eval(action.Arg2!, scope)), scope);
                    Console.WriteLine($"[user] add-group {name} -> {group}");
                }
                else
                {
                    Console.WriteLine($"[user] {action.Subject} {name}");
                    if (action.Subject == "create")
                        _globals["user"] = new Dict { ["status"] = "created", ["name"] = name };
                }
                break;
            }

            case "group":
            {
                var name = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[group] {action.Subject} {name}");
                break;
            }

            case "net":
            {
                var iface = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[net] {action.Subject} {iface}");
                _globals["net"] = new Dict { ["status"] = "up", ["iface"] = iface };
                break;
            }

            case "bootloader":
            {
                if (action.Subject == "entry")
                {
                    var label = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                    Console.WriteLine($"[bootloader] entry '{label}'");
                    if (action.Fields is not null)
                        foreach (var (k, v) in action.Fields)
                            Console.WriteLine($"  {k} = {Interpolate(Stringify(Eval(v, scope)), scope)}");
                }
                else
                {
                    var loader = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                    Console.WriteLine($"[bootloader] install {loader}");
                    _globals["boot"] = new Dict { ["status"] = "installed" };
                }
                break;
            }

            case "initramfs":
            {
                var target = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
                Console.WriteLine($"[initramfs] build {target}");
                _globals["initramfs"] = new Dict { ["status"] = "built", ["target"] = target };
                break;
            }

            case "reboot":
            {
                var target = action.Subject == "target" && action.Arg1 is not null
                    ? Interpolate(Stringify(Eval(action.Arg1, scope)), scope)
                    : null;
                Console.WriteLine(target is not null ? $"[reboot] target {target}" : "[reboot]");
                _globals["boot"] = new Dict { ["status"] = "rebooting" };
                break;
            }

            default:
                throw new PaxException($"unsupported action: {action.Verb}");
        }
    }

    private void RunSet(ActionNode action, Dict scope)
    {
        var val = Interpolate(Stringify(Eval(action.Arg1!, scope)), scope);
        switch (action.Subject)
        {
            case "hostname": Console.WriteLine($"[set] hostname {val}"); break;
            case "locale":   Console.WriteLine($"[set] locale {val}");   break;
            case "timezone": Console.WriteLine($"[set] timezone {val}"); break;
            case "keymap":   Console.WriteLine($"[set] keymap {val}");   break;
            case "password-for": Console.WriteLine($"[set] password for {val}"); break;
            default: throw new PaxException($"unknown set target: {action.Subject}");
        }
    }

    private object? Eval(Expression expr, Dict scope)
    {
        return expr.Kind switch
        {
            ExpressionKind.String  => expr.Text,
            ExpressionKind.Integer => expr.IntValue,
            ExpressionKind.Boolean => expr.BoolValue,
            ExpressionKind.Symbol  => expr.Text == "null" ? null : (object?)expr.Text,
            ExpressionKind.Path    => ResolvePath(expr.Path!, scope),
            ExpressionKind.List    => expr.Items!.Select(e => Eval(e, scope)).ToList<object?>(),
            _ => throw new PaxException($"unsupported expression kind: {expr.Kind}")
        };
    }

    private object? ResolvePath(List<string> path, Dict scope)
    {
        if (path.Count == 0) return null;

        object? current = null;
        bool found = false;
        if (_defines.TryGetValue(path[0], out var def)) { current = def; found = true; }
        else if (scope.TryGetValue(path[0], out var local)) { current = local; found = true; }
        else if (_globals.TryGetValue(path[0], out var global)) { current = global; found = true; }

        // Unknown root → treat the whole dotted path as a literal package/domain identifier
        // e.g. dev.praxis.firefox, org.mozilla.firefox, com.github.neovim
        if (!found) return string.Join('.', path);

        for (var i = 1; i < path.Count; i++)
        {
            if (current is Dict map && map.TryGetValue(path[i], out var next)) { current = next; continue; }
            return null;
        }
        return current;
    }

    private string Interpolate(string template, Dict scope)
    {
        return Regex.Replace(template, @"\{([A-Za-z_][A-Za-z0-9_.]*)\}", match =>
        {
            var parts = match.Groups[1].Value.Split('.');
            return Stringify(ResolvePath(parts.ToList(), scope));
        });
    }

    private static bool ValuesEqual(object? left, object? right)
    {
        if (left is bool lb && right is bool rb) return lb == rb;
        if (left is long li && right is long ri) return li == ri;
        return string.Equals(Stringify(left), Stringify(right), StringComparison.Ordinal);
    }

    private static Dict Status(string s) => new() { ["status"] = s };

    private static string Stringify(object? value) => value switch
    {
        null => "null",
        bool b => b ? "true" : "false",
        long l => l.ToString(),
        List<object?> list => "[" + string.Join(", ", list.Select(Stringify)) + "]",
        Dict map => "{" + string.Join(", ", map.Select(kv => $"{kv.Key}={Stringify(kv.Value)}")) + "}",
        _ => value.ToString() ?? string.Empty
    };
}

internal sealed class Dict : Dictionary<string, object?>
{
    public Dict() : base(StringComparer.Ordinal) { }
    public Dict(Dict other) : base(other, StringComparer.Ordinal) { }
}

internal sealed class PaxException : Exception
{
    public PaxException(string message) : base(message) { }
}
