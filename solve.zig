const std = @import("std");
const Maze = @import("gen.zig").Dfs;

const lib = @import("lib.zig");
const Point = lib.Point;
const xy = lib.xy;

pub const Dfs = struct {
    maze: Maze,
    stack: std.ArrayList(Point),
    alloc: std.mem.Allocator,
    checked: [][]bool,

    /// will use the provieded maze's allocator if none is provided;
    pub fn init(maze: Maze, alloc_arg: ?std.mem.Allocator) !@This() {
        const alloc = alloc_arg orelse maze.alloc;

        var stack = std.ArrayList(StackItem).init(alloc);
        try stack.append(xy(0, 0));

        var checked = try alloc.alloc([]bool, maze.buffer.len);
        for (0..checked.len) |i| {
            checked[i] = try alloc.alloc(bool, maze.buffer[i].len);
            @memset(checked[i], false);
        }

        return .{
            .maze = maze,
            .stack = stack,
            .alloc = alloc,
            .checked = checked,
        };
    }

    pub fn next(self: @This()) !void {
        const curr = self.stack.getLast();

        for (try self.maze.adjacent_cells(curr)) |p| {
            if (self.checked[p.y][p.x]) continue;
        }
    }
};

const StackItem = struct {
    pos: Point,
    neighbors: std.ArrayList(Point),
};
