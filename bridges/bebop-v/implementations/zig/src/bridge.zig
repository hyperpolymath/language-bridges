// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
//
// bridge.zig - Zig implementation of the Bebop-V-FFI C ABI
//
// This exports C-callable functions matching include/bebop_v_ffi.h.
// No C compiler needed — Zig handles the ABI directly.

const std = @import("std");
const Allocator = std.mem.Allocator;

// ABI Version - must match include/bebop_v_ffi.h
pub const ABI_VERSION_MAJOR: u32 = 1;
pub const ABI_VERSION_MINOR: u32 = 0;
pub const ABI_VERSION_PATCH: u32 = 0;
pub const ABI_VERSION: u32 = (ABI_VERSION_MAJOR << 16) | (ABI_VERSION_MINOR << 8) | ABI_VERSION_PATCH;

// SensorType enum values (matches sensors.bop)
pub const SensorType = struct {
    pub const Temperature: u16 = 1;
    pub const Humidity: u16 = 2;
    pub const Pressure: u16 = 3;
    pub const Vibration: u16 = 4;
};

// -----------------------------------------------------------------------------
// Types matching bebop_v_ffi.h
// -----------------------------------------------------------------------------

/// Byte slice passed across FFI. Data is NOT NUL-terminated.
pub const VBytes = extern struct {
    ptr: ?[*]const u8,
    len: usize,

    pub fn empty() VBytes {
        return .{ .ptr = null, .len = 0 };
    }

    pub fn fromSlice(slice: []const u8) VBytes {
        return .{
            .ptr = if (slice.len > 0) slice.ptr else null,
            .len = slice.len,
        };
    }
};

/// Flat, FFI-friendly representation of SensorReading.
pub const VSensorReading = extern struct {
    timestamp: u64,
    sensor_id: VBytes,
    sensor_type: u16,
    value: f64,
    unit: VBytes,
    location: VBytes,

    metadata_count: usize,
    metadata_keys: ?[*]VBytes,
    metadata_values: ?[*]VBytes,

    error_code: i32,
    error_message: ?[*:0]const u8,

    pub fn empty() VSensorReading {
        return .{
            .timestamp = 0,
            .sensor_id = VBytes.empty(),
            .sensor_type = 0,
            .value = 0.0,
            .unit = VBytes.empty(),
            .location = VBytes.empty(),
            .metadata_count = 0,
            .metadata_keys = null,
            .metadata_values = null,
            .error_code = 0,
            .error_message = null,
        };
    }
};

// Error codes - must match include/bebop_v_ffi.h
pub const BEBOP_OK: i32 = 0;
pub const BEBOP_ERR_NULL_CTX: i32 = -1;
pub const BEBOP_ERR_NULL_DATA: i32 = -2;
pub const BEBOP_ERR_INVALID_LENGTH: i32 = -3;
pub const BEBOP_ERR_DECODE_FAILED: i32 = -4;
pub const BEBOP_ERR_ENCODE_FAILED: i32 = -5;
pub const BEBOP_ERR_BUFFER_TOO_SMALL: i32 = -6;
pub const BEBOP_ERR_NOT_IMPLEMENTED: i32 = -99;

// -----------------------------------------------------------------------------
// Context (arena-based allocator for zero-copy decode)
// -----------------------------------------------------------------------------

pub const BebopCtx = struct {
    arena: std.heap.ArenaAllocator,
    error_buf: [256]u8,
    error_msg: ?[*:0]const u8,

    pub fn init() *BebopCtx {
        const backing = std.heap.page_allocator;
        const ctx = backing.create(BebopCtx) catch return @ptrFromInt(0);
        ctx.* = .{
            .arena = std.heap.ArenaAllocator.init(backing),
            .error_buf = undefined,
            .error_msg = null,
        };
        return ctx;
    }

    pub fn deinit(self: *BebopCtx) void {
        self.arena.deinit();
        std.heap.page_allocator.destroy(self);
    }

    pub fn reset(self: *BebopCtx) void {
        _ = self.arena.reset(.retain_capacity);
        self.error_msg = null;
    }

    pub fn allocator(self: *BebopCtx) Allocator {
        return self.arena.allocator();
    }

    pub fn setError(self: *BebopCtx, msg: []const u8) void {
        const len = @min(msg.len, self.error_buf.len - 1);
        @memcpy(self.error_buf[0..len], msg[0..len]);
        self.error_buf[len] = 0;
        self.error_msg = @ptrCast(&self.error_buf);
    }
};

