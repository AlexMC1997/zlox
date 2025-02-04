const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Chunk = @import("chunk.zig").Chunk;
const Value = @import("value.zig").Value;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const InterpretError = @import("zlox.zig").InterpretError;
const OpCode = @import("opcode.zig").OpCode;
const ParseFloatError = std.fmt.ParseFloatError;
const Allocator = std.mem.Allocator;

const PREC_NONE: u8 = 0;
const PREC_ASSIGNMENT: u8 = 1; // =
const PREC_TERNARY: u8 = 2; // =
const PREC_OR: u8 = 3; // or
const PREC_AND: u8 = 4; // and
const PREC_EQUALITY: u8 = 5; // == !=
const PREC_COMPARISON: u8 = 6; // < > <= >=
const PREC_TERM: u8 = 7; // + -
const PREC_FACTOR: u8 = 8; // * /
const PREC_UNARY: u8 = 9; // ! -
const PREC_CALL: u8 = 10; // . ()
const PREC_PRIMARY: u8 = 11;

pub const Parser = struct {
    const Self = @This();

    const Local = struct {
        id: []u8,
        depth: usize,

        pub fn init(id: []u8, depth: usize) Local {
            return .{.id = id, .depth = depth};
        }
    };

    parse_alloc: std.heap.ArenaAllocator, 
    chunk: ?Chunk,
    scanner: ?*const Scanner,
    token_number: usize,
    current: Token,
    previous: Token,
    op_last: bool,
    depth: usize,
    locals: std.ArrayList(Local),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ 
            .parse_alloc = std.heap.ArenaAllocator.init(allocator),
            .chunk = null, 
            .scanner = null, .token_number = 0, 
            .current = Token.default(), 
            .previous = Token.default(), 
            .op_last = true,
            .depth = 0,
            .locals = std.ArrayList(Local).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.parse_alloc.deinit();
        self.locals.deinit();
    }

    pub fn parse(self: *Self, scanner: *const Scanner, allocator: std.mem.Allocator) !Chunk {
        self.chunk = Chunk.init(allocator);
        self.scanner = scanner;
        self.nextToken();
        while (self.current.tok_type != .TOKEN_EOF) {
            self.declaration() catch |err| {
                std.debug.print("Syntax error on line {} token {s}.\n", .{self.current.line, @tagName(self.current.tok_type)});
                return err;
            };
        }
        try self.emitCode(.OP_RETURN, self.current.line);
        self.scanner = null;
        const chunk = self.chunk orelse return InterpretError.INTERPRET_COMPILE_ERROR;
        self.chunk = null;
        return chunk;
    }

    fn tokenData(self: *const Self) []const u8 {
        return self.scanner.?.read_buf[self.current.start..(self.current.start+self.current.len)];
    }

    fn emitConstant(self: *Self, val: Value, line: usize) !void {
        // std.debug.print("Emitting constant {} on line {}.\n", .{ val, line });
        try self.chunk.?.writeConstant(val, line);
    }

    fn emitCode(self: *Self, code: OpCode, line: usize) !void {
        // std.debug.print("Emitting op on line {}.\n", .{line});
        try self.chunk.?.writeOpCode(code, line);
    }

    fn nextToken(self: *Self) void {
        if (self.current.tok_type == .TOKEN_EOF)
            return;
        self.previous = self.current;
        self.current = self.scanner.?.getToken(self.token_number);
        self.token_number += 1;
    }

    fn value(self: *Self) !void {
        const val = try self.scanner.?.getValue(self.current, self.chunk.?.static_alloc.allocator());
        try self.emitConstant(val, self.current.line);
        try self.consume(self.current.tok_type);
        self.op_last = false;
    }

    fn consume(self: *Self, tok_type: TokenType) !void {
        if (self.current.tok_type == tok_type) {
            self.nextToken();
            return;
        } else {
            return error.INTERPRET_SYNTAX_ERROR;
        }
    }

    fn grouping(self: *Self) !void {
        try self.consume(.TOKEN_LEFT_PAREN);
        try self.expression(PREC_ASSIGNMENT);
        try self.consume(.TOKEN_RIGHT_PAREN);
    }

    fn stackOp(self: *Self, prec: u8, op: OpCode, tok: TokenType) !void {
        try self.consume(tok);
        self.op_last = true;
        try self.expression(prec);
        try self.emitCode(op, self.current.line);
    }

    fn add(self: *Self) !void {
        try self.stackOp(PREC_TERM, .OP_ADD, .TOKEN_PLUS);
    }

    fn negate(self: *Self) !void {
        try self.stackOp(PREC_UNARY, .OP_NEGATE, .TOKEN_MINUS);
    }

    fn subtract(self: *Self) !void {
        try self.stackOp(PREC_TERM, .OP_SUBTRACT, .TOKEN_MINUS);
    }

    fn multiply(self: *Self) !void {
        try self.stackOp(PREC_FACTOR, .OP_MULTIPLY, .TOKEN_STAR);
    }

    fn divide(self: *Self) !void {
        try self.stackOp(PREC_FACTOR, .OP_DIVIDE, .TOKEN_SLASH);
    }

    fn ternary(self: *Self) !void {
        try self.consume(.TOKEN_QUESTION);
        //jump logic
        try self.expression(PREC_TERNARY);
        try self.consume(.TOKEN_COLON);
        try self.expression(PREC_TERNARY);
    }

    fn findLastLocal(self: *Self) !?usize {
        const ident = try self.scanner.?.readStringValue(self.current, self.parse_alloc.allocator());
        var it = std.mem.reverseIterator(self.locals.items);
        while (it.next()) |l| {
            if (std.mem.eql(u8, l.id, ident)) {
                return it.index;
            }
        }
        return null;
    }

    fn variable(self: *Self) !void {
        const line = self.current.line;
        const ind = try self.findLastLocal();
        if (self.depth == 0 or ind == null) {
            try self.value();
            if (self.current.tok_type != .TOKEN_EQUAL) {
                try self.emitCode(.OP_VAR, line);
            }
        } else {
            const val = Value{.t_number = @floatFromInt(ind.?)};
            try self.consume(.TOKEN_IDENTIFIER);
            try self.emitConstant(val, line);
            if (self.current.tok_type != .TOKEN_EQUAL) {
                try self.emitCode(.OP_GET, line);
            } else {
                try self.stackOp(PREC_ASSIGNMENT, .OP_SET, .TOKEN_EQUAL);
            }
        }
    }

    fn expression(self: *Self, prec: u8) (ParseFloatError || Allocator.Error || InterpretError)!void {
        while (true) {
            switch (self.current.tok_type) {
                .TOKEN_QUESTION => try self.ternary(),
                .TOKEN_LEFT_PAREN => try self.grouping(),
                .TOKEN_NUMBER => try self.value(),
                .TOKEN_STRING => try self.value(),
                .TOKEN_TRUE => try self.value(),
                .TOKEN_FALSE => try self.value(),
                .TOKEN_NIL => try self.value(),
                .TOKEN_PLUS => if (prec < PREC_TERM) try self.add() else return,
                .TOKEN_MINUS => if (!self.op_last and prec < PREC_TERM) try self.subtract() 
                                else if (self.op_last and prec < PREC_UNARY) try self.negate() 
                                else return,
                .TOKEN_BANG => if (prec < PREC_UNARY) try self.stackOp(PREC_UNARY, .OP_NOT, .TOKEN_BANG),
                .TOKEN_STAR => if (prec < PREC_FACTOR) try self.multiply() else return,
                .TOKEN_SLASH => if (prec < PREC_FACTOR) try self.divide() else return,
                .TOKEN_GREATER_EQUAL => if (prec < PREC_COMPARISON) try self.stackOp(PREC_COMPARISON, .OP_GEQ, .TOKEN_GREATER_EQUAL) else return,
                .TOKEN_LESS_EQUAL => if (prec < PREC_COMPARISON) try self.stackOp(PREC_COMPARISON, .OP_LEQ, .TOKEN_LESS_EQUAL) else return,
                .TOKEN_LESS => if (prec < PREC_COMPARISON) try self.stackOp(PREC_COMPARISON, .OP_LT, .TOKEN_LESS) else return,
                .TOKEN_GREATER => if (prec < PREC_COMPARISON) try self.stackOp(PREC_COMPARISON, .OP_GT, .TOKEN_GREATER) else return,
                .TOKEN_EQUAL_EQUAL => if (prec < PREC_EQUALITY) try self.stackOp(PREC_EQUALITY, .OP_EQ, .TOKEN_EQUAL_EQUAL) else return,
                .TOKEN_AND => if (prec < PREC_AND) try self.stackOp(PREC_AND, .OP_AND, .TOKEN_AND) else return,
                .TOKEN_OR => if (prec < PREC_OR) try self.stackOp(PREC_OR, .OP_OR, .TOKEN_OR) else return,
                .TOKEN_IDENTIFIER => try self.variable(),
                .TOKEN_EQUAL => if (prec < PREC_ASSIGNMENT) 
                                try self.stackOp(prec, .OP_ASSIGN, .TOKEN_EQUAL) 
                                else return InterpretError.INTERPRET_SYNTAX_ERROR,
                // .TOKEN_SEMICOLON => return std.debug.print("Reached end of statement.\n", .{}),
                // .TOKEN_EOF => return std.debug.print("Reached end of file.\n", .{}),
                else => return,
            }
        }
    }

    fn block(self: *Self) (InterpretError || error{OutOfMemory, InvalidCharacter})!void
    {
        try self.consume(.TOKEN_LEFT_BRACE);
        self.depth += 1;
        while (self.current.tok_type != .TOKEN_RIGHT_BRACE) : (try self.declaration()) {}
        while (self.locals.items.len > 0 and self.locals.getLast().depth == self.depth) : (_ = self.locals.pop()) {}
        self.depth -= 1;
        try self.consume(.TOKEN_RIGHT_BRACE);
    }

    fn statement(self: *Self) !void {
        switch (self.current.tok_type) {
            .TOKEN_PRINT => {
                try self.stackOp(PREC_ASSIGNMENT, .OP_STRING, .TOKEN_PRINT);
                try self.emitCode(.OP_PRINT, self.current.line);
            },
            .TOKEN_LEFT_BRACE => try self.block(),
            else => try self.expression(PREC_NONE),
        }
    }

    fn varDef(self: *Self) !void {
        try self.consume(.TOKEN_VAR);
        if (self.current.tok_type != .TOKEN_IDENTIFIER) {
            return InterpretError.INTERPRET_SYNTAX_ERROR;
        }
        if (self.depth == 0) {
            try self.value();
            try self.stackOp(PREC_ASSIGNMENT, .OP_ASSIGN, .TOKEN_EQUAL);
        } else {
            const ident = try self.scanner.?.readStringValue(self.current, self.parse_alloc.allocator());
            try self.consume(.TOKEN_IDENTIFIER);
            self.op_last = false;
            try self.locals.append(Local.init(ident, self.depth));
            try self.emitConstant(Value{.t_nil = undefined}, self.current.line);
            try self.emitConstant(Value{.t_number = @floatFromInt(self.locals.items.len - 1)}, self.current.line);
            try self.stackOp(PREC_ASSIGNMENT, .OP_SET, .TOKEN_EQUAL);
        }
    }

    fn declaration(self: *Self) !void {
        if (self.current.tok_type == .TOKEN_VAR) {
            try self.varDef();
        } else {
            try self.statement();
            if (self.depth > 0 and self.current.tok_type == .TOKEN_RIGHT_BRACE) return;
        }
        self.consume(.TOKEN_SEMICOLON) catch try self.consume(.TOKEN_EOF);
    }
};
