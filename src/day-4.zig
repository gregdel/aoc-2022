const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const PuzzleError = error{ParseError};

const Operation = enum {
    Contains,
    Overlaps,
};

const Range = struct {
    min: u8,
    max: u8,

    const Self = @This();

    fn init(self: *Self, data: *[2]u8) void {
        self.min = data[0];
        self.max = data[1];
    }

    fn contains(self: Self, other: Range) bool {
        if ((other.min >= self.min) and (other.max <= self.max)) return true;
        return false;
    }

    fn overlaps(self: Self, other: Range) bool {
        if (((other.min >= self.min) and (other.min <= self.max)) or
            ((other.max >= self.min) and (other.max <= self.max))) return true;
        return false;
    }
};

pub fn main() !void {
    const cmd = try aoc.parseCmdLine();
    const result: u64 = switch (cmd.part) {
        1 => try solve(cmd.filename, Operation.Contains),
        2 => try solve(cmd.filename, Operation.Overlaps),
        else => {
            print("Missing day part\n", .{});
            return;
        },
    };
    print("Result: {d}\n", .{result});
}

fn parseLine(line: []u8) ![2]Range {
    const delim = [_]u8{ '-', ',' };
    var iterator = mem.tokenize(u8, line, delim[0..]);
    var values: [4]u8 = undefined;
    var ranges: [2]Range = undefined;

    var i: usize = 0;
    while (iterator.next()) |item| {
        if (i > 3) {
            return PuzzleError.ParseError;
        }

        values[i] = try fmt.parseInt(u8, item, 10);
        i += 1;
    }

    ranges[0].init(values[0..2]);
    ranges[1].init(values[2..]);
    return ranges;
}

fn solve(filename: ([:0]const u8), op: Operation) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var result: u64 = 0;
    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var ranges = try parseLine(line);

        switch (op) {
            Operation.Contains => {
                if (ranges[0].contains(ranges[1]) or ranges[1].contains(ranges[0])) {
                    result += 1;
                }
            },
            Operation.Overlaps => {
                if (ranges[0].overlaps(ranges[1]) or ranges[1].overlaps(ranges[0])) {
                    result += 1;
                }
            },
        }
    }

    return result;
}

test "part_1_test" {
    const filename = "data/input-test-4";
    const result: u64 = try solve(filename, Operation.Contains);
    try testing.expectEqual(result, 2);
}

test "part_1" {
    const filename = "data/input-4";
    const result: u64 = try solve(filename, Operation.Contains);
    try testing.expectEqual(result, 511);
}

test "part_2_test" {
    const filename = "data/input-test-4";
    const result: u64 = try solve(filename, Operation.Overlaps);
    try testing.expectEqual(result, 4);
}

test "part_2" {
    const filename = "data/input-4";
    const result: u64 = try solve(filename, Operation.Overlaps);
    try testing.expectEqual(result, 821);
}
