const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

pub fn main() !void {
    const cmd = try aoc.parseCmdLine();
    if (cmd.part == 1) {
        print("Result: {d}\n", .{try solvePart1(cmd.filename)});
        return;
    }

    if (cmd.part == 2) {
        var crt = try solvePart2(cmd.filename);
        printCrt(crt);
        return;
    }

    print("Missing day part\n", .{});
    return;
}

fn cycleScore(cycle: usize, register: i32) u64 {
    if (((cycle + 20) % 40) == 0) return cycle * @intCast(u64, register);
    return 0;
}

fn shouldLit(cycle: usize, register: i32) bool {
    var c = ((cycle + 0) % 40);
    if ((c > (register - 2)) and (c < (register + 2))) return true;
    return false;
}

fn printCrt(crt: [240]bool) void {
    var i: u8 = 0;
    while (i < 240) : (i += 1) {
        if (((i % 40) == 0) and (i > 0)) print("\n", .{});
        const char: u8 = if (crt[i]) '#' else '.';
        print("{c}", .{char});
    }
    print("\n", .{});
}

fn solvePart1(filename: []const u8) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var register: i32 = 1;
    var cycles: usize = 0;
    var total: u64 = 0;

    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = mem.split(u8, line, &[1]u8{' '});
        var ins = if (it.next()) |ins| ins else unreachable;

        cycles += 1;
        total += cycleScore(cycles, register);
        if (ins[0] != 'n') {
            cycles += 1;
            total += cycleScore(cycles, register);
            var n = if (it.next()) |n| try fmt.parseInt(i32, n, 10) else unreachable;
            register += n;
        }
    }

    return total;
}

fn solvePart2(filename: []const u8) ![240]bool {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var register: i32 = 1;
    var cycles: usize = 0;
    var crt: [240]bool = .{false} ** 240;

    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = mem.split(u8, line, &[1]u8{' '});
        var ins = if (it.next()) |ins| ins else unreachable;

        crt[cycles] = shouldLit(cycles, register);
        cycles += 1;
        if (ins[0] != 'n') {
            crt[cycles] = shouldLit(cycles, register);
            cycles += 1;
            var n = if (it.next()) |n| try fmt.parseInt(i32, n, 10) else unreachable;
            register += n;
        }
    }

    return crt;
}

test "part_1_test" {
    const filename = "data/input-test-10";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 13140), result);
}

test "part_1" {
    const filename = "data/input-10";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 17020), result);
}

fn strToCrt(input: []const u8) [240]bool {
    var crt: [240]bool = .{false} ** 240;
    var i: usize = 0;
    for (input) |c| {
        if (c == '\n') continue;
        if (c == '#') crt[i] = true;
        i += 1;
    }
    return crt;
}

test "part_2_test" {
    const filename = "data/input-test-10";
    const result: [240]bool = try solvePart2(filename);
    const img =
        \\##..##..##..##..##..##..##..##..##..##..
        \\###...###...###...###...###...###...###.
        \\####....####....####....####....####....
        \\#####.....#####.....#####.....#####.....
        \\######......######......######......####
        \\#######.......#######.......#######.....
    ;
    const expected: [240]bool = strToCrt(img);
    try testing.expectEqual(expected, result);
}

test "part_2" {
    const filename = "data/input-10";
    const result: [240]bool = try solvePart2(filename);
    const img =
        \\###..#....####.####.####.#.....##..####.
        \\#..#.#....#.......#.#....#....#..#.#....
        \\#..#.#....###....#..###..#....#....###..
        \\###..#....#.....#...#....#....#.##.#....
        \\#.#..#....#....#....#....#....#..#.#....
        \\#..#.####.####.####.#....####..###.####.
    ;
    const expected: [240]bool = strToCrt(img);
    try testing.expectEqual(expected, result);
}
