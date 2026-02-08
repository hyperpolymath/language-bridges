// SPDX-License-Identifier: AGPL-3.0-or-later
// Ada-Zig-FFI - Bidirectional FFI between Ada and Zig
//
// Directions:
// 1. Ada -> Zig: Import via Interfaces.C with pragma Import
// 2. Zig -> Ada: Callback procedures via access-to-procedure types

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
// BASIC FUNCTIONS (Ada -> Zig)
// ============================================================================

export fn add(a: c_int, b: c_int) callconv(.C) c_int {
    return a + b;
}

export fn multiply(a: c_int, b: c_int) callconv(.C) c_int {
    return a * b;
}

export fn factorial(n: c_uint) callconv(.C) c_ulong {
    if (n <= 1) return 1;
    var result: c_ulong = 1;
    var i: c_uint = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

export fn fibonacci(n: c_uint) callconv(.C) c_ulong {
    if (n <= 1) return n;
    var a: c_ulong = 0;
    var b: c_ulong = 1;
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

export fn buffer_sum(ptr: [*]const u8, len: usize) callconv(.C) c_ulong {
    var sum: c_ulong = 0;
    for (0..len) |i| {
        sum += ptr[i];
    }
    return sum;
}

// ============================================================================
// CALLBACK SUPPORT (Zig -> Ada)
// Ada side uses: type Callback is access procedure (Value : Integer);
// ============================================================================

/// Callback types matching Ada access-to-procedure types
pub const IntProcedure = *const fn (c_int) callconv(.C) void;
pub const LongProcedure = *const fn (c_long) callconv(.C) void;
pub const BoolFunction = *const fn () callconv(.C) c_int; // Ada Boolean via int
pub const StatusCallback = *const fn (c_int, [*:0]const u8) callconv(.C) void;

/// Callback storage
var g_int_callback: ?IntProcedure = null;
var g_long_callback: ?LongProcedure = null;
var g_status_callback: ?StatusCallback = null;

/// Register callbacks (called from Ada)
export fn register_int_callback(cb: IntProcedure) callconv(.C) void {
    g_int_callback = cb;
}

export fn register_long_callback(cb: LongProcedure) callconv(.C) void {
    g_long_callback = cb;
}

export fn register_status_callback(cb: StatusCallback) callconv(.C) void {
    g_status_callback = cb;
}

/// Invoke callbacks (Zig -> Ada)
export fn invoke_int_callback(value: c_int) callconv(.C) void {
    if (g_int_callback) |cb| cb(value);
}

export fn invoke_long_callback(value: c_long) callconv(.C) void {
    if (g_long_callback) |cb| cb(value);
}

export fn invoke_status_callback(code: c_int, message: [*:0]const u8) callconv(.C) void {
    if (g_status_callback) |cb| cb(code, message);
}

// ============================================================================
// ITERATOR PATTERN - Ada style with termination control
// ============================================================================

/// Iterate with Ada-style control
export fn for_each_in_range(
    start: c_int,
    stop: c_int,
    step: c_int,
    handler: *const fn (c_int) callconv(.C) c_int, // Return 0 to continue, 1 to stop
) callconv(.C) c_int {
    var count: c_int = 0;
    var i = start;
    while ((step > 0 and i < stop) or (step < 0 and i > stop)) : (i += step) {
        if (handler(i) != 0) break;
        count += 1;
    }
    return count;
}

// ============================================================================
// SAFETY-CRITICAL PATTERNS (Ada's strength)
// ============================================================================

/// Bounded operation with precondition check
export fn safe_divide(
    numerator: c_int,
    denominator: c_int,
    result: *c_int,
    error_cb: ?*const fn ([*:0]const u8) callconv(.C) void,
) callconv(.C) c_int {
    if (denominator == 0) {
        if (error_cb) |cb| cb("Division by zero");
        return -1;
    }
    result.* = @divTrunc(numerator, denominator);
    return 0;
}

/// Array bounds check with callback on violation
export fn checked_array_access(
    arr: [*]const c_int,
    len: usize,
    index: usize,
    result: *c_int,
    bounds_error: ?*const fn (usize, usize) callconv(.C) void,
) callconv(.C) c_int {
    if (index >= len) {
        if (bounds_error) |cb| cb(index, len);
        return -1;
    }
    result.* = arr[index];
    return 0;
}

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

const c_int = i32;
const c_uint = u32;
const c_long = i64;
const c_ulong = u64;

// ============================================================================
// TESTS
// ============================================================================

test "basic arithmetic" {
    try std.testing.expectEqual(@as(c_int, 5), add(2, 3));
    try std.testing.expectEqual(@as(c_int, 6), multiply(2, 3));
}

test "factorial" {
    try std.testing.expectEqual(@as(c_ulong, 120), factorial(5));
}

test "safe_divide success" {
    var result: c_int = 0;
    const status = safe_divide(10, 2, &result, null);
    try std.testing.expectEqual(@as(c_int, 0), status);
    try std.testing.expectEqual(@as(c_int, 5), result);
}

test "safe_divide error" {
    var result: c_int = 0;
    const status = safe_divide(10, 0, &result, null);
    try std.testing.expectEqual(@as(c_int, -1), status);
}

test "buffer_sum" {
    const data = [_]u8{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(@as(c_ulong, 15), buffer_sum(&data, data.len));
}

test "fibonacci" {
    try std.testing.expectEqual(@as(c_ulong, 0), fibonacci(0));
    try std.testing.expectEqual(@as(c_ulong, 1), fibonacci(1));
    try std.testing.expectEqual(@as(c_ulong, 55), fibonacci(10));
}

test "string_length" {
    const str: [*:0]const u8 = "hello";
    try std.testing.expectEqual(@as(usize, 5), string_length(str));
}
