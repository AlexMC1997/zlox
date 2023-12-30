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

    chunk: Chunk,
    scanner: *const Scanner,
    token_number: usize,
    current: Token,
    previous: Token,

    pub fn init(scanner: *const Scanner, allocator: std.mem.Allocator) Self {
        return .{ .chunk = Chunk.init(allocator), .scanner = scanner, .token_number = 0, .current = Token.default(), .previous = Token.default() };
    }

    pub fn emitConstant(self: *Self, val: Value, line: usize) !void {
        // std.debug.print("Emitting constant {} on line {}.\n", .{ val, line });
        try self.chunk.writeConstant(val, line);
    }

    pub fn emitCode(self: *Self, code: OpCode, line: usize) !void {
        // std.debug.print("Emitting op on line {}.\n", .{line});
        try self.chunk.writeOpCode(code, line);
    }

    pub fn nextToken(self: *Self) void {
        if (self.current.tok_type == .TOKEN_EOF)
            return;
        self.previous = self.current;
        self.current = self.scanner.getToken(self.token_number);
        self.token_number += 1;
    }

    pub fn number(self: *Self) !void {
        const val = try self.scanner.getValue(self.current);
        try self.emitConstant(val, self.current.line);
        try self.consume(.TOKEN_NUMBER);
    }

    pub fn consume(self: *Self, tok_type: TokenType) !void {
        if (self.current.tok_type == tok_type) {
            self.nextToken();
            return;
        } else {
            return error.INTERPRET_SYNTAX_ERROR;
        }
    }

    pub fn grouping(self: *Self) !void {
        try self.consume(.TOKEN_LEFT_PAREN);
        try self.expression(PREC_ASSIGNMENT);
        try self.consume(.TOKEN_RIGHT_PAREN);
    }

    pub fn stack_op(self: *Self, prec: u8, op: OpCode, tok: TokenType) !void {
        try self.consume(tok);
        try self.expression(prec);
        try self.emitCode(op, self.current.line);
    }

    pub fn add(self: *Self) !void {
        try self.stack_op(PREC_TERM, .OP_ADD, .TOKEN_PLUS);
    }

    pub fn negate(self: *Self) !void {
        try self.stack_op(PREC_UNARY, .OP_NEGATE, .TOKEN_MINUS);
    }

    pub fn subtract(self: *Self) !void {
        try self.stack_op(PREC_TERM, .OP_SUBTRACT, .TOKEN_MINUS);
    }

    pub fn multiply(self: *Self) !void {
        try self.stack_op(PREC_FACTOR, .OP_MULTIPLY, .TOKEN_STAR);
    }

    pub fn divide(self: *Self) !void {
        try self.stack_op(PREC_FACTOR, .OP_DIVIDE, .TOKEN_SLASH);
    }

    pub fn ternary(self: *Self) !void {
        try self.consume(.TOKEN_QUESTION);
        //jump logic
        try self.expression(PREC_TERNARY);
        try self.consume(.TOKEN_COLON);
        try self.expression(PREC_TERNARY);
    }

    pub fn expression(self: *Self, prec: u8) (ParseFloatError || Allocator.Error || InterpretError)!void {
        while (true) {
            switch (self.current.tok_type) {
                .TOKEN_QUESTION => try self.ternary(),
                .TOKEN_LEFT_PAREN => try self.grouping(),
                .TOKEN_NUMBER => try self.number(),
                .TOKEN_PLUS => if (prec < PREC_TERM) try self.add() else return,
                .TOKEN_MINUS => if (prec < PREC_TERM) try self.subtract() else if (prec < PREC_UNARY) try self.negate() else return,
                .TOKEN_STAR => if (prec < PREC_FACTOR) try self.multiply() else return,
                .TOKEN_SLASH => if (prec < PREC_FACTOR) try self.divide() else return,
                // .TOKEN_SEMICOLON => return std.debug.print("Reached end of statement.\n", .{}),
                // .TOKEN_EOF => return std.debug.print("Reached end of file.\n", .{}),
                else => return,
            }
        }
    }

    pub fn parse(self: *Self) !void {
        while (self.current.tok_type != .TOKEN_EOF) {
            self.nextToken();
            self.expression(PREC_ASSIGNMENT) catch |err| {
                std.debug.print("Syntax error on line {}.\n", .{self.current.line});
                return err;
            };
        }
        try self.emitCode(.OP_RETURN, self.current.line);
    }
};
