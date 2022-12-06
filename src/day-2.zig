const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;
const testing = std.testing;
const aoc = @import("lib/aoc.zig");

const Move = enum { Rock, Paper, Scissor };
const Outcome = enum { Win, Lose, Draw };

const Round = struct {
    opponent: Move,
    myself: Move,
    expected_outcome: Outcome,
};

const ParseError = error{InvalidInput};

fn parseMove(input: u8) ParseError!Move {
    return switch (input) {
        'A', 'X' => Move.Rock,
        'B', 'Y' => Move.Paper,
        'C', 'Z' => Move.Scissor,
        else => ParseError.InvalidInput,
    };
}

fn parseOutcome(input: u8) ParseError!Outcome {
    return switch (input) {
        'X' => Outcome.Lose,
        'Y' => Outcome.Draw,
        'Z' => Outcome.Win,
        else => ParseError.InvalidInput,
    };
}

fn getOutcome(round: Round) Outcome {
    if (round.myself == round.opponent) {
        return Outcome.Draw;
    }

    if (((@enumToInt(round.opponent) + 1) % 3) == @enumToInt(round.myself)) {
        return Outcome.Win;
    }

    return Outcome.Lose;
}

fn roundScore(round: Round) u64 {
    var score: u64 = switch (round.myself) {
        Move.Rock => 1,
        Move.Paper => 2,
        Move.Scissor => 3,
    };

    score += switch (getOutcome(round)) {
        Outcome.Lose => 0,
        Outcome.Draw => 3,
        Outcome.Win => 6,
    };

    return score;
}

fn getMove(opponent_move: Move, expected_outcome: Outcome) Move {
    var m: u8 = @enumToInt(opponent_move);
    return switch (expected_outcome) {
        Outcome.Draw => opponent_move,
        Outcome.Win => @intToEnum(Move, (m + 1) % 3),
        Outcome.Lose => @intToEnum(Move, (m + 2) % 3),
    };
}

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

fn solvePart1(filename: ([:0]const u8)) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var result: u64 = 0;
    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len != 3) continue;
        var round: Round = undefined;
        round.opponent = try parseMove(line[0]);
        round.myself = try parseMove(line[2]);
        result += roundScore(round);
    }

    return result;
}

fn solvePart2(filename: ([:0]const u8)) !u64 {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var result: u64 = 0;
    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len != 3) continue;
        var round: Round = undefined;
        round.opponent = try parseMove(line[0]);
        round.expected_outcome = try parseOutcome(line[2]);
        round.myself = getMove(round.opponent, round.expected_outcome);
        result += roundScore(round);
    }

    return result;
}

test "part_1_test" {
    const filename = "data/input-test-2";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 15), result);
}

test "part_1" {
    const filename = "data/input-2";
    const result: u64 = try solvePart1(filename);
    try testing.expectEqual(@as(u64, 12156), result);
}

test "part_2_test" {
    const filename = "data/input-test-2";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 12), result);
}

test "part_2" {
    const filename = "data/input-2";
    const result: u64 = try solvePart2(filename);
    try testing.expectEqual(@as(u64, 10835), result);
}
