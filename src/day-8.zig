const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const maxLines = 100;
const maxCols = 100;

const Direction = enum { Left, Right, Up, Down };
const all_directions: [4]Direction = .{
    .Up, .Down, .Left, .Right,
};

const Iterator = struct {
    forest: *Forest,
    line: usize,
    col: usize,
    direction: Direction,

    fn init(forest: *Forest, line: usize, col: usize, direction: Direction) Iterator {
        return .{
            .forest = forest,
            .line = line,
            .col = col,
            .direction = direction,
        };
    }

    fn next(self: *Iterator) ?usize {
        if ((self.line == 0) or (self.col == 0)) return null;
        if (self.line == (self.forest.lines - 1)) return null;
        if (self.col == (self.forest.cols - 1)) return null;
        switch (self.direction) {
            .Left => self.col -= 1,
            .Right => self.col += 1,
            .Up => self.line -= 1,
            .Down => self.line += 1,
        }

        return self.forest.map[self.line][self.col];
    }
};

const Forest = struct {
    map: [maxLines][maxCols]u8,
    visible_map: [maxLines][maxCols]bool,
    cols: u8,
    lines: u8,

    fn init() Forest {
        return .{
            .cols = 0,
            .lines = 0,
            .map = .{.{0} ** maxCols} ** maxLines,
            .visible_map = .{.{false} ** maxCols} ** maxLines,
        };
    }

    fn addLine(self: *Forest, line: []u8) !void {
        var maxCol: u8 = 0;
        for (line) |c, i| {
            self.map[self.lines][i] = try fmt.parseInt(u8, &[1]u8{c}, 10);
            maxCol += 1;
        }

        if (self.cols == 0) self.cols = maxCol;
        self.lines += 1;
    }

    fn isVisible(self: *Forest, line: usize, col: usize) bool {
        const height = self.map[line][col];
        for (all_directions) |direction| {
            var iterator = Iterator.init(self, line, col, direction);
            const clear_sight = blk: {
                while (iterator.next()) |value| {
                    if (value >= height) break :blk false;
                }
                break :blk true;
            };
            if (clear_sight) return true;
        }

        return false;
    }

    fn visible_trees(self: *Forest) !u64 {
        var l: usize = 0;
        var c: usize = 0;
        var total: usize = 0;
        while (l < self.lines) : (l += 1) {
            c = 0;
            while (c < self.cols) : (c += 1) {
                if (self.isVisible(l, c)) {
                    total += 1;
                    self.visible_map[l][c] = true;
                }
            }
        }

        return total;
    }

    fn scenicScore(self: *Forest, line: usize, col: usize) u64 {
        const height = self.map[line][col];
        var score: u64 = 1;
        for (all_directions) |direction| {
            var iterator = Iterator.init(self, line, col, direction);
            var distance: u8 = 0;
            while (iterator.next()) |value| {
                distance += 1;
                if (value >= height) break;
            }
            if (distance == 0) distance = 1;
            score *= distance;
        }

        return score;
    }

    fn bestScenicScore(self: *Forest) u64 {
        var l: usize = 0;
        var c: usize = 0;
        var best: u64 = 0;
        while (l < self.lines) : (l += 1) {
            c = 0;
            while (c < self.cols) : (c += 1) {
                best = @max(best, self.scenicScore(l, c));
            }
        }
        return best;
    }

    fn print(self: *Forest) void {
        std.debug.print("Max lines:{d} Max cols:{d}\n", .{ self.lines, self.cols });
        var l: usize = 0;
        var c: usize = 0;
        var max_lines = @min(self.lines, 50);
        var max_cols = @min(self.cols, 50);
        while (l < max_lines) : (l += 1) {
            c = 0;
            while (c < max_cols) : (c += 1) {
                const v = self.visible_map[l][c];
                if (v) {
                    std.debug.print(" {d} ", .{self.map[l][c]});
                } else {
                    std.debug.print("[{d}]", .{self.map[l][c]});
                }
            }
            std.debug.print("\n", .{});
        }
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

fn parseInput(filename: []const u8) !Forest {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var forest = Forest.init();

    var buf: [maxCols]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try forest.addLine(line);
    }

    return forest;
}

fn solvePart1(filename: []const u8) !u64 {
    var forest = try parseInput(filename);
    return try forest.visible_trees();
}

fn solvePart2(filename: []const u8) !u64 {
    var forest = try parseInput(filename);
    return forest.bestScenicScore();
}

test "part_1_test" {
    const filename = "data/input-test-8";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 21), result);
}

test "part_1" {
    const filename = "data/input-8";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 1832), result);
}

test "part_2_test" {
    const filename = "data/input-test-8";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 8), result);
}

test "part_2" {
    const filename = "data/input-8";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 157320), result);
}
