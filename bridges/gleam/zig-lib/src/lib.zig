// SPDX-License-Identifier: AGPL-3.0-or-later
// Gleam-Zig-FFI - Bidirectional FFI between Gleam and Zig
//
// Directions:
// 1. Gleam -> Zig: Direct function calls via BEAM NIF or Deno FFI
// 2. Zig -> Gleam: Callback functions registered from Gleam

const std = @import("std");

// ============================================================================
// VERSION INFO
// ============================================================================

pub const VERSION_MAJOR: u32 = 0;
pub const VERSION_MINOR: u32 = 1;
pub const VERSION_PATCH: u32 = 0;

export fn get_version() callconv(.C) u32 {
    return (VERSION_MAJOR << 16) | (VERSION_MINOR << 8) | VERSION_PATCH;
}

// ============================================================================
// BASIC FUNCTIONS (Gleam -> Zig)
// ============================================================================

export fn add(a: i32, b: i32) callconv(.C) i32 {
    return a + b;
}

export fn multiply(a: i32, b: i32) callconv(.C) i32 {
    return a * b;
}

export fn factorial(n: u32) callconv(.C) u64 {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

export fn fibonacci(n: u32) callconv(.C) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    for (2..n + 1) |_| {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

export fn string_length(str: [*:0]const u8) callconv(.C) usize {
    return std.mem.len(str);
}

// ============================================================================
// CALLBACK SUPPORT (Zig -> Gleam)
// ============================================================================

/// Callback types for different scenarios
pub const IntCallback = *const fn (i64) callconv(.C) void;
pub const StringCallback = *const fn ([*:0]const u8) callconv(.C) void;
pub const ResultCallback = *const fn (bool, [*:0]const u8) callconv(.C) void;

/// Callback storage
var g_int_callback: ?IntCallback = null;
var g_string_callback: ?StringCallback = null;
var g_result_callback: ?ResultCallback = null;

/// Register callbacks (called from Gleam)
export fn register_int_callback(cb: IntCallback) callconv(.C) void {
    g_int_callback = cb;
}

export fn register_string_callback(cb: StringCallback) callconv(.C) void {
    g_string_callback = cb;
}

export fn register_result_callback(cb: ResultCallback) callconv(.C) void {
    g_result_callback = cb;
}

/// Invoke callbacks (Zig -> Gleam)
export fn invoke_int_callback(value: i64) callconv(.C) void {
    if (g_int_callback) |cb| cb(value);
}

export fn invoke_string_callback(msg: [*:0]const u8) callconv(.C) void {
    if (g_string_callback) |cb| cb(msg);
}

export fn invoke_result_callback(success: bool, message: [*:0]const u8) callconv(.C) void {
    if (g_result_callback) |cb| cb(success, message);
}

// ============================================================================
// ASYNC PATTERN - For BEAM compatibility
// ============================================================================

/// Process data asynchronously and call back with result
export fn process_async(
    input: i64,
    on_success: *const fn (i64) callconv(.C) void,
    on_error: *const fn ([*:0]const u8) callconv(.C) void,
) callconv(.C) void {
    // Simulate processing
    if (input >= 0) {
        on_success(input * 2);
    } else {
        on_error("negative input not allowed");
    }
}

/// Map operation with callback (functional style)
export fn map_with_callback(
    input: i64,
    transform: *const fn (i64) callconv(.C) i64,
) callconv(.C) i64 {
    return transform(input);
}

// ============================================================================
// ITERATOR PATTERN - Streaming data to Gleam
// ============================================================================

/// Iterate over a range and call handler for each value
export fn iterate_range(
    start: i64,
    end: i64,
    handler: *const fn (i64) callconv(.C) bool,
) callconv(.C) u64 {
    var count: u64 = 0;
    var i = start;
    while (i < end) : (i += 1) {
        if (!handler(i)) break;
        count += 1;
    }
    return count;
}

// ============================================================================
// TESTS
// ============================================================================

test "basic arithmetic" {
    try std.testing.expectEqual(@as(i32, 5), add(2, 3));
    try std.testing.expectEqual(@as(i32, 6), multiply(2, 3));
}

test "factorial" {
    try std.testing.expectEqual(@as(u64, 120), factorial(5));
}

test "callback storage" {
    const TestCb = struct {
        fn cb(_: i64) callconv(.C) void {}
    };
    register_int_callback(TestCb.cb);
    try std.testing.expect(g_int_callback != null);
}
