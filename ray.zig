const std = @import("std");
const ray = @cImport(@cInclude("raylib.h"));
const dfs_gen = @import("gen.zig");

const PADDING: c_int = 0;
const SQ_SIZE: c_int = 37;

pub fn main() !void {
    var dfs = try dfs_gen.Dfs.init(15, 7, std.heap.c_allocator, std.crypto.random);
    defer dfs.deinit();

    while (try dfs.next()) |_| {}

    const mazeW = @as(c_int, @intCast(dfs.buffer[0].len)) * SQ_SIZE;
    const mazeH = @as(c_int, @intCast(dfs.buffer.len)) * SQ_SIZE;

    const screenW = mazeW + (SQ_SIZE + PADDING) * 2;
    const screenH = mazeH + (SQ_SIZE + PADDING) * 2;

    ray.InitWindow(screenW, screenH, "mooze");
    defer ray.CloseWindow();

    ray.SetConfigFlags(ray.FLAG_WINDOW_UNDECORATED);

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.GREEN);

        var pos = ray.Vector2{ .x = PADDING + SQ_SIZE, .y = PADDING + SQ_SIZE };

        for (dfs.buffer) |row| {
            for (row) |cell| {
                const color = switch (cell) {
                    .none => ray.GREEN,
                    .done => ray.BLACK,
                    .explore => ray.ORANGE,
                };
                ray.DrawRectangleV(pos, .{ .x = SQ_SIZE, .y = SQ_SIZE }, color);
                pos.x += SQ_SIZE;
            }
            pos.x = PADDING + SQ_SIZE;
            pos.y += SQ_SIZE;
        }
    }
}
