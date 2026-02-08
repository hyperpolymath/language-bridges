// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath
//! idris2-zig-ffi: Pure Zig FFI bridge for Idris 2
//!
//! This library provides a pure Zig ABI for bidirectional interop between
//! Idris 2 verified code and Zig applications. No C headers or C code required.
//!
//! ## Quick Start
//!
//! ```zig
//! const ffi = @import("idris2_zig_ffi");
//!
//! pub fn safeDiv(a: i64, b: i64) ?i64 {
//!     const result = ffi.types.toOption(i64, yourIdrisFunc(a, b));
//!     return ffi.types.fromOption(i64, result);
//! }
//!
//! // Register Zig callback for Idris to call
//! pub fn registerCallback() void {
//!     ffi.callbacks.register("myCallback", myZigFunction);
//! }
//! ```
//!
//! ## ABI Targets
//!
//! - **Native**: Pure Zig ABI (this module)
//! - **WASM**: WebAssembly for browsers
//! - **WASI**: WebAssembly System Interface for runtimes

const std = @import("std");
const builtin = @import("builtin");

// Core modules
pub const memory = @import("memory.zig");
pub const types = @import("types.zig");
pub const idris_rts = @import("idris_rts.zig");
pub const errors = @import("errors.zig");

// ABI-specific modules
pub const abi = struct {
    pub const native = @import("abi/native.zig");
    pub const wasm = @import("abi/wasm.zig");
    pub const wasi = @import("abi/wasi.zig");
};

// Convenience aliases for current target
pub const native_abi = abi.native;
pub usingnamespace if (builtin.target.cpu.arch == .wasm32)
    if (builtin.os.tag == .wasi) abi.wasi else abi.wasm
else
    struct {};

// Re-export commonly used functions
pub const alloc = memory.alloc;
pub const free = memory.free;
pub const toIdrisString = types.toIdrisString;
pub const fromIdrisString = types.fromIdrisString;
pub const freeIdrisString = memory.freeIdrisString;
pub const toOption = types.toOption;
pub const fromOption = types.fromOption;
pub const toEither = types.toEither;
pub const fromEither = types.fromEither;
pub const toSlice = types.toSlice;
pub const fromSlice = types.fromSlice;

/// ABI version for compatibility checking
pub const ABI_VERSION: u32 = 1;

/// Initialize the Idris 2 runtime
/// Must be called before any Idris functions
pub fn init() !void {
    try idris_rts.initRuntime();
}

/// Cleanup the Idris 2 runtime
/// Should be called when done using Idris functions
pub fn deinit() void {
    idris_rts.deinitRuntime();
}

/// Call an Idris function with automatic type marshalling
pub fn call(comptime func: anytype, args: anytype) @TypeOf(callResult(func)) {
    const ArgsType = @TypeOf(args);
    const args_info = @typeInfo(ArgsType);

    if (args_info != .Struct) {
        @compileError("Expected tuple of arguments");
    }

    // Marshal arguments to Idris types
    var idris_args: [args_info.Struct.fields.len]idris_rts.IdrisValue = undefined;
    inline for (args_info.Struct.fields, 0..) |field, i| {
        idris_args[i] = types.toIdris(@field(args, field.name));
    }

    // Call the function
    const result = @call(.auto, func, idris_args);

    // Marshal result back to Zig type
    return types.fromIdris(@TypeOf(callResult(func)), result);
}

fn callResult(comptime func: anytype) type {
    const FnType = @TypeOf(func);
    const fn_info = @typeInfo(FnType);
    if (fn_info != .Fn) {
        @compileError("Expected function");
    }
    return fn_info.Fn.return_type orelse void;
}

/// Call an Idris function that returns Either Error Value
pub fn callChecked(comptime func: anytype, args: anytype) errors.Result(callResult(func)) {
    const raw_result = call(func, args);
    return errors.fromIdrisEither(raw_result);
}