// -----------------------------------------------------------------------------
// Bebop Wire Format Decoder
// -----------------------------------------------------------------------------

const DecodeError = error{
    UnexpectedEnd,
    InvalidFieldIndex,
    InvalidUtf8,
    AllocationFailed,
};

/// Read a little-endian u32 from buffer
fn readU32(data: []const u8, pos: *usize) DecodeError!u32 {
    if (pos.* + 4 > data.len) return DecodeError.UnexpectedEnd;
    const val = std.mem.readInt(u32, data[pos.*..][0..4], .little);
    pos.* += 4;
    return val;
}

/// Read a little-endian u64 from buffer
fn readU64(data: []const u8, pos: *usize) DecodeError!u64 {
    if (pos.* + 8 > data.len) return DecodeError.UnexpectedEnd;
    const val = std.mem.readInt(u64, data[pos.*..][0..8], .little);
    pos.* += 8;
    return val;
}

/// Read a little-endian u16 from buffer
fn readU16(data: []const u8, pos: *usize) DecodeError!u16 {
    if (pos.* + 2 > data.len) return DecodeError.UnexpectedEnd;
    const val = std.mem.readInt(u16, data[pos.*..][0..2], .little);
    pos.* += 2;
    return val;
}

/// Read a little-endian f64 from buffer
fn readF64(data: []const u8, pos: *usize) DecodeError!f64 {
    if (pos.* + 8 > data.len) return DecodeError.UnexpectedEnd;
    const bytes = data[pos.*..][0..8];
    pos.* += 8;
    return @bitCast(std.mem.readInt(u64, bytes, .little));
}

/// Read a Bebop string (4-byte len + UTF-8 bytes)
fn readString(data: []const u8, pos: *usize) DecodeError![]const u8 {
    const len = try readU32(data, pos);
    if (pos.* + len > data.len) return DecodeError.UnexpectedEnd;
    const str = data[pos.* .. pos.* + len];
    pos.* += len;
    // Validate UTF-8
    if (!std.unicode.utf8ValidateSlice(str)) return DecodeError.InvalidUtf8;
    return str;
}

/// Decode SensorReading from Bebop wire format into VSensorReading struct
fn decodeSensorReading(ctx: *BebopCtx, data: []const u8, out: *VSensorReading) DecodeError!void {
    const alloc = ctx.allocator();
    var pos: usize = 0;

    // Initialize output to empty
    out.* = VSensorReading.empty();

    // Parse message fields (field index + data, terminated by 0)
    while (pos < data.len) {
        if (pos >= data.len) break;
        const field_index = data[pos];
        pos += 1;

        if (field_index == 0) break; // End of message

        switch (field_index) {
            1 => { // timestamp: uint64
                out.timestamp = try readU64(data, &pos);
            },
            2 => { // sensorId: string
                const str = try readString(data, &pos);
                out.sensor_id = VBytes.fromSlice(str);
            },
            3 => { // sensorType: uint16
                out.sensor_type = try readU16(data, &pos);
            },
            4 => { // value: float64
                out.value = try readF64(data, &pos);
            },
            5 => { // unit: string
                const str = try readString(data, &pos);
                out.unit = VBytes.fromSlice(str);
            },
            6 => { // location: string
                const str = try readString(data, &pos);
                out.location = VBytes.fromSlice(str);
            },
            7 => { // metadata: map<string, string>
                const count = try readU32(data, &pos);
                if (count > 0) {
                    const keys = alloc.alloc(VBytes, count) catch return DecodeError.AllocationFailed;
                    const values = alloc.alloc(VBytes, count) catch return DecodeError.AllocationFailed;

                    for (0..count) |i| {
                        const k = try readString(data, &pos);
                        const v = try readString(data, &pos);
                        keys[i] = VBytes.fromSlice(k);
                        values[i] = VBytes.fromSlice(v);
                    }

                    out.metadata_count = count;
                    out.metadata_keys = keys.ptr;
                    out.metadata_values = values.ptr;
                }
            },
            else => return DecodeError.InvalidFieldIndex,
        }
    }
}

// -----------------------------------------------------------------------------
// Exported C ABI functions
// -----------------------------------------------------------------------------

/// Return ABI version for runtime compatibility checks.
export fn bebop_version() callconv(.c) u32 {
    return ABI_VERSION;
}

/// Create a new context. Returns null on allocation failure.
export fn bebop_ctx_new() callconv(.c) ?*BebopCtx {
    const ctx = BebopCtx.init();
    if (@intFromPtr(ctx) == 0) return null;
    return ctx;
}

