const std = @import("std");

const Day = struct {
    number: usize,
    name: []u8,
    src_path: []u8,
    input_path: []u8,
    input_test_path: []u8,
    const Self = @This();

    fn init(allocator: std.mem.Allocator, name: []const u8) !*Self {
        var day = try allocator.create(Self);

        var iterator = std.mem.tokenize(u8, name, &[_]u8{ '-', '.' });
        _ = iterator.next();
        day.number = if (iterator.next()) |item| try std.fmt.parseInt(u8, item, 10) else unreachable;
        day.name = try std.fmt.allocPrint(allocator, "day-{d}", .{day.number});
        day.src_path = try std.fmt.allocPrint(allocator, "./src/day-{d}.zig", .{day.number});
        day.input_path = try std.fmt.allocPrint(allocator, "./data/input-{d}", .{day.number});
        day.input_test_path = try std.fmt.allocPrint(allocator, "./data/input-test-{d}", .{day.number});

        return day;
    }

    fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.src_path);
        allocator.free(self.input_path);
        allocator.free(self.input_test_path);
        allocator.destroy(self);
    }
};

pub fn build(b: *std.build.Builder) !void {
    const allocator = b.allocator;

    var dir = try std.fs.cwd().openIterableDir("./src", .{});
    defer dir.close();
    var iter = dir.iterate();
    while (try iter.next()) |item| {
        if (item.kind != std.fs.IterableDir.Entry.Kind.File) continue;
        var day = try Day.init(allocator, item.name);
        defer day.deinit(allocator);

        const exec = b.addExecutable(day.name, day.src_path);
        exec.install();

        const parts: [2][]const u8 = .{ "1", "2" };
        for (parts) |part| {
            const run_step = b.step(b.fmt("run-day-{d}-{s}", .{ day.number, part }), b.fmt(
                "Run day {d} part {s}",
                .{
                    day.number,
                    part,
                },
            ));

            const run = exec.run();
            run.addArgs(&[2][]const u8{ part, day.input_path });
            run_step.dependOn(&run.step);

            const run_example_step = b.step(b.fmt("run-day-{d}-{s}-example", .{ day.number, part }), b.fmt(
                "Run the example for day {d} part {s}",
                .{
                    day.number,
                    part,
                },
            ));

            const run_example = exec.run();
            run_example.addArgs(&[2][]const u8{ part, day.input_test_path });
            run_example_step.dependOn(&run_example.step);
        }

        const exec_tests = b.addTest(day.src_path);
        const test_step = b.step(b.fmt("test-day-{d}", .{day.number}), b.fmt(
            "Run tests for day {d}",
            .{day.number},
        ));
        test_step.dependOn(&exec_tests.step);
    }

    // TODO: add a function run the tests for every day
    const test_all = b.step("test-all", "Run all the tests");
    _ = test_all;
}
