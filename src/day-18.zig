const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const ParseError = error{InvalidNumber};

var current_cluster_id: u64 = 0;

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

const Side = enum { Up, Down, Back, Front, Right, Left };

const CubeHash = AutoHashMap(Point, *Cube);

const Cube = struct {
    x: i16,
    y: i16,
    z: i16,

    explored: bool,
    allocator: mem.Allocator,
    cluster_id: u64,
    connected_sides: [@typeInfo(Side).Enum.fields.len]?*Cube,

    fn init(allocator: mem.Allocator, x: i16, y: i16, z: i16) !*Cube {
        var cube = try allocator.create(Cube);
        cube.* = .{
            .x = x,
            .y = y,
            .z = z,
            .explored = false,
            .allocator = allocator,
            .cluster_id = 0,
            .connected_sides = undefined,
        };
        for (cube.connected_sides) |_, i| cube.connected_sides[i] = null;
        return cube;
    }

    fn deinit(self: *Cube) void {
        self.allocator.destroy(self);
    }

    fn point(self: *Cube) Point {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }

    fn freeSides(self: *Cube) u8 {
        var free: u8 = 0;
        for (self.connected_sides) |other| {
            if (other == null) free += 1;
        }

        return free;
    }

    fn show(self: *Cube) void {
        print("x:{d} y:{d} z:{d} cluster:{d} free:{d} explored:{?}\n", .{
            self.x,
            self.y,
            self.z,
            self.cluster_id,
            self.freeSides(),
            self.explored,
        });
    }

    const Iterator = struct {
        cube: *Cube,
        others: *CubeHash,
        current: u8,
        max: u8,

        const Entry = struct {
            other: *Cube,
            side: u8,
            other_side: u8,
        };

        fn init(cube: *Cube, others: *CubeHash) Iterator {
            return .{
                .cube = cube,
                .others = others,
                .current = 0,
                .max = cube.connected_sides.len,
            };
        }

        fn next(self: *Iterator) ?Entry {
            while (self.current < self.max) : (self.current += 1) {
                var side = @intToEnum(Side, self.current);

                var p: Point = switch (side) {
                    .Up => .{ .x = self.cube.x, .y = self.cube.y + 1, .z = self.cube.z },
                    .Down => .{ .x = self.cube.x, .y = self.cube.y - 1, .z = self.cube.z },
                    .Back => .{ .x = self.cube.x, .y = self.cube.y, .z = self.cube.z + 1 },
                    .Front => .{ .x = self.cube.x, .y = self.cube.y, .z = self.cube.z - 1 },
                    .Right => .{ .x = self.cube.x + 1, .y = self.cube.y, .z = self.cube.z },
                    .Left => .{ .x = self.cube.x - 1, .y = self.cube.y, .z = self.cube.z },
                };

                if (self.others.get(p)) |other| {
                    if (other.explored) continue;
                    var i = self.current;
                    var other_side_i = if ((i % 2) == 0) i + 1 else i - 1;
                    self.current += 1;
                    return .{
                        .other = other,
                        .side = i,
                        .other_side = other_side_i,
                    };
                }
            }
            return null;
        }
    };

    fn iterator(self: *Cube, others: *CubeHash) Iterator {
        return Iterator.init(self, others);
    }

    fn updateSides(self: *Cube, others: *CubeHash) void {
        if (self.explored) return;

        var it = self.iterator(others);
        while (it.next()) |entry| {
            if (self.cluster_id == 0) {
                current_cluster_id += 1;
                self.cluster_id = current_cluster_id;
            }

            self.connected_sides[entry.side] = entry.other;
            entry.other.connected_sides[entry.other_side] = self;
            entry.other.cluster_id = self.cluster_id;
            self.explored = true;
        }
    }
};

const Point = struct { x: i16, y: i16, z: i16 };

fn findCubeFreeSides(cubes: *ArrayList(*Cube)) !u64 {
    var result: u64 = 0;
    for (cubes.items) |cube| result += cube.freeSides();
    return result;
}

