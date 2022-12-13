const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const ParseError = error{InvalidDirection};

const Op = enum { Plus, Times };

const Operation = struct {
    operation: Op,
    b: ?u64,

    fn do(self: *Operation, a: u64) u64 {
        var b: u64 = if (self.b) |bee| bee else a;
        return switch (self.operation) {
            .Plus => a + b,
            .Times => a * b,
        };
    }

    fn print(self: Operation) void {
        std.debug.print("operation:{any}\n", .{self.operation});
    }
};

const Monkey = struct {
    items: ArrayList(u64),
    allocator: mem.Allocator,
    operation: Operation,
    denominator: u32,
    super_factor: u64,
    true_monkey: u32,
    false_monkey: u32,
    times: u64,
    chill_factor: u8,

    fn init(allocator: mem.Allocator, chill_factor: u8) !*Monkey {
        var monkey = try allocator.create(Monkey);
        monkey.* = .{
            .operation = .{
                .operation = .Plus,
                .b = null,
            },
            .denominator = 1,
            .super_factor = 1,
            .chill_factor = chill_factor,
            .allocator = allocator,
            .true_monkey = 0,
            .false_monkey = 0,
            .items = ArrayList(u64).init(allocator),
            .times = 0,
        };
        return monkey;
    }

    fn nextItem(self: *Monkey, limit_worry_level: bool) ?u64 {
        if (self.items.items.len == 0) return null;
        self.times += 1;
        var item: u64 = self.items.pop();
        item = if (limit_worry_level)
            self.operation.do(item) % self.super_factor
        else
            self.operation.do(item);

        return @divFloor(item, @as(u64, self.chill_factor));
    }

    fn destinationMonkey(self: *Monkey, item: *?u64) usize {
        var value: u64 = if (item.*) |i| i else unreachable;
        if ((value % @as(u64, self.denominator)) == 0) {
            return self.true_monkey;
        } else {
            return self.false_monkey;
        }
    }

    fn deinit(self: *Monkey) void {
        self.items.deinit();
        self.allocator.destroy(self);
    }

    fn print(self: *Monkey, id: usize) void {
        std.debug.print("Monkey {d}: {any}\n", .{ id, self.items.items });
    }

    fn moreThan(_: void, a: *Monkey, b: *Monkey) bool {
        if (a.times > b.times) {
            return true;
        } else {
            return false;
        }
    }
};

pub fn main() !void {
    const cmd = try aoc.parseCmdLine();
    const allocator = std.heap.page_allocator;
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

fn parseInput(filename: []const u8, allocator: mem.Allocator, chill_factor: u8) !ArrayList(*Monkey) {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var monkeys = ArrayList(*Monkey).init(allocator);

    var i: usize = 0;
    var monkey_id: ?usize = null;
    var m: *Monkey = undefined;
    var buf: [64]u8 = undefined;
    var super_factor: u64 = 1;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var idx = i % 7;
        switch (idx) {
            0 => {
                m = try Monkey.init(allocator, chill_factor);
                if (monkey_id == null) {
                    monkey_id = 0;
                } else {
                    monkey_id.? += 1;
                }
                try monkeys.append(m);
            },
            1 => {
                var iterator = mem.tokenize(u8, line[18..], &[_]u8{ ' ', ',' });
                while (iterator.next()) |str| {
                    try m.items.append(try fmt.parseInt(u64, str, 10));
                }
            },
            2 => {
                m.operation.operation = switch (line[23]) {
                    '*' => .Times,
                    '+' => .Plus,
                    else => unreachable,
                };

                if (line[25] != 'o') {
                    m.operation.b = try fmt.parseInt(u64, line[25..], 10);
                } else {
                    m.operation.b = null;
                }
            },
            3 => {
                m.denominator = try fmt.parseInt(u32, line[21..], 10);
                super_factor *= m.denominator;
            },
            4 => {
                m.true_monkey = try fmt.parseInt(u32, line[29..], 10);
            },
            5 => {
                m.false_monkey = try fmt.parseInt(u32, line[30..], 10);
            },
            else => {},
        }
        i += 1;
    }

    for (monkeys.items) |monkey| monkey.super_factor = super_factor;

    return monkeys;
}

fn solve(filename: []const u8, allocator: mem.Allocator, denominator: u8, rounds: usize, limit_worry_level: bool) !u64 {
    var monkeys = try parseInput(filename, allocator, denominator);
    defer monkeys.deinit();

    var i: usize = 0;
    while (i < rounds) : (i += 1) {
        for (monkeys.items) |monkey| {
            while (true) {
                var next_item = monkey.nextItem(limit_worry_level);
                if (next_item == null) break;

                var new_monkey = monkey.destinationMonkey(&next_item);
                var new_value = next_item.?;
                try monkeys.items[new_monkey].items.append(new_value);
            }
        }
    }

    std.sort.sort(*Monkey, monkeys.items, {}, Monkey.moreThan);
    var result: u64 = monkeys.items[0].times * monkeys.items[1].times;
    for (monkeys.items) |m| m.deinit();
    return result;
}

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !u64 {
    return solve(filename, allocator, 3, 20, false);
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !u64 {
    return solve(filename, allocator, 1, 10000, true);
}

test "part_1_test" {
    const filename = "data/input-test-11";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 10605), result);
}

test "part_1" {
    const filename = "data/input-11";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 120056), result);
}

test "part_2_test" {
    const filename = "data/input-test-11";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 2713310158), result);
}

test "part_2" {
    const filename = "data/input-11";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 21816744824), result);
}
