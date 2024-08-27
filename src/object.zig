const std = @import("std");
const String = @import("string.zig").String;

pub const ObjType = enum {
    t_string,
};

pub const Object = struct {
    type: ObjType,

    pub fn opAdd(obj1: *const Object, obj2: *const Object, allocator: std.mem.Allocator) !*Object {
        return @alignCast(@ptrCast(switch (obj1.type) {
            .t_string => blk1: {
                const s1: *const String = @alignCast(@ptrCast(obj1));
                const s2: *const String = @alignCast(@ptrCast(obj2));
                break :blk1 try String.opAdd(s1, s2, allocator);
            },
        }));
    }
};
