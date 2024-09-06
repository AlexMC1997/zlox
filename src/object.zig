const std = @import("std");
const String = @import("string.zig").String;

pub const ObjType = enum {
    t_string,
};

pub const Object = struct {
    const Self = @This();
    type: ObjType,

    pub fn Sub(comptime t: ObjType) type {
        return struct {
            pub fn from(obj: *const Object) switch (t) {
                .t_string => *const String,
            } {
                return @alignCast(@ptrCast(obj));
            }
        };
    }

    pub fn opAdd(obj1: *const Self, obj2: *const Self, allocator: std.mem.Allocator) !*Object {
        return @alignCast(@ptrCast(switch (obj1.type) {
            .t_string => blk1: {
                const s1: *const String = @alignCast(@ptrCast(obj1));
                const s2: *const String = @alignCast(@ptrCast(obj2));
                break :blk1 try String.opAdd(s1, s2, allocator);
            },
        }));
    }

    pub fn opString(self: *const Self, allocator: std.mem.Allocator) String {
        _ = allocator;
        return switch (self.type) {
            .t_string => Sub(.t_string).from(self).*,
        };
    }
 };
