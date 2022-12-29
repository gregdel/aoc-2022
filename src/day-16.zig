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

const PathFinder = struct {
    nodes: ArrayList(Node),
    queue: std.PriorityQueue(*Node, void, Node.compareDistance),

    const Node = struct {
        valve: *Valve,
        visited: bool,
        distance: u32,

        fn init(valve: *Valve) Node {
            return .{
                .valve = valve,
                .visited = false,
                .distance = 0,
            };
        }

        fn reset(self: *Node) void {
            self.visited = false;
            self.distance = std.math.maxInt(u32);
        }

        fn compareDistance(context: void, a: *Node, b: *Node) std.math.Order {
            _ = context;
            return std.math.order(a.distance, b.distance);
        }
    };

    fn init(allocator: mem.Allocator, valves: ArrayList(*Valve)) !PathFinder {
        var nodes = try ArrayList(Node).initCapacity(allocator, valves.items.len);
        for (valves.items) |v| try nodes.append(Node.init(v));
        return .{
            .nodes = nodes,
            .queue = std.PriorityQueue(*Node, void, Node.compareDistance).init(allocator, {}),
        };
    }

    fn deinit(self: *PathFinder) void {
        self.queue.deinit();
        self.nodes.deinit();
    }

    fn update_all(self: *PathFinder) !void {
        for (self.nodes.items) |*n| try self.update(n);
    }

    fn update(self: *PathFinder, node: *Node) !void {
        for (self.nodes.items) |*n| n.reset();

        node.distance = 0;
        try self.queue.add(node);

        while (self.queue.removeOrNull()) |v| try self.explore(v);

        for (self.nodes.items) |n| {
            if (n.valve == node.valve) continue;
            if (n.valve.flow_rate == 0 and !n.valve.is_root) continue;
            try node.valve.paths.put(n.valve, n.distance);
        }
    }

    fn explore(self: *PathFinder, n: *Node) !void {
        if (n.visited) return;
        n.visited = true;
        for (n.valve.neighbors.items) |v| {
            for (self.nodes.items) |*neigh| {
                if (neigh.valve != v) continue;
                if (neigh.visited) continue;

                neigh.distance = @min(neigh.distance, n.distance + 1);
                try self.queue.add(neigh);
            }
        }
    }
};

const Explorer = struct {
    allocator: mem.Allocator,
    duration: u8,
    current_best: u64,
    root_valve: *Valve,

    fn init(allocator: mem.Allocator, root: *Valve, duration: u8) !Explorer {
        return .{
            .allocator = allocator,
            .current_best = 0,
            .duration = duration,
            .root_valve = root,
        };
    }

    fn find(self: *Explorer, valves: ValveSet) !u64 {
        self.current_best = 0;
        var current_node: ?*Node = try Node.init(
            self.allocator,
            self.root_valve,
            null,
            self.duration,
            valves,
        );

        while (current_node != null) {
            if (current_node.?.to_explore.items.len == 0) {
                self.current_best = @max(self.current_best, current_node.?.flow);
            }

            current_node = try current_node.?.next(self.current_best, valves);
        }

        return self.current_best;
    }

    const Node = struct {
        allocator: mem.Allocator,
        valve: *Valve,
        prev: ?*Node,
        time_left: u8,
        flow: u64,
        to_explore: ArrayList(*Valve),
        best_estimate: u64,

        fn init(allocator: mem.Allocator, valve: *Valve, prev: ?*Node, time_left: u8, allowed_valves: ValveSet) !*Node {
            var node = try allocator.create(Node);
            node.* = .{
                .valve = valve,
                .allocator = allocator,
                .prev = prev,
                .flow = 0,
                .time_left = time_left,
                .best_estimate = 0,
                .to_explore = ArrayList(*Valve).init(allocator),
            };

            var explored = ValveSet.init(node.allocator);
            defer explored.deinit();

            node.flow = node.valve.flow_rate * @intCast(u64, node.time_left);

            var p: ?*Node = node.prev;
            while (true) {
                if (p == null) break;
                try explored.put(p.?.valve, true);
                node.flow += @intCast(u64, p.?.time_left) * p.?.valve.flow_rate;
                p = p.?.prev;
            }

            node.best_estimate = node.flow;
            var it = node.valve.paths.iterator();
            while (it.next()) |entry| {
                var v: *Valve = entry.key_ptr.*;
                var distance: u32 = entry.value_ptr.*;
                if (explored.get(v) != null) continue;
                if (allowed_valves.get(v) == null) continue;

                const cost = distance + 1;
                if (cost > node.time_left) continue;
                node.best_estimate += v.flow_rate * (node.time_left - cost);

                try node.to_explore.append(v);
            }

            node.sortToExplore();
            return node;
        }

        fn next(self: *Node, current_best: u64, allowed_valves: ValveSet) !?*Node {
            if ((current_best != 0) and (self.best_estimate < current_best)) {
                // Killing exploration branch
                var ret: ?*Node = self.prev;
                self.deinit();
                return ret;
            }

            var valve = self.to_explore.popOrNull();
            if (valve) |v| {
                var distance = self.valve.paths.get(v);
                if (distance == null) return null;

                var node = try Node.init(
                    self.allocator,
                    v,
                    self,
                    self.time_left - @intCast(u8, distance.? + 1),
                    allowed_valves,
                );
                return node;
            }

            var ret: ?*Node = self.prev;
            self.deinit();
            return ret;
        }

        fn deinit(self: *Node) void {
            self.to_explore.deinit();
            self.allocator.destroy(self);
        }

        fn sortToExplore(self: *Node) void {
            std.sort.sort(*Valve, self.to_explore.items, self, Node.sortByDistance);
        }

        fn show(self: *Node) void {
            print("time_left:{d} {s}({d}[{d}])", .{
                self.time_left,
                self.valve.name,
                self.flow,
                self.best_estimate,
            });
            var prev: ?*Node = self.prev;
            while (true) {
                if (prev) |p| {
                    print(" <- {s}({d}[{d}])", .{
                        p.valve.name,
                        p.flow,
                        p.best_estimate,
                    });
                    prev = p.prev;
                } else {
                    break;
                }
            }
            print("\n", .{});
        }

        fn sortByDistance(self: *Node, a: *Valve, b: *Valve) bool {
            var da = a.paths.get(self.valve);
            var db = b.paths.get(self.valve);
            if (da == null or db == null) return false;

            if (da.? == db.?) {
                // Return the highest flow_rate
                return (a.flow_rate < b.flow_rate);
            }

            // Return the lowest distance
            return (da.? > db.?);
        }
    };
};

