// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
//
// gen_header.zig - Auto-generate C header from Zig type definitions
//
// Usage: zig build gen-header
// Output: include/bebop_v_ffi.h
//
// This file generates the C header from the canonical Zig definitions in bridge.zig.
// The ABI version and error codes are defined here and MUST match bridge.zig.
//
// NOTE: When updating bridge.zig, update the constants here too, then regenerate.

const std = @import("std");

// ABI Version - MUST match bridge.zig
const ABI_VERSION_MAJOR: u32 = 1;
const ABI_VERSION_MINOR: u32 = 0;
const ABI_VERSION_PATCH: u32 = 0;

// Error codes - MUST match bridge.zig
const BEBOP_OK: i32 = 0;
const BEBOP_ERR_NULL_CTX: i32 = -1;
const BEBOP_ERR_NULL_DATA: i32 = -2;
const BEBOP_ERR_INVALID_LENGTH: i32 = -3;
const BEBOP_ERR_DECODE_FAILED: i32 = -4;
const BEBOP_ERR_ENCODE_FAILED: i32 = -5;
const BEBOP_ERR_BUFFER_TOO_SMALL: i32 = -6;
const BEBOP_ERR_NOT_IMPLEMENTED: i32 = -99;

// Sensor types - MUST match bridge.zig
const SENSOR_TYPE_TEMPERATURE: u16 = 1;
const SENSOR_TYPE_HUMIDITY: u16 = 2;
const SENSOR_TYPE_PRESSURE: u16 = 3;
const SENSOR_TYPE_VIBRATION: u16 = 4;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const output_path = if (args.len > 1) args[1] else "include/bebop_v_ffi.h";

    const header = generateHeader();

    // Use std.posix for Zig 0.16.0-dev
    const file = std.fs.createFileAbsolute(output_path, .{}) catch |err| {
        // Try relative path
        const cwd = std.fs.cwd();
        const f = try cwd.createFile(output_path, .{});
        try f.writeAll(header);
        f.close();

        const stdout = std.io.getStdOut().writer();
        try stdout.print("Generated C header: {s}\n", .{output_path});
        return;
    };
    defer file.close();

    try file.writeAll(header);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Generated C header: {s}\n", .{output_path});
}