const Obsidian = struct {
    allocator: mem.Allocator,
    cubes: ArrayList(*Cube),
    used_space: CubeHash,
    min_x: i16,
    max_x: i16,
    min_y: i16,
    max_y: i16,
    min_z: i16,
    max_z: i16,

    fn init(allocator: mem.Allocator) Obsidian {
        return .{
            .allocator = allocator,
            .cubes = ArrayList(*Cube).init(allocator),
            .used_space = CubeHash.init(allocator),
            .min_x = std.math.maxInt(i16),
            .max_x = 0,
            .min_y = std.math.maxInt(i16),
            .max_y = 0,
            .min_z = std.math.maxInt(i16),
            .max_z = 0,
        };
    }

    fn deinit(self: *Obsidian) void {
        for (self.cubes.items) |c| c.deinit();
        self.used_space.deinit();
        self.cubes.deinit();
    }

    fn addCube(self: *Obsidian, x: i16, y: i16, z: i16) !void {
        self.max_x = @max(self.max_x, x);
        self.min_x = @min(self.min_x, x);
        self.max_y = @max(self.max_y, y);
        self.min_y = @min(self.min_y, y);
        self.max_z = @max(self.max_z, z);
        self.min_z = @min(self.min_z, z);
        var cube = try Cube.init(self.allocator, x, y, z);
        try self.used_space.put(cube.point(), cube);
        try self.cubes.append(cube);
    }

    fn findAllSides(self: *Obsidian) !u64 {
        for (self.cubes.items) |cube| cube.updateSides(&self.used_space);
        return try findCubeFreeSides(&self.cubes);
    }

    fn findInnerSides(self: *Obsidian) !u64 {
        // Compute the total number of air cubes
        var total_cubes: u32 =
            @intCast(u32, (self.max_x - self.min_x + 2)) *
            @intCast(u32, (self.max_y - self.min_y + 2)) *
            @intCast(u32, (self.max_z - self.min_z + 2));
        total_cubes -= @intCast(u32, self.cubes.items.len);

        var all_cubes = try ArrayList(*Cube).initCapacity(self.allocator, total_cubes);
        defer all_cubes.deinit();
        var free_space = CubeHash.init(self.allocator);
        defer free_space.deinit();
        try free_space.ensureTotalCapacity(total_cubes);

        // Add cubes that are not in the input
        var x: i16 = self.min_x - 1;
        while (x < self.max_x + 2) : (x += 1) {
            var y: i16 = self.min_y - 1;
            while (y < self.max_y + 2) : (y += 1) {
                var z: i16 = self.min_z - 1;
                while (z < self.max_z + 2) : (z += 1) {
                    var point: Point = .{ .x = x, .y = y, .z = z };
                    if (self.used_space.get(point) != null) continue;
                    var cube = try Cube.init(self.allocator, x, y, z);
                    try free_space.put(point, cube);
                    try all_cubes.append(cube);
                }
            }
        }

        var start_cube = free_space.get(Point{
            .x = self.min_x - 1,
            .y = self.min_y - 1,
            .z = self.min_z - 1,
        }) orelse return 0;

        var to_explore = ArrayList(*Cube).init(self.allocator);
        defer to_explore.deinit();
        try to_explore.append(start_cube);
        while (to_explore.popOrNull()) |cube| {
            _ = free_space.remove(cube.point());
            var it = cube.iterator(&free_space);
            while (it.next()) |entry| try to_explore.append(entry.other);
        }

        var internal_sides: u64 = 0;
        var remaining_cubes = free_space.valueIterator();
        while (remaining_cubes.next()) |c| {
            var cube = c.*;
            cube.updateSides(&free_space);
            internal_sides += cube.freeSides();
        }

        for (all_cubes.items) |cube| cube.deinit();

        return internal_sides;
    }
};

fn parseInput(filename: []const u8, allocator: mem.Allocator) !Obsidian {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var obsidian = Obsidian.init(allocator);

    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var parts = mem.split(u8, line, ",");
        try obsidian.addCube(
            try fmt.parseInt(u8, parts.next() orelse return ParseError.InvalidNumber, 10),
            try fmt.parseInt(u8, parts.next() orelse return ParseError.InvalidNumber, 10),
            try fmt.parseInt(u8, parts.next() orelse return ParseError.InvalidNumber, 10),
        );
    }

    return obsidian;
}

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !u64 {
    var obsidian = try parseInput(filename, allocator);
    defer obsidian.deinit();
    return try obsidian.findAllSides();
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !u64 {
    var obsidian = try parseInput(filename, allocator);
    defer obsidian.deinit();
    return try obsidian.findAllSides() - try obsidian.findInnerSides();
}

test "part_1_test" {
    const filename = "data/input-test-18";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 64), result);
}

test "part_1" {
    const filename = "data/input-18";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 3564), result);
}

test "part_2_test" {
    const filename = "data/input-test-18";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 58), result);
}

test "part_2" {
    const filename = "data/input-18";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 2106), result);
}
