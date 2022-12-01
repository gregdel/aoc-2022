const std = @import("std");
const print = std.debug.print;
const process = std.process;
const heap = std.heap;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;

pub fn main() !void {
    var arena = heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator: mem.Allocator = arena.allocator();

    var arg_it = try process.argsWithAllocator(allocator);
    _ = arg_it.skip();

    const filename = arg_it.next() orelse {
        print("Missing filename\n", .{});
        return error.InvalidArgs;
    };

    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var max: u32 = 0;
    var current_sum: u32 = 0;

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            if (current_sum > max) {
                max = current_sum;
            }

            current_sum = 0;
            continue;
        }

        var value = try fmt.parseInt(u32, line, 10);
        current_sum += value;
    }

    print("Value: {d}\n", .{max});
}
