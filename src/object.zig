const std = @import("std");
const String = @import("string.zig").String;

pub const ObjType = enum {
    t_string,
};

pub const ObjectError = error{
    OPERATOR_TYPE_ERROR,
};

pub const Object = struct {
    const Self = @This();
    type: ObjType,

    pub fn SubCast(comptime t: ObjType) type {
        return struct {
            pub fn from(obj: *const Object) switch (t) {
                .t_string => *const String,
            } {
                return @alignCast(@ptrCast(obj));
            }
        };
    }

    pub fn subName(self: *const Self) []const u8 {
        return switch(self.type) {
            .t_string => "Object::String",
        };
    }

    pub fn opAdd(obj1: *const Self, obj2: *const Self, allocator: std.mem.Allocator) !*Object {
        return @alignCast(@ptrCast(switch (obj1.type) {
            .t_string => blk1: {
                if (obj2.type != .t_string) {
                    return ObjectError.OPERATOR_TYPE_ERROR;
                }
                const s1 = SubCast(.t_string).from(obj1);
                const s2 = SubCast(.t_string).from(obj2);
                break :blk1 try String.opAdd(s1, s2, allocator);
            },
        }));
    }

    pub fn opString(self: *const Self, allocator: std.mem.Allocator) String {
        _ = allocator;
        return switch (self.type) {
            .t_string => SubCast(.t_string).from(self).*,
        };
    }
 };
