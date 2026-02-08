// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath
//! WebAssembly System Interface (WASI) ABI
//!
//! This module provides WASI-specific functionality for running
//! Idris 2 code in WASI-compatible runtimes (Wasmtime, Wasmer,
//! Node.js WASI, Deno, edge runtimes, etc.)
//!
//! WASI provides a standardized system interface including:
//! - File system access
//! - Environment variables
//! - Command line arguments
//! - Random number generation
//! - Clock/time access

const std = @import("std");
const builtin = @import("builtin");
const memory = @import("../memory.zig");
const types = @import("../types.zig");
const idris_rts = @import("../idris_rts.zig");

// ============================================================================
// WASI Detection
// ============================================================================

/// Check if we're running in a WASI environment
pub fn isWasi() bool {
    return builtin.os.tag == .wasi;
}

// ============================================================================
// WASI File System Operations
// ============================================================================

/// WASI file descriptor type
pub const Fd = std.os.wasi.fd_t;

/// Standard file descriptors
pub const STDIN: Fd = 0;
pub const STDOUT: Fd = 1;
pub const STDERR: Fd = 2;

/// Write to a file descriptor
pub fn write(fd: Fd, data: []const u8) !usize {
    if (builtin.os.tag == .wasi) {
        const iov = std.os.wasi.iovec_t{
            .base = data.ptr,
            .len = data.len,
        };
        var written: usize = undefined;
        const result = std.os.wasi.fd_write(fd, &[_]std.os.wasi.iovec_t{iov}, 1, &written);
        if (result != .SUCCESS) {
            return error.WasiError;
        }
        return written;
    } else {
        // Fallback for non-WASI
        const file = switch (fd) {
            STDOUT => std.io.getStdOut(),
            STDERR => std.io.getStdErr(),
            else => return error.InvalidFd,
        };
        return file.write(data);
    }
}

/// Read from a file descriptor
pub fn read(fd: Fd, buffer: []u8) !usize {
    if (builtin.os.tag == .wasi) {
        const iov = std.os.wasi.iovec_t{
            .base = buffer.ptr,
            .len = buffer.len,
        };
        var bytes_read: usize = undefined;
        const result = std.os.wasi.fd_read(fd, &[_]std.os.wasi.iovec_t{iov}, 1, &bytes_read);
        if (result != .SUCCESS) {
            return error.WasiError;
        }
        return bytes_read;
    } else {
        // Fallback for non-WASI
        const file = switch (fd) {
            STDIN => std.io.getStdIn(),
            else => return error.InvalidFd,
        };
        return file.read(buffer);
    }
}

// ============================================================================
// WASI Environment
// ============================================================================

/// Get environment variable
pub fn getEnv(name: []const u8) ?[]const u8 {
    if (builtin.os.tag == .wasi) {
        // WASI requires explicit environment access
        return std.process.getEnvVarOwned(memory.allocator, name) catch null;
    } else {
        return std.posix.getenv(name);
    }
}

/// Get all environment variables as key=value pairs
pub fn getAllEnv(allocator: std.mem.Allocator) ![]const [:0]const u8 {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var list = std.ArrayList([:0]const u8).init(allocator);

    var it = env_map.iterator();
    while (it.next()) |entry| {
        const kv = try std.fmt.allocPrintZ(allocator, "{s}={s}", .{ entry.key_ptr.*, entry.value_ptr.* });
        try list.append(kv);
    }

    return list.toOwnedSlice();
}

// ============================================================================
// WASI Arguments
// ============================================================================

/// Get command line arguments
pub fn getArgs(allocator: std.mem.Allocator) ![]const [:0]const u8 {
    return try std.process.argsAlloc(allocator);
}

/// Free arguments allocated by getArgs
pub fn freeArgs(allocator: std.mem.Allocator, args: []const [:0]const u8) void {
    std.process.argsFree(allocator, args);
}

// ============================================================================
// WASI Random
// ============================================================================

/// Get cryptographically secure random bytes
pub fn getRandomBytes(buffer: []u8) !void {
    if (builtin.os.tag == .wasi) {
        const result = std.os.wasi.random_get(buffer.ptr, buffer.len);
        if (result != .SUCCESS) {
            return error.WasiRandomError;
        }
    } else {
        std.crypto.random.bytes(buffer);
    }
}