/// Free a context and all its allocations.
export fn bebop_ctx_free(ctx: ?*BebopCtx) callconv(.c) void {
    if (ctx) |c| {
        c.deinit();
    }
}

/// Reset context arena for reuse (high-throughput pattern).
export fn bebop_ctx_reset(ctx: ?*BebopCtx) callconv(.c) void {
    if (ctx) |c| {
        c.reset();
    }
}

/// Decode a SensorReading from Bebop wire format.
/// Returns 0 on success, negative error code on failure.
export fn bebop_decode_sensor_reading(
    ctx: ?*BebopCtx,
    data: ?[*]const u8,
    len: usize,
    out: ?*VSensorReading,
) callconv(.c) i32 {
    const c = ctx orelse return BEBOP_ERR_NULL_CTX;
    const output = out orelse return BEBOP_ERR_NULL_DATA;
    const bytes_ptr = data orelse return BEBOP_ERR_NULL_DATA;

    if (len == 0) return BEBOP_ERR_INVALID_LENGTH;

    const bytes = bytes_ptr[0..len];

    decodeSensorReading(c, bytes, output) catch |err| {
        output.* = VSensorReading.empty();
        output.error_code = BEBOP_ERR_DECODE_FAILED;

        const msg = switch (err) {
            DecodeError.UnexpectedEnd => "unexpected end of data",
            DecodeError.InvalidFieldIndex => "invalid field index",
            DecodeError.InvalidUtf8 => "invalid UTF-8 string",
            DecodeError.AllocationFailed => "allocation failed",
        };
        c.setError(msg);
        output.error_message = c.error_msg;

        return BEBOP_ERR_DECODE_FAILED;
    };

    output.error_code = BEBOP_OK;
    output.error_message = null;
    return BEBOP_OK;
}

/// Free per-reading allocations. Safe to call multiple times.
export fn bebop_free_sensor_reading(ctx: ?*BebopCtx, reading: ?*VSensorReading) callconv(.c) void {
    // With arena allocation, individual frees are no-ops.
    // Memory is reclaimed on ctx reset/free.
    _ = ctx;
    if (reading) |r| {
        r.* = VSensorReading.empty();
    }
}

/// Encode a batch of readings. Returns bytes written, 0 on failure.
export fn bebop_encode_batch_readings(
    ctx: ?*BebopCtx,
    readings: ?[*]const VSensorReading,
    count: usize,
    out_buf: ?[*]u8,
    out_len: usize,
) callconv(.c) usize {
    _ = ctx;
    _ = readings;
    _ = count;
    _ = out_buf;
    _ = out_len;

    // TODO: Implement actual Bebop encoding
    return 0; // Not implemented
}

// -----------------------------------------------------------------------------
// Callback Types and Registration (Bidirectional FFI)
// -----------------------------------------------------------------------------

/// Callback invoked when a sensor reading is received
pub const SensorReadingCallback = *const fn (*const VSensorReading) callconv(.c) void;

/// Callback invoked on errors
pub const ErrorCallback = *const fn (i32, [*:0]const u8) callconv(.c) void;

// Global callback storage
var g_reading_callback: ?SensorReadingCallback = null;
var g_error_callback: ?ErrorCallback = null;

/// Register callback for receiving sensor readings.
export fn bebop_register_reading_callback(callback: ?SensorReadingCallback) callconv(.c) void {
    g_reading_callback = callback;
}

/// Register callback for error notifications.
export fn bebop_register_error_callback(callback: ?ErrorCallback) callconv(.c) void {
    g_error_callback = callback;
}

/// Invoke registered reading callback (called from Zig side).
export fn bebop_invoke_reading_callback(reading: ?*const VSensorReading) callconv(.c) void {
    if (g_reading_callback) |cb| {
        if (reading) |r| {
            cb(r);
        }
    }
}

