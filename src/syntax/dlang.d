module syntax.dlang;

import std.ascii;
import std.algorithm.searching: canFind;
import dlangui;
import syntax.lexer;

class DSyntaxSupport: SyntaxSupport {
    string[] delims = [
        " ", "\n", "\r",
        "//", "/*", "*/", "/+", "+/",
        "\"", "\'", "`", "\\\"", "\\\'",
        ".", ",", ":", ";",
        "+", "-", "*", "/", "=", "<", ">", "|", "&", "%", "^", "^^", "!", "?", "~",
        "(", ")", "{", "}", "[", "]",
        "==", "++", "--", "||", "&&", ">>", "<<", ">>>",
        "+=", "-=", "*=", "/=", "%=", "!=", ">=", "<=", "=>", "~=",
        "|=", "&=", "^=", "<<=", ">>=", ">>>=", "^^=", ".."
    ];
    dstring[] quotes = ["\""d, "\'"d, "`"d];
    dstring[] commentOpeners = ["/*"d, "/+"d];
    dstring[] commentClosers = ["*/"d, "+/"d];
    dstring[dstring] commentCloserByOpener = [
        "/*"d: "*/"d,
        "/+"d: "+/"d
    ];
    dstring[] keywords = [
        "abstract"d, "alias"d, "align"d, "asm"d, "assert"d, "auto"d,
        "body"d, "bool"d, "break"d, "byte"d,
        "case"d, "cast"d, "catch"d, "cdouble"d, "cent"d, "cfloat"d,
        "char"d, "class"d, "const"d, "continue"d, "creal"d,
        "dchar"d, "debug"d, "default"d, "delegate"d, "delete"d, "deprecated"d, "do"d, "double"d, "dstring"d,
        "else"d, "enum"d, "export"d, "extern"d,
        "false"d, "final"d, "finally"d, "float"d, "for"d, "foreach"d, "foreach_reverse"d, "function"d,
        "goto"d,
        "idouble"d, "if"d, "ifloat"d, "immutable"d, "import"d, "in"d, "inout"d, "int"d, "interface"d, "invariant"d, "ireal"d, "is"d,
        "lazy"d, "long"d,
        "macro"d, "mixin"d, "module"d,
        "new"d, "nothrow"d, "noreturn"d, "null"d,
        "out"d, "override"d, "package"d,
        "pragma"d, "private"d, "protected"d, "ptrdiff_t"d,
        "public"d, "pure"d,
        "real"d, "ref"d, "return"d,
        "scope"d, "shared"d, "short"d, "size_t"d, "static"d, "string"d, "struct"d, "super"d, "switch"d, "synchronized"d,
        "template"d, "this"d, "throw"d, "true"d, "try"d, "typeid"d, "typeof"d,
        "ubyte"d, "ucent"d, "uint"d, "ulong"d, "union"d, "unittest"d, "ushort"d,
        "version"d, "void"d,
        "wchar"d, "while"d, "with"d, "wstring"d,
        "__FILE__"d, "__FILE_FULL_PATH__"d, "__MODULE__"d, "__LINE__"d,
        "__FUNCTION__"d, "__PRETTY_FUNCTION__"d, "__gshared"d, "__traits"d, "__vector"d, "__parameters"d
    ];
    protected EditableContent _content;
    protected Lexer _lexer;
    
    this()
    {
        _lexer = new Lexer("", delims);
    }

    /// returns editable content
    @property EditableContent content()
    {
        return _content;
    }
    
    /// set editable content
    @property SyntaxSupport content(EditableContent content)
    {
        _content = content;
        return this;
    }
    
    bool isKeyword(dstring lexeme)
    {
        return canFind(keywords, lexeme);
    }
    
    bool isQuote(dstring lexeme)
    {
        return canFind(quotes, lexeme);
    }
    
    bool isMultiCommentOpener(dstring lexeme)
    {
        return canFind(commentOpeners, lexeme);
    }
    
    bool isMultiCommentCloser(dstring lexeme)
    {
        return canFind(commentClosers, lexeme);
    }
    
    dstring getCommentCloser(dstring commentOpener)
    {
        return commentCloserByOpener[commentOpener];
    }
    
