const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const ParseError = error{InvalidDirection};

const Point = struct { x: i32, y: i32 };

fn abs(a: i32) i32 {
    if (a > 0) {
        return a;
    }
    return -1 * a;
}

fn sign(a: i32) i32 {
    if (a > 0) {
        return 1;
    }
    return -1;
}

const MovementVector = struct {
    i: i32,
    j: i32,

    fn init(x1: i32, y1: i32, x2: i32, y2: i32) MovementVector {
        var h = x1 - x2;
        var v = y1 - y2;

        if ((abs(h) == 2) and (v == 0)) return .{ .i = sign(h), .j = 0 };
        if ((abs(v) == 2) and (h == 0)) return .{ .i = 0, .j = sign(v) };
        if ((abs(h) + abs(v)) <= 2) return .{ .i = 0, .j = 0 };
        return .{ .i = sign(h), .j = sign(v) };
    }
};

const Knot = struct {
    x: i32 = 0,
    y: i32 = 0,
    display_char: u8,
    child: ?*Knot = null,

    fn init(self: *Knot, display_char: u8) void {
        self.x = 0;
        self.y = 0;
        self.child = null;
        self.display_char = display_char;
    }

    fn move(self: *Knot, vector: MovementVector) void {
        self.x += vector.i;
        self.y += vector.j;
        var child = if (self.child) |c| c else return;
        child.move(MovementVector.init(self.x, self.y, child.x, child.y));
    }
};

const Grid = struct {
    map: std.AutoHashMap(Point, bool),
    allocator: mem.Allocator,
    head: *Knot,
    tail: *Knot,

    fn init(allocator: mem.Allocator, knots: usize) !Grid {
        var head: *Knot = try allocator.create(Knot);
        head.init('#');
        var tail: *Knot = head;
        var i: u8 = 0;
        while (i < knots) : (i += 1) {
            var k: *Knot = try allocator.create(Knot);
            k.init(i + '0' + 1);
            tail.child = k;
            tail = k;
        }

        return .{
            .allocator = allocator,
            .map = std.AutoHashMap(Point, bool).init(allocator),
            .head = head,
            .tail = tail,
        };
    }

    fn deinit(self: *Grid) void {
        self.map.deinit();
        var prev: *Knot = self.head;
        while (true) {
            var child = prev.child;
            self.allocator.destroy(prev);
            if (child == null) break;
            prev = child.?;
        }
    }

    fn updateTailMap(self: *Grid) !void {
        try self.map.put(.{ .x = self.tail.x, .y = self.tail.y }, true);
    }

    fn print(self: *Grid, size: i32) void {
        var y: i32 = size;
        while (y > (-1 * size)) : (y -= 1) {
            var x: i32 = -1 * size;
            while (x < size) : (x += 1) {
                var char: u8 = '.';

                var knot: *Knot = self.head;
                var i: u8 = 0;
                while (true) : (i += 1) {
                    if ((knot.y == y) and (knot.x == x)) {
                        char = knot.display_char;
                        break;
                    }
                    if (knot.child) |k| knot = k else break;
                }
                std.debug.print("{c}", .{char});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("------------------------\n", .{});
    }
};

pub fn main() !void {
    const cmd = try aoc.parseCmdLine();
    const result: u64 = switch (cmd.part) {
        1 => try solvePart1(cmd.filename),
        2 => try solvePart2(cmd.filename),
        else => {
            print("Missing day part\n", .{});
            return;
        },
    };
    print("Result: {d}\n", .{result});
}

fn solve(filename: []const u8, knots: usize) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    const allocator = std.heap.page_allocator;
    var grid = try Grid.init(allocator, knots - 1);
    defer grid.deinit();

    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var vector: MovementVector = switch (line[0]) {
            'R' => MovementVector{ .i = 1, .j = 0 },
            'L' => MovementVector{ .i = -1, .j = 0 },
            'U' => MovementVector{ .i = 0, .j = 1 },
            'D' => MovementVector{ .i = 0, .j = -1 },
            else => return ParseError.InvalidDirection,
        };
        var count: u8 = try fmt.parseInt(u8, line[2..], 10);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            grid.head.move(vector);
            try grid.updateTailMap();
        }
    }

    return grid.map.count();
}

fn solvePart1(filename: []const u8) !u64 {
    return solve(filename, 2);
}

fn solvePart2(filename: []const u8) !u64 {
    return solve(filename, 10);
}

test "part_1_test" {
    const filename = "data/input-test-9";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 13), result);
}

test "part_1" {
    const filename = "data/input-9";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 6269), result);
}

test "part_2_test" {
    const filename = "data/input-test-9";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 1), result);
}

test "part_2_test_extra" {
    const filename = "data/input-test-9-extra";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 36), result);
}

test "part_2" {
    const filename = "data/input-9";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 2557), result);
}
