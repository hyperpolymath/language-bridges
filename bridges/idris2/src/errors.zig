// SPDX-License-Identifier: Palimpsest-MPL-1.0
//! Error handling for Idris 2 FFI bridge
//!
//! This module provides error types and utilities for working with
//! Idris functions that return Either Error Value.

const std = @import("std");
const idris_rts = @import("idris_rts.zig");
const types = @import("types.zig");

// ============================================================================
// Error Types
// ============================================================================

/// Idris error representation
pub const IdrisError = struct {
    code: ErrorCode,
    message: []const u8,
    context: ?[]const u8,
};

/// Standard error codes
pub const ErrorCode = enum(u32) {
    unknown = 0,

    // Parsing errors
    parse_error = 100,
    invalid_input = 101,
    unexpected_eof = 102,

    // Validation errors
    validation_error = 200,
    out_of_range = 201,
    type_mismatch = 202,

    // Security errors
    security_error = 300,
    injection_detected = 301,
    traversal_detected = 302,

    // Resource errors
    resource_error = 400,
    not_found = 401,
    access_denied = 402,

    // Math errors
    math_error = 500,
    division_by_zero = 501,
    overflow = 502,
    underflow = 503,
};

/// Result type for checked calls
pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: IdrisError,

        const Self = @This();

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        pub fn isErr(self: Self) bool {
            return self == .err;
        }

        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |v| v,
                .err => @panic("Attempted to unwrap an error result"),
            };
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |v| v,
                .err => default,
            };
        }

        pub fn unwrapOrElse(self: Self, f: *const fn (IdrisError) T) T {
            return switch (self) {
                .ok => |v| v,
                .err => |e| f(e),
            };
        }

        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Result(U) {
            return switch (self) {
                .ok => |v| .{ .ok = f(v) },
                .err => |e| .{ .err = e },
            };
        }
    };
}

// ============================================================================
// Error Conversion
// ============================================================================

/// Convert an Idris Either to a Result
pub fn fromIdrisEither(either: idris_rts.IdrisEitherValue) Result(idris_rts.IdrisValue) {
    return switch (either.tag) {
        .left => .{ .err = parseError(either.left) },
        .right => .{ .ok = either.right },
    };
}

/// Parse an Idris error value into our error type
fn parseError(value: idris_rts.IdrisValue) IdrisError {
    // Try to extract error information from the Idris value
    // This depends on how errors are structured in the Idris code

    // For now, return a generic error
    return .{
        .code = .unknown,
        .message = extractErrorMessage(value),
        .context = null,
    };
}

/// Extract error message from Idris value
fn extractErrorMessage(value: idris_rts.IdrisValue) []const u8 {
    // If it's a string, use it directly
    if (value.string.data != null) {
        return types.fromIdrisString(value.string);
    }

    // Otherwise return generic message
    return "Unknown error";
}

/// Get the error message as a string
pub fn getMessage(err: IdrisError) []const u8 {
    return err.message;
}

/// Get the error code
pub fn getCode(err: IdrisError) ErrorCode {
    return err.code;
}

/// Get error context if available
pub fn getContext(err: IdrisError) ?[]const u8 {
    return err.context;
}

// ============================================================================
// Error Creation (for testing/mocking)
// ============================================================================

/// Create an error with a code and message
pub fn makeError(code: ErrorCode, message: []const u8) IdrisError {
    return .{
        .code = code,
        .message = message,
        .context = null,
    };
}

/// Create an error with context
pub fn makeErrorWithContext(code: ErrorCode, message: []const u8, context: []const u8) IdrisError {
    return .{
        .code = code,
        .message = message,
        .context = context,
    };
}

// ============================================================================
// Error Formatting
// ============================================================================

/// Format an error for display
pub fn format(err: IdrisError, writer: anytype) !void {
    try writer.print("Error {d}: {s}", .{ @intFromEnum(err.code), err.message });
    if (err.context) |ctx| {
        try writer.print(" (context: {s})", .{ctx});
    }
}

/// Format an error to a string (allocates)
pub fn toString(err: IdrisError, allocator: std.mem.Allocator) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    try format(err, list.writer());
    return list.toOwnedSlice();
}

// ============================================================================
// Tests
// ============================================================================

test "Result ok" {
    const result: Result(i32) = .{ .ok = 42 };
    try std.testing.expect(result.isOk());
    try std.testing.expect(!result.isErr());
    try std.testing.expect(result.unwrap() == 42);
}

test "Result err" {
    const err = makeError(.division_by_zero, "Cannot divide by zero");
    const result: Result(i32) = .{ .err = err };

    try std.testing.expect(!result.isOk());
    try std.testing.expect(result.isErr());
    try std.testing.expect(result.unwrapOr(0) == 0);
}

test "error formatting" {
    const err = makeErrorWithContext(.injection_detected, "SQL injection detected", "user_input");
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try format(err, stream.writer());

    const output = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "SQL injection") != null);
}
