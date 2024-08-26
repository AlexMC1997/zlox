const std = @import("std");
const zlox = @import("zlox.zig");
const InterpretError = @import("zlox.zig").InterpretError;
const Chunk = @import("chunk.zig").Chunk;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Value = @import("value.zig").Value;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;

fn init_key_words(allocator: std.mem.Allocator) !StringHashMap(TokenType) {
    var tmp = StringHashMap(TokenType).init(allocator);
    try tmp.put("print", .TOKEN_PRINT);
    try tmp.put("return", .TOKEN_RETURN);
    try tmp.put("true", .TOKEN_TRUE);
    try tmp.put("false", .TOKEN_FALSE);
    try tmp.put("if", .TOKEN_IF);
    try tmp.put("else", .TOKEN_ELSE);
    try tmp.put("nil", .TOKEN_NIL);
    try tmp.put("class", .TOKEN_CLASS);
    try tmp.put("and", .TOKEN_AND);
    try tmp.put("or", .TOKEN_OR);
    try tmp.put("super", .TOKEN_SUPER);
    try tmp.put("var", .TOKEN_VAR);
    try tmp.put("while", .TOKEN_WHILE);
    try tmp.put("fun", .TOKEN_FUN);
    try tmp.put("this", .TOKEN_THIS);
    try tmp.put("for", .TOKEN_FOR);
    return tmp;
}

