const std = @import("std");

pub fn main() !void {
    std.debug.print("{d}\n", .{bad()});
}

fn bad() [4]i32 {
    const x = [_]i32{ 1, 2, 3, 3 };
    return x;
}
