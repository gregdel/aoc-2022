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
    b: ?u128,

    fn do(self: *Operation, a: u128) u128 {
        var b: u128 = if (self.b) |bee| bee else a;
        // if (self.b == null) self.b = a;
        std.debug.print("doing op :{any} with {d}\n", .{ self, a });
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
    items: ArrayList(u128),
    allocator: mem.Allocator,
    operation: Operation,
    denominator: u32,
    true_monkey: u32,
    false_monkey: u32,
    times: u128,
    chill_factor: u8,

    fn init(allocator: mem.Allocator, chill_factor: u8) !*Monkey {
        var monkey = try allocator.create(Monkey);
        monkey.* = .{
            .operation = .{
                .operation = .Plus,
                .b = null,
            },
            .denominator = 1,
            .chill_factor = chill_factor,
            .allocator = allocator,
            .true_monkey = 0,
            .false_monkey = 0,
            .items = ArrayList(u128).init(allocator),
            .times = 0,
        };
        return monkey;
    }

    fn nextItem(self: *Monkey) ?u128 {
        if (self.items.items.len == 0) return null;
        self.times += 1;
        // var item: u128 = self.items.orderedRemove(0);
        var item: u128 = self.items.pop();
        item = self.operation.do(item);
        // item %= (self.denominator * self.chill_factor);
        return @divFloor(item, @as(u128, self.chill_factor));
    }

    fn destinationMonkey(self: *Monkey, item: u128) usize {
        return if ((item % self.denominator) == 0) self.true_monkey else self.false_monkey;
    }

    fn deinit(self: *Monkey) void {
        self.items.deinit();
        self.allocator.destroy(self);
    }

    fn print(self: *Monkey, id: usize) void {
        // std.debug.print("items:{d}\n", .{self.items.items.len});
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
    const result: u128 = switch (cmd.part) {
        1 => try solvePart1(cmd.filename),
        2 => try solvePart2(cmd.filename),
        else => {
            print("Missing day part\n", .{});
            return;
        },
    };
    print("Result: {d}\n", .{result});
}

fn parseInput(filename: []const u8, chill_factor: u8) !ArrayList(*Monkey) {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    const allocator = std.heap.page_allocator;
    var monkeys = ArrayList(*Monkey).init(allocator);
    monkeys.deinit();

    var i: usize = 0;
    var m: *Monkey = undefined;
    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // print("[{d}]{s}\n", .{ i, line });
        var idx = i % 7;
        switch (idx) {
            0 => {
                m = try Monkey.init(allocator, chill_factor);
                try monkeys.append(m);
            },
            1 => {
                // m.print();
                var iterator = mem.tokenize(u8, line[18..], &[_]u8{ ' ', ',' });
                while (iterator.next()) |str| {
                    // print("\t{s}\n", .{str});
                    try m.items.append(try fmt.parseInt(u128, str, 10));
                }
            },
            2 => {
                m.operation.operation = switch (line[23]) {
                    '*' => .Times,
                    '+' => .Plus,
                    else => unreachable,
                };

                if (line[25] != 'o') {
                    m.operation.b = try fmt.parseInt(u128, line[25..], 10);
                } else {
                    m.operation.b = null;
                }
            },
            3 => {
                m.denominator = try fmt.parseInt(u32, line[21..], 10);
            },
            4 => {
                m.true_monkey = try fmt.parseInt(u32, line[29..], 10);
            },
            5 => {
                m.false_monkey = try fmt.parseInt(u32, line[30..], 10);
            },
            else => {
                print("{any}\n", .{m});
            },
        }
        i += 1;
    }

    return monkeys;
}

fn solve(filename: []const u8, denominator: u8, rounds: usize) !u128 {
    var monkeys = try parseInput(filename, denominator);
    // monkeys.deinit();

    // var
    // for (monkeys.items) |monkey| {
    // }

    var i: usize = 0;
    while (i < rounds) : (i += 1) {
        print("Round {d}\n", .{i});
        for (monkeys.items) |monkey| {
            // monkey.print(c);
            while (true) {
                var next_item = monkey.nextItem();
                if (next_item == null) break;

                var new_monkey = monkey.destinationMonkey(next_item.?);
                // print("{d} new monkey:{d} item:{d}\n", .{ c, new_monkey, next_item.? });
                try monkeys.items[new_monkey].items.append(next_item.?);
            }
        }
        for (monkeys.items) |monkey, c| {
            monkey.print(c);
        }
    }

    var sortedMonkeys = monkeys.toOwnedSlice();
    std.sort.sort(*Monkey, sortedMonkeys, {}, Monkey.moreThan);
    for (sortedMonkeys) |item| {
        print("{}\n", .{item.times});
    }

    return sortedMonkeys[0].times * sortedMonkeys[1].times;
}

fn solvePart1(filename: []const u8) !u128 {
    return solve(filename, 3, 20);
}

fn solvePart2(filename: []const u8) !u128 {
    return solve(filename, 1, 20);
}

test "part_1_test" {
    const filename = "data/input-test-9";
    const result: u128 = try solvePart1(filename);
    try testing.expectEqual(@as(u128, 13), result);
}

test "part_1" {
    const filename = "data/input-9";
    const result: u128 = try solvePart1(filename);
    try testing.expectEqual(@as(u128, 6269), result);
}

test "part_2_test" {
    const filename = "data/input-test-9";
    const result: u128 = try solvePart2(filename);
    try testing.expectEqual(@as(u128, 1), result);
}

test "part_2_test_extra" {
    const filename = "data/input-test-9-extra";
    const result: u128 = try solvePart2(filename);
    try testing.expectEqual(@as(u128, 36), result);
}

test "part_2" {
    const filename = "data/input-9";
    const result: u128 = try solvePart2(filename);
    try testing.expectEqual(@as(u128, 2557), result);
}
