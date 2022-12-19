const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const AutoHashMap = std.AutoHashMap;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

pub fn main() !void {
    const cmd = try aoc.parseCmdLine();
    var allocator = std.heap.page_allocator;
    const result: u64 = switch (cmd.part) {
        1 => try solvePart1(cmd.filename, allocator),
        2 => try solvePart2(cmd.filename, allocator),
        else => {
            print("Missing day part\n", .{});
            return;
        },
    };
    print("Result: {d}\n", .{result});
}

const Element = enum { Air, Sand, Rock };

const Map = struct {
    allocator: mem.Allocator,
    data: AutoHashMap(Point, Element),

    min_x: usize,
    max_x: usize,
    min_y: usize,
    max_y: usize,

    fn init(allocator: mem.Allocator) Map {
        return .{
            .allocator = allocator,
            .data = AutoHashMap(Point, Element).init(allocator),
            .min_x = 500,
            .max_x = 500,
            .min_y = 0,
            .max_y = 0,
        };
    }

    fn deinit(self: *Map) void {
        self.data.deinit();
    }

    fn dropSand(self: *Map) !bool {
        var sand: Point = .{ .x = 500, .y = 0 };

        while (true) {
            if (sand.y > self.max_y) break;

            if (self.data.get(.{ .x = sand.x, .y = sand.y + 1 }) == null) {
                sand.y += 1;
                continue;
            } else if (self.data.get(.{ .x = sand.x - 1, .y = sand.y + 1 }) == null) {
                sand.x -= 1;
                sand.y += 1;
                continue;
            } else if (self.data.get(.{ .x = sand.x + 1, .y = sand.y + 1 }) == null) {
                sand.x += 1;
                sand.y += 1;
                continue;
            } else {
                try self.data.put(sand, .Sand);
                return if ((sand.x != 500) or (sand.y != 0)) true else false;
            }
        }

        return false;
    }

    fn addSegment(self: *Map, segment: Segment) !void {
        var min_x = @min(segment.a.x, segment.b.x);
        var max_x = @max(segment.a.x, segment.b.x);
        var min_y = @min(segment.a.y, segment.b.y);
        var max_y = @max(segment.a.y, segment.b.y);

        self.min_x = @min(self.min_x, min_x);
        self.max_x = @max(self.max_x, max_x);
        self.min_y = @min(self.min_y, min_y);
        self.max_y = @max(self.max_y, max_y);

        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var x = min_x;
            while (x <= max_x) : (x += 1) try self.data.put(.{ .x = x, .y = y }, .Rock);
        }
    }

    fn show(self: *Map) void {
        print("Map: min_x:{d} max_x:{d} min_y:{d} max_y:{d}\n", .{
            self.min_x,
            self.max_x,
            self.min_y,
            self.max_y,
        });

        var y: usize = 0;
        while (y <= self.max_y) : (y += 1) {
            var x = self.min_x;
            while (x <= self.max_x) : (x += 1) {
                var el = self.data.get(.{ .x = x, .y = y });

                if (el) |e| {
                    switch (e) {
                        .Air => print(".", .{}),
                        .Rock => print("#", .{}),
                        .Sand => print("o", .{}),
                    }
                } else {
                    print(".", .{});
                }
            }
            print("\n", .{});
        }
    }
};

const Point = struct { x: usize, y: usize };

const Segment = struct { a: Point, b: Point };

fn parseInput(filename: []const u8, allocator: mem.Allocator) !Map {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var map = Map.init(allocator);
    var last_point: ?Point = null;

    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var segments = mem.split(u8, line, " -> ");
        last_point = null;
        while (segments.next()) |segment| {
            var coords = mem.split(u8, segment, ",");
            var x = try fmt.parseInt(usize, coords.next() orelse unreachable, 10);
            var y = try fmt.parseInt(usize, coords.next() orelse unreachable, 10);
            var point: Point = .{ .x = x, .y = y };
            if (last_point) |lp| {
                try map.addSegment(.{ .a = lp, .b = point });
            }
            last_point = point;
        }
    }

    return map;
}

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try parseInput(filename, allocator);
    defer map.deinit();

    var i: u64 = 0;
    while (try map.dropSand()) i += 1;

    return i;
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try parseInput(filename, allocator);
    defer map.deinit();

    try map.addSegment(.{
        .a = .{ .x = map.max_x - 300, .y = map.max_y + 2 },
        .b = .{ .x = map.max_x + 300, .y = map.max_y + 2 },
    });

    var i: u64 = 0;
    while (try map.dropSand()) i += 1;

    return i + 1;
}

test "part_1_test" {
    const filename = "data/input-test-14";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 24), result);
}

test "part_1" {
    const filename = "data/input-14";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 888), result);
}

test "part_2_test" {
    const filename = "data/input-test-14";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 93), result);
}

test "part_2" {
    const filename = "data/input-14";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 26461), result);
}
