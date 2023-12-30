pub const TokenType = enum {
    // Single-character tokens.
    TOKEN_LEFT_PAREN,
    TOKEN_RIGHT_PAREN,
    TOKEN_LEFT_BRACE,
    TOKEN_RIGHT_BRACE,
    TOKEN_COMMA,
    TOKEN_DOT,
    TOKEN_MINUS,
    TOKEN_PLUS,
    TOKEN_SEMICOLON,
    TOKEN_SLASH,
    TOKEN_STAR,
    TOKEN_QUESTION,
    TOKEN_COLON,
    // One or two character tokens.
    TOKEN_BANG,
    TOKEN_BANG_EQUAL,
    TOKEN_EQUAL,
    TOKEN_EQUAL_EQUAL,
    TOKEN_GREATER,
    TOKEN_GREATER_EQUAL,
    TOKEN_LESS,
    TOKEN_LESS_EQUAL,
    // Literals.
    TOKEN_IDENTIFIER,
    TOKEN_STRING,
    TOKEN_NUMBER,
    // Keywords.
    TOKEN_AND,
    TOKEN_CLASS,
    TOKEN_ELSE,
    TOKEN_FALSE,
    TOKEN_FOR,
    TOKEN_FUN,
    TOKEN_IF,
    TOKEN_NIL,
    TOKEN_OR,
    TOKEN_PRINT,
    TOKEN_RETURN,
    TOKEN_SUPER,
    TOKEN_THIS,
    TOKEN_TRUE,
    TOKEN_VAR,
    TOKEN_WHILE,

    TOKEN_INCOMPLETE,
    TOKEN_ERROR,
    TOKEN_EOF,
};

pub const Token = struct {
    const Self = @This();

    tok_type: TokenType,
    start: usize,
    len: usize,
    line: usize,

    pub fn default() Self {
        return .{ .tok_type = .TOKEN_ERROR, .start = 0, .line = 0, .len = 0 };
    }

    pub fn printTokens(tokens: []Token, writer: anytype) !void {
        var l: usize = 1;
        try writer.print("Line {}: ", .{l});
        for (tokens) |t| {
            if (t.line > l) {
                l = t.line;
                try writer.print("\nLine {}: ", .{l});
            }
            try writer.print("[{s}]", .{switch (t.tok_type) {
                .TOKEN_QUESTION => "?",
                .TOKEN_COLON => ":",
                .TOKEN_LEFT_PAREN => "(",
                .TOKEN_RIGHT_PAREN => ")",
                .TOKEN_LEFT_BRACE => "{",
                .TOKEN_RIGHT_BRACE => "}",
                .TOKEN_COMMA => ",",
                .TOKEN_DOT => ".",
                .TOKEN_MINUS => "-",
                .TOKEN_PLUS => "+",
                .TOKEN_SEMICOLON => ";",
                .TOKEN_SLASH => "/",
                .TOKEN_STAR => "*",
                .TOKEN_BANG => "!",
                .TOKEN_BANG_EQUAL => "!=",
                .TOKEN_EQUAL => "=",
                .TOKEN_EQUAL_EQUAL => "==",
                .TOKEN_GREATER => ">",
                .TOKEN_GREATER_EQUAL => ">=",
                .TOKEN_LESS => "<",
                .TOKEN_LESS_EQUAL => "<=",
                .TOKEN_IDENTIFIER => "ID",
                .TOKEN_STRING => "STR",
                .TOKEN_NUMBER => "NUM",
                .TOKEN_AND => "and",
                .TOKEN_CLASS => "class",
                .TOKEN_ELSE => "else",
                .TOKEN_FALSE => "false",
                .TOKEN_FOR => "for",
                .TOKEN_FUN => "fun",
                .TOKEN_IF => "if",
                .TOKEN_NIL => "nil",
                .TOKEN_OR => "or",
                .TOKEN_PRINT => "print",
                .TOKEN_RETURN => "return",
                .TOKEN_SUPER => "super",
                .TOKEN_THIS => "this",
                .TOKEN_TRUE => "true",
                .TOKEN_VAR => "var",
                .TOKEN_WHILE => "while",
                .TOKEN_INCOMPLETE => "INCOMPLETE",
                .TOKEN_ERROR => "ERROR",
                .TOKEN_EOF => "EOF",
            }});
        }
        try writer.print("\n", .{});
    }
};