/// Get the error message from an Idris error
pub fn getErrorMessage(err: errors.IdrisError) []const u8 {
    return errors.getMessage(err);
}

// ============================================================================
// Bidirectional Callback System (Zig ↔ Idris)
// ============================================================================

/// Callback function type for Zig functions callable from Idris
pub const CallbackFn = *const fn (args: []const idris_rts.IdrisValue) idris_rts.IdrisValue;

/// Callback registry for bidirectional FFI
pub const callbacks = struct {
    const max_callbacks = 256;
    var registry: [max_callbacks]?CallbackEntry = [_]?CallbackEntry{null} ** max_callbacks;
    var count: usize = 0;

    const CallbackEntry = struct {
        name: []const u8,
        func: CallbackFn,
    };

    /// Register a Zig callback that Idris code can invoke
    pub fn register(name: []const u8, func: CallbackFn) !void {
        if (count >= max_callbacks) return error.TooManyCallbacks;
        registry[count] = .{ .name = name, .func = func };
        count += 1;
    }

    /// Unregister a callback by name
    pub fn unregister(name: []const u8) void {
        for (&registry, 0..) |*entry, i| {
            if (entry.*) |e| {
                if (std.mem.eql(u8, e.name, name)) {
                    entry.* = null;
                    // Compact if last
                    if (i == count - 1) count -= 1;
                    return;
                }
            }
        }
    }

    /// Lookup a callback by name
    pub fn lookup(name: []const u8) ?CallbackFn {
        for (registry[0..count]) |entry| {
            if (entry) |e| {
                if (std.mem.eql(u8, e.name, name)) {
                    return e.func;
                }
            }
        }
        return null;
    }

    /// Invoke a registered callback by name
    pub fn invoke(name: []const u8, args: []const idris_rts.IdrisValue) ?idris_rts.IdrisValue {
        if (lookup(name)) |func| {
            return func(args);
        }
        return null;
    }

    /// Clear all registered callbacks
    pub fn clear() void {
        for (&registry) |*entry| {
            entry.* = null;
        }
        count = 0;
    }

    /// Get count of registered callbacks
    pub fn getCount() usize {
        return count;
    }
};

// ============================================================================
// Zig Exports (Pure Zig ABI)
// ============================================================================

/// Exported initialization for linking
pub export fn idris2_zig_init() i32 {
    init() catch return -1;
    return 0;
}

/// Exported cleanup for linking
pub export fn idris2_zig_deinit() void {
    deinit();
}

/// Get ABI version for compatibility checking
pub export fn idris2_zig_abi_version() u32 {
    return ABI_VERSION;
}

/// Invoke a registered Zig callback (for Idris → Zig calls)
pub export fn idris2_zig_invoke_callback(
    name_ptr: [*]const u8,
    name_len: usize,
    args_ptr: [*]const idris_rts.IdrisValue,
    args_len: usize,
) idris_rts.IdrisValue {
    const name = name_ptr[0..name_len];
    const args = args_ptr[0..args_len];
    return callbacks.invoke(name, args) orelse .{ .int = 0 };
}

// ============================================================================
// Tests
// ============================================================================

test "ABI version is set" {
    try std.testing.expect(ABI_VERSION >= 1);
}

test "init and deinit" {
    try init();
    deinit();
}

test "callback registration" {
    const testCallback = struct {
        fn call(args: []const idris_rts.IdrisValue) idris_rts.IdrisValue {
            if (args.len > 0) {
                return .{ .int = args[0].int * 2 };
            }
            return .{ .int = 0 };
        }
    }.call;

    try callbacks.register("double", testCallback);
    try std.testing.expect(callbacks.getCount() == 1);

    const args = [_]idris_rts.IdrisValue{.{ .int = 21 }};
    const result = callbacks.invoke("double", &args);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.int == 42);

    callbacks.unregister("double");
    callbacks.clear();
}
