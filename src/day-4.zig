const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const PuzzleError = error{ParseError};

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

fn parseLine(line: []u8) ![4]u8 {
    const delim = [_]u8{ '-', ',' };
    var values: [4]u8 = undefined;
    var iterator = mem.tokenize(u8, line, delim[0..]);
    var i: usize = 0;
    while (iterator.next()) |item| {
        if (i > 3) {
            return PuzzleError.ParseError;
        }

        values[i] = try fmt.parseInt(u8, item, 10);
        i += 1;
    }

    return values;
}

fn solvePart1(filename: ([:0]const u8)) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var result: u64 = 0;
    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var values = try parseLine(line);

        var contained = (((values[0] <= values[2]) and (values[1] >= values[3])) or
            ((values[2] <= values[0]) and (values[3] >= values[1])));

        if (contained) result += 1;
    }

    return result;
}

fn solvePart2(filename: ([:0]const u8)) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var result: u64 = 0;
    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var values = try parseLine(line);

        var contained = (((values[0] >= values[2]) and (values[0] <= values[3])) or
            ((values[1] >= values[2]) and (values[1] <= values[3])) or
            ((values[2] >= values[0]) and (values[2] <= values[1])) or
            ((values[3] >= values[0]) and (values[3] <= values[1])));

        if (contained) result += 1;
    }

    return result;
}

test "part_1_test" {
    const filename = "data/input-test-4";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(result, 2);
}

test "part_1" {
    const filename = "data/input-4";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(result, 511);
}

test "part_2_test" {
    const filename = "data/input-test-4";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(result, 4);
}

test "part_2" {
    const filename = "data/input-4";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(result, 821);
}
