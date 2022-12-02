const std = @import("std");
const print = std.debug.print;
const process = std.process;
const fmt = std.fmt;
const heap = std.heap;
const mem = std.mem;

const Cmd = struct {
    filename: [:0]const u8,
    part: u8,
};

pub fn parseCmdLine() anyerror!Cmd {
    var arena = heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator: mem.Allocator = arena.allocator();

    var arg_it = try process.argsWithAllocator(allocator);
    _ = arg_it.skip();

    const part = arg_it.next() orelse {
        print("Missing day part\n", .{});
        return error.InvalidArgs;
    };

    const filename = arg_it.next() orelse {
        print("Missing filename\n", .{});
        return error.InvalidArgs;
    };

    var cmd: Cmd = undefined;
    cmd.filename = filename;
    cmd.part = try fmt.parseInt(u8, part, 10);

    return cmd;
}
