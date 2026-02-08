// SPDX-License-Identifier: Palimpsest-MPL-1.0
//! Memory management for Idris 2 FFI bridge
//!
//! This module provides safe memory allocation that integrates with
//! the Idris 2 runtime garbage collector.

const std = @import("std");
const idris_rts = @import("idris_rts.zig");

/// Global allocator for FFI bridge
/// Uses the general purpose allocator for now, but can be swapped
/// for a custom allocator that integrates with Idris GC
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

/// Allocate memory for a slice of T
pub fn alloc(comptime T: type, count: usize) ![]T {
    return try allocator.alloc(T, count);
}

/// Free memory allocated by alloc
pub fn free(ptr: anytype) void {
    allocator.free(ptr);
}

/// Raw allocation for C interop
pub fn allocRaw(size: usize) ?*anyopaque {
    const slice = allocator.alloc(u8, size) catch return null;
    return slice.ptr;
}

/// Raw free for C interop
pub fn freeRaw(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        // We need to know the size to free properly
        // For now, this is a limitation - in production, we'd track allocations
        _ = p;
    }
}

/// Free an Idris string
pub fn freeIdrisString(str: idris_rts.IdrisString) void {
    if (str.data) |data| {
        const slice: []u8 = @ptrCast(data[0..str.len]);
        allocator.free(slice);
    }
}

/// Memory pool for frequently allocated types
pub const Pool = struct {
    allocator: std.mem.Allocator,

    pub fn init() Pool {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Pool) void {
        _ = self;
        // Cleanup pool resources
    }

    pub fn create(self: *Pool, comptime T: type) !*T {
        return try self.allocator.create(T);
    }

    pub fn destroy(self: *Pool, ptr: anytype) void {
        self.allocator.destroy(ptr);
    }
};

/// RAII wrapper for automatic cleanup
pub fn Managed(comptime T: type) type {
    return struct {
        value: T,
        cleanup_fn: ?*const fn (*T) void,

        const Self = @This();

        pub fn init(value: T, cleanup: ?*const fn (*T) void) Self {
            return .{ .value = value, .cleanup_fn = cleanup };
        }

        pub fn deinit(self: *Self) void {
            if (self.cleanup_fn) |cleanup| {
                cleanup(&self.value);
            }
        }

        pub fn get(self: *const Self) T {
            return self.value;
        }
    };
}

/// Arena allocator for batch allocations that are freed together
pub const Arena = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init() Arena {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Arena) void {
        self.arena.deinit();
    }

    pub fn alloc(self: *Arena, comptime T: type, count: usize) ![]T {
        return try self.arena.allocator().alloc(T, count);
    }

    pub fn reset(self: *Arena) void {
        _ = self.arena.reset(.retain_capacity);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "basic allocation" {
    const slice = try alloc(u8, 100);
    defer free(slice);
    try std.testing.expect(slice.len == 100);
}

test "pool allocation" {
    var pool = Pool.init();
    defer pool.deinit();

    const ptr = try pool.create(u64);
    defer pool.destroy(ptr);

    ptr.* = 42;
    try std.testing.expect(ptr.* == 42);
}

test "arena allocation" {
    var arena = Arena.init();
    defer arena.deinit();

    const slice1 = try arena.alloc(u8, 100);
    const slice2 = try arena.alloc(u32, 50);

    try std.testing.expect(slice1.len == 100);
    try std.testing.expect(slice2.len == 50);

    // All freed at once when arena is deinitialized
}
