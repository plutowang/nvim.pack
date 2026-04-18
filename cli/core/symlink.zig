const std = @import("std");
const fs = std.fs;
const Io = std.Io;

const zlap = @import("zlap");

/// Backs up an existing file or directory by renaming it with a timestamp suffix.
/// Returns true if a backup was made, false if the path didn't exist or was a symlink.
pub fn backup(io: Io, log: *zlap.Logger, allocator: std.mem.Allocator, file_path: []const u8) !bool {
    const work_dir = Io.Dir.cwd();
    const file = work_dir.openFile(io, file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close(io);

    const stat = file.stat(io) catch return false;
    if (stat.kind == .sym_link) {
        return false;
    }

    const now = Io.Clock.real.now(io);
    const ts = now.toNanoseconds();
    const backup_path = try std.fmt.allocPrint(allocator, "{s}.backup.{d}", .{ file_path, ts });
    defer allocator.free(backup_path);

    try work_dir.rename(file_path, work_dir, backup_path, io);
    log.info("Backed up existing {s} to {s}", .{ file_path, backup_path });

    return true;
}

/// Verifies that `dir_path` is a real directory (not a symlink).
/// Returns `true` if it's a real directory, `false` if it doesn't exist.
/// Returns an error if the path is a symlink or a regular file.
pub fn verifyIsRealDirectory(io: Io, dir_path: []const u8) !bool {
    const work_dir = Io.Dir.cwd();

    // Check if the path is a symlink first (readLink does not follow symlinks)
    var link_buffer: [fs.max_path_bytes]u8 = undefined;
    if (work_dir.readLink(io, dir_path, &link_buffer)) |_| {
        // It's a symlink — this is unsafe for our use case
        return error.IsSymlink;
    } else |err| switch (err) {
        error.FileNotFound, error.NotLink => {},
        else => return err,
    }

    // Check if the path exists
    work_dir.access(io, dir_path, .{}) catch {
        // Path doesn't exist
        return false;
    };

    // Path exists and is not a symlink — verify it's a directory
    var dir = work_dir.openDir(io, dir_path, .{}) catch {
        // Exists but can't open as directory — it's a regular file
        return error.NotADirectory;
    };
    defer dir.close(io);

    return true;
}

/// Creates a symbolic link at `target_path` pointing to `source_path`.
/// If `target_path` already points to `source_path`, reports it as already linked.
/// If `target_path` is a different symlink, replaces it.
/// If `target_path` is a regular file/directory, backs it up first.
pub fn createSymlink(
    io: Io,
    source_path: []const u8,
    target_path: []const u8,
    name: []const u8,
    allocator: std.mem.Allocator,
    dry_run: bool,
    log: *zlap.Logger,
) !void {
    log.info("Setting up {s}", .{name});

    const work_dir = Io.Dir.cwd();

    // Verify source exists
    work_dir.access(io, source_path, .{}) catch {
        log.err("Source does not exist: {s}", .{source_path});
        return error.SourceNotFound;
    };

    if (dry_run) {
        log.info("Would link: {s} -> {s}", .{ target_path, source_path });
        return;
    }

    // Safety guard: verify the target's parent directory is a real directory
    if (fs.path.dirname(target_path)) |parent_dir| {
        const is_real_dir = verifyIsRealDirectory(io, parent_dir) catch |err| {
            log.err("Target parent directory is not a real directory: {s} (error: {s})", .{ parent_dir, @errorName(err) });
            return err;
        };
        if (!is_real_dir) {
            // Parent directory doesn't exist — create it
            work_dir.createDirPath(io, parent_dir) catch |err| switch (err) {
                error.PathAlreadyExists => {},
                else => return err,
            };
        }
    }

    var link_buffer: [fs.max_path_bytes]u8 = undefined;
    if (work_dir.readLink(io, target_path, &link_buffer)) |len| {
        const current_target = link_buffer[0..len];
        if (std.mem.eql(u8, current_target, source_path)) {
            log.success("{s}: already linked - {s} -> {s}", .{ name, target_path, source_path });
            return;
        }

        log.warning("Replacing existing symlink: {s} -> {s}", .{ target_path, current_target });
        try work_dir.deleteFile(io, target_path);
    } else |err| switch (err) {
        error.FileNotFound => {},
        error.NotLink => {
            _ = try backup(io, log, allocator, target_path);
        },
        else => return err,
    }

    try work_dir.symLink(io, source_path, target_path, .{});
    log.success("{s}: linked - {s} -> {s}", .{ name, target_path, source_path });
}

/// Ensures `dir_path` exists as a real directory (not a symlink).
/// If `dir_path` is a symlink, removes it and creates a real directory.
/// If `dir_path` is a regular directory, does nothing.
/// If `dir_path` doesn't exist, creates it.
/// Returns true if a symlink was replaced, false otherwise.
pub fn ensureRealDirectory(
    io: Io,
    dir_path: []const u8,
    log: *zlap.Logger,
) !bool {
    const work_dir = Io.Dir.cwd();

    // First, check if the path is a symlink (readLink does not follow symlinks)
    var link_buffer: [fs.max_path_bytes]u8 = undefined;
    if (work_dir.readLink(io, dir_path, &link_buffer)) |len| {
        const link_target = link_buffer[0..len];
        // It's a symlink — remove it and create a real directory
        log.info("Removing existing symlink: {s} -> {s}", .{ dir_path, link_target });
        try work_dir.deleteFile(io, dir_path);
        try work_dir.createDirPath(io, dir_path);
        log.info("Created directory: {s}", .{dir_path});
        return true;
    } else |err| switch (err) {
        error.FileNotFound, error.NotLink => {
            // Not a symlink — check if it exists as a directory or doesn't exist
            work_dir.access(io, dir_path, .{}) catch {
                // Path doesn't exist — create the directory
                try work_dir.createDirPath(io, dir_path);
                log.info("Created directory: {s}", .{dir_path});
                return false;
            };

            // Path exists and is not a symlink — verify it's actually a directory
            var dir = work_dir.openDir(io, dir_path, .{}) catch {
                // Exists but not a directory — treat as needing creation
                try work_dir.createDirPath(io, dir_path);
                log.info("Created directory: {s}", .{dir_path});
                return false;
            };
            defer dir.close(io);
            const stat = dir.stat(io) catch {
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