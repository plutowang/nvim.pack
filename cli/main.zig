const std = @import("std");
const zlap = @import("zlap");
const link_cmd = @import("commands/link.zig");
const bench_cmd = @import("commands/bench.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var logger = zlap.Logger{};

    var parser = zlap.Parser.init(
        allocator,
        "nvim-pack",
        "Neovim configuration management tool (vim.pack)",
        &logger,
    );
    defer parser.deinit();

    {
        const link_sub = try parser.subCommand("link", "Link nvim config resources to ~/.config/nvim", link_cmd.handler);
        _ = link_sub.flag('d', "dry-run", "Preview changes without executing");
    }

    {
        const bench_sub = try parser.subCommand("bench", "Benchmark Neovim startup time", bench_cmd.handler);
        _ = bench_sub.option('f', "file", "File to open in Neovim (default: temp .lua file)", "PATH")
            .optionWithDefault('i', "iterations", "Number of benchmark iterations", "N", "30")
            .optionWithDefault('s', "settle", "Milliseconds to wait for async ops", "MS", "200")
            .optionWithDefault('w', "warmup", "Warmup iterations to discard", "N", "3")
            .optionWithDefault('t', "top", "Number of slowest sources to show", "N", "15");
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try parser.parse(args);
    try parser.execute();
}
