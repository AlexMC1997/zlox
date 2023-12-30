pub const std = @import("std");
pub const Value = @import("./value.zig").Value;
pub const OpCode = @import("./opcode.zig").OpCode;
pub const Chunk = @import("./chunk.zig").Chunk;
pub const VM = @import("./vm.zig").VM;
pub const Scanner = @import("./scanner.zig").Scanner;
pub const Token = @import("./token.zig").Token;
pub const Parser = @import("./parser.zig").Parser;

const Allocator = std.mem.Allocator;

pub const InterpretError = error{
    INTERPRET_LEXICAL_ERROR,
    INTERPRET_SYNTAX_ERROR,
    INTERPRET_SEMANTIC_ERROR,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub fn runFile(path: []const u8, writer: anytype, allocator: Allocator) !void {
    const file: std.fs.File = std.fs.cwd().openFile(path, .{}) catch try std.fs.openFileAbsolute(path, .{});

    var scanner = try Scanner.init(file.reader(), allocator);
    defer scanner.deinit(allocator);

    try scanner.scan();
    try scanner.printTokens(writer);

    var parser = Parser.init(&scanner, allocator);
    try parser.parse();

    // try parser.chunk.disassemble("Test Prog", std.io.getStdOut().writer());

    var vm = VM.init(&parser.chunk, allocator);
    defer vm.deinit();

    try vm.run(writer);
}
