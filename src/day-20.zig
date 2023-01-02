const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

pub fn main() !void {
    const cmd = try aoc.parseCmdLine();
    var allocator = std.heap.page_allocator;
    const result: i64 = switch (cmd.part) {
        1 => try solvePart1(cmd.filename, allocator),
        2 => try solvePart2(cmd.filename, allocator),
        else => {
            print("Missing day part\n", .{});
            return;
        },
    };
    print("Result: {d}\n", .{result});
}

const Element = struct {
    allocator: mem.Allocator,
    prev: *Element,
    next: *Element,
    value: i64,
    reduced_value: i32,

    fn init(allocator: mem.Allocator, value: i64) !*Element {
        var el = try allocator.create(Element);
        el.* = .{
            .allocator = allocator,
            .prev = undefined,
            .next = undefined,
            .value = value,
            .reduced_value = 0,
        };
        return el;
    }

    fn deinit(self: *Element) void {
        self.allocator.destroy(self);
    }

    fn distance(self: *Element) usize {
        return if (self.reduced_value < 0)
            @intCast(usize, self.reduced_value * -1)
        else
            @intCast(usize, self.reduced_value);
    }

    fn getNext(self: *Element, e: *Element) *Element {
        return if (self.reduced_value < 0) e.prev else e.next;
    }
};

const Message = struct {
    allocator: mem.Allocator,
    elements: ArrayList(*Element),
    zero: *Element,
    decryption_key: u64,
    moves: usize,

    fn init(allocator: mem.Allocator, decryption_key: u64, moves: usize) Message {
        return .{
            .allocator = allocator,
            .elements = ArrayList(*Element).init(allocator),
            .zero = undefined,
            .decryption_key = decryption_key,
            .moves = moves,
        };
    }

    fn deinit(self: *Message) void {
        for (self.elements.items) |e| e.deinit();
        self.elements.deinit();
    }

    fn reduceValue(self: *Message, value: i64) i32 {
        const len: i32 = @intCast(i32, self.elements.items.len);
        var v: i32 = @intCast(i32, @mod(value, len - 1));
        const half: i32 = @divFloor(len, 2);
        if (v < -1 * half) return v + (len - 1);
        if (v > half) return v - (len - 1);
        return v;
    }

    fn updateLinks(self: *Message) void {
        var prev: *Element = self.elements.items[self.elements.items.len - 1];
        for (self.elements.items) |e| {
            e.prev = prev;
            e.reduced_value = self.reduceValue(e.value);
            prev.next = e;
            prev = e;
        }
    }

    fn addElement(self: *Message, value: i64) !void {
        var element = try Element.init(self.allocator, value);
        if (value == 0) self.zero = element;
        element.value *= @intCast(i64, self.decryption_key);
        try self.elements.append(element);
    }

    fn get(self: *Message, value: usize) i64 {
        return self.elements.items[value % self.elements.items.len].value;
    }

    fn moveAll(self: *Message) void {
        var i: usize = 0;
        while (i < self.moves) : (i += 1) {
            for (self.elements.items) |e| self.move(e);
        }
    }

    fn reorder(self: *Message) void {
        var e: *Element = self.zero;
        var i: usize = 0;
        while (true) : (i += 1) {
            self.elements.items[i] = e;
            e = e.next;
            if (e.value == 0) break;
        }
    }

    fn move(_: *Message, element: *Element) void {
        if (element.value == 0) return;
        var count = element.distance();
        if (count == 0) return;

        element.prev.next = element.next;
        element.next.prev = element.prev;

        var e: *Element = element;
        while (count > 0) : (count -= 1) e = element.getNext(e);

        if (element.reduced_value < 0) {
            element.prev = e.prev;
            element.next = e;
            e.prev = element;
            element.prev.next = element;
        } else {
            element.prev = e;
            element.next = e.next;
            e.next = element;
            element.next.prev = element;
        }
    }

    fn showList(self: *Message) void {
        print("Elements:\n", .{});
        var e: *Element = self.zero;
        var i: usize = 0;
        while (true) : (i += 1) {
            print("{d} ({d}) {d} ({d})\n", .{
                i,
                e.prev.value,
                e.value,
                e.next.value,
            });
            e = e.next;
            if (e.value == 0) break;
        }
    }
};

fn parseInput(filename: []const u8, message: *Message) !void {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try message.addElement(try fmt.parseInt(i64, line, 10));
    }
}

fn solve(filename: []const u8, allocator: mem.Allocator, decryption_key: u64, rounds: usize) !i64 {
    var message = Message.init(allocator, decryption_key, rounds);
    try parseInput(filename, &message);
    defer message.deinit();
    message.updateLinks();
    message.moveAll();
    message.reorder();
    return message.get(1000) + message.get(2000) + message.get(3000);
}

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !i64 {
    return solve(filename, allocator, 1, 1);
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !i64 {
    return solve(filename, allocator, 811589153, 10);
}

test "part_1_test" {
    const filename = "data/input-test-20";
    const result: i64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(i64, 3), result);
}

test "part_1" {
    const filename = "data/input-20";
    const result: i64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(i64, 4426), result);
}

test "part_2_test" {
    const filename = "data/input-test-20";
    const result: i64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(i64, 1623178306), result);
}

test "part_2" {
    const filename = "data/input-20";
    const result: i64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(i64, 8119137886612), result);
}
