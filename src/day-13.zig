const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const Error = error{ ParseError, InvalidElement };

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    const cmd = try aoc.parseCmdLine();
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

const Kind = enum { Int, List };

const Element = struct {
    kind: Kind,
    parent: ?*Element,
    allocator: mem.Allocator,
    data: union {
        list: ArrayList(Element),
        int: u32,
    },

    fn initList(allocator: mem.Allocator, parent: ?*Element) !Element {
        return .{
            .kind = .List,
            .allocator = allocator,
            .parent = parent,
            .data = .{ .list = ArrayList(Element).init(allocator) },
        };
    }

    fn deinit(self: *Element) void {
        if (self.kind == .Int) return;
        for (self.data.list.items) |*el| el.deinit();
        self.data.list.deinit();
    }

    fn addInt(self: *Element, value: u32) !void {
        if (self.kind != .List) return Error.InvalidElement;

        try self.data.list.append(.{
            .parent = self,
            .allocator = self.allocator,
            .kind = .Int,
            .data = .{ .int = value },
        });
    }

    fn addList(self: *Element) !*Element {
        if (self.kind != .List) return Error.InvalidElement;

        try self.data.list.append(try Element.initList(self.allocator, self));

        return &self.data.list.items[self.data.list.items.len - 1];
    }

    fn cmp(self: *Element, el: *Element) !std.math.Order {
        if ((self.kind == .Int) and (el.kind == .Int)) {
            return std.math.order(self.data.int, el.data.int);
        }

        if ((self.kind == .List) and (el.kind == .List)) {
            var default: std.math.Order = .eq;
            if (self.data.list.items.len > el.data.list.items.len) default = .gt;
            if (self.data.list.items.len < el.data.list.items.len) default = .lt;
            var i_max = @min(self.data.list.items.len, el.data.list.items.len);

            var i: usize = 0;
            while (i < i_max) : (i += 1) {
                var l = self.data.list.items[i];
                var r = el.data.list.items[i];
                var result = try l.cmp(&r);
                if (result != .eq) return result;
            }

            return default;
        }

        if ((self.kind == .List) and (el.kind == .Int)) {
            var new_list = try Element.initList(self.allocator, null);
            try new_list.addInt(el.data.int);
            var result = try self.cmp(&new_list);
            new_list.deinit();
            return result;
        }

        if ((self.kind == .Int) and (el.kind == .List)) {
            var new_list = try Element.initList(self.allocator, null);
            try new_list.addInt(self.data.int);
            var result = try new_list.cmp(el);
            new_list.deinit();
            return result;
        }

        unreachable;
    }
};

const Packet = struct {
    element: Element,
    allocator: mem.Allocator,
    is_decoder_key: bool,

    fn init(allocator: mem.Allocator, line: []const u8, is_decoder_key: bool) !*Packet {
        var packet = try allocator.create(Packet);
        packet.* = .{
            .is_decoder_key = is_decoder_key,
            .allocator = allocator,
            .element = try Element.initList(allocator, null),
        };

        var current: *Element = &packet.element;

        var buf: [5]u8 = .{0} ** 5;
        var buf_idx: usize = 0;
        var parsing_int: bool = false;

        for (line[1..]) |char| {
            switch (char) {
                '[', ']', ',' => {
                    if (parsing_int) {
                        try current.addInt(try fmt.parseInt(u32, buf[0..buf_idx], 10));
                        parsing_int = false;
                        buf_idx = 0;
                    }

                    if (char == '[') current = try current.addList();
                    if (char == ']') if (current.parent) |p| {
                        current = p;
                    } else {
                        break;
                    };
                },
                '0'...'9' => {
                    parsing_int = true;
                    buf[buf_idx] = char;
                    buf_idx += 1;
                },
                else => return Error.ParseError,
            }
        }

        return packet;
    }

    fn lessThan(_: void, left: *Packet, right: *Packet) bool {
        var order = left.element.cmp(&right.element) catch unreachable;
        if (order == .lt) return true else return false;
    }

    fn deinit(self: *Packet) void {
        self.element.deinit();
        self.allocator.destroy(self);
    }
};

fn parseInput(filename: []const u8, allocator: mem.Allocator) !ArrayList(*Packet) {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var packets = ArrayList(*Packet).init(allocator);

    var line_number: usize = 0;
    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (line_number % 3) {
            0, 1 => try packets.append(try Packet.init(allocator, line, false)),
            2 => {},
            else => return Error.ParseError,
        }
        line_number += 1;
    }

    return packets;
}

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !u64 {
    var packets = try parseInput(filename, allocator);
    defer packets.deinit();

    var result: u64 = 0;

    var i: usize = 0;
    while (i < packets.items.len) : (i += 2) {
        var p1 = packets.items[i];
        var p2 = packets.items[i + 1];
        var order = try p1.element.cmp(&p2.element);
        if (order == .lt) result += (i / 2) + 1;
    }

    for (packets.items) |p| p.deinit();

    return result;
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !u64 {
    var packets = try parseInput(filename, allocator);
    defer packets.deinit();

    try packets.append(try Packet.init(allocator, "[[2]]", true));
    try packets.append(try Packet.init(allocator, "[[6]]", true));

    std.sort.sort(*Packet, packets.items, {}, Packet.lessThan);

    var result: u64 = 1;
    for (packets.items) |p, i| {
        if (p.is_decoder_key) result *= i + 1;
        p.deinit();
    }

    return result;
}

test "part_1_test" {
    const filename = "data/input-test-13";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 13), result);
}

test "part_1" {
    const filename = "data/input-13";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 5684), result);
}

test "part_2_test" {
    const filename = "data/input-test-13";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 140), result);
}

test "part_2" {
    const filename = "data/input-13";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 22932), result);
}
