const std = @import("std");
const zlox = @import("./zlox.zig");
const Value = @import("./value.zig").Value;
const ValueType = @import("./value.zig").ValueType;
const Object = @import("object.zig").Object;

const test_path = "./test/";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    try zlox.runFile(test_path ++ "types.lox", std.io.getStdOut().writer(), allocator);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn expectValue(comptime vtype: ValueType, value: Value, expected: anytype) !void {
    return switch (value) {
        vtype => |val| try expect(val == expected),
        else => expectEqual(std.meta.activeTag(value), vtype),
    };
}

test "arithmetic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var vm = zlox.VM(std.fs.File.Writer, void).init(allocator);
    defer vm.deinit();

    const writer = std.io.getStdErr().writer();

    var chunk = zlox.Chunk.init(allocator);
    defer chunk.deinit();

    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeConstant(.{ .t_number = 2.0 }, 1);
    try chunk.writeOpCode(.OP_MULTIPLY, 1);
    try chunk.writeConstant(.{ .t_number = 3.0 }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer, null, true);
    try expectValue(ValueType.t_number, vm.stack.getLast(), 5);

    chunk.reinit();

    try chunk.writeConstant(.{ .t_number = 3.0 }, 1);
    try chunk.writeConstant(.{ .t_number = 2.0 }, 1);
    try chunk.writeOpCode(.OP_MULTIPLY, 1);
    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer, null, true);
    try expectValue(ValueType.t_number, vm.stack.getLast(), 7);

    chunk.reinit();

    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeConstant(.{ .t_number = 2.0 }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeConstant(.{ .t_number = 3.0 }, 1);
    try chunk.writeOpCode(.OP_SUBTRACT, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer, null, true);
    try expectValue(ValueType.t_number, vm.stack.getLast(), 0);

    chunk.reinit();

    try chunk.writeConstant(.{ .t_number = 2.0 }, 1);
    try chunk.writeConstant(.{ .t_number = 3.0 }, 1);
    try chunk.writeOpCode(.OP_MULTIPLY, 1);
    try chunk.writeConstant(.{ .t_number = 4.0 }, 1);
    try chunk.writeConstant(.{ .t_number = 5.0 }, 1);
    try chunk.writeOpCode(.OP_NEGATE, 1);
    try chunk.writeOpCode(.OP_DIVIDE, 1);
    try chunk.writeOpCode(.OP_SUBTRACT, 1);
    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer, null, true);
    try expectValue(ValueType.t_number, vm.stack.getLast(), 39.0 / 5.0);
}

test "type error" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var vm = zlox.VM(std.fs.File.Writer, void).init(allocator);
    defer vm.deinit();

    const writer = std.io.getStdErr().writer();

    var chunk = zlox.Chunk.init(allocator);
    defer chunk.deinit();

    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeConstant(.{ .t_boolean = true }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    const res: anyerror!void = vm.interpret(&chunk, writer, null, true);
    try std.testing.expectError(zlox.InterpretError.INTERPRET_RUNTIME_ERROR, res);
}

test "expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const writer = std.io.getStdErr().writer();
    const path = test_path ++ "expr.lox";

    const file: std.fs.File = std.fs.cwd().openFile(path, .{}) catch try std.fs.openFileAbsolute(path, .{});

    var scanner = try zlox.Scanner.init(file.reader(), allocator);
    defer scanner.deinit();

    var parser = zlox.Parser.init(allocator);
    defer parser.deinit();

    var vm = zlox.VM(std.fs.File.Writer, void).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, null, true);

    try expectValue(ValueType.t_number, vm.stack.getLast(), (-3.0 - -3.4 * 4.0 / -(51 + 2.0) - 5));
}

test "logic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const writer = std.io.getStdErr().writer();
    const path = test_path ++ "bool.lox";

    const file: std.fs.File = std.fs.cwd().openFile(path, .{}) catch try std.fs.openFileAbsolute(path, .{});

    var scanner = try zlox.Scanner.init(file.reader(), allocator);
    defer scanner.deinit();

    var parser = zlox.Parser.init(allocator);
    defer parser.deinit();

    var vm = zlox.VM(std.fs.File.Writer, void).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, null, true);

    try expectValue(ValueType.t_boolean, vm.stack.getLast(), !(true and 2 * 2 > 1.5 + 1.5 or false) or 2 * 2 + 2 < 3 + 3 + 3 or (false or 5 == 5));
}

test "strings" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const writer = std.io.getStdErr().writer();
    const path = test_path ++ "strings.lox";

    const file: std.fs.File = std.fs.cwd().openFile(path, .{}) catch try std.fs.openFileAbsolute(path, .{});

    var scanner = try zlox.Scanner.init(file.reader(), allocator);
    defer scanner.deinit();

    var parser = zlox.Parser.init(allocator);
    defer parser.deinit();

    var vm = zlox.VM(std.fs.File.Writer, void).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, null, true);

    try expectValue(ValueType.t_boolean, vm.stack.getLast(), true);
}

test "print" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const writer = std.io.getStdErr().writer();
    const path = test_path ++ "print.lox";

    const file: std.fs.File = std.fs.cwd().openFile(path, .{}) catch try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const out_file: std.fs.File = try std.fs.cwd().createFile(test_path ++ "out/print.out", .{});
    defer out_file.close();

    var scanner = try zlox.Scanner.init(file.reader(), allocator);
    defer scanner.deinit();

    var parser = zlox.Parser.init(allocator);
    defer parser.deinit();

    var vm = zlox.VM(std.fs.File.Writer, std.fs.File.Writer).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, out_file.writer(), true);

    var buf_out: [1024]u8 = undefined;
    var buf_in: [1024]u8 = undefined;

    const out = try std.fs.cwd().readFile(test_path ++ "out/print.out", &buf_out);
    const in = try std.fs.cwd().readFile(test_path ++ "in/print.out", &buf_in);
    try expectEqual(in.len, out.len);
    for (0..@min(in.len, out.len)) |i| {
        try expectEqual(out[i], in[i]);
    } 
}

test "vars" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const writer = std.io.getStdErr().writer();
    const path = test_path ++ "vars.lox";

    const file: std.fs.File = std.fs.cwd().openFile(path, .{}) catch try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const out_file: std.fs.File = try std.fs.cwd().createFile(test_path ++ "out/print.out", .{});
    defer out_file.close();

    var scanner = try zlox.Scanner.init(file.reader(), allocator);
    defer scanner.deinit();

    var parser = zlox.Parser.init(allocator);
    defer parser.deinit();

    var vm = zlox.VM(std.fs.File.Writer, std.fs.File.Writer).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, out_file.writer(), true);

    const v = vm.stack.getLast();
    const s = Object.Sub(.t_string).from(switch (v) {
        .t_obj => |obj| obj,
        else => return error.TestUnexpectedResult,
    });

    try expect(std.mem.eql(u8, s.data, "woah woah buddy woah woah"));
}
