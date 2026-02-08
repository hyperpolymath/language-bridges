// SPDX-License-Identifier: Palimpsest-MPL-1.0
//! Type conversion utilities for Idris 2 FFI bridge
//!
//! This module provides bidirectional type marshalling between
//! Zig types and Idris 2 runtime representations.

const std = @import("std");
const memory = @import("memory.zig");
const idris_rts = @import("idris_rts.zig");

// ============================================================================
// String Conversions
// ============================================================================

/// Convert a Zig string slice to an Idris string
pub fn toIdrisString(str: []const u8) idris_rts.IdrisString {
    const data = memory.allocator.alloc(u8, str.len) catch return .{ .data = null, .len = 0 };
    @memcpy(data, str);
    return .{
        .data = data.ptr,
        .len = str.len,
    };
}

/// Convert an Idris string to a Zig string slice
/// The returned slice is valid until the Idris string is freed
pub fn fromIdrisString(str: idris_rts.IdrisString) []const u8 {
    if (str.data) |data| {
        return data[0..str.len];
    }
    return "";
}

// ============================================================================
// Option/Maybe Conversions
// ============================================================================

/// Convert a Zig optional to an Idris Maybe
pub fn toOption(comptime T: type, value: ?T) idris_rts.IdrisMaybe(T) {
    if (value) |v| {
        return .{ .tag = .just, .value = v };
    }
    return .{ .tag = .nothing, .value = undefined };
}

/// Convert an Idris Maybe to a Zig optional
pub fn fromOption(comptime T: type, maybe: idris_rts.IdrisMaybe(T)) ?T {
    return switch (maybe.tag) {
        .just => maybe.value,
        .nothing => null,
    };
}

// ============================================================================
// Either Conversions
// ============================================================================

/// Zig representation of Idris Either
pub fn Either(comptime L: type, comptime R: type) type {
    return union(enum) {
        left: L,
        right: R,
    };
}

/// Convert a Zig Either to an Idris Either
pub fn toEither(comptime L: type, comptime R: type, value: Either(L, R)) idris_rts.IdrisEither(L, R) {
    return switch (value) {
        .left => |l| .{ .tag = .left, .left = l, .right = undefined },
        .right => |r| .{ .tag = .right, .left = undefined, .right = r },
    };
}

/// Convert an Idris Either to a Zig Either
pub fn fromEither(comptime L: type, comptime R: type, either: idris_rts.IdrisEither(L, R)) Either(L, R) {
    return switch (either.tag) {
        .left => .{ .left = either.left },
        .right => .{ .right = either.right },
    };
}

// ============================================================================
// List/Slice Conversions
// ============================================================================

/// Convert a Zig slice to an Idris List
pub fn toSlice(comptime T: type, slice: []const T) !idris_rts.IdrisList(T) {
    if (slice.len == 0) {
        return .{ .head = null, .tail = null, .len = 0 };
    }

    const nodes = try memory.allocator.alloc(idris_rts.IdrisListNode(T), slice.len);

    for (slice, 0..) |item, i| {
        nodes[i].value = item;
        nodes[i].next = if (i + 1 < slice.len) &nodes[i + 1] else null;
    }

    return .{
        .head = &nodes[0],
        .tail = &nodes[slice.len - 1],
        .len = slice.len,
    };
}

/// Convert an Idris List to a Zig slice
/// Caller owns the returned slice
pub fn fromSlice(comptime T: type, list: idris_rts.IdrisList(T)) ![]T {
    if (list.len == 0) {
        return &[_]T{};
    }

    const result = try memory.allocator.alloc(T, list.len);

    var current = list.head;
    var i: usize = 0;
    while (current) |node| : (i += 1) {
        result[i] = node.value;
        current = node.next;
    }

    return result;
}

// ============================================================================
// Pair/Tuple Conversions
// ============================================================================

/// Convert a Zig tuple to an Idris Pair
pub fn toPair(comptime A: type, comptime B: type, pair: struct { A, B }) idris_rts.IdrisPair(A, B) {
    return .{ .fst = pair[0], .snd = pair[1] };
}

/// Convert an Idris Pair to a Zig tuple
pub fn fromPair(comptime A: type, comptime B: type, pair: idris_rts.IdrisPair(A, B)) struct { A, B } {
    return .{ pair.fst, pair.snd };
}

// ============================================================================
// Generic Conversions
// ============================================================================

/// Convert any supported Zig type to its Idris representation
pub fn toIdris(value: anytype) idris_rts.IdrisValue {
    const T = @TypeOf(value);

    return switch (@typeInfo(T)) {
        .Int => .{ .int = @intCast(value) },
        .Float => .{ .float = @floatCast(value) },
        .Bool => .{ .int = if (value) 1 else 0 },
        .Pointer => |ptr_info| {
            if (ptr_info.size == .Slice and ptr_info.child == u8) {
                return .{ .string = toIdrisString(value) };
            }
            return .{ .ptr = @ptrCast(@constCast(value)) };
        },
        .Optional => {
            if (value) |v| {
                return .{ .maybe = .{ .tag = .just, .value = toIdris(v) } };
            }
            return .{ .maybe = .{ .tag = .nothing, .value = undefined } };
        },
        else => @compileError("Unsupported type for Idris conversion: " ++ @typeName(T)),
    };
}

/// Convert an Idris value to the specified Zig type
pub fn fromIdris(comptime T: type, value: idris_rts.IdrisValue) T {
    return switch (@typeInfo(T)) {
        .Int => @intCast(value.int),
        .Float => @floatCast(value.float),
        .Bool => value.int != 0,
        .Pointer => |ptr| {
            if (ptr.size == .Slice and ptr.child == u8) {
                return fromIdrisString(value.string);
            }
            return @ptrCast(@alignCast(value.ptr));
        },
        .Optional => |opt| {
            return switch (value.maybe.tag) {
                .just => fromIdris(opt.child, value.maybe.value),
                .nothing => null,
            };
        },
        else => @compileError("Unsupported type for Idris conversion: " ++ @typeName(T)),
    };
}

// ============================================================================
// Tests
// ============================================================================

test "string conversion roundtrip" {
    const original = "Hello, Idris!";
    const idris_str = toIdrisString(original);
    defer memory.freeIdrisString(idris_str);

    const back = fromIdrisString(idris_str);
    try std.testing.expectEqualStrings(original, back);
}

test "option conversion" {
    const some: ?i32 = 42;
    const none: ?i32 = null;

    const idris_some = toOption(i32, some);
    const idris_none = toOption(i32, none);

    try std.testing.expect(fromOption(i32, idris_some) == 42);
    try std.testing.expect(fromOption(i32, idris_none) == null);
}

test "either conversion" {
    const left: Either([]const u8, i32) = .{ .left = "error" };
    const right: Either([]const u8, i32) = .{ .right = 42 };

    const idris_left = toEither([]const u8, i32, left);
    const idris_right = toEither([]const u8, i32, right);

    const back_left = fromEither([]const u8, i32, idris_left);
    const back_right = fromEither([]const u8, i32, idris_right);

    try std.testing.expectEqualStrings("error", back_left.left);
    try std.testing.expect(back_right.right == 42);
}