/// Get a random u64
pub fn getRandomU64() !u64 {
    var bytes: [8]u8 = undefined;
    try getRandomBytes(&bytes);
    return std.mem.readInt(u64, &bytes, .little);
}

// ============================================================================
// WASI Clock
// ============================================================================

/// Clock types
pub const ClockId = enum(u32) {
    realtime = 0,
    monotonic = 1,
    process_cputime = 2,
    thread_cputime = 3,
};

/// Get current time in nanoseconds
pub fn getTime(clock: ClockId) !u64 {
    if (builtin.os.tag == .wasi) {
        var time: u64 = undefined;
        const result = std.os.wasi.clock_time_get(@intFromEnum(clock), 1, &time);
        if (result != .SUCCESS) {
            return error.WasiClockError;
        }
        return time;
    } else {
        const nanos = std.time.nanoTimestamp();
        return @intCast(@max(0, nanos));
    }
}

/// Get monotonic time (for measuring durations)
pub fn getMonotonicTime() !u64 {
    return getTime(.monotonic);
}

/// Get wall clock time
pub fn getRealTime() !u64 {
    return getTime(.realtime);
}

// ============================================================================
// WASI Process Control
// ============================================================================

/// Exit the process
pub fn exit(code: u32) noreturn {
    if (builtin.os.tag == .wasi) {
        std.os.wasi.proc_exit(code);
    } else {
        std.process.exit(@truncate(code));
    }
}

// ============================================================================
// WASI Exports (C ABI)
// ============================================================================

/// Initialize WASI environment
export fn wasi_init() callconv(.C) i32 {
    // WASI initialization
    return 0;
}

/// Write to stdout
export fn wasi_print(ptr: [*]const u8, len: usize) callconv(.C) i32 {
    write(STDOUT, ptr[0..len]) catch return -1;
    return 0;
}

/// Write to stderr
export fn wasi_eprint(ptr: [*]const u8, len: usize) callconv(.C) i32 {
    write(STDERR, ptr[0..len]) catch return -1;
    return 0;
}

/// Get random bytes
export fn wasi_random(ptr: [*]u8, len: usize) callconv(.C) i32 {
    getRandomBytes(ptr[0..len]) catch return -1;
    return 0;
}

/// Get monotonic time in nanoseconds
export fn wasi_clock_monotonic() callconv(.C) i64 {
    return @intCast(getMonotonicTime() catch 0);
}

/// Get real time in nanoseconds since epoch
export fn wasi_clock_realtime() callconv(.C) i64 {
    return @intCast(getRealTime() catch 0);
}

/// Exit with code
export fn wasi_exit(code: u32) callconv(.C) noreturn {
    exit(code);
}

// ============================================================================
// Idris Integration
// ============================================================================

/// Convert WASI error to Idris Either
pub fn wasiResultToIdris(comptime T: type, result: anyerror!T) idris_rts.IdrisEitherValue {
    if (result) |value| {
        return .{
            .tag = .right,
            .left = undefined,
            .right = types.toIdris(value),
        };
    } else |err| {
        const msg = @errorName(err);
        return .{
            .tag = .left,
            .left = .{ .string = types.toIdrisString(msg) },
            .right = undefined,
        };
    }
}

// ============================================================================
// Tests
// ============================================================================

test "wasi detection" {
    const is_wasi = isWasi();
    // Should be false in native test environment
    if (builtin.os.tag != .wasi) {
        try std.testing.expect(!is_wasi);
    }
}

test "random bytes" {
    var buf1: [32]u8 = undefined;
    var buf2: [32]u8 = undefined;

    try getRandomBytes(&buf1);
    try getRandomBytes(&buf2);

    // Very unlikely to be equal
    try std.testing.expect(!std.mem.eql(u8, &buf1, &buf2));
}

test "monotonic time increases" {
    const t1 = try getMonotonicTime();
    std.time.sleep(1_000_000); // 1ms
    const t2 = try getMonotonicTime();

    try std.testing.expect(t2 > t1);
}
