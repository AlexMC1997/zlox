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

    try vm.chunk.writeConstant(1, 1);
    try vm.chunk.writeConstant(2, 1);
    try vm.chunk.writeOpCode(.OP_MULTIPLY, 1);
    try vm.chunk.writeConstant(3, 1);
    try vm.chunk.writeOpCode(.OP_ADD, 1);
    try vm.chunk.writeOpCode(.OP_RETURN, 2);
    try vm.run(writer);
    try expect(vm.stack.getLast() == 5);

    vm.reinit(allocator);

    try vm.chunk.writeConstant(3, 1);
    try vm.chunk.writeConstant(2, 1);
    try vm.chunk.writeOpCode(.OP_MULTIPLY, 1);
    try vm.chunk.writeConstant(1, 1);
    try vm.chunk.writeOpCode(.OP_ADD, 1);
    try vm.chunk.writeOpCode(.OP_RETURN, 2);
    try vm.run(writer);
    try expect(vm.stack.getLast() == 7);

    vm.reinit(allocator);

    try vm.chunk.writeConstant(1, 1);
    try vm.chunk.writeConstant(2, 1);
    try vm.chunk.writeOpCode(.OP_ADD, 1);
    try vm.chunk.writeConstant(3, 1);
    try vm.chunk.writeOpCode(.OP_SUBTRACT, 1);
    try vm.chunk.writeOpCode(.OP_RETURN, 2);
    try vm.run(writer);
    try expect(vm.stack.getLast() == 0);

    vm.reinit(allocator);

    try vm.chunk.writeConstant(2, 1);
    try vm.chunk.writeConstant(3, 1);
    try vm.chunk.writeOpCode(.OP_MULTIPLY, 1);
    try vm.chunk.writeConstant(4, 1);
    try vm.chunk.writeConstant(5, 1);
    try vm.chunk.writeOpCode(.OP_NEGATE, 1);
    try vm.chunk.writeOpCode(.OP_DIVIDE, 1);
    try vm.chunk.writeOpCode(.OP_SUBTRACT, 1);
    try vm.chunk.writeConstant(1, 1);
    try vm.chunk.writeOpCode(.OP_ADD, 1);
    try vm.chunk.writeOpCode(.OP_RETURN, 2);
    try vm.run(writer);
    try expect(vm.stack.getLast() == 39.0 / 5.0);
}
