// SPDX-License-Identifier: AGPL-3.0-or-later
//! Swift-Zig FFI - Core Library
//!
//! Provides bidirectional FFI between Swift and Zig with zero hand-written C.
//! The C bridging header is auto-generated from these Zig definitions.
//!
//! Features:
//! - Type-safe data exchange (strings, arrays, structs)
//! - Bidirectional callbacks (Swift → Zig and Zig → Swift)
//! - Memory-safe patterns with explicit ownership
//! - iOS/macOS/watchOS/tvOS compatible

const std = @import("std");

// ============================================================================
// ABI Version
// ============================================================================

pub const ABI_VERSION_MAJOR: u32 = 1;
pub const ABI_VERSION_MINOR: u32 = 0;
pub const ABI_VERSION_PATCH: u32 = 0;
pub const ABI_VERSION: u32 = (ABI_VERSION_MAJOR << 16) | (ABI_VERSION_MINOR << 8) | ABI_VERSION_PATCH;

// ============================================================================
// Error Codes
// ============================================================================

pub const SZF_OK: i32 = 0;
pub const SZF_ERR_NULL_PTR: i32 = -1;
pub const SZF_ERR_INVALID_UTF8: i32 = -2;
pub const SZF_ERR_ALLOC_FAILED: i32 = -3;
pub const SZF_ERR_INVALID_LENGTH: i32 = -4;
pub const SZF_ERR_NOT_FOUND: i32 = -5;
pub const SZF_ERR_ALREADY_EXISTS: i32 = -6;
pub const SZF_ERR_CALLBACK_FAILED: i32 = -7;
pub const SZF_ERR_NOT_IMPLEMENTED: i32 = -99;

// ============================================================================
// FFI-Safe Types
// ============================================================================

/// Byte buffer for FFI. Data is NOT NUL-terminated.
/// Use szf_bytes_free() to release when done.
pub const SzfBytes = extern struct {
    ptr: ?[*]const u8,
    len: usize,
    /// Capacity (for owned buffers)
    cap: usize,
    /// Non-zero if caller should free
    owned: u8,

    pub fn empty() SzfBytes {
        return .{ .ptr = null, .len = 0, .cap = 0, .owned = 0 };
    }

    pub fn fromSlice(slice: []const u8) SzfBytes {
        return .{
            .ptr = if (slice.len > 0) slice.ptr else null,
            .len = slice.len,
            .cap = 0,
            .owned = 0, // Borrowed, don't free
        };
    }

    pub fn toSlice(self: SzfBytes) []const u8 {
        if (self.ptr) |p| {
            return p[0..self.len];
        }
        return &[_]u8{};
    }
};

/// NUL-terminated C string wrapper
pub const SzfString = extern struct {
    ptr: ?[*:0]const u8,
    len: usize,

    pub fn empty() SzfString {
        return .{ .ptr = null, .len = 0 };
    }

    pub fn fromSlice(slice: [:0]const u8) SzfString {
        return .{
            .ptr = slice.ptr,
            .len = slice.len,
        };
    }
};

/// Result type for operations that return data or error
pub const SzfResult = extern struct {
    /// Error code (0 = success)
    code: i32,
    /// Error message (NUL-terminated, owned by library)
    message: ?[*:0]const u8,
    /// Result data (if successful)
    data: SzfBytes,

    pub fn ok(data: SzfBytes) SzfResult {
        return .{ .code = SZF_OK, .message = null, .data = data };
    }

    pub fn err(code: i32, msg: ?[*:0]const u8) SzfResult {
        return .{ .code = code, .message = msg, .data = SzfBytes.empty() };
    }
};

// ============================================================================
// Callback Types (Bidirectional FFI)
// ============================================================================

/// Callback: Swift notifies Zig of data
pub const SzfDataCallback = *const fn (data: SzfBytes, context: ?*anyopaque) callconv(.c) void;

/// Callback: Swift notifies Zig of completion with result
pub const SzfResultCallback = *const fn (result: SzfResult, context: ?*anyopaque) callconv(.c) void;

/// Callback: Swift notifies Zig of progress (return false to cancel)
pub const SzfProgressCallback = *const fn (current: usize, total: usize, context: ?*anyopaque) callconv(.c) bool;

