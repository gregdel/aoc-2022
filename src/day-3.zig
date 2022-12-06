const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const PuzzleError = error{ NotFound, InvalidSize };

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

fn itemValue(item: u8) u8 {
    return switch (item) {
        'A'...'Z' => item - 'A' + 27,
        'a'...'z' => item - 'a' + 1,
        else => 0,
    };
}

fn solvePart1(filename: ([:0]const u8)) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var result: u64 = 0;
    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var half: usize = line.len / 2;
        var first_half = line[0..half];
        var second_half = line[half..];

        if (first_half.len != second_half.len) {
            return PuzzleError.InvalidSize;
        }

        const found: ?u8 = blk: {
            for (first_half) |a| {
                for (second_half) |b| {
                    if (a == b) {
                        break :blk a;
                    }
                }
            }
            break :blk null;
        };

        if (found) |c| {
            result += itemValue(c);
        } else {
            print("Line: {s}\n", .{line});
            return PuzzleError.NotFound;
        }
    }

    return result;
}

fn solvePart2(filename: ([:0]const u8)) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var groups: usize = 0;
    var result: u64 = 0;
    var buf: [1024]u8 = undefined;
    var elves_backpacks: [3][60]u8 = undefined;
    var elf: usize = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        elves_backpacks[elf] = undefined;
        mem.copy(u8, elves_backpacks[elf][0..], line);

        if (elf == 2) {
            var found = blk: {
                for (elves_backpacks[0]) |a| {
                    for (elves_backpacks[1]) |b| {
                        if (a == b) {
                            for (elves_backpacks[2]) |c| {
                                if (c == a) {
                                    break :blk a;
                                }
                            }
                        }
                    }
                }
                break :blk null;
            };

            if (found) |c| {
                result += itemValue(c);
            } else {
                return PuzzleError.NotFound;
            }

            elf = 0;
            groups += 1;
        } else {
            elf += 1;
        }
    }

    return result;
}

test "part_1_test" {
    const filename = "data/input-test-3";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 157), result);
}

test "part_1" {
    const filename = "data/input-3";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 8252), result);
}

test "part_2_test" {
    const filename = "data/input-test-3";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 70), result);
}

test "part_2" {
    const filename = "data/input-3";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 2828), result);
}
