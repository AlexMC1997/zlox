const std = @import("std");
const Object = @import("./object.zig").Object;
const String = @import("./string.zig").String;

pub const ValueType = enum { t_number, t_boolean, t_nil, t_obj };
pub const Value = union(ValueType) {
    const Self = @This();
    pub const NumberType = f64;
    pub const BoolType = bool;
    t_number: NumberType,
    t_boolean: BoolType,
    t_obj: *Object,
    t_nil: void,

    pub fn parseNumber(s: []const u8) !Value {
        return .{ .t_number = try std.fmt.parseFloat(NumberType, s) };
    }

    const ToStringChoice = enum {
        BUF,
        ALLOC,
    };

    fn ToString(comptime choice: ToStringChoice) type {
        const printFn = comptime switch (choice) {
            .BUF => std.fmt.bufPrint,
            .ALLOC => std.fmt.allocPrint,
        };
        const argT = comptime switch (choice) {
            .BUF => []u8,
            .ALLOC => std.mem.Allocator,
        };
        return struct {
            pub fn toString(self: Self, arg: argT) ![]u8 {
                return switch (self) {
                    .t_number => |val| try printFn(arg, "{}", .{val}),
                    .t_boolean => |val| try printFn(arg, "{}", .{val}),
                    .t_obj => |val| blk1: {
                        break :blk1 switch (val.type) {
                            .t_string => blk2: {
                                const str: *const String = @alignCast(@ptrCast(val));
                                break :blk2 try printFn(arg, "\"{s}\"", .{str.data});
                            },
                            // else => "none",
                        };
                    },
                    .t_nil => try printFn(arg, "nil", .{}),
                };
            }
        };
    }

    pub fn toString(self: Self, buf: []u8) ![]u8 {
        return ToString(.BUF).toString(self, buf);
    }

    pub fn toStringAlloc(self: Self, allocator: std.mem.Allocator) ![]u8 {
        return ToString(.ALLOC).toString(self, allocator);
    }

    pub fn eq(self: Self, rhs: Self) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(rhs)) {
            return false;
        }
        return switch (self) {
            .t_nil => true,
            .t_boolean => self.t_boolean == rhs.t_boolean,
            .t_obj => |val| blk1: {
                break :blk1 switch (val.type) {
                    .t_string => blk2: {
                        const str1: *const String = @alignCast(@ptrCast(val));
                        const str2: *const String = @alignCast(@ptrCast(rhs.t_obj));
                        break :blk2 str1.eq(str2);
                    },
                    // else => false,
                };
            },
            .t_number => self.t_number == rhs.t_number,
        };
    }
};
