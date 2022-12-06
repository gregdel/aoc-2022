const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
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

fn isMarker(input: []u8, size: usize) bool {
    if (input.len != size) return false;

    var i: usize = 0;
    while (i < (size - 1)) : (i += 1) {
        var j: usize = i + 1;
        while (j < size) : (j += 1) {
            if (input[i] == input[j]) return false;
        }
    }

    return true;
}

fn solve(filename: ([:0]const u8), marker_size: usize) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    var size = try file.readAll(&buf);

    var start: usize = 0;
    while (start < size - 4) : (start += 1) {
        if (isMarker(buf[start .. start + marker_size], marker_size)) return start + marker_size;
    }

    return 0;
}

fn solvePart1(filename: ([:0]const u8)) !u64 {
    return solve(filename, 4);
}

fn solvePart2(filename: ([:0]const u8)) !u64 {
    return solve(filename, 14);
}

test "part_1_test" {
    const filename = "data/input-test-6";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 7), result);
}

test "part_1" {
    const filename = "data/input-6";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 1356), result);
}

test "part_2_test" {
    const filename = "data/input-test-6";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 19), result);
}

test "part_2" {
    const filename = "data/input-6";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 2564), result);
}
