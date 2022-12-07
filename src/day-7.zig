const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const Error = error{InvalidDir};

const Kind = enum { File, Dir };

const Item = struct {
    kind: Kind,
    entry: union {
        dir: *Dir,
        file: *File,
    },
};

const DirSize = struct {
    dir: *Dir,
    size: usize,
};

const Dir = struct {
    name: []u8,
    items: ArrayList(Item),
    parent: ?*Dir,
    allocator: mem.Allocator,

    fn init(allocator: mem.Allocator, name: []const u8) !*Dir {
        var dir = try allocator.create(Dir);
        dir.allocator = allocator;
        dir.items = ArrayList(Item).init(allocator);
        dir.name = try allocator.alloc(u8, name.len);
        mem.copy(u8, dir.name, name);
        dir.parent = null;
        return dir;
    }

    fn addFile(self: *Dir, name: []const u8, size: usize) !void {
        try self.items.append(Item{
            .kind = Kind.File,
            .entry = .{ .file = try File.init(self.allocator, name, size) },
        });
    }

    fn addDir(self: *Dir, name: []const u8) !void {
        var dir = try Dir.init(self.allocator, name);
        dir.parent = self;
        try self.items.append(Item{
            .kind = Kind.Dir,
            .entry = .{ .dir = dir },
        });
    }

    fn cd(self: *Dir, dst: []const u8) !*Dir {
        if ((dst.len == 2) and (dst[0] == '.' and dst[1] == '.')) {
            if (self.parent) |dir| return dir else return Error.InvalidDir;
        }

        for (self.items.items) |item| {
            if (item.kind != Kind.Dir) continue;
            if (mem.eql(u8, item.entry.dir.name, dst)) return item.entry.dir;
        }
        return Error.InvalidDir;
    }

    fn ls(self: *Dir, depth: usize) void {
        var spaces: [64]u8 = undefined;
        const space_count = (depth + 1) * 2;
        var i: usize = 0;
        while (i < space_count) : (i += 2) {
            spaces[i] = ' ';
            spaces[i + 1] = ' ';
        }
        spaces[i] = 0;

        var dir_spaces = space_count - 2;

        print(
            "{s}- {s} (dir, size={d})\n",
            .{ spaces[0..dir_spaces], self.name, self.total_size() },
        );
        for (self.items.items) |item| {
            switch (item.kind) {
                Kind.File => print(
                    "{s}- {s} (file, size={d})\n",
                    .{ spaces, item.entry.file.name, item.entry.file.size },
                ),
                Kind.Dir => {
                    var dir = item.entry.dir;
                    dir.ls(depth + 1);
                },
            }
        }
    }

    fn addDirWithSizeMoreThan(self: *Dir, list: *ArrayList(DirSize), min_size: usize) !void {
        var total = self.total_size();
        if (total >= min_size) try list.append(DirSize{
            .dir = self,
            .size = total,
        });

        for (self.items.items) |item| {
            if (item.kind != Kind.Dir) continue;
            try item.entry.dir.addDirWithSizeMoreThan(list, min_size);
        }
    }

    fn cleanup_space(self: *Dir, required_space: usize, total_space: usize) !usize {
        var eligible = ArrayList(DirSize).init(self.allocator);
        defer eligible.deinit();

        const free_space = total_space - self.total_size();
        const to_free = if (free_space >= required_space) 0 else required_space - free_space;

        try self.addDirWithSizeMoreThan(&eligible, to_free);

        if (eligible.items.len == 0) return 0;

        var min: ?usize = null;
        for (eligible.items) |item| {
            if ((min == null) or (item.size < min.?)) min = item.size;
        }

        return if (min) |m| m else unreachable;
    }

    fn total_size(self: *Dir) usize {
        var total: usize = 0;
        for (self.items.items) |item| {
            total += switch (item.kind) {
                Kind.File => item.entry.file.size,
                Kind.Dir => item.entry.dir.total_size(),
            };
        }
        return total;
    }

    fn total_size_less_than(self: *Dir, max_size: usize) usize {
        var total: usize = 0;
        for (self.items.items) |item| {
            if (item.kind != Kind.Dir) continue;

            const dir = item.entry.dir;

            total += dir.total_size_less_than(max_size);

            const dir_size = dir.total_size();
            if (dir_size < max_size) {
                total += dir_size;
            }
        }

        return total;
    }

    fn deinit(self: *Dir) void {
        self.allocator.free(self.name);
        for (self.items.items) |item| {
            switch (item.kind) {
                Kind.File => item.entry.file.deinit(),
                Kind.Dir => item.entry.dir.deinit(),
            }
        }
        self.items.deinit();
        self.allocator.destroy(self);
    }
};

const File = struct {
    name: []u8,
    size: usize,
    parent: ?*Dir,
    allocator: mem.Allocator,

    fn init(allocator: mem.Allocator, name: []const u8, size: usize) !*File {
        var file = try allocator.create(File);
        file.allocator = allocator;
        file.size = size;
        file.name = try allocator.alloc(u8, name.len);
        mem.copy(u8, file.name, name);
        return file;
    }

    fn deinit(self: *File) void {
        self.allocator.free(self.name);
        self.allocator.destroy(self);
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

fn parseInput(filename: []const u8) !*Dir {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    const allocator = std.heap.page_allocator;
    var root = try Dir.init(allocator, "/");

    var working_directory = root;

    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var iterator = mem.split(u8, line, &[_]u8{' '});
        if (line[0] == '$') {
            _ = iterator.next();
            const cmd = if (iterator.next()) |e| e else unreachable;
            if (mem.eql(u8, cmd, "ls")) continue;

            const dir = if (iterator.next()) |e| e else unreachable;
            if (dir[0] == '/') continue;

            working_directory = try working_directory.cd(dir);
        } else {
            const part1 = if (iterator.next()) |e| e else unreachable;
            const part2 = if (iterator.next()) |e| e else unreachable;
            if (mem.eql(u8, part1, "dir")) {
                try working_directory.addDir(part2);
            } else {
                try working_directory.addFile(part2, try fmt.parseInt(u32, part1, 10));
            }
        }
    }

    return root;
}

fn solvePart1(filename: []const u8) !u64 {
    var root = try parseInput(filename);
    defer root.deinit();
    return root.total_size_less_than(100000);
}

fn solvePart2(filename: []const u8) !u64 {
    var root = try parseInput(filename);
    defer root.deinit();
    return try root.cleanup_space(30000000, 70000000);
}

test "part_1_test" {
    const filename = "data/input-test-7";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 95437), result);
}

test "part_1" {
    const filename = "data/input-7";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 1447046), result);
}

test "part_2_test" {
    const filename = "data/input-test-7";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 24933642), result);
}

test "part_2" {
    const filename = "data/input-7";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 578710), result);
}
