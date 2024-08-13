const std = @import("std");

const Dfs = struct {
    const Self = @This();

    buffer: [][]CellState,
    alloc: std.mem.Allocator,
    dimensions: Dimensions,
    stack: std.ArrayList(StackItem),
    rng: std.Random,

    fn init(width: usize, height: usize, alloc: std.mem.Allocator, rng: std.Random) !Self {
        const CSAL = std.ArrayList(CellState);

        const true_width = width * 2 - 1;
        const true_height = height * 2 - 1;

        var tbl = std.ArrayList([]CellState).init(alloc);

        for (0..true_height) |_| {
            var row = CSAL.init(alloc);
            try row.appendNTimes(.none, true_width);

            const s = try row.toOwnedSlice();
            try tbl.append(s);
        }

        var buf = try tbl.toOwnedSlice();
        buf[0][0] = .explore;

        var stack = std.ArrayList(StackItem).init(alloc);
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

    fn deinit(self: Self) void {
        for (self.buffer) |x| {
            self.alloc.free(x);
        }
        self.alloc.free(self.buffer);

        self.stack.deinit();
    }

    fn adjacent_cells(self: Self, p: Point) ![]Point {
        var lst = try std.ArrayList(Point).initCapacity(self.alloc, 4);

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

    fn get_cell(self: Self, p: Point) CellState {
        return self.buffer[p.y][p.x];
    }

    fn set_cell(self: *Self, p: Point, c: CellState) void {
        self.buffer[p.y][p.x] = c;
    }

    /// returns the updates to each cell
    fn next(self: *Self) !?struct { p: Point, c: CellState } {
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

    fn print(self: Self) !void {
        const stdout = std.io.getStdOut().writer();

        var lines = std.ArrayList([]u8).init(self.alloc);
        defer lines.deinit();

        for (self.buffer) |row| {
            var line = std.ArrayList(u8).init(self.alloc);

            for (row, 0..) |cell, x| {
                const repeat = ((x + 1) & 1) + 1;
                for (0..repeat) |_| {
                    try line.appendSlice(switch (cell) {
                        .done => " ",
                        .none => "#",
                        .explore => "+",
                    });
                }
            }

            try lines.append(try line.toOwnedSlice());
        }

        const line_len = lines.items[0].len;

        for (0..line_len + 2) |_| {
            try stdout.print("#", .{});
        }
        try stdout.print("\n", .{});

        for (lines.items) |row| {
            try stdout.print("#{s}#\n", .{row});
        }

        for (0..line_len + 2) |_| {
            try stdout.print("#", .{});
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
};

const Dimensions = struct { w: usize, h: usize };
const Point = struct { x: usize, y: usize };
const CellState = enum { done, none, explore };
const StackItem = struct { p: Point, last: Point };

fn xy(x: usize, y: usize) Point {
    return Point{ .x = x, .y = y };
}

fn mid(a: Point, b: Point) Point {
    return .{
        .x = (a.x + b.x) / 2,
        .y = (a.y + b.y) / 2,
    };
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

test "print" {
    var dfs = try Dfs.init(5, 5, std.testing.allocator, test_rng);
    defer dfs.deinit();

    while (try dfs.next()) |_| {}

    try dfs.print();
}
