const Object = @import("object.zig").Object;
const std = @import("std");

pub const String = struct {
    const Self = @This();
    metadata: Object,
    data: []u8,

    pub fn init(str: []u8, allocator: std.mem.Allocator) !Self {
        var obj: Self = undefined;
        obj.data = try allocator.dupe(u8, str);
        obj.metadata = .{ .type = .t_string };
        return obj;
    }

    pub fn initEmpty(sz: usize, allocator: std.mem.Allocator) !Self {
        var obj: Self = undefined;
        obj.data = try allocator.alloc(u8, sz);
        obj.metadata = .{ .type = .t_string };
        return obj;
    }

    pub fn new(str: []u8, allocator: std.mem.Allocator) !*Self {
        var obj: *Self = try allocator.create(Self);
        obj.* = try String.init(str, allocator);
        return obj;
    }

    pub fn newEmpty(sz: usize, allocator: std.mem.Allocator) !*Self {
        var obj: *Self = try allocator.create(Self);
        obj.* = try String.initEmpty(sz, allocator);
        return obj;
    }

    pub fn eq(self: *const Self, rhs: *const Self) bool {
        return std.mem.eql(u8, self.data, rhs.data);
    }

    pub fn opAdd(s1: *const Self, s2: *const Self, allocator: std.mem.Allocator) !*Self {
        var s3: *String = try String.newEmpty(s1.data.len + s2.data.len, allocator);
        @memcpy(s3.data[0..s1.data.len], s1.data);
        @memcpy(s3.data[s1.data.len..], s2.data);
        return s3;
    }
};
