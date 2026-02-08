// SPDX-License-Identifier: AGPL-3.0-or-later
// Example Zig library demonstrating bidirectional FFI with OCaml
//
// This library shows:
// 1. Exported functions (Zig -> OCaml direction)
// 2. Callback functions (OCaml -> Zig direction)

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
// BASIC FUNCTIONS (OCaml -> Zig)
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
// CALLBACK SUPPORT (Zig -> OCaml)
// ============================================================================

/// Callback type for integer operations
pub const IntCallback = *const fn (i32) callconv(.C) void;

/// Callback type for results
pub const ResultCallback = *const fn (i32, [*:0]const u8) callconv(.C) void;

/// Global callback storage
var g_int_callback: ?IntCallback = null;
var g_result_callback: ?ResultCallback = null;

/// Register an integer callback (called from OCaml)
export fn register_int_callback(cb: IntCallback) callconv(.C) void {
    g_int_callback = cb;
}

/// Register a result callback (called from OCaml)
export fn register_result_callback(cb: ResultCallback) callconv(.C) void {
    g_result_callback = cb;
}

/// Call the registered integer callback (demonstrates Zig -> OCaml)
export fn call_int_callback(value: i32) callconv(.C) void {
    if (g_int_callback) |cb| {
        cb(value);
    }
}

/// Process data and call back with result
export fn process_with_callback(data: i32) callconv(.C) void {
    const result = data * 2 + 1;
    if (g_result_callback) |cb| {
        cb(result, "processed");
    }
}

// ============================================================================
// ASYNC/EVENT PATTERN (Common in bidirectional FFI)
// ============================================================================

/// Event callback type
pub const EventCallback = *const fn (u32, [*:0]const u8, usize) callconv(.C) void;

var g_event_callback: ?EventCallback = null;

/// Register event handler
export fn set_event_handler(cb: EventCallback) callconv(.C) void {
    g_event_callback = cb;
}

/// Emit an event (Zig -> OCaml)
export fn emit_event(event_type: u32, data: [*]const u8, len: usize) callconv(.C) void {
    if (g_event_callback) |cb| {
        // In real code, you'd properly handle the string conversion
        cb(event_type, @ptrCast(data), len);
    }
}

/// Simulate async work that calls back on completion
export fn async_compute(input: i32, on_complete: *const fn (i32) callconv(.C) void) callconv(.C) void {
    // Simulate computation
    const result = input * input + input;
    // Call back with result
    on_complete(result);
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

test "fibonacci" {
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "callback registration" {
    var called = false;
    const TestCallback = struct {
        fn cb(_: i32) callconv(.C) void {
            _ = &called; // Capture
        }
    };
    register_int_callback(TestCallback.cb);
    try std.testing.expect(g_int_callback != null);
}
