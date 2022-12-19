const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
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

fn abs(a: i32) i32 {
    if (a > 0) return a;
    return a * -1;
}

const Sensor = struct {
    point: Point,
    beacon: Point,
    range: i32,
};

const Point = struct {
    x: i32,
    y: i32,

    fn distance(self: Point, point: Point) i32 {
        return abs(self.x - point.x) + abs(self.y - point.y);
    }
};

const Segment = struct {
    y: i32,
    start: i32,
    end: i32,

    fn members(self: Segment) u64 {
        return @intCast(u64, abs(self.start - self.end) + 1);
    }

    fn contains(self: Segment, point: Point) bool {
        if (point.y != self.y) return false;
        return ((point.x >= self.start) and (point.x <= self.end));
    }

    fn lessThan(_: void, a: Segment, b: Segment) bool {
        return (a.start < b.start);
    }
};

const Map = struct {
    allocator: mem.Allocator,
    sensors: ArrayList(Sensor),

    fn init(allocator: mem.Allocator) Map {
        return .{
            .allocator = allocator,
            .sensors = ArrayList(Sensor).init(allocator),
        };
    }

    fn addSensor(self: *Map, sensor: Point, beacon: Point) !void {
        var range: i32 = sensor.distance(beacon);
        try self.sensors.append(.{ .point = sensor, .beacon = beacon, .range = range });
    }

    fn covered_segments(self: *Map, y: i32) !ArrayList(Segment) {
        var segments = ArrayList(Segment).init(self.allocator);

        for (self.sensors.items) |sensor| {
            var vertical_distance = abs(sensor.point.y - y);
            if (vertical_distance > sensor.range) continue;
            var x_range = sensor.range - vertical_distance;
            try segments.append(.{
                .y = y,
                .start = sensor.point.x - x_range,
                .end = sensor.point.x + x_range,
            });
        }

        std.sort.sort(Segment, segments.items, {}, Segment.lessThan);

        var i: usize = 1;
        while (i < segments.items.len) : (i += 1) {
            var previous = &segments.items[i - 1];
            var segment = &segments.items[i];

            if ((segment.start >= previous.start) and (segment.start <= previous.end + 1)) {
                previous.end = @max(segment.end, previous.end);
                _ = segments.orderedRemove(i);
                i -= 1;
            }
        }

        return segments;
    }

    fn intersect(self: *Map, y: i32) !u64 {
        var segments = try self.covered_segments(y);
        defer segments.deinit();

        var result: u64 = 0;
        var objects = AutoHashMap(Point, bool).init(self.allocator);
        defer objects.deinit();
        for (segments.items) |segment| {
            var count: u64 = segment.members();
            for (self.sensors.items) |sensor| {
                if (segment.contains(sensor.point)) try objects.put(sensor.point, true);
                if (segment.contains(sensor.beacon)) try objects.put(sensor.beacon, true);
            }
            result += count;
        }

        return result - objects.count();
    }

    fn searchBeacon(self: *Map, max: i32) !u64 {
        var y: i32 = max;
        while (y >= 0) : (y -= 1) {
            var segments = try self.covered_segments(y);
            if (segments.items.len == 1) {
                segments.deinit();
                continue;
            }

            var x: u64 = @intCast(u64, segments.items[0].end) + 1;
            segments.deinit();
            return x * 4000000 + @intCast(u64, y);
        }

        return 0;
    }

    fn deinit(self: *Map) void {
        self.sensors.deinit();
    }
};

fn parseInput(filename: []const u8, allocator: mem.Allocator) !Map {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var map = Map.init(allocator);

    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var parts = mem.split(u8, line[12..], ": closest beacon is at x=");
        var sensor: ?Point = null;
        var i: usize = 0;
        while (parts.next()) |part| {
            var coords = mem.split(u8, part, ", y=");
            var point: Point = .{
                .x = try fmt.parseInt(i32, coords.next() orelse unreachable, 10),
                .y = try fmt.parseInt(i32, coords.next() orelse unreachable, 10),
            };
            if (i % 2 == 0) {
                sensor = point;
            } else {
                try map.addSensor(sensor.?, point);
            }
            i += 1;
        }
    }

    return map;
}

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try parseInput(filename, allocator);
    defer map.deinit();
    var y: i32 = if (map.sensors.items.len == 14) 10 else 2000000;
    return map.intersect(y);
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try parseInput(filename, allocator);
    defer map.deinit();
    var max: i32 = if (map.sensors.items.len == 14) 20 else 4000000;
    return map.searchBeacon(max);
}

test "part_1_test" {
    const filename = "data/input-test-15";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 26), result);
}

test "part_1" {
    const filename = "data/input-15";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 5832528), result);
}

test "part_2_test" {
    const filename = "data/input-test-15";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 56000011), result);
}

test "part_2" {
    const filename = "data/input-15";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 13360899249595), result);
}
