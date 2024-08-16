const std = @import("std");

pub const Point = struct { x: usize, y: usize };
pub const Dimensions = struct { w: usize, h: usize };

pub fn xy(x: usize, y: usize) Point {
    return Point{ .x = x, .y = y };
}

pub fn mid(a: Point, b: Point) Point {
    return .{
        .x = (a.x + b.x) / 2,
        .y = (a.y + b.y) / 2,
    };
}
