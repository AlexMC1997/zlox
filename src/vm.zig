const std = @import("std");
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./opcode.zig").OpCode;
const Value = @import("./value.zig").Value;

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
            try writer.print("[ {} ]", .{v});
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
                    try self.stack.append(-self.stack.pop());
                    self.ip += 1;
                },
                .OP_ADD => {
                    const v2 = self.stack.pop();
                    const v1 = self.stack.pop();
                    try self.stack.append(v1 + v2);
                    self.ip += 1;
                },
                .OP_SUBTRACT => {
                    const v2 = self.stack.pop();
                    const v1 = self.stack.pop();
                    try self.stack.append(v1 - v2);
                    self.ip += 1;
                },
                .OP_MULTIPLY => {
                    const v2 = self.stack.pop();
                    const v1 = self.stack.pop();
                    try self.stack.append(v1 * v2);
                    self.ip += 1;
                },
                .OP_DIVIDE => {
                    const v2 = self.stack.pop();
                    const v1 = self.stack.pop();
                    try self.stack.append(v1 / v2);
                    self.ip += 1;
                },
                .OP_RETURN => {
                    return;
                },
                // else =>
            }
        }
    }

    pub fn interpret(self: *Self, chunk: *const Chunk, trace_writer: anytype) !void {
        self.ip = 0;
        self.stack.clearAndFree();
        try self.run(chunk, trace_writer);
    }
};
