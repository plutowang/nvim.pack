const std = @import("std");
const zlap = @import("zlap");
const print = std.debug.print;

// =============================================================================
// Startup log parsing
// =============================================================================

const SourceEntry = struct {
    name: []u8,
    self_ms: f64,
    total_ms: f64,
};

const ParsedLog = struct {
    sources: std.ArrayList(SourceEntry),
    startup_ms: f64, // Clock time of last sourced entry (excludes settle sleep)
};

/// Internal lifecycle entries from --startuptime that we skip (they are Neovim
/// internals, not user plugin sources). Keeping them out of the breakdown keeps
/// the output focused on config/plugin load time.
const SKIP_PREFIXES = [_][]const u8{
    "event init",
    "early init",
    "locale set",
    "init first window",
    "inits 1",
    "inits 2",
    "window checked",
    "parsing arguments",
    "expanding arguments",
    "init lua interpreter",
    "init highlight",
    "clear screen",
    "entering main loop",
    "UIEnter",
    "BufReadPre",
    "BufNewFile",
};

fn parseStartupLog(allocator: std.mem.Allocator, log_path: []const u8) !?ParsedLog {
    const file = std.fs.cwd().openFile(log_path, .{}) catch |err| {
        print("Warning: could not open startup log: {}\n", .{err});
        return null;
    };
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(contents);

    var sources = std.ArrayList(SourceEntry){};
    var startup_ms: f64 = 0;
    var last_source_clock: f64 = 0;

    var line_iter = std.mem.splitSequence(u8, contents, "\n");
    while (line_iter.next()) |line| {
        // Skip header lines and empty lines
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "---")) continue;
        if (std.mem.startsWith(u8, line, "times")) continue;
        if (std.mem.startsWith(u8, line, " clock")) continue;

        // Find the colon that separates timing from source name
        const colon_pos = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const timing_part = line[0..colon_pos];
        const source_name = std.mem.trim(u8, line[colon_pos + 1 ..], " ");

        // Check for "--- NVIM STARTED ---" marker to extract total startup time
        if (std.mem.startsWith(u8, source_name, "--- NVIM STARTED")) {
            // The first numeric field is the clock time = total startup ms
            var fields = std.mem.splitSequence(u8, timing_part, "  ");
            while (fields.next()) |field| {
                if (field.len == 0) continue;
                startup_ms = std.fmt.parseFloat(f64, field) catch continue;
                break;
            }
            continue;
        }

        // Skip non-source entries (lifecycle events, etc.)
        if (std.mem.startsWith(u8, source_name, "---")) continue;
        var should_skip = false;
        for (SKIP_PREFIXES) |prefix| {
            if (std.mem.startsWith(u8, source_name, prefix)) {
                should_skip = true;
                break;
            }
        }
        if (should_skip) continue;

        // Parse timing fields from the timing part
        // Format: "  001.835  000.024  000.024" or "  130.922  062.198"
        var fields = std.mem.splitSequence(u8, timing_part, "  ");
        var field_count: usize = 0;
        var clock_ms: f64 = 0;
        var self_ms: f64 = 0;
        var total_ms: f64 = 0;
        while (fields.next()) |field| {
            if (field.len == 0) continue;
            const val = std.fmt.parseFloat(f64, field) catch continue;
            field_count += 1;
            if (field_count == 1) {
                clock_ms = val;
            } else if (field_count == 2) {
                total_ms = val;
            } else if (field_count == 3) {
                self_ms = val;
            }
        }

        // If only 2 fields, self_ms == total_ms
        if (field_count == 2) {
            self_ms = total_ms;
        }

        if (field_count >= 2 and source_name.len > 0) {
            const name_owned = try allocator.dupe(u8, source_name);
            try sources.append(allocator, .{
                .name = name_owned,
                .self_ms = self_ms,
                .total_ms = total_ms,
            });
            last_source_clock = clock_ms;
        }
    }

    // Prefer last source clock (excludes settle sleep) over NVIM STARTED (includes it)
    if (last_source_clock > 0) {
        startup_ms = last_source_clock;
    }

    return ParsedLog{
        .sources = sources,
        .startup_ms = startup_ms,
    };
}

// =============================================================================
// Benchmark runner
// =============================================================================

