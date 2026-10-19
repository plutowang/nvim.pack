const std = @import("std");
const fs = std.fs;
const Io = std.Io;

const zlap = @import("zlap");
const symlink = @import("../core/symlink.zig");
const context = @import("../core/context.zig");

/// Resource definition: a file or directory in the project root to link into ~/.config/nvim/.
const Resource = struct {
    /// Path relative to the project root (e.g., "init.lua", "lua")
    source: []const u8,
    /// Name displayed in logs
    name: []const u8,
};

const RESOURCES = [_]Resource{
    .{ .source = "init.lua", .name = "Neovim init.lua" },
    .{ .source = "lua", .name = "Neovim lua modules" },
    .{ .source = "nvim-pack-lock.json", .name = "Neovim pack lock file" },
};

pub fn handler(parser: *zlap.Parser) zlap.ParseError!void {
    const allocator = parser.allocator;
    const io = context.init.io;
    const dry_run = parser.getFlag("dry-run");

    if (dry_run) {
        parser.logger.info("DRY RUN MODE - No changes will be made", .{});
        std.debug.print("\n", .{});
    }

    parser.logger.info("Starting nvim.pack link setup...", .{});
    std.debug.print("\n", .{});

    const home_dir = context.init.environ_map.get("HOME") orelse {
        parser.logger.err("Error: HOME environment variable not set", .{});
        return;
    };

    // Determine the project root directory (current working directory)
    const base_dir = std.process.currentPathAlloc(io, allocator) catch |err| {
        parser.logger.err("Failed to get current directory: {}", .{err});
        return;
    };
    defer allocator.free(base_dir);

    // Verify that the required resources exist in the project root
    verifyResources(io, base_dir, allocator) catch {
        parser.logger.err("Please run this program from the nvim.pack directory or install it properly", .{});
        return;
    };

    const nvim_config_path = try fs.path.join(allocator, &.{ home_dir, ".config", "nvim" });
    defer allocator.free(nvim_config_path);

    // Handle the three cases for ~/.config/nvim
    if (dry_run) {
        // In dry-run mode, just report what would happen
        var link_buffer: [fs.max_path_bytes]u8 = undefined;
        const work_dir = Io.Dir.cwd();
        const existing = work_dir.readLink(io, nvim_config_path, &link_buffer);
        if (existing) |len| {
            const target = link_buffer[0..len];
            parser.logger.info("Would replace symlink: {s} -> {s}", .{ nvim_config_path, target });
            parser.logger.info("Would create directory: {s}", .{nvim_config_path});
        } else |_| {
            const dir_accessible = work_dir.access(io, nvim_config_path, .{}) catch null;
            if (dir_accessible != null) {
                parser.logger.info("Would backup existing directory: {s}", .{nvim_config_path});
            } else {
                parser.logger.info("Would create directory: {s}", .{nvim_config_path});
            }
        }

        for (RESOURCES) |resource| {
            const source_path = try fs.path.join(allocator, &.{ base_dir, resource.source });
            defer allocator.free(source_path);
            const target_path = try fs.path.join(allocator, &.{ nvim_config_path, resource.source });
            defer allocator.free(target_path);

            parser.logger.info("Would link: {s} -> {s}", .{ target_path, source_path });
        }

        parser.logger.success("Dry run complete - link setup preview finished", .{});
        return;
    }

    // Ensure ~/.config/nvim is a real directory (handle symlink/backup cases)
    const replaced_symlink = symlink.ensureRealDirectory(io, nvim_config_path, parser.logger) catch |err| {
        parser.logger.err("Failed to prepare ~/.config/nvim: {}", .{err});
        return;
    };

    // Safety verification: confirm ~/.config/nvim is now a real directory (not a symlink).
    const is_real_dir = symlink.verifyIsRealDirectory(io, nvim_config_path) catch |err| {
        parser.logger.err("~/.config/nvim is not a real directory: {}", .{err});
        parser.logger.err("This usually means ~/.config/nvim is a symlink. Run 'nvim-pack link' again to fix this.", .{});
        return;
    };
    if (!is_real_dir) {
        parser.logger.err("~/.config/nvim does not exist after setup", .{});
        return;
    }

    if (replaced_symlink) {
        std.debug.print("\n", .{});
    } else {
        std.debug.print("\n", .{});
    }

    // Link each resource into ~/.config/nvim/
    var success_count: usize = 0;
    for (RESOURCES) |resource| {
        const source_path = fs.path.join(allocator, &.{ base_dir, resource.source }) catch |err| {
            parser.logger.err("Failed to construct source path: {}", .{err});
            continue;
        };
        defer allocator.free(source_path);

        const target_path = fs.path.join(allocator, &.{ nvim_config_path, resource.source }) catch |err| {
            parser.logger.err("Failed to construct target path: {}", .{err});
            continue;
        };
        defer allocator.free(target_path);

        symlink.createSymlink(io, source_path, target_path, resource.name, allocator, dry_run, parser.logger) catch |err| {
            parser.logger.err("Failed to link {s}: {}", .{ resource.name, err });
            continue;
        };
        success_count += 1;
        std.debug.print("\n", .{});
    }

    if (success_count > 0) {
        parser.logger.success("nvim.pack link setup complete! ({d}/{d} resources linked)", .{ success_count, RESOURCES.len });
        parser.logger.info("Please restart Neovim to apply changes", .{});
    } else {
        parser.logger.warning("No resources were linked.", .{});
    }
}

fn verifyResources(io: Io, base_dir: []const u8, allocator: std.mem.Allocator) !void {
    const work_dir = Io.Dir.cwd();
    for (RESOURCES) |resource| {
        const path = try fs.path.join(allocator, &.{ base_dir, resource.source });
        defer allocator.free(path);
        try work_dir.access(io, path, .{});
    }
}