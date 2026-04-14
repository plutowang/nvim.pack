const std = @import("std");
const fs = std.fs;
const zlap = @import("zlap");

/// Backs up an existing file or directory by renaming it with a timestamp suffix.
/// Returns true if a backup was made, false if the path didn't exist or was a symlink.
pub fn backup(file_path: []const u8, allocator: std.mem.Allocator, logger: *zlap.Logger) !bool {
    const work_dir = fs.cwd();
    const file = work_dir.openFile(file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close();

    const stat = file.stat() catch return false;
    if (stat.kind == .sym_link) {
        return false;
    }

    const ts = std.time.timestamp();
    const backup_path = try std.fmt.allocPrint(allocator, "{s}.backup.{d}", .{ file_path, ts });
    defer allocator.free(backup_path);

    try work_dir.rename(file_path, backup_path);
    logger.info("Backed up existing {s} to {s}", .{ file_path, backup_path });

    return true;
}

/// Verifies that `dir_path` is a real directory (not a symlink).
/// Returns `true` if it's a real directory, `false` if it doesn't exist.
/// Returns an error if the path is a symlink or a regular file.
pub fn verifyIsRealDirectory(dir_path: []const u8) !bool {
    const work_dir = fs.cwd();

    // Check if the path is a symlink first (readLink does not follow symlinks)
    var link_buffer: [std.fs.max_path_bytes]u8 = undefined;
    if (work_dir.readLink(dir_path, &link_buffer)) |_| {
        // It's a symlink — this is unsafe for our use case
        return error.IsSymlink;
    } else |err| switch (err) {
        error.FileNotFound, error.NotLink => {},
        else => return err,
    }

    // Check if the path exists
    work_dir.access(dir_path, .{}) catch {
        // Path doesn't exist
        return false;
    };

    // Path exists and is not a symlink — verify it's a directory
    var dir = work_dir.openDir(dir_path, .{}) catch {
        // Exists but can't open as directory — it's a regular file
        return error.NotADirectory;
    };
    defer dir.close();

    return true;
}

/// Creates a symbolic link at `target_path` pointing to `source_path`.
/// If `target_path` already points to `source_path`, reports it as already linked.
/// If `target_path` is a different symlink, replaces it.
/// If `target_path` is a regular file/directory, backs it up first.
///
/// **Safety guard**: Before performing any destructive operation (backup, delete, symlink),
/// this function verifies that the target path's parent directory is a real directory
/// (not a symlink). This prevents operations from following a symlinked parent into an
/// unintended directory, which could corrupt files outside the config directory.
pub fn createSymlink(
    source_path: []const u8,
    target_path: []const u8,
    name: []const u8,
    allocator: std.mem.Allocator,
    logger: *zlap.Logger,
) !void {
    logger.info("Setting up {s}", .{name});

    const work_dir = fs.cwd();

    work_dir.access(source_path, .{}) catch {
        logger.err("Source does not exist: {s}", .{source_path});
        return error.SourceNotFound;
    };

    // Safety guard: verify the target's parent directory is a real directory,
    // not a symlink. This prevents us from operating through a symlinked parent
    // and corrupting files in an unintended directory.
    if (std.fs.path.dirname(target_path)) |parent_dir| {
        const is_real_dir = verifyIsRealDirectory(parent_dir) catch |err| {
            logger.err("Target parent directory is not a real directory: {s} (error: {})", .{ parent_dir, err });
            logger.err("This usually means {s} is a symlink. Run 'nvim-pack link' to fix this.", .{parent_dir});
            return err;
        };
        if (!is_real_dir) {
            // Parent directory doesn't exist — create it
            work_dir.makePath(parent_dir) catch |err| switch (err) {
                error.PathAlreadyExists => {},
                else => return err,
            };
        }
    }

    var link_buffer: [std.fs.max_path_bytes]u8 = undefined;
    if (work_dir.readLink(target_path, &link_buffer)) |current_target| {
        if (std.mem.eql(u8, current_target, source_path)) {
            logger.success("{s}: already linked - {s} -> {s}", .{ name, target_path, source_path });
            return;
        }

        logger.warning("Replacing existing symlink: {s} -> {s}", .{ target_path, current_target });
        try work_dir.deleteFile(target_path);
    } else |err| switch (err) {
        error.FileNotFound => {},
        error.NotLink => {
            _ = try backup(target_path, allocator, logger);
        },
        else => return err,
    }

    try work_dir.symLink(source_path, target_path, .{});
    logger.success("{s}: linked - {s} -> {s}", .{ name, target_path, source_path });
}

/// Ensures `dir_path` exists as a real directory (not a symlink).
/// If `dir_path` is a symlink, removes it and creates a real directory.
/// If `dir_path` is a regular directory, does nothing.
/// If `dir_path` doesn't exist, creates it.
/// Returns true if a symlink was replaced, false otherwise.
pub fn ensureRealDirectory(
    dir_path: []const u8,
    logger: *zlap.Logger,
) !bool {
    const work_dir = fs.cwd();

    // First, check if the path is a symlink (readLink does not follow symlinks)
    var link_buffer: [std.fs.max_path_bytes]u8 = undefined;
    if (work_dir.readLink(dir_path, &link_buffer)) |link_target| {
        // It's a symlink — remove it and create a real directory
        logger.info("Removing existing symlink: {s} -> {s}", .{ dir_path, link_target });
        try work_dir.deleteFile(dir_path);
        try work_dir.makePath(dir_path);
        logger.info("Created directory: {s}", .{dir_path});
        return true;
    } else |err| switch (err) {
        error.FileNotFound, error.NotLink => {
            // Not a symlink — check if it exists as a directory or doesn't exist
            work_dir.access(dir_path, .{}) catch {
                // Path doesn't exist — create the directory
                try work_dir.makePath(dir_path);
                logger.info("Created directory: {s}", .{dir_path});
                return false;
            };

            // Path exists and is not a symlink — verify it's actually a directory
            var dir = work_dir.openDir(dir_path, .{}) catch {
                // Exists but not a directory — treat as needing creation
                // (backup should have been handled by the caller or createSymlink)
                try work_dir.makePath(dir_path);
                logger.info("Created directory: {s}", .{dir_path});
                return false;
            };
            defer dir.close();
            const stat = dir.stat() catch {
                // Can't stat — assume it's a directory and proceed
                return false;
            };
            if (stat.kind == .directory) {
                // Already a real directory — nothing to do
                return false;
            }
            // It's a regular file or something else — can't proceed
            return error.NotADirectory;
        },
        else => return err,
    }
}
