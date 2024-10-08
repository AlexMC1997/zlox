const std = @import("std");
const Value = @import("./zlox.zig").Value;
const OpCode = @import("./zlox.zig").OpCode;

pub const Chunk = struct {
    const Self = @This();

    code: std.ArrayList(u8),
    lint_numbers: std.ArrayList(usize),
    constants: std.ArrayList(Value),
    static_alloc: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self { 
            .code = std.ArrayList(u8).init(allocator), 
            .constants = std.ArrayList(Value).init(allocator), 
            .lint_numbers = std.ArrayList(usize).init(allocator), 
            .static_alloc = std.heap.ArenaAllocator.init(allocator) 
        };
    }

    pub fn deinit(self: Self) void {
        self.code.deinit();
        self.lint_numbers.deinit();
        self.constants.deinit();
        return;
    }

    pub fn reinit(self: *Self) void {
        self.code.clearAndFree();
        self.lint_numbers.clearAndFree();
        self.constants.clearAndFree();
        return;
    }

    pub fn len(self: Self) usize {
        return self.code.items.len;
    }

    pub fn write(self: *Self, byte: u8, line: usize) !void {
        try self.code.append(byte);
        if (self.lint_numbers.items.len == line) {
            self.lint_numbers.items[line - 1] += 1;
        } else {
            try self.lint_numbers.append(1);
        }
        return;
    }

    pub fn getLine(self: Self, offset: usize) usize {
        var i: usize = self.lint_numbers.items[0];
        var line: usize = 1;
        while (i <= offset) : (line += 1) {
            i += self.lint_numbers.items[line];
        }
        return line;
    }

    pub fn getInstr(self: Self, ip: usize) OpCode {
        return @as(OpCode, @enumFromInt(self.code.items[ip]));
    }

    pub fn addConstant(self: *Self, val: Value) !usize {
        try self.constants.append(val);
        return self.constants.items.len - 1;
    }

    pub fn getConstant(self: Self, addr: usize) Value {
        const ind: usize = self.code.items[addr];
        return self.constants.items[ind];
    }

    pub fn getConstantLong(self: Self, addr: usize) Value {
        const ind: usize = @as(usize, @as(*u24, @ptrCast(@alignCast(self.code.items.ptr + addr))).*);
        return self.constants.items[ind];
    }

    pub fn writeOpCode(self: *Self, op: OpCode, line: usize) !void {
        try self.write(@intFromEnum(op), line);
    }

    pub fn writeConstant(self: *Self, val: Value, line: usize) !void {
        const n = try self.addConstant(val);
        if (self.constants.items.len > 256) {
            try self.writeOpCode(.OP_CONSTANT_LONG, line);
            try self.write(@as(u8, @truncate(n)), line);
            try self.write(@as(u8, @truncate(n >> 8)), line);
            try self.write(@as(u8, @truncate(n >> 16)), line);
        } else {
            try self.writeOpCode(.OP_CONSTANT, line);
            try self.write(@as(u8, @truncate(n)), line);
        }
    }

    pub fn disassembleInstr(self: Self, offset: usize, writer: anytype) !usize {
        if (offset > 0 and self.getLine(offset) == self.getLine(offset - 1)) {
            try writer.print("{} | ", .{offset});
        } else {
            try writer.print("{} {} ", .{ offset, self.getLine(offset) });
        }
        const instr: OpCode = @enumFromInt(self.code.items[offset]);
        var buf: [256]u8 = undefined;
        var alloc = std.heap.FixedBufferAllocator.init(&buf);
        switch (instr) {
            .OP_CONSTANT => {
                const constantInd = self.code.items[offset + 1];
                const str = try self.constants.items[constantInd].toString(alloc.allocator());
                try writer.print("OP_CONSTANT {} {s}\n", .{ constantInd,  str});
                return offset + 2;
            },
            .OP_CONSTANT_LONG => {
                const constantInd: usize = @as(usize, self.code.items[offset + 1]) + (@as(usize, self.code.items[offset + 1]) << 8) + (@as(usize, self.code.items[offset + 1]) << 16);
                const str = try self.constants.items[constantInd].toString(alloc.allocator());
                try writer.print("OP_CONSTANT {} {s}\n", .{ constantInd, str});
                return offset + 4;
            },
            else => {
                try writer.print("{s}\n", .{@tagName(instr)});
                return offset + 1;
            },
        }
    }

    pub fn disassemble(self: Self, name: []const u8, writer: anytype) !void {
        try writer.print("Disassembly of \"{s}\"\n", .{name});

        var offset: usize = 0;
        while (offset < self.len()) {
            offset = try disassembleInstr(self, offset, writer);
        }
    }
};
