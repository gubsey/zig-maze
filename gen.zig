const std = @import("std");
const AL = std.ArrayList;

const lib = @import("lib.zig");
const Point = lib.Point;
const Dimensions = lib.Dimensions;
const xy = lib.xy;
const mid = lib.mid;

const WALL = "█";

pub const Maze = struct {
    cells: [][]Tile,
    alloc: std.mem.Allocator,

    pub fn deinit(self: @This()) void {
        for (self.cells) |r| {
            self.alloc.free(r);
        }
        self.alloc.free(self.cells);
    }

    /// remember to free the returned string with the maze's allocater
    pub fn to_ascii(maze: @This()) ![]u8 {
        var lines = AL([]u8).init(maze.alloc);
        defer lines.deinit();
        defer for (lines.items) |row| {
            maze.alloc.free(row);
        };

        var hat_len: usize = 0;

        for (maze.cells) |row| {
            var line = AL(u8).init(maze.alloc);

            hat_len = 0;
            for (row, 0..) |cell, x| {
                const repeat = ((x + 1) & 1) + 1;
                for (0..repeat) |_| {
                    try line.appendSlice(switch (cell) {
                        .Hall => " ",
                        .Wall => WALL,
                        .Othe => "%",
                    });
                    hat_len += 1;
                }
            }

            try lines.append(try line.toOwnedSlice());
        }

        var alb = std.ArrayList(u8).init(maze.alloc);
        const walb = alb.writer();

        for (0..hat_len + 4) |_| {
            try walb.print("{s}", .{WALL});
        }
        try walb.print("\n", .{});

        for (lines.items) |row| {
            try walb.print("{s}{s}{s}{s}{s}\n", .{ WALL, WALL, row, WALL, WALL });
        }

        for (0..hat_len + 4) |_| {
            try walb.print("{s}", .{WALL});
        }
        try walb.print("\n", .{});

        return alb.toOwnedSlice();
    }
};

pub const Tile = enum {
    Wall,
    Hall,
    Othe,
};

pub const Wilson = struct {
    buffer: [][]CellState,
    dimensions: Dimensions,
    stack: Al(Point),
}

