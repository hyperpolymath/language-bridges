// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath
//! WebAssembly ABI for browser environments
//!
//! This module provides WASM-specific functionality for running
//! Idris 2 code in web browsers. It includes JavaScript interop,
//! memory management for the WASM linear memory model, and
//! browser-specific optimizations.

const std = @import("std");
const builtin = @import("builtin");
const memory = @import("../memory.zig");
const types = @import("../types.zig");
const idris_rts = @import("../idris_rts.zig");

// ============================================================================
// WASM Memory Management
// ============================================================================

/// WASM linear memory allocator
/// Uses a simple bump allocator for WASM's linear memory model
pub const WasmAllocator = struct {
    heap_base: usize,
    heap_end: usize,
    current: usize,

    const Self = @This();

    pub fn init(heap_base: usize, heap_size: usize) Self {
        return .{
            .heap_base = heap_base,
            .heap_end = heap_base + heap_size,
            .current = heap_base,
        };
    }

    pub fn alloc(self: *Self, size: usize, alignment: usize) ?[*]u8 {
        const aligned_current = std.mem.alignForward(usize, self.current, alignment);
        const new_current = aligned_current + size;

        if (new_current > self.heap_end) {
            return null; // Out of memory
        }

        self.current = new_current;
        return @ptrFromInt(aligned_current);
    }

    pub fn reset(self: *Self) void {
        self.current = self.heap_base;
    }

    /// Get remaining free memory
    pub fn freeSpace(self: *const Self) usize {
        return self.heap_end - self.current;
    }
};

/// Global WASM allocator instance
var wasm_allocator: ?WasmAllocator = null;

/// Initialize WASM allocator with given heap bounds
pub fn initWasmHeap(heap_base: usize, heap_size: usize) void {
    wasm_allocator = WasmAllocator.init(heap_base, heap_size);
}

// ============================================================================
// JavaScript Interop
// ============================================================================

/// External JavaScript functions (imported from JS environment)
pub const js = struct {
    /// Console logging
    pub extern "env" fn js_console_log(ptr: [*]const u8, len: usize) void;
    pub extern "env" fn js_console_error(ptr: [*]const u8, len: usize) void;

    /// Memory operations
    pub extern "env" fn js_alloc(size: usize) usize;
    pub extern "env" fn js_free(ptr: usize) void;

    /// DOM interaction (optional)
    pub extern "env" fn js_get_element_by_id(id_ptr: [*]const u8, id_len: usize) i32;
    pub extern "env" fn js_set_inner_html(element_id: i32, html_ptr: [*]const u8, html_len: usize) void;

    /// Callbacks
    pub extern "env" fn js_set_timeout(callback_id: u32, delay_ms: u32) void;
    pub extern "env" fn js_request_animation_frame(callback_id: u32) void;
};

/// Log a message to JavaScript console
pub fn consoleLog(msg: []const u8) void {
    if (builtin.target.cpu.arch == .wasm32) {
        js.js_console_log(msg.ptr, msg.len);
    } else {
        std.debug.print("{s}\n", .{msg});
    }
}

/// Log an error to JavaScript console
pub fn consoleError(msg: []const u8) void {
    if (builtin.target.cpu.arch == .wasm32) {
        js.js_console_error(msg.ptr, msg.len);
    } else {
        std.debug.print("ERROR: {s}\n", .{msg});
    }
}

// ============================================================================
// String Conversion for JS
// ============================================================================

/// Result of a string allocated for JS
pub const JsString = struct {
    ptr: [*]const u8,
    len: usize,
};

/// Convert Zig string to JS-compatible format
/// Returns pointer and length for JS to read
pub fn toJsString(str: []const u8) JsString {
    return .{ .ptr = str.ptr, .len = str.len };
}

/// Read a string from JS memory
pub fn fromJsString(ptr: [*]const u8, len: usize) []const u8 {
    return ptr[0..len];
}

// ============================================================================
// WASM Exports
// ============================================================================

/// Initialize WASM module
export fn wasm_init() callconv(.C) i32 {
    // Initialize with 1MB heap by default
    // In real usage, this would be configured by the host
    initWasmHeap(0x10000, 1024 * 1024);
    return 0;
}

