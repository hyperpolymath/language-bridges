// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath
//! Native Zig ABI Layer
//!
//! This module provides the stable Zig ABI for interop between Zig and
//! Idris 2 code. It defines:
//!
//! - Zig-native struct layouts with extern for ABI stability
//! - Exported functions for library linking
//! - Memory management functions
//! - Type conversion between Zig and Idris types
//!
//! The ABI is versioned to ensure compatibility across updates.

const std = @import("std");
const memory = @import("../memory.zig");
const types = @import("../types.zig");
const idris_rts = @import("../idris_rts.zig");
const errors = @import("../errors.zig");

// ============================================================================
// ABI Version
// ============================================================================

/// Current ABI version
/// Increment on breaking changes
pub const ABI_VERSION: u32 = 1;

/// Minimum supported ABI version
pub const ABI_VERSION_MIN: u32 = 1;

/// Check if a version is compatible
pub fn isCompatible(version: u32) bool {
    return version >= ABI_VERSION_MIN and version <= ABI_VERSION;
}

// ============================================================================
// ABI Types (extern struct for stability)
// ============================================================================

/// ABI-stable string (pointer + length)
pub const CString = extern struct {
    data: ?[*]u8,
    len: usize,

    pub fn fromSlice(slice: []const u8) CString {
        return .{
            .data = @constCast(slice.ptr),
            .len = slice.len,
        };
    }

    pub fn toSlice(self: CString) []const u8 {
        if (self.data) |data| {
            return data[0..self.len];
        }
        return "";
    }

    pub fn empty() CString {
        return .{ .data = null, .len = 0 };
    }
};

/// C-compatible result type (success/error)
pub const CResult = extern struct {
    success: bool,
    error_code: u32,
    error_msg: CString,
    value: CValue,

    pub fn ok(value: CValue) CResult {
        return .{
            .success = true,
            .error_code = 0,
            .error_msg = CString.empty(),
            .value = value,
        };
    }

    pub fn err(code: u32, msg: []const u8) CResult {
        return .{
            .success = false,
            .error_code = code,
            .error_msg = CString.fromSlice(msg),
            .value = .{ .int = 0 },
        };
    }
};

/// C-compatible value union
pub const CValue = extern union {
    int: i64,
    uint: u64,
    float: f64,
    boolean: bool,
    string: CString,
    ptr: ?*anyopaque,
};

/// C-compatible option/maybe type
pub const COption = extern struct {
    has_value: bool,
    value: CValue,

    pub fn some(value: CValue) COption {
        return .{ .has_value = true, .value = value };
    }

    pub fn none() COption {
        return .{ .has_value = false, .value = .{ .int = 0 } };
    }
};

/// C-compatible array/list type
pub const CArray = extern struct {
    data: ?[*]CValue,
    len: usize,
    capacity: usize,

    pub fn empty() CArray {
        return .{ .data = null, .len = 0, .capacity = 0 };
    }
};

// ============================================================================
// Error Codes (matching errors.zig)
// ============================================================================

pub const ErrorCode = struct {
    pub const OK: u32 = 0;
    pub const UNKNOWN: u32 = 1;

    // Memory errors
    pub const OUT_OF_MEMORY: u32 = 100;
    pub const INVALID_POINTER: u32 = 101;

    // Type errors
    pub const TYPE_MISMATCH: u32 = 200;
    pub const INVALID_ARGUMENT: u32 = 201;

    // Parse errors
    pub const PARSE_ERROR: u32 = 300;
    pub const INVALID_INPUT: u32 = 301;

    // Math errors
    pub const DIVISION_BY_ZERO: u32 = 400;
    pub const OVERFLOW: u32 = 401;
    pub const UNDERFLOW: u32 = 402;

    // Security errors
    pub const INJECTION_DETECTED: u32 = 500;
    pub const TRAVERSAL_DETECTED: u32 = 501;

    // Runtime errors
    pub const NOT_INITIALIZED: u32 = 600;
    pub const ALREADY_INITIALIZED: u32 = 601;
};

// ============================================================================
// Initialization
// ============================================================================

var initialized: bool = false;

