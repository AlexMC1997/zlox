const std = @import("std");
pub const Value = f64;

pub fn parseValue(s: []const u8) !Value {
    return std.fmt.parseFloat(Value, s);
}