fn generateHeader() []const u8 {
    return std.fmt.comptimePrint(
        \\// SPDX-License-Identifier: AGPL-3.0-or-later
        \\// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
        \\//
        \\// bebop_v_ffi.h - C header for interoperability with C/C++ consumers
        \\//
        \\// ┌──────────────────────────────────────────────────────────────────────────┐
        \\// │ AUTO-GENERATED FILE - DO NOT EDIT MANUALLY                              │
        \\// │                                                                          │
        \\// │ Source: implementations/zig/src/bridge.zig                               │
        \\// │ Generator: implementations/zig/src/gen_header.zig                        │
        \\// │ Regenerate: zig build gen-header                                         │
        \\// └──────────────────────────────────────────────────────────────────────────┘
        \\//
        \\// The canonical ABI definition is in implementations/zig/src/bridge.zig.
        \\// This header is auto-generated from those Zig type definitions.
        \\//
        \\// For Zig consumers: Use implementations/zig/src/bridge.zig directly.
        \\// For V consumers: Use the V bindings in v/ directory.
        \\// For other languages: Link against the compiled library and use this header.
        \\//
        \\// ABI STABILITY GUARANTEE:
        \\// - Version 1.x.x: Backwards compatible (no breaking changes)
        \\// - Structs: Fields may be added at end only, never removed/reordered
        \\// - Functions: New functions may be added, existing signatures frozen
        \\// - Error codes: New codes may be added, existing values frozen
        \\
        \\#ifndef BEBOP_V_FFI_H
        \\#define BEBOP_V_FFI_H
        \\
        \\#include <stddef.h>
        \\#include <stdint.h>
        \\
        \\// ============================================================================
        \\// ABI Version
        \\// ============================================================================
        \\
        \\#define BEBOP_V_FFI_VERSION_MAJOR {d}
        \\#define BEBOP_V_FFI_VERSION_MINOR {d}
        \\#define BEBOP_V_FFI_VERSION_PATCH {d}
        \\#define BEBOP_V_FFI_VERSION_STRING "{d}.{d}.{d}"
        \\
        \\// Combine version for runtime checks: (major << 16) | (minor << 8) | patch
        \\#define BEBOP_V_FFI_VERSION \
        \\    ((BEBOP_V_FFI_VERSION_MAJOR << 16) | \
        \\     (BEBOP_V_FFI_VERSION_MINOR << 8) | \
        \\     BEBOP_V_FFI_VERSION_PATCH)
        \\
        \\#ifdef __cplusplus
        \\extern "C" {{
        \\#endif
        \\
        \\// ============================================================================
        \\// Error Codes
        \\// ============================================================================
        \\
        \\#define BEBOP_OK                    {d}
        \\#define BEBOP_ERR_NULL_CTX         {d}
        \\#define BEBOP_ERR_NULL_DATA        {d}
        \\#define BEBOP_ERR_INVALID_LENGTH   {d}
        \\#define BEBOP_ERR_DECODE_FAILED    {d}
        \\#define BEBOP_ERR_ENCODE_FAILED    {d}
        \\#define BEBOP_ERR_BUFFER_TOO_SMALL {d}
        \\#define BEBOP_ERR_NOT_IMPLEMENTED  {d}
        \\
        \\// ============================================================================
        \\// Sensor Types (matches sensors.bop)
        \\// ============================================================================
        \\
        \\#define SENSOR_TYPE_TEMPERATURE  {d}
        \\#define SENSOR_TYPE_HUMIDITY     {d}
        \\#define SENSOR_TYPE_PRESSURE     {d}
        \\#define SENSOR_TYPE_VIBRATION    {d}
        \\
        \\// ============================================================================
        \\// Types
        \\// ============================================================================
        \\
        \\// Opaque context for allocations and state.
        \\// Prefer one context per connection/thread for thread-safety.
        \\typedef struct BebopCtx BebopCtx;
        \\
        \\// Byte slice passed across FFI. Data is NOT NUL-terminated.
        \\// Layout matches Zig's extern struct VBytes.
        \\typedef struct VBytes {{
        \\    const uint8_t* ptr;  // Pointer to byte data (may be NULL if len == 0)
        \\    size_t len;          // Length in bytes
        \\}} VBytes;
        \\
        \\// Flat, FFI-friendly representation of SensorReading (schema-defined).
        \\// Layout matches Zig's extern struct VSensorReading.
        \\typedef struct VSensorReading {{
        \\    uint64_t timestamp;           // Unix timestamp in milliseconds
        \\    VBytes sensor_id;             // Unique sensor identifier
        \\    uint16_t sensor_type;         // One of SENSOR_TYPE_* values
        \\    double value;                 // Measured value
        \\    VBytes unit;                  // Unit of measurement (e.g., "C", "Pa")
        \\    VBytes location;              // Physical location
        \\
        \\    size_t metadata_count;        // Number of metadata key-value pairs
        \\    VBytes* metadata_keys;        // Array of keys (length = metadata_count)
        \\    VBytes* metadata_values;      // Array of values (length = metadata_count)
        \\
        \\    int32_t error_code;           // 0 = success, negative = error
        \\    const char* error_message;    // NUL-terminated; owned by context
        \\}} VSensorReading;
        \\
        \\// ============================================================================
        \\// Callback Types (for bidirectional FFI)
        \\// ============================================================================
        \\
        \\// Callback invoked when a sensor reading is received.
        \\// The reading pointer is only valid during the callback.
        \\typedef void (*bebop_reading_callback_t)(const VSensorReading* reading);
        \\
        \\// Callback invoked on errors.
        \\// code: One of BEBOP_ERR_* values
        \\// message: NUL-terminated error description
        \\typedef void (*bebop_error_callback_t)(int32_t code, const char* message);
        \\
        \\// ============================================================================
        \\// Functions
        \\// ============================================================================
        \\
        \\// --- Version ---
        \\
        \\// Returns ABI version for runtime compatibility checks.
        \\// Compare with BEBOP_V_FFI_VERSION to detect mismatches.
        \\uint32_t bebop_version(void);
        \\
        \\// --- Context Lifecycle ---
        \\
        \\// Create a new context. Returns NULL on allocation failure.
        \\// The context manages memory for decoded structures.
        \\BebopCtx* bebop_ctx_new(void);
        \\
        \\// Free a context and all its allocations.
        \\// Safe to call with NULL.
        \\void bebop_ctx_free(BebopCtx* ctx);
        \\
        \\// Reset context arena for reuse (high-throughput pattern).
        \\// Invalidates all previously decoded data.
        \\void bebop_ctx_reset(BebopCtx* ctx);
        \\
        \\// --- Decode/Encode ---
        \\
        \\// Decode a SensorReading from Bebop wire format.
        \\// Returns BEBOP_OK on success, negative error code on failure.
        \\// On failure, out->error_code and out->error_message are set.
        \\int32_t bebop_decode_sensor_reading(
        \\    BebopCtx* ctx,
        \\    const uint8_t* data,
        \\    size_t len,
        \\    VSensorReading* out
        \\);
        \\
        \\// Frees any per-reading allocations (if needed).
        \\// Safe to call multiple times. With arena allocation, this is a no-op.
        \\void bebop_free_sensor_reading(BebopCtx* ctx, VSensorReading* reading);
        \\
        \\// Encode a batch of readings into out_buf.
        \\// Returns bytes written, or 0 on failure.
        \\size_t bebop_encode_batch_readings(
        \\    BebopCtx* ctx,
        \\    const VSensorReading* readings,
        \\    size_t count,
        \\    uint8_t* out_buf,
        \\    size_t out_len
        \\);
        \\
        \\// --- Callbacks (Bidirectional FFI) ---
        \\
        \\// Register callback for receiving sensor readings.
        \\// Pass NULL to unregister.
        \\void bebop_register_reading_callback(bebop_reading_callback_t callback);
        \\
        \\// Register callback for error notifications.
        \\// Pass NULL to unregister.
        \\void bebop_register_error_callback(bebop_error_callback_t callback);
        \\
        \\// Invoke registered reading callback (called from Zig side).
        \\// This is how the Zig implementation notifies C consumers.
        \\void bebop_invoke_reading_callback(const VSensorReading* reading);
        \\
        \\// Invoke registered error callback (called from Zig side).
        \\void bebop_invoke_error_callback(int32_t code, const char* message);
        \\
        \\#ifdef __cplusplus
        \\}}
        \\#endif
        \\
        \\#endif // BEBOP_V_FFI_H
        \\
    , .{
        // ABI Version
        ABI_VERSION_MAJOR,
        ABI_VERSION_MINOR,
        ABI_VERSION_PATCH,
        ABI_VERSION_MAJOR,
        ABI_VERSION_MINOR,
        ABI_VERSION_PATCH,
        // Error codes
        BEBOP_OK,
        BEBOP_ERR_NULL_CTX,
        BEBOP_ERR_NULL_DATA,
        BEBOP_ERR_INVALID_LENGTH,
        BEBOP_ERR_DECODE_FAILED,
        BEBOP_ERR_ENCODE_FAILED,
        BEBOP_ERR_BUFFER_TOO_SMALL,
        BEBOP_ERR_NOT_IMPLEMENTED,
        // Sensor types
        SENSOR_TYPE_TEMPERATURE,
        SENSOR_TYPE_HUMIDITY,
        SENSOR_TYPE_PRESSURE,
        SENSOR_TYPE_VIBRATION,
    });
}

// Verify header generation at comptime
comptime {
    _ = generateHeader();
}
