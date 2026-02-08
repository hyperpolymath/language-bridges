// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
//
// abi.zig - Bebop-V-FFI ABI definitions (pure Zig replacement for bebop_v_ffi.h)
//
// This module defines the stable ABI contract. The types here are exported
// with C-compatible layout using `extern struct`, enabling interop with:
// - C/C++ via Zig's C header generation
// - V via direct FFI bindings
// - Any other language supporting C ABI
//
// ABI STABILITY GUARANTEE:
// - Version 1.x.x: Backwards compatible (no breaking changes)
// - Structs: Fields may be added at end only, never removed/reordered
// - Functions: New functions may be added, existing signatures frozen
// - Error codes: New codes may be added, existing values frozen
//
// To generate a C header for consumers who need one:
//   zig build -Dheader=true
//
// The generated header will be in zig-out/include/bebop_v_ffi.h

const std = @import("std");

/// ABI Version - LOCKED (matches semantic versioning)
pub const version = struct {
    pub const major: u32 = 1;
    pub const minor: u32 = 0;
    pub const patch: u32 = 0;
    pub const string = "1.0.0";

    /// Combined version for runtime checks: (major << 16) | (minor << 8) | patch
    pub const combined: u32 = (major << 16) | (minor << 8) | patch;
};

/// Error codes - LOCKED (values frozen, new codes may be added)
/// These match POSIX conventions where applicable.
pub const Error = enum(i32) {
    ok = 0,
    null_ctx = -1,
    null_data = -2,
    invalid_length = -3,
    decode_failed = -4,
    encode_failed = -5,
    buffer_too_small = -6,
    not_implemented = -99,

    /// Check if error represents success
    pub fn isOk(self: Error) bool {
        return self == .ok;
    }

    /// Convert to human-readable message
    pub fn message(self: Error) []const u8 {
        return switch (self) {
            .ok => "success",
            .null_ctx => "null context pointer",
            .null_data => "null data pointer",
            .invalid_length => "invalid data length",
            .decode_failed => "decode failed",
            .encode_failed => "encode failed",
            .buffer_too_small => "output buffer too small",
            .not_implemented => "not implemented",
        };
    }
};

/// Byte slice passed across FFI. Data is NOT NUL-terminated.
/// Uses extern struct for C ABI compatibility.
pub const Bytes = extern struct {
    ptr: ?[*]const u8,
    len: usize,

    /// Create empty byte slice
    pub fn empty() Bytes {
        return .{ .ptr = null, .len = 0 };
    }

    /// Create from Zig slice
    pub fn fromSlice(slice: []const u8) Bytes {
        return .{
            .ptr = if (slice.len > 0) slice.ptr else null,
            .len = slice.len,
        };
    }

    /// Convert to Zig slice (returns empty slice if null)
    pub fn toSlice(self: Bytes) []const u8 {
        if (self.ptr) |p| {
            return p[0..self.len];
        }
        return &[_]u8{};
    }

    /// Check if empty
    pub fn isEmpty(self: Bytes) bool {
        return self.len == 0 or self.ptr == null;
    }
};

/// SensorType enum values (matches sensors.bop schema)
pub const SensorType = struct {
    pub const temperature: u16 = 1;
    pub const humidity: u16 = 2;
    pub const pressure: u16 = 3;
    pub const vibration: u16 = 4;

    /// Get human-readable name for sensor type
    pub fn name(sensor_type: u16) []const u8 {
        return switch (sensor_type) {
            temperature => "Temperature",
            humidity => "Humidity",
            pressure => "Pressure",
            vibration => "Vibration",
            else => "Unknown",
        };
    }
};

/// Flat, FFI-friendly representation of SensorReading (schema-defined).
/// Uses extern struct for C ABI compatibility.
pub const SensorReading = extern struct {
    timestamp: u64,
    sensor_id: Bytes,
    sensor_type: u16,
    value: f64,
    unit: Bytes,
    location: Bytes,

    metadata_count: usize,
    metadata_keys: ?[*]Bytes,
    metadata_values: ?[*]Bytes,

    error_code: i32,
    error_message: ?[*:0]const u8,

    /// Create empty/zeroed SensorReading
    pub fn empty() SensorReading {
        return .{
            .timestamp = 0,
            .sensor_id = Bytes.empty(),
            .sensor_type = 0,
            .value = 0.0,
            .unit = Bytes.empty(),
            .location = Bytes.empty(),
            .metadata_count = 0,
            .metadata_keys = null,
            .metadata_values = null,
            .error_code = 0,
            .error_message = null,
        };
    }

    /// Check if reading has an error
    pub fn hasError(self: *const SensorReading) bool {
        return self.error_code != 0;
    }

    /// Get sensor type name
    pub fn sensorTypeName(self: *const SensorReading) []const u8 {
        return SensorType.name(self.sensor_type);
    }

    /// Get metadata as key-value pairs (returns slice iterator)
    pub fn getMetadata(self: *const SensorReading) MetadataIterator {
        return MetadataIterator.init(self);
    }
};

/// Iterator over metadata key-value pairs
pub const MetadataIterator = struct {
    reading: *const SensorReading,
    index: usize,

    pub fn init(reading: *const SensorReading) MetadataIterator {
        return .{ .reading = reading, .index = 0 };
    }

    pub fn next(self: *MetadataIterator) ?struct { key: Bytes, value: Bytes } {
        if (self.index >= self.reading.metadata_count) return null;
        if (self.reading.metadata_keys == null or self.reading.metadata_values == null) return null;

        const result = .{
            .key = self.reading.metadata_keys.?[self.index],
            .value = self.reading.metadata_values.?[self.index],
        };
        self.index += 1;
        return result;
    }
};

/// Opaque context handle for C interop
/// Actual implementation is in bridge.zig
pub const Context = opaque {};

// =========================================================
// TESTS
// =========================================================

test "version format" {
    try std.testing.expectEqual(@as(u32, 0x010000), version.combined);
}

test "bytes from slice" {
    const data = "hello";
    const bytes = Bytes.fromSlice(data);
    try std.testing.expectEqual(@as(usize, 5), bytes.len);
    try std.testing.expect(!bytes.isEmpty());
}

test "bytes empty" {
    const bytes = Bytes.empty();
    try std.testing.expect(bytes.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), bytes.toSlice().len);
}

test "sensor_reading empty" {
    const reading = SensorReading.empty();
    try std.testing.expectEqual(@as(u64, 0), reading.timestamp);
    try std.testing.expect(!reading.hasError());
}

test "error messages" {
    try std.testing.expectEqualStrings("success", Error.ok.message());
    try std.testing.expectEqualStrings("decode failed", Error.decode_failed.message());
}
