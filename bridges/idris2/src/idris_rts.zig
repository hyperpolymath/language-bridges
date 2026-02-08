// SPDX-License-Identifier: PMPL-1.0
//! Idris 2 Runtime System integration
//!
//! This module provides types and functions that mirror the Idris 2
//! runtime representation. It enables bidirectional interop between
//! Zig and Idris 2 verified code.

const std = @import("std");

// ============================================================================
// Core Idris Types
// ============================================================================

/// Universal Idris value representation
/// Simple tagged union for FFI - use accessor functions for complex types
pub const IdrisValue = extern union {
    int: i64,
    float: f64,
    string: IdrisString,
    ptr: ?*anyopaque,
};

/// Idris String representation
pub const IdrisString = extern struct {
    data: ?[*]u8,
    len: usize,
};

/// Generic Maybe value (untyped) - uses pointer to avoid circular dependency
pub const IdrisMaybeValue = extern struct {
    tag: MaybeTag,
    value_ptr: ?*anyopaque, // Pointer to value (cast as needed)
};

/// Maybe/Option tag
pub const MaybeTag = enum(u8) {
    nothing = 0,
    just = 1,
};

/// Typed Maybe for compile-time type safety
pub fn IdrisMaybe(comptime T: type) type {
    return struct {
        tag: MaybeTag,
        value: T,
    };
}

/// Generic Either value (untyped) - uses pointers to avoid circular dependency
pub const IdrisEitherValue = extern struct {
    tag: EitherTag,
    left_ptr: ?*anyopaque, // Pointer to left value
    right_ptr: ?*anyopaque, // Pointer to right value
};

/// Either tag
pub const EitherTag = enum(u8) {
    left = 0,
    right = 1,
};

/// Typed Either for compile-time type safety
pub fn IdrisEither(comptime L: type, comptime R: type) type {
    return struct {
        tag: EitherTag,
        left: L,
        right: R,
    };
}

/// Idris List node
pub fn IdrisListNode(comptime T: type) type {
    return struct {
        value: T,
        next: ?*IdrisListNode(T),
    };
}

/// Idris List
pub fn IdrisList(comptime T: type) type {
    return struct {
        head: ?*IdrisListNode(T),
        tail: ?*IdrisListNode(T),
        len: usize,
    };
}

/// Idris Pair/Tuple
pub fn IdrisPair(comptime A: type, comptime B: type) type {
    return struct {
        fst: A,
        snd: B,
    };
}

/// Idris algebraic data type constructor
pub const IdrisConstructor = extern struct {
    tag: u32,
    arity: u32,
    args: [*]IdrisValue,
};

// ============================================================================
// Runtime Initialization
// ============================================================================

/// Whether the runtime has been initialized
var runtime_initialized: bool = false;

/// Initialize the Idris 2 runtime
/// This must be called before any Idris functions are invoked
pub fn initRuntime() !void {
    if (runtime_initialized) return;

    // Call Idris runtime initialization if available
    if (@hasDecl(@import("root"), "idris2_init")) {
        @import("root").idris2_init();
    }

    runtime_initialized = true;
}

/// Deinitialize the Idris 2 runtime
pub fn deinitRuntime() void {
    if (!runtime_initialized) return;

    // Call Idris runtime cleanup if available
    if (@hasDecl(@import("root"), "idris2_deinit")) {
        @import("root").idris2_deinit();
    }

    runtime_initialized = false;
}

/// Check if runtime is initialized
pub fn isInitialized() bool {
    return runtime_initialized;
}

// ============================================================================
// GC Integration
// ============================================================================

/// Hint to the Idris GC that we're holding a reference
pub fn gcRoot(value: *IdrisValue) void {
    // In production, this would register with Idris GC
    _ = value;
}

/// Release a GC root
pub fn gcUnroot(value: *IdrisValue) void {
    // In production, this would unregister from Idris GC
    _ = value;
}

/// Force a garbage collection cycle
pub fn gcCollect() void {
    // In production, this would trigger Idris GC
}

// ============================================================================
// Foreign Function Interface
// ============================================================================

/// Call an Idris function with raw arguments
pub fn callRaw(
    func_ptr: *const fn () callconv(.C) IdrisValue,
) IdrisValue {
    return func_ptr();
}

/// Call an Idris function with one argument
pub fn callRaw1(
    func_ptr: *const fn (IdrisValue) callconv(.C) IdrisValue,
    arg: IdrisValue,
) IdrisValue {
    return func_ptr(arg);
}

/// Call an Idris function with two arguments
pub fn callRaw2(
    func_ptr: *const fn (IdrisValue, IdrisValue) callconv(.C) IdrisValue,
    arg1: IdrisValue,
    arg2: IdrisValue,
) IdrisValue {
    return func_ptr(arg1, arg2);
}

/// Call an Idris function with three arguments
pub fn callRaw3(
    func_ptr: *const fn (IdrisValue, IdrisValue, IdrisValue) callconv(.C) IdrisValue,
    arg1: IdrisValue,
    arg2: IdrisValue,
    arg3: IdrisValue,
) IdrisValue {
    return func_ptr(arg1, arg2, arg3);
}

// ============================================================================
// World Token
// ============================================================================

/// Idris World token for IO operations
/// This is a phantom type in Idris but needs representation in FFI
pub const World = extern struct {
    _marker: u8 = 0,
};

/// Create a World token for IO operations
pub fn makeWorld() World {
    return .{};
}

// ============================================================================
// Tests
// ============================================================================

test "IdrisString layout" {
    const str = IdrisString{ .data = null, .len = 0 };
    try std.testing.expect(str.len == 0);
    try std.testing.expect(str.data == null);
}

test "IdrisMaybe layout" {
    const nothing = IdrisMaybe(i32){ .tag = .nothing, .value = undefined };
    const just = IdrisMaybe(i32){ .tag = .just, .value = 42 };

    try std.testing.expect(nothing.tag == .nothing);
    try std.testing.expect(just.tag == .just);
    try std.testing.expect(just.value == 42);
}

test "runtime initialization" {
    try initRuntime();
    try std.testing.expect(isInitialized());
    deinitRuntime();
    try std.testing.expect(!isInitialized());
}
