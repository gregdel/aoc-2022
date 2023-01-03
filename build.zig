const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const time = std.time;
const print = std.debug.print;
const Step = std.build.Step;
const Builder = std.build.Builder;
const ArrayList = std.ArrayList;

// This script should
// - build all binaries in super fast native ++
// - run all the tests
// - start all the binaries for day 1 and day 2 seperately

const Day = struct {
    number: usize,
    name: []u8,
    src_path: []u8,
    input_path: []u8,
    input_test_path: []u8,
    const Self = @This();

    fn init(allocator: mem.Allocator, name: []const u8) !*Self {
        var day = try allocator.create(Self);

        var iterator = mem.tokenize(u8, name, &[_]u8{ '-', '.' });
        _ = iterator.next();
        day.number = if (iterator.next()) |item| try fmt.parseInt(u8, item, 10) else unreachable;
        day.name = try fmt.allocPrint(allocator, "day-{d}", .{day.number});
        day.src_path = try fmt.allocPrint(allocator, "./src/day-{d}.zig", .{day.number});
        day.input_path = try fmt.allocPrint(allocator, "./data/input-{d}", .{day.number});
        day.input_test_path = try fmt.allocPrint(allocator, "./data/input-test-{d}", .{day.number});

        return day;
    }

    fn setup(self: *Day, b: *Builder) void {
        const exec = b.addExecutable(self.name, self.src_path);
        exec.install();

        const parts: [2][]const u8 = .{ "1", "2" };
        for (parts) |part| {
            const run = exec.run();
            run.addArgs(&[2][]const u8{ part, self.input_path });
            const run_timer = TimerStep.init(b, &run.step);

            const run_step = b.step(
                b.fmt("run-day-{d}-{s}", .{ self.number, part }),
                b.fmt("Run day {d} part {s}", .{ self.number, part }),
            );

            run_step.dependOn(b.getInstallStep());
            run_step.dependOn(&run_timer.step);

            const run_example_step = b.step(
                b.fmt("run-day-{d}-{s}-example", .{ self.number, part }),
                b.fmt("Run the example for day {d} part {s}", .{ self.number, part }),
            );

            const run_example = exec.run();
            run_example.addArgs(&[2][]const u8{ part, self.input_test_path });
            run_example_step.dependOn(&run_example.step);
        }

        const test_name = b.fmt("test-day-{d}", .{self.number});
        const test_step = b.step(test_name, b.fmt(
            "Run tests for day {d}",
            .{self.number},
        ));

        const tests = &b.addTest(self.src_path).step;
        const test_wrapper = TimerStep.init(b, tests);

        test_step.dependOn(&test_wrapper.step);
    }

    fn deinit(self: *Self, allocator: mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.src_path);
        allocator.free(self.input_path);
        allocator.free(self.input_test_path);
        allocator.destroy(self);
    }
};

const TimerStep = struct {
    step: Step,
    wrapped_step: *Step,

    fn init(b: *Builder, step: *Step) *TimerStep {
        const self = b.allocator.create(TimerStep) catch unreachable;
        const name = b.fmt("[timer] {s}", .{step.name});
        self.* = .{
            .wrapped_step = step,
            .step = Step.init(.custom, name, b.allocator, make),
        };
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(TimerStep, "step", step);
        print("Testing {s}...\n", .{self.wrapped_step.name});

        const start = try time.Instant.now();
        try self.wrapped_step.make();
        const stop = try time.Instant.now();
        const duration_ns = stop.since(start);

        print("{s} done in {d}ms\n", .{
            self.wrapped_step.name,
            @divFloor(duration_ns, time.ns_per_ms),
        });
    }
};

pub fn build(b: *Builder) !void {
    const allocator = b.allocator;

    b.setPreferredReleaseMode(.ReleaseFast);

    // var test_list = ArrayList(*TimerStep).init(allocator);
    // defer test_list.deinit();

    var dir = try fs.cwd().openIterableDir("./src", .{});
    defer dir.close();
    var iter = dir.iterate();
    while (try iter.next()) |item| {
        if (item.kind != .File) continue;
        var day = try Day.init(allocator, item.name);
        defer day.deinit(allocator);
        day.setup(b);
    }

    // const test_all = b.step("test-all", "Run all the tests");
    // for (test_list.items) |wrapper| {
    //     test_all.dependOn(&wrapper.step);
    // }
}