/// Allocate memory (for JS to call)
export fn wasm_alloc(size: usize) callconv(.C) usize {
    if (wasm_allocator) |*alloc| {
        if (alloc.alloc(size, 8)) |ptr| {
            return @intFromPtr(ptr);
        }
    }
    return 0;
}

/// Free memory (for JS to call)
export fn wasm_free(ptr: usize) callconv(.C) void {
    // In bump allocator, individual frees are no-ops
    // Memory is reclaimed on reset
    _ = ptr;
}

/// Reset allocator (free all memory)
export fn wasm_reset() callconv(.C) void {
    if (wasm_allocator) |*alloc| {
        alloc.reset();
    }
}

/// Get remaining free memory
export fn wasm_free_space() callconv(.C) usize {
    if (wasm_allocator) |*alloc| {
        return alloc.freeSpace();
    }
    return 0;
}

// ============================================================================
// Type Marshalling for WASM
// ============================================================================

/// Convert Idris Int to WASM i64
pub fn toWasmInt(value: i64) i64 {
    return value;
}

/// Convert WASM i64 to Idris Int
pub fn fromWasmInt(value: i64) i64 {
    return value;
}

/// Convert Idris Float to WASM f64
pub fn toWasmFloat(value: f64) f64 {
    return value;
}

/// Convert WASM f64 to Idris Float
pub fn fromWasmFloat(value: f64) f64 {
    return value;
}

/// Pack a Maybe into WASM-friendly format
/// Returns: [tag (i32), value (i64)]
pub fn packMaybe(comptime T: type, maybe: ?T) struct { i32, i64 } {
    if (maybe) |v| {
        return .{ 1, @bitCast(v) };
    }
    return .{ 0, 0 };
}

/// Unpack a Maybe from WASM format
pub fn unpackMaybe(comptime T: type, tag: i32, value: i64) ?T {
    if (tag == 0) return null;
    return @bitCast(value);
}

// ============================================================================
// Callback Registry
// ============================================================================

/// Maximum number of registered callbacks
const MAX_CALLBACKS = 256;

/// Callback function type
pub const CallbackFn = *const fn (usize) void;

/// Registered callbacks
var callbacks: [MAX_CALLBACKS]?CallbackFn = [_]?CallbackFn{null} ** MAX_CALLBACKS;
var next_callback_id: u32 = 0;

/// Register a callback and return its ID
pub fn registerCallback(func: CallbackFn) ?u32 {
    if (next_callback_id >= MAX_CALLBACKS) {
        return null;
    }
    const id = next_callback_id;
    callbacks[id] = func;
    next_callback_id += 1;
    return id;
}

/// Invoke a callback by ID
export fn wasm_invoke_callback(id: u32, arg: usize) callconv(.C) void {
    if (id < MAX_CALLBACKS) {
        if (callbacks[id]) |func| {
            func(arg);
        }
    }
}

// ============================================================================
// Tests (native only)
// ============================================================================

test "wasm allocator" {
    if (builtin.target.cpu.arch == .wasm32) return;

    var buffer: [4096]u8 = undefined;
    var alloc = WasmAllocator.init(@intFromPtr(&buffer), buffer.len);

    const ptr1 = alloc.alloc(100, 8);
    try std.testing.expect(ptr1 != null);

    const ptr2 = alloc.alloc(200, 8);
    try std.testing.expect(ptr2 != null);

    try std.testing.expect(alloc.freeSpace() < buffer.len - 300);

    alloc.reset();
    try std.testing.expect(alloc.freeSpace() == buffer.len);
}

test "maybe packing" {
    if (builtin.target.cpu.arch == .wasm32) return;

    const some: ?i64 = 42;
    const none: ?i64 = null;

    const packed_some = packMaybe(i64, some);
    const packed_none = packMaybe(i64, none);

    try std.testing.expect(packed_some[0] == 1);
    try std.testing.expect(packed_some[1] == 42);
    try std.testing.expect(packed_none[0] == 0);

    try std.testing.expect(unpackMaybe(i64, packed_some[0], packed_some[1]) == 42);
    try std.testing.expect(unpackMaybe(i64, packed_none[0], packed_none[1]) == null);
}