pub const Dfs = struct {
    buffer: [][]CellState,
    alloc: std.mem.Allocator,
    dimensions: Dimensions,
    stack: AL(StackItem),
    rng: std.Random,

    const Self = @This();

    pub fn init(
        width: usize,
        height: usize,
        alloc: std.mem.Allocator,
        rng: std.Random,
    ) !Self {
        const true_width = width * 2 - 1;
        const true_height = height * 2 - 1;

        var tbl = AL([]CellState).init(alloc);

        for (0..true_height) |_| {
            var row = AL(CellState).init(alloc);
            try row.appendNTimes(.none, true_width);

            const s = try row.toOwnedSlice();
            try tbl.append(s);
        }

        var buf = try tbl.toOwnedSlice();
        buf[0][0] = .explore;

        var stack = AL(StackItem).init(alloc);
        try stack.append(.{
            .p = xy(0, 0),
            .last = xy(0, 0),
        });

        return Self{
            .buffer = buf,
            .alloc = alloc,
            .dimensions = Dimensions{ .w = width, .h = height },
            .rng = rng,
            .stack = stack,
        };
    }

    pub fn deinit(self: Self) void {
        for (self.buffer) |x| {
            self.alloc.free(x);
        }
        self.alloc.free(self.buffer);

        self.stack.deinit();
    }

    pub fn gen(
        width: usize,
        height: usize,
        alloc: std.mem.Allocator,
        rng: std.Random,
    ) !Maze {
        var self = try Self.init(width, height, alloc, rng);
        defer self.deinit();
        while (try self.next()) |_| {}
        return try self.to_maze();
    }

    pub fn adjacent_cells(self: Self, p: Point) ![]Point {
        var lst = try AL(Point).initCapacity(self.alloc, 4);

        const x = p.x;
        const y = p.y;

        if (y > 0) {
            try lst.append(xy(x, y - 2));
        }

        if (x < self.buffer[0].len - 1) {
            try lst.append(xy(x + 2, y));
        }

        if (y < self.buffer.len - 1) {
            try lst.append(xy(x, y + 2));
        }

        if (x > 0) {
            try lst.append(xy(x - 2, y));
        }

        return try lst.toOwnedSlice();
    }

    pub fn get_cell(self: Self, p: Point) CellState {
        return self.buffer[p.y][p.x];
    }

    pub fn set_cell(self: *Self, p: Point, c: CellState) void {
        self.buffer[p.y][p.x] = c;
    }

    /// returns the updates to each cell
    pub fn next(self: *Self) !?struct { p: Point, c: CellState } {
        const tail = self.stack.getLastOrNull() orelse return null;
        const p = tail.p;
        const last = tail.last;

        var moves = try self.adjacent_cells(p);
        defer self.alloc.free(moves);
        self.rng.shuffle(Point, moves[0..]);

        for (moves) |m| {
            if (self.buffer[m.y][m.x] != .none) continue;

            const midp = mid(p, m);
            self.set_cell(midp, .explore);

            try self.stack.append(.{ .p = m, .last = p });
            self.set_cell(m, .explore);
            return .{ .p = m, .c = .explore };
        }

        const midp = mid(p, last);
        self.set_cell(midp, .done);

        _ = self.stack.pop();
        self.set_cell(p, .done);
        return .{ .p = p, .c = .done };
    }

    pub fn print(self: Self) !void {
        const stdout = std.io.getStdOut().writer();

        var lines = AL([]u8).init(self.alloc);
        defer lines.deinit();

        var hat_len: usize = 0;

        for (self.buffer) |row| {
            var line = AL(u8).init(self.alloc);

            hat_len = 0;
            for (row, 0..) |cell, x| {
                const repeat = ((x + 1) & 1) + 1;
                for (0..repeat) |_| {
                    try line.appendSlice(switch (cell) {
                        .done => " ",
                        .none => WALL,
                        .explore => "+",
                    });
                    hat_len += 1;
                }
            }

            try lines.append(try line.toOwnedSlice());
        }

        // const line_len = lines.items[0].len;

        for (0..hat_len + 2) |_| {
            try stdout.print("{s}", .{WALL});
        }
        try stdout.print("\n", .{});

        for (lines.items) |row| {
            try stdout.print("{s}{s}{s}\n", .{ WALL, row, WALL });
        }

        for (0..hat_len + 2) |_| {
            try stdout.print("{s}", .{WALL});
        }
        try stdout.print("\n", .{});

        for (lines.items) |row| {
            self.alloc.free(row);
        }
    }

    fn internal_dimensions(self: Self) Dimensions {
        return .{
            .w = self.buffer[0].len,
            .h = self.buffer.len,
        };
    }

    fn to_maze(self: Self) !Maze {
        var cellList = try std.ArrayList([]Tile).initCapacity(self.alloc, self.buffer.len);
        for (self.buffer) |row| {
            var list = try std.ArrayList(Tile).initCapacity(self.alloc, row.len);
            for (row) |cs| {
                list.appendAssumeCapacity(switch (cs) {
                    .done => .Hall,
                    .none => .Wall,
                    .explore => .Othe,
                });
            }
            cellList.appendAssumeCapacity(try list.toOwnedSlice());
        }
        return .{
            .cells = try cellList.toOwnedSlice(),
            .alloc = self.alloc,
        };
    }
};

const CellState = enum { done, none, explore };
const StackItem = struct { p: Point, last: Point };

