// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
//
// bebop_v_ffi.h - C header for interoperability with C/C++ consumers
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ AUTO-GENERATED FILE - DO NOT EDIT MANUALLY                              │
// │                                                                          │
// │ Source: implementations/zig/src/bridge.zig                               │
// │ Generator: implementations/zig/src/gen_header.zig                        │
// │ Regenerate: zig build gen-header                                         │
// └──────────────────────────────────────────────────────────────────────────┘
//
// The canonical ABI definition is in implementations/zig/src/bridge.zig.
// This header is auto-generated from those Zig type definitions.
//
// For Zig consumers: Use implementations/zig/src/bridge.zig directly.
// For V consumers: Use the V bindings in v/ directory.
// For other languages: Link against the compiled library and use this header.
//
// ABI STABILITY GUARANTEE:
// - Version 1.x.x: Backwards compatible (no breaking changes)
// - Structs: Fields may be added at end only, never removed/reordered
// - Functions: New functions may be added, existing signatures frozen
// - Error codes: New codes may be added, existing values frozen

#ifndef BEBOP_V_FFI_H
#define BEBOP_V_FFI_H

#include <stddef.h>
#include <stdint.h>

// ============================================================================
// ABI Version
// ============================================================================

#define BEBOP_V_FFI_VERSION_MAJOR 1
#define BEBOP_V_FFI_VERSION_MINOR 0
#define BEBOP_V_FFI_VERSION_PATCH 0
#define BEBOP_V_FFI_VERSION_STRING "1.0.0"

// Combine version for runtime checks: (major << 16) | (minor << 8) | patch
#define BEBOP_V_FFI_VERSION \
    ((BEBOP_V_FFI_VERSION_MAJOR << 16) | \
     (BEBOP_V_FFI_VERSION_MINOR << 8) | \
     BEBOP_V_FFI_VERSION_PATCH)

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Error Codes
// ============================================================================

#define BEBOP_OK                    0
#define BEBOP_ERR_NULL_CTX         -1
#define BEBOP_ERR_NULL_DATA        -2
#define BEBOP_ERR_INVALID_LENGTH   -3
#define BEBOP_ERR_DECODE_FAILED    -4
#define BEBOP_ERR_ENCODE_FAILED    -5
#define BEBOP_ERR_BUFFER_TOO_SMALL -6
#define BEBOP_ERR_NOT_IMPLEMENTED  -99

// ============================================================================
// Sensor Types (matches sensors.bop)
// ============================================================================

#define SENSOR_TYPE_TEMPERATURE  1
#define SENSOR_TYPE_HUMIDITY     2
#define SENSOR_TYPE_PRESSURE     3
#define SENSOR_TYPE_VIBRATION    4

// ============================================================================
// Types
// ============================================================================

// Opaque context for allocations and state.
// Prefer one context per connection/thread for thread-safety.
typedef struct BebopCtx BebopCtx;

// Byte slice passed across FFI. Data is NOT NUL-terminated.
// Layout matches Zig's extern struct VBytes.
typedef struct VBytes {
    const uint8_t* ptr;  // Pointer to byte data (may be NULL if len == 0)
    size_t len;          // Length in bytes
} VBytes;

// Flat, FFI-friendly representation of SensorReading (schema-defined).
// Layout matches Zig's extern struct VSensorReading.
typedef struct VSensorReading {
    uint64_t timestamp;           // Unix timestamp in milliseconds
    VBytes sensor_id;             // Unique sensor identifier
    uint16_t sensor_type;         // One of SENSOR_TYPE_* values
    double value;                 // Measured value
    VBytes unit;                  // Unit of measurement (e.g., "C", "Pa")
    VBytes location;              // Physical location

    size_t metadata_count;        // Number of metadata key-value pairs
    VBytes* metadata_keys;        // Array of keys (length = metadata_count)
    VBytes* metadata_values;      // Array of values (length = metadata_count)

    int32_t error_code;           // 0 = success, negative = error
    const char* error_message;    // NUL-terminated; owned by context
} VSensorReading;

// ============================================================================
// Callback Types (for bidirectional FFI)
// ============================================================================

// Callback invoked when a sensor reading is received.
// The reading pointer is only valid during the callback.
typedef void (*bebop_reading_callback_t)(const VSensorReading* reading);

// Callback invoked on errors.
// code: One of BEBOP_ERR_* values
// message: NUL-terminated error description
typedef void (*bebop_error_callback_t)(int32_t code, const char* message);

// ============================================================================
// Functions
// ============================================================================

// --- Version ---

// Returns ABI version for runtime compatibility checks.
// Compare with BEBOP_V_FFI_VERSION to detect mismatches.
uint32_t bebop_version(void);

// --- Context Lifecycle ---

// Create a new context. Returns NULL on allocation failure.
// The context manages memory for decoded structures.
BebopCtx* bebop_ctx_new(void);

// Free a context and all its allocations.
// Safe to call with NULL.
void bebop_ctx_free(BebopCtx* ctx);

// Reset context arena for reuse (high-throughput pattern).
// Invalidates all previously decoded data.
void bebop_ctx_reset(BebopCtx* ctx);

// --- Decode/Encode ---

// Decode a SensorReading from Bebop wire format.
// Returns BEBOP_OK on success, negative error code on failure.
// On failure, out->error_code and out->error_message are set.
int32_t bebop_decode_sensor_reading(
    BebopCtx* ctx,
    const uint8_t* data,
    size_t len,
    VSensorReading* out
);

// Frees any per-reading allocations (if needed).
// Safe to call multiple times. With arena allocation, this is a no-op.
void bebop_free_sensor_reading(BebopCtx* ctx, VSensorReading* reading);

// Encode a batch of readings into out_buf.
// Returns bytes written, or 0 on failure.
size_t bebop_encode_batch_readings(
    BebopCtx* ctx,
    const VSensorReading* readings,
    size_t count,
    uint8_t* out_buf,
    size_t out_len
);

// --- Callbacks (Bidirectional FFI) ---

// Register callback for receiving sensor readings.
// Pass NULL to unregister.
void bebop_register_reading_callback(bebop_reading_callback_t callback);

// Register callback for error notifications.
// Pass NULL to unregister.
void bebop_register_error_callback(bebop_error_callback_t callback);

// Invoke registered reading callback (called from Zig side).
// This is how the Zig implementation notifies C consumers.
void bebop_invoke_reading_callback(const VSensorReading* reading);

// Invoke registered error callback (called from Zig side).
void bebop_invoke_error_callback(int32_t code, const char* message);

#ifdef __cplusplus
}
#endif

#endif // BEBOP_V_FFI_H