/// Callback: Zig notifies Swift of events
pub const SzfEventCallback = *const fn (event_type: i32, data: SzfBytes, context: ?*anyopaque) callconv(.c) void;

/// Callback: Zig notifies Swift of errors
pub const SzfErrorCallback = *const fn (code: i32, message: ?[*:0]const u8, context: ?*anyopaque) callconv(.c) void;

// ============================================================================
// Global Callback Storage
// ============================================================================

var g_event_callback: ?SzfEventCallback = null;
var g_event_context: ?*anyopaque = null;
var g_error_callback: ?SzfErrorCallback = null;
var g_error_context: ?*anyopaque = null;

// ============================================================================
// Context Management
// ============================================================================

/// Opaque context for library state
pub const SzfContext = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    error_buf: [512]u8,
    error_msg: ?[*:0]const u8,

    pub fn init() !*SzfContext {
        const backing = std.heap.page_allocator;
        const ctx = try backing.create(SzfContext);
        ctx.* = .{
            .allocator = backing,
            .arena = std.heap.ArenaAllocator.init(backing),
            .error_buf = undefined,
            .error_msg = null,
        };
        return ctx;
    }

    pub fn deinit(self: *SzfContext) void {
        self.arena.deinit();
        self.allocator.destroy(self);
    }

    pub fn reset(self: *SzfContext) void {
        _ = self.arena.reset(.retain_capacity);
        self.error_msg = null;
    }

    pub fn alloc(self: *SzfContext) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn setError(self: *SzfContext, msg: []const u8) void {
        const len = @min(msg.len, self.error_buf.len - 1);
        @memcpy(self.error_buf[0..len], msg[0..len]);
        self.error_buf[len] = 0;
        self.error_msg = @ptrCast(&self.error_buf);
    }
};

// ============================================================================
// Exported C ABI Functions
// ============================================================================

/// Return ABI version for compatibility checks
export fn szf_version() callconv(.c) u32 {
    return ABI_VERSION;
}

/// Create a new context
export fn szf_context_new() callconv(.c) ?*SzfContext {
    return SzfContext.init() catch null;
}

/// Free a context
export fn szf_context_free(ctx: ?*SzfContext) callconv(.c) void {
    if (ctx) |c| c.deinit();
}

/// Reset context arena for reuse
export fn szf_context_reset(ctx: ?*SzfContext) callconv(.c) void {
    if (ctx) |c| c.reset();
}

/// Get last error message
export fn szf_context_get_error(ctx: ?*SzfContext) callconv(.c) ?[*:0]const u8 {
    if (ctx) |c| return c.error_msg;
    return null;
}

// ============================================================================
// String Operations
// ============================================================================

/// Create owned string from C string (caller must free with szf_string_free)
export fn szf_string_from_cstr(cstr: ?[*:0]const u8) callconv(.c) SzfString {
    const ptr = cstr orelse return SzfString.empty();
    const len = std.mem.len(ptr);
    return .{ .ptr = ptr, .len = len };
}

/// Free an owned string
export fn szf_string_free(str: *SzfString) callconv(.c) void {
    str.* = SzfString.empty();
}

/// Free owned bytes
export fn szf_bytes_free(bytes: *SzfBytes) callconv(.c) void {
    if (bytes.owned != 0) {
        if (bytes.ptr) |p| {
            // In real implementation, would track allocator
            _ = p;
        }
    }
    bytes.* = SzfBytes.empty();
}

// ============================================================================
// Callback Registration (Swift → Zig direction)
// ============================================================================

/// Register event callback (Zig will call this to notify Swift)
export fn szf_register_event_callback(
    callback: ?SzfEventCallback,
    context: ?*anyopaque,
) callconv(.c) void {
    g_event_callback = callback;
    g_event_context = context;
}

/// Register error callback (Zig will call this to notify Swift of errors)
export fn szf_register_error_callback(
    callback: ?SzfErrorCallback,
    context: ?*anyopaque,
) callconv(.c) void {
    g_error_callback = callback;
    g_error_context = context;
}

// ============================================================================
// Callback Invocation (Zig → Swift direction)
// ============================================================================

