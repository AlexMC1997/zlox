const std = @import("std");
const zlox = @import("./zlox.zig");

const test_path = "./test/";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    try zlox.runFile(test_path ++ "expr.lox", std.io.getStdOut().writer(), allocator);
}

const expect = std.testing.expect;

test "arithmetic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var vm = zlox.VM.init(allocator);
    defer vm.deinit();

    const writer = std.io.getStdErr().writer();

    var chunk = zlox.Chunk.init(allocator);
    defer chunk.deinit();

    try chunk.writeConstant(1, 1);
    try chunk.writeConstant(2, 1);
    try chunk.writeOpCode(.OP_MULTIPLY, 1);
    try chunk.writeConstant(3, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer);
    try expect(vm.stack.getLast() == 5);

    chunk.reinit();

    try chunk.writeConstant(3, 1);
    try chunk.writeConstant(2, 1);
    try chunk.writeOpCode(.OP_MULTIPLY, 1);
    try chunk.writeConstant(1, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer);
    try expect(vm.stack.getLast() == 7);

    chunk.reinit();

    try chunk.writeConstant(1, 1);
    try chunk.writeConstant(2, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeConstant(3, 1);
    try chunk.writeOpCode(.OP_SUBTRACT, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer);
    try expect(vm.stack.getLast() == 0);

    chunk.reinit();

    try chunk.writeConstant(2, 1);
    try chunk.writeConstant(3, 1);
    try chunk.writeOpCode(.OP_MULTIPLY, 1);
    try chunk.writeConstant(4, 1);
    try chunk.writeConstant(5, 1);
    try chunk.writeOpCode(.OP_NEGATE, 1);
    try chunk.writeOpCode(.OP_DIVIDE, 1);
    try chunk.writeOpCode(.OP_SUBTRACT, 1);
    try chunk.writeConstant(1, 1);
    try chunk.writeOpCode(.OP_ADD, 1);
    try chunk.writeOpCode(.OP_RETURN, 2);
    try vm.interpret(&chunk, writer);
    try expect(vm.stack.getLast() == 39.0 / 5.0);
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

    var vm = zlox.VM.init(allocator);
    defer vm.deinit();

    try scanner.scan();
    try scanner.printTokens(writer);

    try parser.parse(&scanner);

    try vm.interpret(&parser.chunk, writer);

    try expect(vm.stack.getLast() == (3.0 - -3.0 * 4.0 / -(5.0 + 2.0)));
}