pub const Scanner = struct {
    const Self = @This();

    start: usize,
    current: usize,
    line: usize,
    read_buf: []u8,
    key_words: StringHashMap(TokenType),
    tokens: std.ArrayList(Token),
    allocator: Allocator,

    pub fn init(reader: anytype, allocator: Allocator) !Self {
        return .{ .start = 0, .current = 0, .line = 1, .read_buf = try reader.readAllAlloc(allocator, 0x100000), .key_words = try init_key_words(allocator), .tokens = std.ArrayList(Token).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.key_words.deinit();
        self.tokens.deinit();
        self.allocator.free(self.read_buf);
    }

    pub fn printTokens(self: Self, writer: anytype) !void {
        try Token.printTokens(self.tokens.items, writer);
    }

    pub fn makeToken(self: *Self, token_type: TokenType) Token {
        return Token{ .tok_type = token_type, .start = self.start, .line = self.line, .len = (self.current - self.start) };
    }

    pub fn getToken(self: Self, index: usize) Token {
        return self.tokens.items[index];
    }

    pub fn getValue(self: Self, token: Token) !Value {
        return switch (token.tok_type) {
            TokenType.TOKEN_NUMBER => Value.parseNumber(self.read_buf[token.start..(token.start + token.len)]),
            TokenType.TOKEN_TRUE => .{ .e_boolean = true },
            TokenType.TOKEN_FALSE => .{ .e_boolean = false },
            TokenType.TOKEN_NIL => .{ .e_nil = undefined },
            else => .{ .e_nil = undefined },
        };
    }

    pub fn next(self: *Self, c: u8) bool {
        if (self.current == self.read_buf.len) {
            return false;
        } else if (self.read_buf[self.current] != c) {
            return false;
        } else {
            self.current += 1;
            return true;
        }
    }

    pub fn clearWhitespace(self: *Self) TokenType {
        while (switch (self.read_buf[self.current]) {
            '\t', ' ', '\r' => true,
            '\n' => blk: {
                self.line += 1;
                break :blk true;
            },
            '/' => blk: {
                self.current += 1;
                if (self.next('/')) {
                    while (self.read_buf[self.current] != '\n') : (self.current += 1) {
                        if (self.current + 1 == self.read_buf.len) {
                            return .TOKEN_EOF;
                        }
                    }
                    self.line += 1;
                    break :blk true;
                } else {
                    self.current -= 1;
                    break :blk false;
                }
            },
            else => false,
        }) : (self.current += 1) {
            if (self.current + 1 == self.read_buf.len) {
                return .TOKEN_EOF;
            }
        }
        return .TOKEN_WHILE;
    }

    pub fn scanString(self: *Self) InterpretError!Token {
        while (self.current < self.read_buf.len and self.read_buf[self.current] != '"') : (self.current += 1) {
            if (self.read_buf[self.current] == '\n') {
                self.line += 1;
            }
        }
        if (self.current == self.read_buf.len) {
            return error.INTERPRET_LEXICAL_ERROR;
        }
        const tok = self.makeToken(.TOKEN_STRING);
        self.current += 1;
        return tok;
    }

    pub fn scanID(self: *Self) Token {
        while (self.current < self.read_buf.len and switch (self.read_buf[self.current]) {
            'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
            else => false,
        }) : (self.current += 1) {}
        return self.makeToken(self.key_words.get(self.read_buf[self.start..self.current]) orelse return self.makeToken(.TOKEN_IDENTIFIER));
    }

    pub fn scanNumber(self: *Self) Token {
        while (self.current < self.read_buf.len and switch (self.read_buf[self.current]) {
            '0'...'9' => true,
            else => false,
        }) : (self.current += 1) {}

        if (self.current < self.read_buf.len and self.read_buf[self.current] == '.') {
            self.current += 1;
            while (self.current < self.read_buf.len and switch (self.read_buf[self.current]) {
                '0'...'9' => true,
                else => false,
            }) : (self.current += 1) {}
        }
        return self.makeToken(.TOKEN_NUMBER);
    }

    pub fn scan(self: *Self) !void {
        std.debug.print("Beginning scan\n", .{});
        while (self.current <= self.read_buf.len) {
            const tok: Token = try self.scanToken();
            try self.tokens.append(tok);
        }
    }

    pub fn scanToken(self: *Self) !Token {
        if (self.current == self.read_buf.len) {
            self.current += 1;
            return self.makeToken(.TOKEN_EOF);
        }

        if (self.clearWhitespace() == .TOKEN_EOF) {
            self.current += 1;
            return self.makeToken(.TOKEN_EOF);
        }
        self.start = self.current;
        self.current += 1;
        return switch (self.read_buf[self.start]) {
            '(' => self.makeToken(.TOKEN_LEFT_PAREN),
            ')' => self.makeToken(.TOKEN_RIGHT_PAREN),
            '{' => self.makeToken(.TOKEN_LEFT_BRACE),
            '}' => self.makeToken(.TOKEN_RIGHT_BRACE),
            ';' => self.makeToken(.TOKEN_SEMICOLON),
            ',' => self.makeToken(.TOKEN_COMMA),
            '.' => self.makeToken(.TOKEN_DOT),
            '-' => self.makeToken(.TOKEN_MINUS),
            '+' => self.makeToken(.TOKEN_PLUS),
            '/' => self.makeToken(.TOKEN_SLASH),
            '*' => self.makeToken(.TOKEN_STAR),
            '!' => self.makeToken(if (self.next('=')) .TOKEN_BANG_EQUAL else .TOKEN_BANG),
            '=' => self.makeToken(if (self.next('=')) .TOKEN_EQUAL_EQUAL else .TOKEN_EQUAL),
            '<' => self.makeToken(if (self.next('=')) .TOKEN_LESS_EQUAL else .TOKEN_LESS),
            '>' => self.makeToken(if (self.next('=')) .TOKEN_GREATER_EQUAL else .TOKEN_GREATER),
            '"' => try self.scanString(),
            '0'...'9' => self.scanNumber(),
            'A'...'Z', 'a'...'z', '_' => self.scanID(),
            else => null,
        } orelse {
            std.debug.print("Lexical error.\nUnexpected token on line {}: '{s}'\n", .{ self.line, self.read_buf[(self.start)..(self.current + 1)] });
            return error.INTERPRET_LEXICAL_ERROR;
        };
    }
};