pub const Kruskal = struct {
    edges: AL([2]Point),
    good_edges: AL([2]Point),
    set: std.AutoHashMap(Point, usize),
    alloc: std.mem.Allocator,
    dimensions: Dimensions,
    rng: std.Random,

    const Self = @This();

    pub fn init(
        width: usize,
        height: usize,
        alloc: std.mem.Allocator,
        rng: std.Random,
    ) !Self {
        var edgeList = AL([2]Point).init(alloc);
        var set = std.AutoHashMap(Point, usize).init(alloc);
        for (0..width) |x| {
            for (0..height) |y| {
                const p = xy(x, y);
                try set.put(p, x + (y * width));
                if (x > 0) {
                    try edgeList.append(.{ xy(x - 1, y), xy(x, y) });
                }
                if (y > 0) {
                    try edgeList.append(.{ xy(x, y - 1), xy(x, y) });
                }
            }
        }
        return .{
            .edges = edgeList,
            .good_edges = AL([2]Point).init(alloc),
            .set = set,
            .alloc = alloc,
            .rng = rng,
            .dimensions = lib.rect(width, height),
        };
    }

    pub fn gen(
        width: usize,
        height: usize,
        alloc: std.mem.Allocator,
        rng: std.Random,
    ) !Maze {
        var self = try Self.init(width, height, alloc, rng);
        defer self.deinit();
        while (try self.next()) |_| {}
        return try self.to_maze();
    }

    pub fn deinit(self: *Self) void {
        self.edges.deinit();
        self.set.deinit();
        self.good_edges.deinit();
    }

    pub fn next(self: *Self) !?[2]Point {
        const e = while (true) {
            if (self.edges.items.len < 1) return null;
            const i = self.rng.int(usize) % self.edges.items.len;
            const e = self.edges.swapRemove(i);
            const p1 = self.set.get(e[0]).?;
            const p2 = self.set.get(e[1]).?;
            if (p1 != p2) break e;
        };

        try self.good_edges.append(e);
        const a = self.set.get(e[0]).?;
        const b = self.set.get(e[1]).?;

        var set_iter = self.set.iterator();
        while (set_iter.next()) |entry| {
            if (entry.value_ptr.* == b) {
                entry.value_ptr.* = a;
            }
        }

        return e;
    }

    pub fn to_maze(self: Self) !Maze {
        const w = self.dimensions.w * 2 - 1;
        const h = self.dimensions.h * 2 - 1;
        var cellList = try AL([]Tile).initCapacity(
            self.alloc,
            h,
        );
        for (0..h) |y| {
            var row = try AL(Tile).initCapacity(
                self.alloc,
                w,
            );

            for (0..w) |x| {
                try row.append(if (x | y & 1 == 0) .Hall else .Wall);
            }

            try cellList.append(try row.toOwnedSlice());
        }
        var cells = try cellList.toOwnedSlice();

        for (self.good_edges.items) |e| {
            const p1 = to_maze_point(e[0]);
            const p2 = to_maze_point(e[1]);
            const pm = mid(p1, p2);

            cells[pm.y][pm.x] = .Hall;
        }

        return .{
            .cells = cells,
            .alloc = self.alloc,
        };
    }
};

fn to_maze_point(p: Point) Point {
    const x = if (p.x == 0) 0 else p.x * 2;
    const y = if (p.y == 0) 0 else p.y * 2;
    return xy(x, y);
}

fn is_adjacent(a: Point, b: Point) bool {
    const x = if (a.x < b.x)
        b.x - a.x == 1
    else
        a.x - b.x == 1;
    const y = if (a.y < b.y) b.y - a.y == 1 else a.y - b.y == 1;
    return x and y;
}

// TEST

const test_rng = std.crypto.random;

test "init dfs" {
    const alloc = std.testing.allocator;

    const dfs = try Dfs.init(5, 5, alloc, test_rng);
    defer dfs.deinit();

    try std.testing.expectEqual(dfs.buffer.len, 9);
    try std.testing.expectEqual(dfs.buffer[0].len, 9);
}

test "initial possible moves" {
    const alloc = std.testing.allocator;

    const dfs = try Dfs.init(5, 5, alloc, test_rng);
    defer dfs.deinit();

    const moves = try dfs.adjacent_cells(xy(0, 0));
    defer dfs.alloc.free(moves);

    try std.testing.expectEqual(moves.len, 2);
}

test "kruskal" {
    var k = try Kruskal.init(5, 5, std.testing.allocator, test_rng);
    k.deinit();
}
