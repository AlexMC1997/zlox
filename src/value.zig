const std = @import("std");

pub const ValueType = enum { e_number, e_boolean, e_nil };
pub const Value = union(ValueType) {
    const Self = @This();
    pub const NumberType = f64;
    pub const BoolType = bool;
    e_number: NumberType,
    e_boolean: BoolType,
    e_nil: void,

    pub fn parseNumber(s: []const u8) !Value {
        return .{ .e_number = try std.fmt.parseFloat(NumberType, s) };
    }

    pub fn toString(self: Self, buf: []u8) ![]u8 {
        return switch (self) {
            .e_number => |val| try std.fmt.bufPrint(buf, "{}", .{val}),
            .e_boolean => |val| try std.fmt.bufPrint(buf, "{}", .{val}),
            .e_nil => try std.fmt.bufPrint(buf, "nil", .{}),
        };
    }

    pub fn eq(self: Self, rhs: Self) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(rhs)) {
            return false;
        }
        return switch (self) {
            ValueType.e_nil => true,
            ValueType.e_boolean => self.e_boolean == rhs.e_boolean,
            ValueType.e_number => self.e_number == rhs.e_number,
        };
    }
};