/// Initialize the library
export fn idris2_init() callconv(.C) i32 {
    if (initialized) {
        return -@as(i32, @intCast(ErrorCode.ALREADY_INITIALIZED));
    }

    idris_rts.initRuntime() catch {
        return -@as(i32, @intCast(ErrorCode.UNKNOWN));
    };

    initialized = true;
    return 0;
}

/// Cleanup the library
export fn idris2_deinit() callconv(.C) void {
    if (initialized) {
        idris_rts.deinitRuntime();
        initialized = false;
    }
}

/// Check if initialized
export fn idris2_is_initialized() callconv(.C) bool {
    return initialized;
}

/// Get ABI version
export fn idris2_abi_version() callconv(.C) u32 {
    return ABI_VERSION;
}

/// Check ABI compatibility
export fn idris2_abi_compatible(version: u32) callconv(.C) bool {
    return isCompatible(version);
}

// ============================================================================
// Memory Management
// ============================================================================

/// Allocate memory
export fn idris2_alloc(size: usize) callconv(.C) ?*anyopaque {
    const slice = memory.allocator.alloc(u8, size) catch return null;
    return slice.ptr;
}

/// Reallocate memory
export fn idris2_realloc(ptr: ?*anyopaque, old_size: usize, new_size: usize) callconv(.C) ?*anyopaque {
    if (ptr == null) {
        return idris2_alloc(new_size);
    }

    const old_slice: []u8 = @as([*]u8, @ptrCast(ptr.?))[0..old_size];
    const new_slice = memory.allocator.realloc(old_slice, new_size) catch return null;
    return new_slice.ptr;
}

/// Free memory
export fn idris2_free(ptr: ?*anyopaque, size: usize) callconv(.C) void {
    if (ptr) |p| {
        const slice: []u8 = @as([*]u8, @ptrCast(p))[0..size];
        memory.allocator.free(slice);
    }
}

// ============================================================================
// String Operations
// ============================================================================

/// Create a string from C string (null-terminated)
export fn idris2_string_from_cstr(cstr: [*:0]const u8) callconv(.C) CString {
    const len = std.mem.len(cstr);
    const data = memory.allocator.alloc(u8, len) catch return CString.empty();
    @memcpy(data, cstr[0..len]);
    return .{ .data = data.ptr, .len = len };
}

/// Create a string from pointer + length
export fn idris2_string_from_ptr(ptr: [*]const u8, len: usize) callconv(.C) CString {
    const data = memory.allocator.alloc(u8, len) catch return CString.empty();
    @memcpy(data, ptr[0..len]);
    return .{ .data = data.ptr, .len = len };
}

/// Convert string to null-terminated C string
/// Caller must free with idris2_free(ptr, len+1)
export fn idris2_string_to_cstr(str: CString) callconv(.C) ?[*:0]u8 {
    if (str.data == null) return null;

    const data = memory.allocator.alloc(u8, str.len + 1) catch return null;
    @memcpy(data[0..str.len], str.data.?[0..str.len]);
    data[str.len] = 0;
    return @ptrCast(data.ptr);
}

/// Free a string
export fn idris2_string_free(str: CString) callconv(.C) void {
    if (str.data) |data| {
        const slice = data[0..str.len];
        memory.allocator.free(slice);
    }
}

/// Get string length
export fn idris2_string_len(str: CString) callconv(.C) usize {
    return str.len;
}

/// Compare two strings
export fn idris2_string_eq(a: CString, b: CString) callconv(.C) bool {
    return std.mem.eql(u8, a.toSlice(), b.toSlice());
}

// ============================================================================
// Option Operations
// ============================================================================

/// Create Some(value)
export fn idris2_option_some_int(value: i64) callconv(.C) COption {
    return COption.some(.{ .int = value });
}

/// Create Some(value) for string
export fn idris2_option_some_string(str: CString) callconv(.C) COption {
    return COption.some(.{ .string = str });
}

/// Create None
export fn idris2_option_none() callconv(.C) COption {
    return COption.none();
}

/// Check if Some
export fn idris2_option_is_some(opt: COption) callconv(.C) bool {
    return opt.has_value;
}