/// Invoke registered error callback (called from Zig side).
export fn bebop_invoke_error_callback(code: i32, message: ?[*:0]const u8) callconv(.c) void {
    if (g_error_callback) |cb| {
        const msg = message orelse "unknown error";
        cb(code, msg);
    }
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

test "version check" {
    const ver = bebop_version();
    try std.testing.expectEqual(@as(u32, 0x010000), ver); // 1.0.0
}

test "context lifecycle" {
    const ctx = bebop_ctx_new();
    try std.testing.expect(ctx != null);

    bebop_ctx_reset(ctx);
    bebop_ctx_free(ctx);
}

test "VBytes from slice" {
    const slice = "hello";
    const vb = VBytes.fromSlice(slice);
    try std.testing.expectEqual(@as(usize, 5), vb.len);
}

test "decode simple sensor reading" {
    const ctx = bebop_ctx_new().?;
    defer bebop_ctx_free(ctx);

    // Wire format for a simple SensorReading:
    // Field 1 (timestamp): 0x01 + u64 LE
    // Field 2 (sensorId): 0x02 + len(4) + "temp-001"
    // Field 3 (sensorType): 0x03 + u16 LE (Temperature = 1)
    // Field 4 (value): 0x04 + f64 LE (23.5)
    // Field 5 (unit): 0x05 + len(4) + "C"
    // Field 6 (location): 0x06 + len(4) + "floor-1"
    // Field 7 (metadata): 0x07 + count(4) + 0 entries
    // End: 0x00
    const wire_data = [_]u8{
        0x01, // field 1: timestamp
        0x00, 0x94, 0x35, 0x77, 0x00, 0x00, 0x00, 0x00, // timestamp = 2000000000 (LE)

        0x02, // field 2: sensorId
        0x08, 0x00, 0x00, 0x00, // length = 8
        't', 'e', 'm', 'p', '-', '0', '0', '1', // "temp-001"

        0x03, // field 3: sensorType
        0x01, 0x00, // Temperature = 1 (LE)

        0x04, // field 4: value
        0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x37, 0x40, // 23.5 as f64 LE

        0x05, // field 5: unit
        0x01, 0x00, 0x00, 0x00, // length = 1
        'C', // "C"

        0x06, // field 6: location
        0x07, 0x00, 0x00, 0x00, // length = 7
        'f', 'l', 'o', 'o', 'r', '-', '1', // "floor-1"

        0x07, // field 7: metadata
        0x00, 0x00, 0x00, 0x00, // count = 0

        0x00, // end of message
    };

    var reading = VSensorReading.empty();
    const result = bebop_decode_sensor_reading(ctx, &wire_data, wire_data.len, &reading);

    try std.testing.expectEqual(BEBOP_OK, result);
    try std.testing.expectEqual(@as(u64, 2000000000), reading.timestamp);
    try std.testing.expectEqual(SensorType.Temperature, reading.sensor_type);
    try std.testing.expectEqual(@as(f64, 23.5), reading.value);
    try std.testing.expectEqual(@as(usize, 8), reading.sensor_id.len);
    try std.testing.expectEqual(@as(usize, 1), reading.unit.len);
    try std.testing.expectEqual(@as(usize, 7), reading.location.len);
    try std.testing.expectEqual(@as(usize, 0), reading.metadata_count);
}

test "decode with metadata" {
    const ctx = bebop_ctx_new().?;
    defer bebop_ctx_free(ctx);

    // Minimal message with just metadata
    const wire_data = [_]u8{
        0x07, // field 7: metadata
        0x01, 0x00, 0x00, 0x00, // count = 1
        0x06, 0x00, 0x00, 0x00, // key length = 6
        's', 't', 'a', 't', 'u', 's', // key = "status"
        0x02, 0x00, 0x00, 0x00, // value length = 2
        'o', 'k', // value = "ok"
        0x00, // end of message
    };

    var reading = VSensorReading.empty();
    const result = bebop_decode_sensor_reading(ctx, &wire_data, wire_data.len, &reading);

    try std.testing.expectEqual(BEBOP_OK, result);
    try std.testing.expectEqual(@as(usize, 1), reading.metadata_count);
    try std.testing.expect(reading.metadata_keys != null);
    try std.testing.expect(reading.metadata_values != null);

    // Verify key/value content
    const key = reading.metadata_keys.?[0];
    const value = reading.metadata_values.?[0];
    try std.testing.expectEqual(@as(usize, 6), key.len);
    try std.testing.expectEqual(@as(usize, 2), value.len);
}

test "decode error on truncated data" {
    const ctx = bebop_ctx_new().?;
    defer bebop_ctx_free(ctx);

    // Truncated: field header says string but no string data
    const wire_data = [_]u8{
        0x02, // field 2: sensorId
        0x08, 0x00, 0x00, 0x00, // length = 8 (but no string data follows)
    };

    var reading = VSensorReading.empty();
    const result = bebop_decode_sensor_reading(ctx, &wire_data, wire_data.len, &reading);

    try std.testing.expectEqual(BEBOP_ERR_DECODE_FAILED, result);
    try std.testing.expect(reading.error_message != null);
}