const Valve = struct {
    name: [2]u8,
    is_root: bool,
    flow_rate: u8,
    neighbors: ArrayList(*Valve),
    paths: AutoHashMap(*Valve, u32),

    allocator: mem.Allocator,

    fn init(allocator: mem.Allocator, name: [2]u8, flow_rate: ?u8) !*Valve {
        var valve = try allocator.create(Valve);
        valve.* = .{
            .name = name,
            .is_root = if (name[0] == 'A' and name[1] == 'A') true else false,
            .flow_rate = flow_rate orelse 0,
            .allocator = allocator,
            .neighbors = ArrayList(*Valve).init(allocator),
            .paths = AutoHashMap(*Valve, u32).init(allocator),
        };
        return valve;
    }

    fn deinit(self: *Valve) void {
        self.paths.deinit();
        self.neighbors.deinit();
        self.allocator.destroy(self);
    }
};

const ValveSet = AutoHashMap(*Valve, bool);

const Map = struct {
    allocator: mem.Allocator,
    root: *Valve,
    valves: AutoHashMap([2]u8, *Valve),
    time_left: u8,

    fn init(allocator: mem.Allocator) Map {
        return .{
            .root = undefined,
            .time_left = 29,
            .allocator = allocator,
            .valves = AutoHashMap([2]u8, *Valve).init(allocator),
        };
    }

    fn addValve(self: *Map, name: [2]u8, flow_rate: ?u8) !*Valve {
        if (self.valves.get(name)) |valve| {
            if (flow_rate) |f| {
                valve.flow_rate = f;
            }
            return valve;
        } else {
            var valve = try Valve.init(self.allocator, name, flow_rate);
            try self.valves.put(name, valve);
            return valve;
        }
    }

    fn addValveNeighbor(self: *Map, name: [2]u8, neigh: [2]u8) !void {
        var neighbor = try self.addValve(neigh, null);
        if (self.valves.get(name)) |valve| {
            try valve.neighbors.append(neighbor);
        } else {
            unreachable;
        }
    }

    fn updateAllPaths(self: *Map) !void {
        var valves = try ArrayList(*Valve).initCapacity(self.allocator, self.valves.count());
        defer valves.deinit();
        var it = self.valves.valueIterator();
        while (it.next()) |v| try valves.append(v.*);

        var path_finder = try PathFinder.init(self.allocator, valves);
        defer path_finder.deinit();
        try path_finder.update_all();

        for (valves.items) |v| {
            if (v.is_root) self.root = v;
            if (!v.is_root and v.flow_rate == 0) {
                _ = self.valves.remove(v.name);
                v.deinit();
                continue;
            }
            // v.show();
        }
    }

    fn deinit(self: *Map) void {
        var it = self.valves.valueIterator();
        while (it.next()) |valve| valve.*.deinit();
        self.valves.deinit();
    }
};

