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

const Shape = enum { Line, Cross, L, Column, Square };

const Block = struct {
    elements: u8,
    points: [5]Point,

    fn init(shape: Shape, y: i32) Block {
        return switch (shape) {
            .Line => .{
                .elements = 4,
                .points = .{
                    .{ .x = 2, .y = y },
                    .{ .x = 3, .y = y },
                    .{ .x = 4, .y = y },
                    .{ .x = 5, .y = y },
                    .{ .x = 0, .y = 0 },
                },
            },
            .Cross => .{
                .elements = 5,
                .points = .{
                    .{ .x = 3, .y = y },
                    .{ .x = 2, .y = y + 1 },
                    .{ .x = 3, .y = y + 1 },
                    .{ .x = 4, .y = y + 1 },
                    .{ .x = 3, .y = y + 2 },
                },
            },
            .L => .{
                .elements = 5,
                .points = .{
                    .{ .x = 2, .y = y },
                    .{ .x = 3, .y = y },
                    .{ .x = 4, .y = y },
                    .{ .x = 4, .y = y + 1 },
                    .{ .x = 4, .y = y + 2 },
                },
            },
            .Column => .{
                .elements = 4,
                .points = .{
                    .{ .x = 2, .y = y },
                    .{ .x = 2, .y = y + 1 },
                    .{ .x = 2, .y = y + 2 },
                    .{ .x = 2, .y = y + 3 },
                    .{ .x = 0, .y = 0 },
                },
            },
            .Square => .{
                .elements = 4,
                .points = .{
                    .{ .x = 2, .y = y },
                    .{ .x = 3, .y = y },
                    .{ .x = 2, .y = y + 1 },
                    .{ .x = 3, .y = y + 1 },
                    .{ .x = 0, .y = 0 },
                },
            },
        };
    }

    fn move(self: *Block, map: *Map, m: Move) bool {
        var can_move = true;
        var new_points: [5]Point = undefined;

        var i: usize = 0;
        while (i < self.elements) : (i += 1) {
            new_points[i] = self.points[i].translate(m);
            if (new_points[i].x < 0 or new_points[i].x > 6) {
                can_move = false;
                break;
            }
            if (new_points[i].y == 0) {
                can_move = false;
                break;
            }
            if (map.points.get(new_points[i]) != null) {
                can_move = false;
                break;
            }
        }

        if (!can_move) return can_move;

        i = 0;
        while (i < self.elements) : (i += 1) self.points[i] = new_points[i];

        return true;
    }

    fn save(self: *Block, map: *Map) !void {
        var i: usize = 0;
        while (i < self.elements) : (i += 1) {
            map.max_y = @max(map.max_y, self.points[i].y + 1);
            try map.points.put(self.points[i], {});
        }
    }
};

const Point = struct {
    x: i32,
    y: i32,

    fn translate(self: *Point, m: Move) Point {
        return switch (m) {
            .Right => Point{ .x = self.x + 1, .y = self.y },
            .Left => Point{ .x = self.x - 1, .y = self.y },
            .Down => Point{ .x = self.x, .y = self.y - 1 },
            .Stop => Point{ .x = self.x, .y = self.y },
        };
    }
};

const Move = enum { Right, Left, Down, Stop };

const Stream = struct {
    buf: [20000]u8,
    size: usize,
    idx: usize,

    fn init(filename: []const u8) !Stream {
        var file = try fs.cwd().openFile(filename, .{});
        defer file.close();
        var stream: Stream = .{
            .buf = undefined,
            .size = 0,
            .idx = 0,
        };

        stream.size = try file.readAll(&stream.buf);
        stream.size -= 1; // Remove the \n
        return stream;
    }

    fn needsReset(self: *Stream) bool {
        return if (self.idx >= self.size) true else false;
    }

    fn next(self: *Stream) !?Move {
        var move: Move = switch (self.buf[self.idx]) {
            '>' => .Right,
            '<' => .Left,
            else => .Stop,
        };
        self.idx += 1;
        if (self.idx >= self.size) self.idx = 0;
        if (move == .Stop) return null;
        return move;
    }
};

const Map = struct {
    allocator: mem.Allocator,
    points: AutoHashMap(Point, void),
    max_y: i32,
    stream: Stream,
    pattern_idx: usize,
    pattern_rounds: u64,
    pattern_increase: u64,
    skipped: u64,

    fn init(allocator: mem.Allocator, filename: []const u8) !Map {
        return .{
            .max_y = 1,
            .pattern_idx = 0,
            .pattern_rounds = 0,
            .pattern_increase = 0,
            .skipped = 0,
            .allocator = allocator,
            .points = AutoHashMap(Point, void).init(allocator),
            .stream = try Stream.init(filename),
        };
    }

    fn run(self: *Map, rounds: u64) !void {
        var max_rounds: u64 = rounds;
        var i: usize = 0;
        var searching_pattern = false;
        while (i < max_rounds) : (i += 1) {
            const shape = @intToEnum(Shape, i % 5);
            var block = Block.init(shape, self.max_y + 3);

            if ((i % 5 == 0) and (i > self.stream.size)) {
                if (self.pattern_idx == 0) {
                    self.pattern_idx = self.stream.idx;
                    self.pattern_rounds = i;
                    self.pattern_increase = @intCast(u64, self.max_y);
                    searching_pattern = true;
                } else {
                    if (self.stream.idx == self.pattern_idx) {
                        if (searching_pattern) {
                            self.pattern_rounds = i - self.pattern_rounds;
                            self.pattern_increase =
                                @intCast(u64, self.max_y) - self.pattern_increase;
                            searching_pattern = false;

                            var remaining_rounds = rounds - i;
                            self.skipped = remaining_rounds / self.pattern_rounds;
                            var left = remaining_rounds % self.pattern_rounds;
                            max_rounds = i + left;
                        }
                    }
                }
            }

            while (true) {
                const move = try self.stream.next() orelse break;
                _ = block.move(self, move);
                const can_go_down = block.move(self, Move.Down);
                if (!can_go_down) {
                    try block.save(self);
                    break;
                }
            }
        }
    }

    fn result(self: *Map) u64 {
        var max: u64 = @intCast(u64, self.max_y);
        max += self.skipped * self.pattern_increase;
        return max - 1;
    }

    fn show(self: *Map) void {
        var y: i32 = self.max_y + 5;
        while (y > 0) : (y -= 1) {
            var x: i32 = 0;
            print("|", .{});
            while (x < 7) : (x += 1) {
                var p = Point{ .x = x, .y = y };
                var c: u8 = if (self.points.get(p) != null) '#' else '.';
                print("{c}", .{c});
            }
            print("|\n", .{});
        }
        print("+-------+\n", .{});
    }

    fn deinit(self: *Map) void {
        self.points.deinit();
    }
};

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try Map.init(allocator, filename);
    defer map.deinit();

    try map.run(2022);
    return map.result();
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try Map.init(allocator, filename);
    defer map.deinit();

    try map.run(1000000000000);
    return map.result();
}

test "part_1_test" {
    const filename = "data/input-test-17";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 3068), result);
}

test "part_1" {
    const filename = "data/input-17";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 3085), result);
}

test "part_2_test" {
    const filename = "data/input-test-17";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 1514285714288), result);
}

test "part_2" {
    const filename = "data/input-17";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 1535483870924), result);
}
