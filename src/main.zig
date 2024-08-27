const std = @import("std");
const zlox = @import("./zlox.zig");
const Value = @import("./value.zig").Value;
const ValueType = @import("./value.zig").ValueType;

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

    var vm = zlox.VM(std.fs.File.Writer).init(allocator);
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
    try vm.interpret(&chunk, writer, true);
    try expectValue(ValueType.t_number, vm.stack.getLast(), 5);

    chunk.reinit();

    try chunk.writeConstant(.{ .t_number = 3.0 }, 1);
    try chunk.writeConstant(.{ .t_number = 2.0 }, 1);
    try chunk.writeOpCode(.OP_MULTIPLY, 1);
    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer, true);
    try expectValue(ValueType.t_number, vm.stack.getLast(), 7);

    chunk.reinit();

    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeConstant(.{ .t_number = 2.0 }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeConstant(.{ .t_number = 3.0 }, 1);
    try chunk.writeOpCode(.OP_SUBTRACT, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer, true);
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
    try vm.interpret(&chunk, writer, true);
    try expectValue(ValueType.t_number, vm.stack.getLast(), 39.0 / 5.0);
}

test "type error" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var vm = zlox.VM(std.fs.File.Writer).init(allocator);
    defer vm.deinit();

    const writer = std.io.getStdErr().writer();

    var chunk = zlox.Chunk.init(allocator);
    defer chunk.deinit();

    try chunk.writeConstant(.{ .t_number = 1.0 }, 1);
    try chunk.writeConstant(.{ .t_boolean = true }, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    const res: anyerror!void = vm.interpret(&chunk, writer, true);
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

    var vm = zlox.VM(std.fs.File.Writer).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, true);

    try expectValue(ValueType.t_number, vm.stack.getLast(), (3.0 - -3.4 * 4.0 / -(51 + 2.0)));
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

    var vm = zlox.VM(std.fs.File.Writer).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, true);

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

    var vm = zlox.VM(std.fs.File.Writer).init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);
    try parser.chunk.disassemble("test_program", writer);

    try vm.interpret(&parser.chunk, writer, true);

    try expectValue(ValueType.t_boolean, vm.stack.getLast(), true);
}
