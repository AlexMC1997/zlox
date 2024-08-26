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
                    switch (self.stack.getLast()) {
                        ValueType.e_number => try self.stack.append(.{ .e_number = -self.stack.pop().e_number }),
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_NEGATE, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    }

                    self.ip += 1;
                },
                .OP_ADD => {
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_ADD, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_ADD, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_number = v1 + v2 });
                    self.ip += 1;
                },
                .OP_SUBTRACT => {
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_SUBTRACT, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_SUBTRACT, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_number = v1 - v2 });
                    self.ip += 1;
                },
                .OP_MULTIPLY => {
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_MULTIPLY, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_MULTIPLY, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_number = v1 * v2 });
                    self.ip += 1;
                },
                .OP_DIVIDE => {
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_DIVIDE, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_DIVIDE, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_number = v1 / v2 });
                    self.ip += 1;
                },
                .OP_NOT => {
                    switch (self.stack.getLast()) {
                        ValueType.e_boolean => try self.stack.append(.{ .e_boolean = !self.stack.pop().e_boolean }),
                        ValueType.e_number, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_NOT, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    }

                    self.ip += 1;
                },
                .OP_OR => {
                    const v2: Value.BoolType = switch (self.stack.getLast()) {
                        ValueType.e_boolean => self.stack.pop().e_boolean,
                        ValueType.e_number, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_OR, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.BoolType = switch (self.stack.getLast()) {
                        ValueType.e_boolean => self.stack.pop().e_boolean,
                        ValueType.e_number, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_OR, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_boolean = v1 or v2 });
                    self.ip += 1;
                },
                .OP_AND => {
                    const v2: Value.BoolType = switch (self.stack.getLast()) {
                        ValueType.e_boolean => self.stack.pop().e_boolean,
                        ValueType.e_number, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_AND, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.BoolType = switch (self.stack.getLast()) {
                        ValueType.e_boolean => self.stack.pop().e_boolean,
                        ValueType.e_number, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_AND, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
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
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_GEQ, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_GEQ, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_boolean = v1 >= v2 });
                    self.ip += 1;
                },
                .OP_LEQ => {
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_LEQ, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_LEQ, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_boolean = v1 <= v2 });
                    self.ip += 1;
                },
                .OP_LT => {
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_LT, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_LT, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    try self.stack.append(.{ .e_boolean = v1 < v2 });
                    self.ip += 1;
                },
                .OP_GT => {
                    const v2: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_GT, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                    const v1: Value.NumberType = switch (self.stack.getLast()) {
                        ValueType.e_number => self.stack.pop().e_number,
                        ValueType.e_boolean, ValueType.e_nil => {
                            try logError(trace_writer, chunk.getLine(self.ip), .OP_GT, self.stack.getLast());
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
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
