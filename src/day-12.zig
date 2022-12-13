const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const Error = error{ParseError};

const Node = struct {
    x: usize,
    y: usize,
    height: u8,
    visited: bool,
    is_start: bool,
    is_end: bool,
    previous_node: ?*Node,
    min_distance: usize,

    fn init(self: *Node, x: usize, y: usize) void {
        self.* = .{
            .x = x,
            .y = y,
            .height = 0,
            .is_start = false,
            .is_end = false,
            .previous_node = null,
            .visited = false,
            .min_distance = std.math.maxInt(usize),
        };
    }

    fn reset(self: *Node) void {
        self.previous_node = null;
        self.visited = false;
        self.min_distance = std.math.maxInt(usize);
    }

    fn set(self: *Node, char: u8) !void {
        switch (char) {
            'a'...'z' => self.height = char - 'a',
            'S' => {
                self.height = 0;
                self.is_start = true;
            },
            'E' => {
                self.height = 'z' - 'a';
                self.is_end = true;
            },
            else => return Error.ParseError,
        }
    }

    fn compareFn(context: void, a: *Node, b: *Node) std.math.Order {
        _ = context;
        return std.math.order(a.min_distance, b.min_distance);
    }
};

const Iterator = struct {
    i: u8,
    map: *Map,
    node: *Node,
    max_x: usize,
    max_y: usize,

    fn init(map: *Map, node: *Node) Iterator {
        return .{
            .map = map,
            .node = node,
            .max_y = map.values.items.len,
            .max_x = map.values.items[0].len,
            .i = 0,
        };
    }

    fn next(self: *Iterator) ?*Node {
        while (self.i < 4) {
            var node = blk: {
                switch (self.i) {
                    0 => { // Up
                        if (self.node.y == self.max_y - 1) break :blk null;
                        break :blk self.map.getNode(self.node.x, self.node.y + 1);
                    },
                    1 => { // Down
                        if (self.node.y == 0) break :blk null;
                        break :blk self.map.getNode(self.node.x, self.node.y - 1);
                    },
                    2 => { // Right
                        if (self.node.x == self.max_x - 1) break :blk null;
                        break :blk self.map.getNode(self.node.x + 1, self.node.y);
                    },
                    3 => { // Left
                        if (self.node.x == 0) break :blk null;
                        break :blk self.map.getNode(self.node.x - 1, self.node.y);
                    },
                    else => {
                        break :blk null;
                    },
                }
            };

            self.i += 1;
            if (node) |n| {
                if (n.visited) continue;
                if (n.height > self.node.height + 1) continue;

                var new_distance = self.node.min_distance + 1;
                if (new_distance < n.min_distance) {
                    n.min_distance = new_distance;
                    n.previous_node = self.node;
                }

                return n;
            } else {
                continue;
            }
        }

        return null;
    }
};

const Map = struct {
    values: std.ArrayList([]Node),
    allocator: mem.Allocator,
    start: *Node,

    fn init(allocator: mem.Allocator) !*Map {
        var map = try allocator.create(Map);
        map.* = .{
            .start = undefined,
            .values = std.ArrayList([]Node).init(allocator),
            .allocator = allocator,
        };
        return map;
    }

    fn resetNodes(self: *Map) void {
        for (self.values.items) |nodes| {
            for (nodes) |*node| {
                node.reset();
            }
        }
    }

    fn addLine(self: *Map, line: []const u8) !void {
        var line_nodes = try self.allocator.alloc(Node, line.len);
        for (line) |char, i| {
            line_nodes[i].init(i, self.values.items.len);
            try line_nodes[i].set(char);
            if (line_nodes[i].is_start) self.start = &line_nodes[i];
        }

        try self.values.append(line_nodes);
    }

    fn getNode(self: *Map, x: usize, y: usize) *Node {
        return &self.values.items[y][x];
    }

    fn findPath(self: *Map, start: *Node) !u64 {
        self.resetNodes();
        start.min_distance = 0;

        var queue = std.PriorityQueue(*Node, void, Node.compareFn).init(self.allocator, {});
        defer queue.deinit();
        try queue.add(start);

        while (queue.removeOrNull()) |item| {
            if (item.visited) continue;
            if (item.is_end) return item.min_distance;
            item.visited = true;
            var it = Iterator.init(self, item);
            while (it.next()) |node| try queue.add(node);
        }

        return 0;
    }
};

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

fn parseInput(filename: []const u8) !*Map {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var allocator = std.heap.page_allocator;
    var map = try Map.init(allocator);

    var buf: [71]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.addLine(line);
    }

    return map;
}

fn solvePart1(filename: []const u8) !u64 {
    var map = try parseInput(filename);
    return try map.findPath(map.start);
}

fn solvePart2(filename: []const u8) !u64 {
    var map = try parseInput(filename);

    var min_steps: u64 = std.math.maxInt(u64);
    for (map.values.items) |nodes| {
        for (nodes) |*node| {
            if (node.height != 0) continue;
            var path = try map.findPath(node);
            if (path == 0) continue;
            min_steps = @min(min_steps, path);
        }
    }

    return min_steps;
}

test "part_1_test" {
    const filename = "data/input-test-12";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 31), result);
}

test "part_1" {
    const filename = "data/input-12";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 352), result);
}

test "part_2_test" {
    const filename = "data/input-test-12";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 29), result);
}

test "part_2" {
    const filename = "data/input-12";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 345), result);
}