fn parseInput(filename: []const u8, allocator: mem.Allocator) !Map {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var map = Map.init(allocator);

    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var valve_name: [2]u8 = .{ line[6], line[7] };
        var parts = mem.split(u8, line[23..], ";");
        var flow_rate = try fmt.parseInt(u8, parts.next() orelse unreachable, 10);
        parts = mem.split(u8, line[23..], " to ");
        _ = parts.next();
        var neighbors = mem.tokenize(u8, parts.next() orelse unreachable, " ,");
        _ = neighbors.next();

        _ = try map.addValve(valve_name, flow_rate);
        while (neighbors.next()) |n| {
            var neigh: [2]u8 = .{ n[0], n[1] };
            try map.addValveNeighbor(valve_name, neigh);
        }
    }

    try map.updateAllPaths();

    return map;
}

const SubsetIterator = struct {
    allocator: mem.Allocator,
    values: ArrayList(*Valve),
    set1: ValveSet,
    set2: ValveSet,
    max_size: usize,
    current_value: u64,
    max_value: u64,

    fn init(allocator: mem.Allocator, values: ArrayList(*Valve)) !SubsetIterator {
        var max_size: usize = (values.items.len / 2) + 2;
        var max_value: u64 = std.math.shl(u64, 1, values.items.len);
        var min_value: u64 = std.math.shl(u64, 1, values.items.len - max_size);
        return .{
            .allocator = allocator,
            .values = values,
            .current_value = min_value,
            .max_value = max_value,
            .max_size = max_size,
            .set1 = ValveSet.init(allocator),
            .set2 = ValveSet.init(allocator),
        };
    }

    fn deinit(self: *SubsetIterator) void {
        self.set1.deinit();
        self.set2.deinit();
    }

    const Entry = struct {
        set1: ValveSet,
        set2: ValveSet,
    };

    fn next(self: *SubsetIterator) !?Entry {
        var should_return = false;
        outer: while (self.current_value < self.max_value) : (self.current_value += 1) {
            if (should_return) {
                return .{
                    .set1 = self.set1,
                    .set2 = self.set2,
                };
            }

            self.set1.clearRetainingCapacity();
            self.set2.clearRetainingCapacity();

            var i: u64 = 0;
            while (i < self.values.items.len) : (i += 1) {
                if ((std.math.shr(u64, self.current_value, i) & 1) == @as(u64, 1)) {
                    if ((self.set1.count() + 1) == self.max_size) continue :outer;
                    try self.set1.put(self.values.items[i], true);
                } else {
                    if ((self.set2.count() + 1) == self.max_size) continue :outer;
                    try self.set2.put(self.values.items[i], true);
                }
            }

            should_return = true;
        }

        return null;
    }
};

fn solvePart1(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try parseInput(filename, allocator);
    defer map.deinit();

    var valves = ValveSet.init(allocator);
    defer valves.deinit();
    var it = map.valves.valueIterator();
    while (it.next()) |v| {
        var valve: *Valve = v.*;
        if (valve.is_root) continue;
        try valves.put(valve, true);
    }

    var explorer = try Explorer.init(allocator, map.root, 30);

    return explorer.find(valves);
}

fn solvePart2(filename: []const u8, allocator: mem.Allocator) !u64 {
    var map = try parseInput(filename, allocator);
    defer map.deinit();

    var explorer = try Explorer.init(allocator, map.root, 26);

    var valves = ArrayList(*Valve).init(allocator);
    defer valves.deinit();
    var it = map.valves.valueIterator();
    while (it.next()) |v| {
        var valve: *Valve = v.*;
        if (valve.is_root) continue;
        try valves.append(valve);
    }

    var best_score: u64 = 0;
    var sets = try SubsetIterator.init(allocator, valves);
    defer sets.deinit();

    while (try sets.next()) |set| {
        const score1 = try explorer.find(set.set1);
        const score2 = try explorer.find(set.set2);
        best_score = @max(best_score, score1 + score2);
    }

    return best_score;
}

test "part_1_test" {
    const filename = "data/input-test-16";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 1651), result);
}

test "part_1" {
    const filename = "data/input-16";
    const result: u64 = try solvePart1(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 2359), result);
}

test "part_2_test" {
    const filename = "data/input-test-16";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 1707), result);
}

test "part_2" {
    const filename = "data/input-16";
    const result: u64 = try solvePart2(filename, std.testing.allocator);
    try testing.expectEqual(@as(u64, 2999), result);
}