    bool isNumber(dstring s)
    {
        if (s.length == 0)
            return false;
        if (s[0] == '.')
        {
            if (s.length > 1)
                return isDigit(s[1]);
            else
                return false;
        }
        else return isDigit(s[0]);
    }

    /// categorize characters in content by token types
    void updateHighlight(dstring[] lines, TokenPropString[] props, int changeStartLine, int changeEndLine)
    {
        bool stringOpened = false;
        bool multiCommentOpened = false;
        bool singleLineComment = false;
        dstring stringOpener;
        dstring commentCloser;
        foreach(i, line; lines)
        {
            if (line.length == 0)
                continue;
            singleLineComment = false;
            _lexer.reset(line);
            syntax.lexer.Token token;
            do
            {
                token = _lexer.getToken();
                if (token.lexeme.length == 0) break;
                
                ubyte category = 0;
                if (stringOpened)
                {
                    category = TokenCategory.String;
                    if (isQuote(token.lexeme) && token.lexeme == stringOpener)
                    {
                        stringOpened = false;
                    }
                }
                else if (singleLineComment)
                {
                    category = TokenCategory.Comment;
                }
                else if (multiCommentOpened)
                {
                    category = TokenCategory.Comment;
                    if (isMultiCommentCloser(token.lexeme) && token.lexeme == commentCloser)
                    {
                        multiCommentOpened = false;
                    }
                }
                else if (token.lexeme == "//"d)
                {
                    category = TokenCategory.Comment;
                    singleLineComment = true;
                }
                else if (isMultiCommentOpener(token.lexeme))
                {
                    category = TokenCategory.Comment;
                    commentCloser = getCommentCloser(token.lexeme);
                    multiCommentOpened = true;
                }
                else if (isQuote(token.lexeme))
                {
                    category = TokenCategory.String;
                    stringOpener = token.lexeme;
                    stringOpened = true;
                }
                else if (isNumber(token.lexeme))
                {
                    category = TokenCategory.Float;
                }
                else if (isKeyword(token.lexeme))
                {
                    category = TokenCategory.Keyword;
                }
                
                foreach(j; token.startPos..token.endPos) {
                    if (j < props[i].length) {
                        props[i][j] = category;
                    }
                }
            }
            while(token.lexeme.length > 0);
        }
    }

    /// return true if toggle line comment is supported for file type
    @property bool supportsToggleLineComment()
    {
        return false;
    }
    
    /// return true if can toggle line comments for specified text range
    bool canToggleLineComment(TextRange range)
    {
        return false;
    }
    
    /// toggle line comments for specified text range
    void toggleLineComment(TextRange range, Object source)
    {
    }

    /// return true if toggle block comment is supported for file type
    @property bool supportsToggleBlockComment()
    {
        return false;
    }
    
    /// return true if can toggle block comments for specified text range
    bool canToggleBlockComment(TextRange range)
    {
        return false;
    }
    
    /// toggle block comments for specified text range
    void toggleBlockComment(TextRange range, Object source)
    {
    }

    /// returns paired bracket {} () [] for char at position p, returns paired char position or p if not found or not bracket
    TextPosition findPairedBracket(TextPosition p)
    {
        return p;
    }

    /// returns true if smart indent is supported
    bool supportsSmartIndents()
    {
        return true;
    }
    
    /// apply smart indent after edit operation, if needed
    void applySmartIndent(EditOperation op, Object source)
    {
        if (op.isInsertNewLine)
        {
            auto startPos = op.newRange.start;
            auto endPos = op.newRange.end;
            int line = endPos.line;
            if (line == 0)
                return;
            int prevLine = line - 1;
            dstring lineText = _content.line(line);
            dstring prevLineText = _content.line(prevLine);
            dstring indent = leadingWhitespace(prevLineText);
            EditOperation op2 = new EditOperation(EditAction.Replace, TextRange(TextPosition(endPos.line, 0), TextPosition(endPos.line, 0)), indent);
            _content.performOperation(op2, source);
        }
    }
}

dstring leadingWhitespace(dstring s)
{
    size_t i = 0;
    while (i < s.length && s[i].isWhite)
    {
        ++i;
    }
    return s[0..i].dup;
}

string insertAt(string original, string toInsert, size_t position)
{
    if (position > original.length)
    {
        throw new Exception("Position is out of bounds");
    }
    return original[0..position] ~ toInsert ~ original[position..$];
}