/// Check if None
export fn idris2_option_is_none(opt: COption) callconv(.C) bool {
    return !opt.has_value;
}

// ============================================================================
// Result Operations
// ============================================================================

/// Create Ok(value)
export fn idris2_result_ok_int(value: i64) callconv(.C) CResult {
    return CResult.ok(.{ .int = value });
}

/// Create Err(code, msg)
export fn idris2_result_err(code: u32, msg: [*:0]const u8) callconv(.C) CResult {
    const len = std.mem.len(msg);
    return CResult.err(code, msg[0..len]);
}

/// Check if Ok
export fn idris2_result_is_ok(result: CResult) callconv(.C) bool {
    return result.success;
}

/// Get error code
export fn idris2_result_error_code(result: CResult) callconv(.C) u32 {
    return result.error_code;
}

// ============================================================================
// Array Operations
// ============================================================================

/// Create an empty array with capacity
export fn idris2_array_new(capacity: usize) callconv(.C) CArray {
    const data = memory.allocator.alloc(CValue, capacity) catch return CArray.empty();
    return .{
        .data = data.ptr,
        .len = 0,
        .capacity = capacity,
    };
}

/// Free an array
export fn idris2_array_free(arr: CArray) callconv(.C) void {
    if (arr.data) |data| {
        const slice = data[0..arr.capacity];
        memory.allocator.free(slice);
    }
}

/// Get array length
export fn idris2_array_len(arr: CArray) callconv(.C) usize {
    return arr.len;
}

/// Get element at index
export fn idris2_array_get(arr: CArray, index: usize) callconv(.C) CValue {
    if (arr.data == null or index >= arr.len) {
        return .{ .int = 0 };
    }
    return arr.data.?[index];
}

// ============================================================================
// Type Conversion
// ============================================================================

/// Convert Idris value to C value
pub fn idrisToCValue(value: idris_rts.IdrisValue) CValue {
    return .{
        .int = value.int,
    };
}

/// Convert C value to Idris value
pub fn cValueToIdris(value: CValue) idris_rts.IdrisValue {
    return .{
        .int = value.int,
    };
}

/// Convert Idris Either to CResult
pub fn idrisEitherToCResult(either: idris_rts.IdrisEitherValue) CResult {
    return switch (either.tag) {
        .left => blk: {
            // Cast left pointer to IdrisString if present
            if (either.left_ptr) |ptr| {
                const str: *idris_rts.IdrisString = @ptrCast(@alignCast(ptr));
                break :blk CResult.err(ErrorCode.UNKNOWN, types.fromIdrisString(str.*));
            }
            break :blk CResult.err(ErrorCode.UNKNOWN, "Unknown error");
        },
        .right => blk: {
            // Cast right pointer to IdrisValue if present
            if (either.right_ptr) |ptr| {
                const val: *idris_rts.IdrisValue = @ptrCast(@alignCast(ptr));
                break :blk CResult.ok(idrisToCValue(val.*));
            }
            break :blk CResult.ok(.{ .int = 0 });
        },
    };
}

// ============================================================================
// Tests
// ============================================================================

test "C string operations" {
    const cstr = idris2_string_from_cstr("hello");
    defer idris2_string_free(cstr);

    try std.testing.expect(cstr.len == 5);
    try std.testing.expectEqualStrings("hello", cstr.toSlice());
}

test "C option operations" {
    const some = idris2_option_some_int(42);
    const none = idris2_option_none();

    try std.testing.expect(idris2_option_is_some(some));
    try std.testing.expect(idris2_option_is_none(none));
    try std.testing.expect(some.value.int == 42);
}

test "C result operations" {
    const ok = idris2_result_ok_int(100);
    const err = idris2_result_err(ErrorCode.PARSE_ERROR, "invalid input");

    try std.testing.expect(idris2_result_is_ok(ok));
    try std.testing.expect(!idris2_result_is_ok(err));
    try std.testing.expect(idris2_result_error_code(err) == ErrorCode.PARSE_ERROR);
}

test "ABI version" {
    try std.testing.expect(idris2_abi_version() >= 1);
    try std.testing.expect(idris2_abi_compatible(ABI_VERSION));
}
