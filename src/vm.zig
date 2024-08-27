const std = @import("std");
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./opcode.zig").OpCode;
const Value = @import("./value.zig").Value;
const ValueType = @import("./value.zig").ValueType;
const Object = @import("object.zig").Object;
const ObjectType = @import("object.zig").ObjectType;
const InterpretError = @import("zlox.zig").InterpretError;

pub fn VM(comptime TraceWriter: type) type {
    return struct {
        const Self = @This();

        ip: usize,
        stack: std.ArrayList(Value),
        heap_alloc: std.mem.Allocator,
        chunk: ?*const Chunk,
        trace_writer: ?TraceWriter,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .ip = 0, .stack = std.ArrayList(Value).init(allocator), .heap_alloc = allocator, .chunk = null, .trace_writer = null };
        }

        pub fn deinit(self: Self) void {
            self.stack.deinit();
        }

        pub fn printStack(self: Self) !void {
            try self.trace_writer.?.print("   ", .{});
            var buf: [256]u8 = undefined;
            for (self.stack.items) |v| {
                try self.trace_writer.?.print("[ {s} ]", .{try v.toString(&buf)});
            }
            try self.trace_writer.?.print("\n", .{});
        }

        fn Unpack(comptime valType: ValueType) type {
            return struct {
                pub fn get(vm: *const VM(TraceWriter), val: Value, op: OpCode) 
                !@TypeOf(@field(val, @tagName(valType))) {
                    return switch (val) {
                        valType => @field(val, @tagName(valType)),
                        else => {
                            try vm.logError(op, val);
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        },
                    };
                }
            };
        }

        pub fn run(self: *Self) !void {
            var instr: OpCode = self.chunk.?.getInstr(self.ip);
            while (true) : (instr = self.chunk.?.getInstr(self.ip)) {
                try self.printStack();
                _ = try self.chunk.?.disassembleInstr(self.ip, self.trace_writer.?);
                switch (instr) {
                    .OP_CONSTANT => {
                        const val: Value = self.chunk.?.getConstant(self.ip + 1);
                        try self.stack.append(val);
                        self.ip += 2;
                    },
                    .OP_CONSTANT_LONG => {
                        const val: Value = self.chunk.?.getConstantLong(self.ip + 1);
                        try self.stack.append(val);
                        self.ip += 4;
                    },
                    .OP_NEGATE => {
                        const v = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_NEGATE);
                        try self.stack.append(.{ .t_number = -v });
                        self.ip += 1;
                    },
                    .OP_ADD => {
                        const v2 = self.stack.pop();
                        const v1 = self.stack.pop();
                        if (std.meta.activeTag(v1) != std.meta.activeTag(v2)) {
                            try self.logTypeError(.OP_ADD, v1, v2);
                            return InterpretError.INTERPRET_RUNTIME_ERROR;
                        }
                        switch (v1) {
                            .t_number => try self.stack.append(.{ .t_number = v1.t_number + v2.t_number }),
                            .t_obj => try self.stack.append(
                                .{.t_obj = try Object.opAdd(v1.t_obj, v2.t_obj, self.heap_alloc)}
                            ),
                            else => try self.logTypeError( .OP_ADD, v1, v2),
                        }
                        
                        self.ip += 1;
                    },
                    .OP_SUBTRACT => {
                        const v2 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_SUBTRACT);
                        const v1 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_SUBTRACT);
                        try self.stack.append(.{ .t_number = v1 - v2 });
                        self.ip += 1;
                    },
                    .OP_MULTIPLY => {
                        const v2 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_MULTIPLY);
                        const v1 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_MULTIPLY);
                        try self.stack.append(.{ .t_number = v1 * v2 });
                        self.ip += 1;
                    },
                    .OP_DIVIDE => {
                        const v2 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_DIVIDE);
                        const v1 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_DIVIDE);
                        try self.stack.append(.{ .t_number = v1 / v2 });
                        self.ip += 1;
                    },
                    .OP_NOT => {
                        const v = try Unpack(.t_boolean)
                            .get(self, self.stack.pop(), .OP_NOT);
                        try self.stack.append(.{ .t_boolean = !v });
                        self.ip += 1;
                    },
                    .OP_OR => {
                        const v2 = try Unpack(.t_boolean)
                            .get(self, self.stack.pop(), .OP_OR);
                        const v1 = try Unpack(.t_boolean)
                            .get(self, self.stack.pop(), .OP_OR);
                        try self.stack.append(.{ .t_boolean = v1 or v2 });
                        self.ip += 1;
                    },
                    .OP_AND => {
                        const v2 = try Unpack(.t_boolean)
                            .get(self, self.stack.pop(), .OP_AND);
                        const v1 = try Unpack(.t_boolean)
                            .get(self, self.stack.pop(), .OP_AND);
                        try self.stack.append(.{ .t_boolean = v1 and v2 });
                        self.ip += 1;
                    },
                    .OP_EQ => {
                        const v2: Value = self.stack.pop();
                        const v1: Value = self.stack.pop();
                        try self.stack.append(.{ .t_boolean = v1.eq(v2) });
                        self.ip += 1;
                    },
                    .OP_GEQ => {
                        const v2 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_GEQ);
                        const v1 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_GEQ);
                        try self.stack.append(.{ .t_boolean = v1 >= v2 });
                        self.ip += 1;
                    },
                    .OP_LEQ => {
                        const v2 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_LEQ);
                        const v1 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_LEQ);
                        try self.stack.append(.{ .t_boolean = v1 <= v2 });
                        self.ip += 1;
                    },
                    .OP_LT => {
                        const v2 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_LT);
                        const v1 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_LT);
                        try self.stack.append(.{ .t_boolean = v1 < v2 });
                        self.ip += 1;
                    },
                    .OP_GT => {
                        const v2 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_GT);
                        const v1 = try Unpack(.t_number)
                            .get(self, self.stack.pop(), .OP_GT);
                        try self.stack.append(.{ .t_boolean = v1 > v2 });
                        self.ip += 1;
                    },
                    .OP_RETURN => {
                        return;
                    },
                    // else =>
                }
            }
        }

        pub fn logTypeError(self: *const Self, op: OpCode, v1: Value, v2: Value) !void {
            var buf1: [256]u8 = undefined;
            var buf2: [256]u8 = undefined;
            try self.trace_writer.?.print(
                "[Line {}] RUNTIME ERROR: {s} called on operands of type {s}, {s} with values {s}, {s}.\n", 
                .{ 
                    self.chunk.?.getLine(self.ip), 
                    @tagName(op), 
                    @tagName(v1), 
                    @tagName(v2), 
                    try v1.toString(&buf1), 
                    try v2.toString(&buf2) 
                }
            );
        }

        pub fn logError(self: *const Self, op: OpCode, val: Value) !void {
            var buf: [256]u8 = undefined;
            try self.trace_writer.?.print(
                "[Line {}] RUNTIME ERROR: {s} called on operand of type {s} with value {s}.\n", 
                .{ self.chunk.?.getLine(self.ip), @tagName(op), @tagName(val), try val.toString(&buf) }
            );
        }

        pub fn interpret(self: *Self, chunk: *const Chunk, trace_writer: TraceWriter) !void {
            self.ip = 0;
            self.stack.clearAndFree();
            self.chunk = chunk;
            self.trace_writer = trace_writer;
            try self.run();
            self.chunk = null;
        }
    };
} 