const BenchmarkResult = struct {
    wall_ms: f64,
    startup_ms: f64, // From --startuptime log (excludes settle sleep)
    startup_log_path: []u8,
};

fn ensureTmpDir() !void {
    std.fs.cwd().makeDir("tmp") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
}

fn createTempTestFile(allocator: std.mem.Allocator) ![]u8 {
    const tmp_dir = std.fs.cwd().openDir("tmp", .{}) catch {
        print("Error: could not open ./tmp directory\n", .{});
        return error.NoTmpDir;
    };
    const file = try tmp_dir.createFile("nvim_bench_test.lua", .{ .read = true, .truncate = true });
    defer file.close();
    try file.writeAll("-- Neovim startup benchmark test file\n");
    try file.writeAll("local x = 1\n");

    // Return absolute path so nvim's `edit` command works regardless of its cwd
    var abs_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try std.fs.cwd().realpath("tmp/nvim_bench_test.lua", &abs_buf);
    return try allocator.dupe(u8, abs_path);
}

fn runBenchmark(allocator: std.mem.Allocator, file_path: []const u8, settle_ms: u32, iteration: u32) !BenchmarkResult {
    // Create unique startup log path for this iteration (absolute path for nvim)
    var rel_buf: [128]u8 = undefined;
    const rel_log = try std.fmt.bufPrint(&rel_buf, "tmp/nvim_startup_{d}.log", .{iteration});
    var log_buf: [std.fs.max_path_bytes]u8 = undefined;
    // Touch the file first so realpath can resolve it
    const touch = try std.fs.cwd().createFile(rel_log, .{ .truncate = false });
    touch.close();
    const log_path = try std.fs.cwd().realpath(rel_log, &log_buf);

    // Build the nvim command:
    // nvim --headless --startuptime <log>
    //      -c "edit <file>"
    //      -c "doautocmd UIEnter"   <- triggers UIEnter-loaded plugins (heirline, which-key, etc.)
    //      -c "sleep <settle>m"
    //      -c "qa!"
    var settle_cmd_buf: [64]u8 = undefined;
    const settle_cmd = try std.fmt.bufPrint(&settle_cmd_buf, "sleep {d}m", .{settle_ms});

    var edit_cmd_buf: [512]u8 = undefined;
    const edit_cmd = try std.fmt.bufPrint(&edit_cmd_buf, "edit {s}", .{file_path});

    var child = std.process.Child.init(&.{
        "nvim",
        "--headless",
        "--startuptime",
        log_path,
        "-c",
        edit_cmd,
        "-c",
        "doautocmd UIEnter",
        "-c",
        settle_cmd,
        "-c",
        "qa!",
    }, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    const start_time = std.time.nanoTimestamp();

    try child.spawn();
    const term = try child.wait();

    const end_time = std.time.nanoTimestamp();

    switch (term) {
        .Exited => |code| {
            if (code != 0) return error.ProcessFailed;
        },
        else => return error.ProcessFailed,
    }

    const duration_ns = end_time - start_time;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;

    // Parse the startup log to get the actual startup time (excludes settle sleep)
    var startup_ms: f64 = duration_ms; // fallback to wall time if log parsing fails
    var parsed_opt = parseStartupLog(allocator, log_path) catch null;
    if (parsed_opt) |*parsed| {
        if (parsed.startup_ms > 0) {
            startup_ms = parsed.startup_ms;
        }
        // Free parsed source names
        for (parsed.sources.items) |entry| {
            allocator.free(entry.name);
        }
        parsed.sources.deinit(allocator);
    }

    return BenchmarkResult{
        .wall_ms = duration_ms,
        .startup_ms = startup_ms,
        .startup_log_path = try allocator.dupe(u8, log_path),
    };
}

// =============================================================================
// Statistics
// =============================================================================

fn calculateStats(times: []const f64, allocator: std.mem.Allocator) !void {
    if (times.len == 0) {
        print("No successful runs recorded\n", .{});
        return;
    }

    // Calculate mean
    var sum: f64 = 0;
    var min_time: f64 = times[0];
    var max_time: f64 = times[0];

    for (times) |time| {
        sum += time;
        if (time < min_time) min_time = time;
        if (time > max_time) max_time = time;
    }

    const mean = sum / @as(f64, @floatFromInt(times.len));

    // Calculate standard deviation
    var variance_sum: f64 = 0;
    for (times) |time| {
        const diff = time - mean;
        variance_sum += diff * diff;
    }
    const variance = variance_sum / @as(f64, @floatFromInt(times.len));
    const std_dev = @sqrt(variance);

    // Calculate median
    const sorted = try allocator.dupe(f64, times);
    defer allocator.free(sorted);
    std.mem.sort(f64, sorted, {}, comptime std.sort.asc(f64));

    const median = if (sorted.len % 2 == 0) blk: {
        const mid1 = sorted.len / 2 - 1;
        const mid2 = sorted.len / 2;
        break :blk (sorted[mid1] + sorted[mid2]) / 2.0;
    } else sorted[sorted.len / 2];

    // Print results
    print("\n==================================================\n", .{});
    print("NEOVIM STARTUP TIME ANALYSIS\n", .{});
    print("(last-source clock from --startuptime log, excludes settle sleep)\n", .{});
    print("Covers: immediate + VimEnter + BufReadPre + UIEnter\n", .{});
    print("==================================================\n", .{});
    print("Successful runs:  {d}\n", .{times.len});
    print("Average startup:  {d:.1} ms\n", .{mean});
    print("Median startup:   {d:.1} ms\n", .{median});
    print("Fastest startup:  {d:.1} ms\n", .{min_time});
    print("Slowest startup:  {d:.1} ms\n", .{max_time});
    print("Standard dev:     {d:.1} ms\n", .{std_dev});
    print("==================================================\n", .{});

    // Thresholds based on last-source clock (excludes settle sleep)
    if (mean <= 50.0) {
        print("EXCELLENT: {d:.1}ms -- fast and responsive!\n", .{mean});
    } else if (mean <= 80.0) {
        print("GOOD: {d:.1}ms -- reasonably fast\n", .{mean});
    } else if (mean <= 120.0) {
        print("FAIR: {d:.1}ms -- could be improved\n", .{mean});
    } else {
        print("SLOW: {d:.1}ms -- needs optimization\n", .{mean});
    }
}

fn printSourceBreakdown(sources: *std.ArrayList(SourceEntry), top_n: u32) void {
    if (sources.items.len == 0) return;

    // Sort by self_ms descending (slowest first)
    std.mem.sort(SourceEntry, sources.items, {}, struct {
        fn lessThan(_: void, a: SourceEntry, b: SourceEntry) bool {
            return a.self_ms > b.self_ms;
        }
    }.lessThan);

    const count = @min(top_n, @as(u32, @intCast(sources.items.len)));

    print("\n==================================================\n", .{});
    print("TOP {d} SLOWEST SOURCES (by self time)\n", .{count});
    print("==================================================\n", .{});
    print("  {s:<8}  {s:<50}  {s:<10}\n", .{ "self(ms)", "Source", "total(ms)" });
    print("  {s:<8}  {s:<50}  {s:<10}\n", .{ "--------", "--------------------------------------------------", "----------" });

    for (sources.items[0..count]) |entry| {
        print("  {d:>8.2}  {s:<50}  {d:>8.2}\n", .{ entry.self_ms, entry.name, entry.total_ms });
    }
    print("==================================================\n", .{});
}

// =============================================================================
// Handler
// =============================================================================

pub fn handler(parser: *zlap.Parser) zlap.ParseError!void {
    const allocator = parser.allocator;

    // Parse --file option
    const file_path_opt = parser.getOption("file");
    const file_path = if (file_path_opt) |p| try allocator.dupe(u8, p) else &.{};
    defer if (file_path.len > 0) allocator.free(file_path);

    // Parse --iterations option
    const iterations_str = parser.getOption("iterations") orelse "30";
    const iterations = std.fmt.parseInt(u32, iterations_str, 10) catch {
        parser.logger.err("Invalid number for --iterations: '{s}'", .{iterations_str});
        return error.UnknownOption;
    };

    // Parse --settle option
    const settle_str = parser.getOption("settle") orelse "200";
    const settle_ms = std.fmt.parseInt(u32, settle_str, 10) catch {
        parser.logger.err("Invalid number for --settle: '{s}'", .{settle_str});
        return error.UnknownOption;
    };

    // Parse --warmup option
    const warmup_str = parser.getOption("warmup") orelse "3";
    const warmup = std.fmt.parseInt(u32, warmup_str, 10) catch {
        parser.logger.err("Invalid number for --warmup: '{s}'", .{warmup_str});
        return error.UnknownOption;
    };

    // Parse --top option
    const top_str = parser.getOption("top") orelse "15";
    const top_n = std.fmt.parseInt(u32, top_str, 10) catch {
        parser.logger.err("Invalid number for --top: '{s}'", .{top_str});
        return error.UnknownOption;
    };

    // Ensure ./tmp/ exists for scratch files (logs, test file).
    ensureTmpDir() catch |err| {
        parser.logger.err("Could not create ./tmp directory: {}", .{err});
        return;
    };

    // Determine the test file path
    var own_test_file = false;
    const test_file_path: []const u8 = if (file_path.len > 0) file_path else blk: {
        const created = createTempTestFile(allocator) catch |err| {
            parser.logger.err("Error creating temp test file: {}", .{err});
            return;
        };
        own_test_file = true;
        break :blk created;
    };
    defer if (own_test_file) allocator.free(test_file_path);

    print("Neovim Startup Benchmark\n", .{});
    print("  Test file:     {s}\n", .{test_file_path});
    print("  Iterations:    {d} (+ {d} warmup)\n", .{ iterations, warmup });
    print("  Settle time:   {d}ms\n", .{settle_ms});
    print("  Top sources:   {d}\n\n", .{top_n});

    // Warmup phase
    if (warmup > 0) {
        print("Warming up ({d} iterations)...\n", .{warmup});
        var i: u32 = 0;
        while (i < warmup) : (i += 1) {
            const result = runBenchmark(allocator, test_file_path, settle_ms, 999_900 + i) catch {
                print("  Warmup {d} failed\n", .{i + 1});
                continue;
            };
            allocator.free(result.startup_log_path);
        }
        print("Warmup complete.\n\n", .{});
    }

    // Benchmark iterations
    print("Running {d} benchmark iterations...\n\n", .{iterations});

    var times = std.ArrayList(f64){};
    defer times.deinit(allocator);

    var last_log_path: ?[]u8 = null;
    var i: u32 = 0;
    var failures: u32 = 0;

    while (i < iterations) : (i += 1) {
        if (iterations > 5 and (i + 1) % 5 == 0) {
            print("  Progress: {d}/{d}\n", .{ i + 1, iterations });
        }

        const result = runBenchmark(allocator, test_file_path, settle_ms, i) catch {
            failures += 1;
            continue;
        };

        // Free previous log path before overwriting
        if (last_log_path) |old_path| {
            allocator.free(old_path);
        }

        try times.append(allocator, result.startup_ms);
        last_log_path = result.startup_log_path;
    }

    if (failures > 0) {
        print("\n  {d} iteration(s) failed\n", .{failures});
    }

    // Calculate and print aggregate stats
    try calculateStats(times.items, allocator);

    // Parse and print per-source breakdown from the last successful run's startup log
    if (last_log_path) |log_path| {
        var parsed_opt = parseStartupLog(allocator, log_path) catch null;
        if (parsed_opt) |*parsed| {
            defer {
                for (parsed.sources.items) |entry| {
                    allocator.free(entry.name);
                }
                parsed.sources.deinit(allocator);
            }
            printSourceBreakdown(&parsed.sources, top_n);
        }
        allocator.free(log_path);
    }

    // Cleanup test file if we created it
    if (own_test_file) {
        std.fs.cwd().deleteFile("tmp/nvim_bench_test.lua") catch {};
    }

    // Clean up startup log files
    var log_i: u32 = 0;
    while (log_i < iterations) : (log_i += 1) {
        var log_buf: [256]u8 = undefined;
        const log_path = std.fmt.bufPrint(&log_buf, "tmp/nvim_startup_{d}.log", .{log_i}) catch continue;
        std.fs.cwd().deleteFile(log_path) catch {};
    }
    // Also clean up warmup logs
    var warmup_i: u32 = 0;
    while (warmup_i < warmup) : (warmup_i += 1) {
        var log_buf: [256]u8 = undefined;
        const log_path = std.fmt.bufPrint(&log_buf, "tmp/nvim_startup_{d}.log", .{999_900 + warmup_i}) catch continue;
        std.fs.cwd().deleteFile(log_path) catch {};
    }
}
