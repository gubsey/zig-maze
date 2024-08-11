const std = @import("std");

const Dfs = struct {
    const Self = @This();

    buffer: [][]CellState,
    alloc: std.mem.Allocator,

    fn init(width: i32, height: i32, alloc: std.mem.Allocator) !Self {
        const CSAL = std.ArrayList(CellState);

        var tbl = std.ArrayList([]CellState).init(alloc);

        for (0..height) |y| {
            var row = CSAL.init(alloc);

            for (0..width) |x| {
                try row.append(.none);
            }

            const s = try row.toOwnedSlice();
            try tbl.append(s);
        }
    }
};

const CellState = enum { done, none, explore };
