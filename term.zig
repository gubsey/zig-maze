const std = @import("std");
const maze = @import("gen.zig");

pub fn main() !void {
    const args = std.os.argv;
    if (args.len != 3) {
        std.log.err("Must have 2 integer arguments", .{});
        return;
    }

    const w = try std.fmt.parseInt(u32, std.mem.span(args[1]), 10);
    const h = try std.fmt.parseInt(u32, std.mem.span(args[2]), 10);

    var m = try maze.Dfs.init(
        w,
        h,
        std.heap.page_allocator,
        std.crypto.random,
    );

    while (try m.next()) |_| {}

    try m.print();
}
