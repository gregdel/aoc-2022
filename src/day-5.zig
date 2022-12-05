const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const MaxRows = 8;
const MaxStacks = 9;

const Operation = enum {
    OneByOne,
    Batch,
};

const Stack = struct {
    count: usize,
    data: [128]?u8,

    const Self = @This();

    fn init(self: *Self) void {
        self.count = 0;
        self.data = .{null} ** 128;
    }

    fn push(self: *Self, e: u8) void {
        self.data[self.count] = e;
        self.count += 1;
    }

    fn pushN(self: *Self, items: []?u8) void {
        mem.copy(?u8, self.data[self.count..], items);
        self.count += items.len;
    }

    fn peek(self: *Self) u8 {
        return if (self.data[self.count - 1]) |v| v else unreachable;
    }

    fn pop(self: *Self) u8 {
        self.count -= 1;
        const value: u8 = if (self.data[self.count]) |v| v else unreachable;
        self.data[self.count] = null;
        return value;
    }

    fn popN(self: *Self, n: usize) []?u8 {
        self.count -= n;
        var i = self.count;
        return self.data[i..(i + n)];
    }

    fn print(self: Self) void {
        if (self.count == 0) return;
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            var c = if (self.data[i]) |d| d else unreachable;
            std.debug.print("{c} ", .{c});
        }
        std.debug.print("\n", .{});
    }
};

pub fn main() !void {
    const cmd = try aoc.parseCmdLine();
    const result: [MaxStacks]u8 = switch (cmd.part) {
        1 => try solvePart1(cmd.filename),
        2 => try solvePart2(cmd.filename),
        else => {
            print("Missing day part\n", .{});
            return;
        },
    };
    print("Result: {s}\n", .{result});
}

fn parseEntries(entries: [MaxRows][MaxStacks]?u8, max_col: usize, max_row: usize) [MaxStacks]Stack {
    var stacks: [MaxStacks]Stack = undefined;
    for (stacks) |*s| s.init();

    var col: usize = 0;
    while (col < max_col) : (col += 1) {
        var row: usize = max_row - 1;
        while (row >= 0) : (row -= 1) {
            if (entries[row][col]) |e| stacks[col].push(e);
            if (row == 0) break;
        }
    }

    return stacks;
}

fn solve(filename: ([:0]const u8), operation: Operation) ![MaxStacks]u8 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var entries: [MaxRows][MaxStacks]?u8 = .{.{null} ** 9} ** 8;
    var max_col: usize = 0;
    var max_row: usize = 0;
    var stacks: [MaxStacks]Stack = undefined;
    var parseStacks: bool = true;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) continue;
        if (parseStacks) {
            var i: usize = 1;
            if (line[i] == '1') {
                stacks = parseEntries(entries, max_col, max_row);
                parseStacks = false;
                continue;
            }

            var col: usize = 0;
            while (i < line.len) : (i += 4) {
                entries[max_row][col] = if (line[i] != ' ') line[i] else null;
                col += 1;
            }

            if (col > max_col) max_col = col;
            max_row += 1;
        } else {
            var iterator = mem.tokenize(u8, line, &[_]u8{' '});
            _ = iterator.next();
            var count: u8 = if (iterator.next()) |item| try fmt.parseInt(u8, item, 10) else 0;
            _ = iterator.next();
            var from: u8 = if (iterator.next()) |item| try fmt.parseInt(u8, item, 10) else 0;
            _ = iterator.next();
            var to: u8 = if (iterator.next()) |item| try fmt.parseInt(u8, item, 10) else 0;

            switch (operation) {
                Operation.OneByOne => {
                    var moved: usize = 0;
                    while (moved != count) : (moved += 1) {
                        const item = stacks[from - 1].pop();
                        stacks[to - 1].push(item);
                    }
                },
                Operation.Batch => {
                    stacks[to - 1].pushN(stacks[from - 1].popN(count));
                },
            }
        }
    }

    var result: [MaxStacks]u8 = .{0} ** 9;

    var i: usize = 0;
    while (i < max_col) : (i += 1) {
        result[i] = stacks[i].peek();
    }

    return result;
}

fn solvePart1(filename: ([:0]const u8)) ![MaxStacks]u8 {
    return solve(filename, Operation.OneByOne);
}

fn solvePart2(filename: ([:0]const u8)) ![MaxStacks]u8 {
    return solve(filename, Operation.Batch);
}

test "part_1_test" {
    const filename = "data/input-test-5";
    const result: [MaxStacks]u8 = try solvePart1(filename);
    const expected = [_]u8{ 'C', 'M', 'Z' } ++ [_]u8{0} ** 6;
    try testing.expectEqual(expected, result);
}

test "part_1" {
    const filename = "data/input-5";
    const result: [MaxStacks]u8 = try solvePart1(filename);
    try testing.expectEqual([MaxStacks]u8{ 'S', 'B', 'P', 'Q', 'R', 'S', 'C', 'D', 'F' }, result);
}

test "part_2_test" {
    const filename = "data/input-test-5";
    const result: [MaxStacks]u8 = try solvePart2(filename);
    const expected = [_]u8{ 'M', 'C', 'D' } ++ [_]u8{0} ** 6;
    try testing.expectEqual(expected, result);
}

test "part_2" {
    const filename = "data/input-5";
    const result: [MaxStacks]u8 = try solvePart2(filename);
    try testing.expectEqual([MaxStacks]u8{ 'R', 'G', 'L', 'V', 'R', 'C', 'Q', 'S', 'B' }, result);
}
