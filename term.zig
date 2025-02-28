const std = @import("std");
const builtin = @import("builtin");
const maze = @import("gen.zig");
const lib = @import("lib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    var int_args = try std.ArrayList(u32).initCapacity(alloc, args.len - 1);
    defer int_args.deinit();
    for (args[1..]) |arg| {
        const n = try std.fmt.parseInt(u32, arg, 10);
        try int_args.append(n);
    }
    var si_args = SliceIter(u32).init(int_args.items);

    const w = si_args.next() orelse 25;
    const h = si_args.next() orelse 6;
    //const w2 = si_args.next() orelse 1;
    //const h2 = si_args.next() orelse 1;

    const mazes = [_]maze.Maze{
        try maze.Dfs.gen(w, h, alloc, std.crypto.random),
        try maze.Kruskal.gen(w, h, alloc, std.crypto.random),
    };
    defer for (mazes) |m| {
        m.deinit();
    };

    const stdout = std.io.getStdOut().writer();
    for (mazes, 0..) |m, i| {
        const mstr = try m.to_ascii();
        defer m.alloc.free(mstr);
        const mstrl = try Lines.from_str(mstr, alloc);
        defer mstrl.deinit();
        const start: usize = if (i == 0) 0 else 1;
        for (mstrl.v[start..]) |l| {
            try stdout.print("{s}\n", .{l});
        }
    }
}

const Lines = struct {
    v: [][]u8,
    alloc: std.mem.Allocator,

    fn from_str(str: []u8, alloc: std.mem.Allocator) !@This() {
        var list = std.ArrayList([]u8).init(alloc);
        var line = std.ArrayList(u8).init(alloc);
        for (str) |c| {
            if (c == '\n') {
                try list.append(try line.toOwnedSlice());
            } else {
                try line.append(c);
            }
        }

        return .{
            .v = try list.toOwnedSlice(),
            .alloc = alloc,
        };
    }

    fn deinit(self: @This()) void {
        for (self.v) |line| {
            self.alloc.free(line);
        }
        self.alloc.free(self.v);
    }
};

fn SliceIter(T: type) type {
    return struct {
        slice: []T,
        index: usize,

        fn init(s: []T) @This() {
            return .{
                .slice = s,
                .index = 0,
            };
        }

        fn next(self: *@This()) ?T {
            if (self.index < self.slice.len) {
                self.index += 1;
                return self.slice[self.index - 1];
            } else {
                return null;
            }
        }
    };
}
