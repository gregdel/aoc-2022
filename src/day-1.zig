const std = @import("std");
const print = std.debug.print;
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

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

pub fn solvePart1(filename: ([:0]const u8)) anyerror!u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var max: u64 = 0;
    var current_sum: u32 = 0;

    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            if (current_sum > max) {
                max = current_sum;
            }

            current_sum = 0;
            continue;
        }

        var value = try fmt.parseInt(u32, line, 10);
        current_sum += value;
    }

    return max;
}

pub fn solvePart2(filename: ([:0]const u8)) anyerror!u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var max = [_]u32{ 0, 0, 0, 0 };
    var current_sum: u32 = 0;

    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            max[max.len - 1] = current_sum;
            sort.sort(u32, max[0..], {}, comptime sort.desc(u32));
            max[max.len - 1] = 0;

            current_sum = 0;
            continue;
        }

        var value = try fmt.parseInt(u32, line, 10);
        current_sum += value;
    }

    max[max.len - 1] = current_sum;
    sort.sort(u32, max[0..], {}, comptime sort.desc(u32));

    return max[0] + max[1] + max[2];
}

test "part_1_test" {
    const filename = "data/input-test-1";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(result, 24000);
}

test "part_1" {
    const filename = "data/input-1";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(result, 68923);
}

test "part_2_test" {
    const filename = "data/input-test-1";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(result, 45000);
}

test "part_2" {
    const filename = "data/input-1";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(result, 200044);
}
