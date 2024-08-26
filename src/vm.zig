const std = @import("std");
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./opcode.zig").OpCode;
const Value = @import("./value.zig").Value;
const ValueType = @import("./value.zig").ValueType;
const InterpretError = @import("zlox.zig").InterpretError;

pub const VM = struct {
    const Self = @This();

    ip: usize,
    stack: std.ArrayList(Value),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .ip = 0, .stack = std.ArrayList(Value).init(allocator) };
    }

    pub fn deinit(self: Self) void {
        self.stack.deinit();
    }

    pub fn printStack(self: Self, writer: anytype) !void {
        try writer.print("   ", .{});
        for (self.stack.items) |v| {
            switch (v) {
                .e_number => |val| try writer.print("[ {} ]", .{val}),
                .e_boolean => |val| try writer.print("[ {} ]", .{val}),
                .e_nil => try writer.print("[ nil ]", .{}),
            }
        }
        try writer.print("\n", .{});
    }

    fn Unpack(comptime valType: ValueType) type {
        return struct {
            pub fn get(val: Value, op: OpCode, trace_writer: anytype, line: usize) !@TypeOf(@field(val, @tagName(valType))) {
                return switch (val) {
                    valType => @field(val, @tagName(valType)),
                    else => {
                        try logError(trace_writer, line, op, val);
                        return InterpretError.INTERPRET_RUNTIME_ERROR;
                    },
                };
            }
        };
    }

    pub fn run(self: *Self, chunk: *const Chunk, trace_writer: anytype) !void {
        var instr: OpCode = chunk.getInstr(self.ip);
        while (true) : (instr = chunk.getInstr(self.ip)) {
            try self.printStack(trace_writer);
            _ = try chunk.disassembleInstr(self.ip, trace_writer);
            switch (instr) {
                .OP_CONSTANT => {
                    const val: Value = chunk.getConstant(self.ip + 1);
                    try self.stack.append(val);
                    self.ip += 2;
                },
                .OP_CONSTANT_LONG => {
                    const val: Value = chunk.getConstantLong(self.ip + 1);
                    try self.stack.append(val);
                    self.ip += 4;
                },
                .OP_NEGATE => {
                    const v = try Unpack(.e_number).get(self.stack.pop(), .OP_NEGATE, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_number = -v });
                    self.ip += 1;
                },
                .OP_ADD => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_ADD, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_ADD, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_number = v1 + v2 });
                    self.ip += 1;
                },
                .OP_SUBTRACT => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_SUBTRACT, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_SUBTRACT, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_number = v1 - v2 });
                    self.ip += 1;
                },
                .OP_MULTIPLY => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_MULTIPLY, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_MULTIPLY, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_number = v1 * v2 });
                    self.ip += 1;
                },
                .OP_DIVIDE => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_DIVIDE, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_DIVIDE, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_number = v1 / v2 });
                    self.ip += 1;
                },
                .OP_NOT => {
                    const v = try Unpack(.e_boolean).get(self.stack.pop(), .OP_NOT, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_boolean = !v });
                    self.ip += 1;
                },
                .OP_OR => {
                    const v2 = try Unpack(.e_boolean).get(self.stack.pop(), .OP_OR, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_boolean).get(self.stack.pop(), .OP_OR, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_boolean = v1 or v2 });
                    self.ip += 1;
                },
                .OP_AND => {
                    const v2 = try Unpack(.e_boolean).get(self.stack.pop(), .OP_AND, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_boolean).get(self.stack.pop(), .OP_AND, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_boolean = v1 and v2 });
                    self.ip += 1;
                },
                .OP_EQ => {
                    const v2: Value = self.stack.pop();
                    const v1: Value = self.stack.pop();
                    try self.stack.append(.{ .e_boolean = v1.eq(v2) });
                    self.ip += 1;
                },
                .OP_GEQ => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_GEQ, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_GEQ, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_boolean = v1 >= v2 });
                    self.ip += 1;
                },
                .OP_LEQ => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_LEQ, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_LEQ, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_boolean = v1 <= v2 });
                    self.ip += 1;
                },
                .OP_LT => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_LT, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_LT, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_boolean = v1 < v2 });
                    self.ip += 1;
                },
                .OP_GT => {
                    const v2 = try Unpack(.e_number).get(self.stack.pop(), .OP_GT, trace_writer, chunk.getLine(self.ip));
                    const v1 = try Unpack(.e_number).get(self.stack.pop(), .OP_GT, trace_writer, chunk.getLine(self.ip));
                    try self.stack.append(.{ .e_boolean = v1 > v2 });
                    self.ip += 1;
                },
                .OP_RETURN => {
                    return;
                },
                // else =>
            }
        }
    }

    pub fn logError(trace_writer: anytype, line: usize, op: OpCode, val: Value) !void {
        var buf: [256]u8 = undefined;
        try trace_writer.print("[Line {}] RUNTIME ERROR: {s} called on operand of type {s} with value {s}.\n", .{ line, @tagName(op), @tagName(val), try val.toString(&buf) });
    }

    pub fn interpret(self: *Self, chunk: *const Chunk, trace_writer: anytype) !void {
        self.ip = 0;
        self.stack.clearAndFree();
        try self.run(chunk, trace_writer);
    }
};
