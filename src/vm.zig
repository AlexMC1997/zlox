const std = @import("std");
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./opcode.zig").OpCode;
const Value = @import("./value.zig").Value;
const ValueType = @import("./value.zig").ValueType;
const Object = @import("object.zig").Object;
const ObjectType = @import("object.zig").ObjectType;
const String = @import("string.zig").String;
const InterpretError = @import("zlox.zig").InterpretError;

pub fn VM(comptime TraceWriter: type, comptime OutputWriter: type) type {
    return struct {
        const Self = @This();

        ip: usize,
        stack: std.ArrayList(Value),
        heap_alloc: std.mem.Allocator,
        chunk: ?*const Chunk,
        trace_writer: ?TraceWriter,
        out: ?OutputWriter,
        debug: bool,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .ip = 0, .stack = std.ArrayList(Value).init(allocator), .heap_alloc = allocator, .chunk = null, .trace_writer = null, .out = null, .debug = false };
        }

        pub fn deinit(self: Self) void {
            self.stack.deinit();
        }

        pub fn printStack(self: Self) !void {
            try self.trace_writer.?.print("   ", .{});
            for (self.stack.items) |v| {
                const str = try v.toString(self.heap_alloc);
                defer self.heap_alloc.free(str);
                try self.trace_writer.?.print("[ {s} ]", .{str});
            }
            try self.trace_writer.?.print("\n", .{});
        }

        fn Unpack(comptime valType: ValueType) type {
            return struct {
                pub fn get(vm: *const VM(TraceWriter, OutputWriter), val: Value, op: OpCode) 
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

        fn opConstant(self: *Self) !void {
            const val: Value = self.chunk.?.getConstant(self.ip + 1);
            try self.stack.append(val);
            self.ip += 2;
        }

        fn opConstantLong(self: *Self) !void {
            const val: Value = self.chunk.?.getConstantLong(self.ip + 1);
            try self.stack.append(val);
            self.ip += 4;
        }

        fn opNegate(self: *Self) !void {
            const v = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_NEGATE);
            try self.stack.append(.{ .t_number = -v });
            self.ip += 1;
        }

        fn opAdd(self: *Self) !void {
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
        }

        fn opSubtract(self: *Self) !void {
            const v2 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_SUBTRACT);
            const v1 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_SUBTRACT);
            try self.stack.append(.{ .t_number = v1 - v2 });
            self.ip += 1;
        }

        fn opMultiply(self: *Self) !void {
            const v2 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_MULTIPLY);
            const v1 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_MULTIPLY);
            try self.stack.append(.{ .t_number = v1 * v2 });
            self.ip += 1;
        }

        fn opDivide(self: *Self) !void {
            const v2 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_DIVIDE);
            const v1 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_DIVIDE);
            try self.stack.append(.{ .t_number = v1 / v2 });
            self.ip += 1;
        }

        fn opNot(self: *Self) !void {
            const v = try Unpack(.t_boolean)
                .get(self, self.stack.pop(), .OP_NOT);
            try self.stack.append(.{ .t_boolean = !v });
            self.ip += 1;
        }

        fn opOr(self: *Self) !void {
            const v2 = try Unpack(.t_boolean)
                .get(self, self.stack.pop(), .OP_OR);
            const v1 = try Unpack(.t_boolean)
                .get(self, self.stack.pop(), .OP_OR);
            try self.stack.append(.{ .t_boolean = v1 or v2 });
            self.ip += 1;
        }

        fn opAnd(self: *Self) !void {
            const v2 = try Unpack(.t_boolean)
                .get(self, self.stack.pop(), .OP_AND);
            const v1 = try Unpack(.t_boolean)
                .get(self, self.stack.pop(), .OP_AND);
            try self.stack.append(.{ .t_boolean = v1 and v2 });
            self.ip += 1;
        }

        fn opEq(self: *Self) !void {
            const v2: Value = self.stack.pop();
            const v1: Value = self.stack.pop();
            try self.stack.append(.{ .t_boolean = v1.eq(v2) });
            self.ip += 1;
        }

        fn opGeq(self: *Self) !void {
            const v2 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_GEQ);
            const v1 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_GEQ);
            try self.stack.append(.{ .t_boolean = v1 >= v2 });
            self.ip += 1;
        }

        fn opLeq(self: *Self) !void {
            const v2 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_LEQ);
            const v1 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_LEQ);
            try self.stack.append(.{ .t_boolean = v1 <= v2 });
            self.ip += 1;
        }

        fn opLt(self: *Self) !void {
            const v2 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_LT);
            const v1 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_LT);
            try self.stack.append(.{ .t_boolean = v1 < v2 });
            self.ip += 1;
        }

        fn opGt(self: *Self) !void {
            const v2 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_GT);
            const v1 = try Unpack(.t_number)
                .get(self, self.stack.pop(), .OP_GT);
            try self.stack.append(.{ .t_boolean = v1 > v2 });
            self.ip += 1;
        }

        fn opString(self: *Self) !void {
            const str: *String = try self.heap_alloc.create(String); 
            str.* = try self.stack.pop().opString(self.heap_alloc);
            try self.stack.append(.{ .t_obj = @alignCast(@ptrCast(str)) });
            self.ip += 1;
        }

        fn print(self: *Self) !void {
            self.ip += 1;
            if (OutputWriter == void) {
                return;
            } else {
                const v: Value = self.stack.pop();
                switch (v) {
                    .t_obj => |obj| switch (obj.type) {
                        .t_string => {
                            const str = Object.Sub(.t_string).from(obj);
                            try self.out.?.print("{s}", .{str.data});
                        },
                        // else => try self.logError(.OP_PRINT, v),
                    },
                    else => try self.logError(.OP_PRINT, v),
                }
            }
        }

        pub fn run(self: *Self) !void {
            var instr: OpCode = self.chunk.?.getInstr(self.ip);
            while (true) : (instr = self.chunk.?.getInstr(self.ip)) {
                if (self.debug) {
                    try self.printStack();
                    _ = try self.chunk.?.disassembleInstr(self.ip, self.trace_writer.?);
                }
                switch (instr) {
                    .OP_CONSTANT => try self.opConstant(),
                    .OP_CONSTANT_LONG => try self.opConstantLong(),
                    .OP_NEGATE => try self.opNegate(),
                    .OP_ADD => try self.opAdd(),
                    .OP_SUBTRACT => try self.opSubtract(),
                    .OP_MULTIPLY => try self.opMultiply(),
                    .OP_DIVIDE => try self.opDivide(),
                    .OP_NOT => try self.opNot(),
                    .OP_OR => try self.opOr(),
                    .OP_AND => try self.opAnd(),
                    .OP_EQ => try self.opEq(),
                    .OP_GEQ => try self.opGeq(),
                    .OP_LEQ => try self.opLeq(),
                    .OP_LT => try self.opLt(),
                    .OP_GT => try self.opGt(),
                    .OP_STRING => try self.opString(),
                    .OP_PRINT => try self.print(),
                    .OP_POP => _ = self.stack.pop(),
                    .OP_RETURN => return,
                    // else =>
                }
            }
        }

        pub fn logTypeError(self: *const Self, op: OpCode, v1: Value, v2: Value) !void {
            const str1 = try v1.toString(self.heap_alloc);
            defer self.heap_alloc.free(str1);
            const str2 = try v2.toString(self.heap_alloc);
            defer self.heap_alloc.free(str2);
            try self.trace_writer.?.print(
                "[Line {}] RUNTIME ERROR: {s} called on operands of type {s}, {s} with values {s}, {s}.\n", 
                .{ 
                    self.chunk.?.getLine(self.ip), 
                    @tagName(op), 
                    @tagName(v1), 
                    @tagName(v2), 
                    str1, 
                    str2 
                }
            );
        }

        pub fn logError(self: *const Self, op: OpCode, val: Value) !void {
            const str = try val.toString(self.heap_alloc);
            defer self.heap_alloc.free(str);
            try self.trace_writer.?.print(
                "[Line {}] RUNTIME ERROR: {s} called on operand of type {s} with value {s}.\n", 
                .{ self.chunk.?.getLine(self.ip), @tagName(op), @tagName(val), str }
            );
        }

        pub fn interpret(self: *Self, chunk: *const Chunk, trace_writer: TraceWriter, out: ?OutputWriter, debug: bool) !void {
            self.ip = 0;
            self.stack.clearAndFree();
            self.chunk = chunk;
            self.trace_writer = trace_writer;
            self.out = out;
            self.debug = debug;
            try self.run();
            self.chunk = null;
            self.debug = false;
            self.trace_writer = null;
            self.out = null;
        }
    };
} 