/// Invoke event callback (called from Zig to notify Swift)
export fn szf_invoke_event(event_type: i32, data: SzfBytes) callconv(.c) void {
    if (g_event_callback) |cb| {
        cb(event_type, data, g_event_context);
    }
}

/// Invoke error callback (called from Zig to notify Swift)
export fn szf_invoke_error(code: i32, message: ?[*:0]const u8) callconv(.c) void {
    if (g_error_callback) |cb| {
        cb(code, message, g_error_context);
    }
}

// ============================================================================
// Example: Data Processing with Callbacks
// ============================================================================

/// Process data with progress callback (demonstrates Swift → Zig callback)
export fn szf_process_data(
    ctx: ?*SzfContext,
    input: SzfBytes,
    progress_cb: ?SzfProgressCallback,
    progress_ctx: ?*anyopaque,
    result_cb: ?SzfResultCallback,
    result_ctx: ?*anyopaque,
) callconv(.c) i32 {
    const c = ctx orelse return SZF_ERR_NULL_PTR;
    const data = input.toSlice();

    if (data.len == 0) {
        c.setError("empty input data");
        if (result_cb) |cb| {
            cb(SzfResult.err(SZF_ERR_INVALID_LENGTH, c.error_msg), result_ctx);
        }
        return SZF_ERR_INVALID_LENGTH;
    }

    // Simulate processing with progress
    var processed: usize = 0;
    const chunk_size: usize = 1024;

    while (processed < data.len) {
        const remaining = data.len - processed;
        const chunk = @min(remaining, chunk_size);
        processed += chunk;

        // Report progress
        if (progress_cb) |cb| {
            if (!cb(processed, data.len, progress_ctx)) {
                c.setError("cancelled by user");
                if (result_cb) |rcb| {
                    rcb(SzfResult.err(SZF_ERR_CALLBACK_FAILED, c.error_msg), result_ctx);
                }
                return SZF_ERR_CALLBACK_FAILED;
            }
        }
    }

    // Return result via callback
    if (result_cb) |cb| {
        cb(SzfResult.ok(input), result_ctx);
    }

    return SZF_OK;
}

/// Transform data (example: uppercase ASCII)
export fn szf_transform_data(
    ctx: ?*SzfContext,
    input: SzfBytes,
    out: ?*SzfBytes,
) callconv(.c) i32 {
    const c = ctx orelse return SZF_ERR_NULL_PTR;
    const output = out orelse return SZF_ERR_NULL_PTR;

    const data = input.toSlice();
    if (data.len == 0) {
        output.* = SzfBytes.empty();
        return SZF_OK;
    }

    // Allocate output buffer
    const alloc = c.alloc();
    const result = alloc.alloc(u8, data.len) catch {
        c.setError("allocation failed");
        return SZF_ERR_ALLOC_FAILED;
    };

    // Transform: uppercase ASCII
    for (data, 0..) |byte, i| {
        result[i] = if (byte >= 'a' and byte <= 'z') byte - 32 else byte;
    }

    output.* = .{
        .ptr = result.ptr,
        .len = result.len,
        .cap = result.len,
        .owned = 0, // Owned by context arena
    };

    return SZF_OK;
}

// ============================================================================
// Tests
// ============================================================================

test "version check" {
    const ver = szf_version();
    try std.testing.expectEqual(@as(u32, 0x010000), ver);
}

test "context lifecycle" {
    const ctx = szf_context_new();
    try std.testing.expect(ctx != null);
    szf_context_reset(ctx);
    szf_context_free(ctx);
}

test "bytes from slice" {
    const data = "hello";
    const bytes = SzfBytes.fromSlice(data);
    try std.testing.expectEqual(@as(usize, 5), bytes.len);
    try std.testing.expectEqualStrings("hello", bytes.toSlice());
}

test "transform data" {
    const ctx = szf_context_new().?;
    defer szf_context_free(ctx);

    const input = SzfBytes.fromSlice("hello world");
    var output: SzfBytes = undefined;

    const result = szf_transform_data(ctx, input, &output);
    try std.testing.expectEqual(SZF_OK, result);
    try std.testing.expectEqualStrings("HELLO WORLD", output.toSlice());
}
