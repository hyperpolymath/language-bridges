// SPDX-License-Identifier: AGPL-3.0-or-later
//! Swift-Zig FFI - C Header Generator
//!
//! Generates the Swift bridging header from Zig definitions.
//! Run: zig build gen-header
//! Output: include/SwiftZigFFI.h

const std = @import("std");

// ABI Version - MUST match lib.zig
const ABI_VERSION_MAJOR: u32 = 1;
const ABI_VERSION_MINOR: u32 = 0;
const ABI_VERSION_PATCH: u32 = 0;

// Error codes - MUST match lib.zig
const SZF_OK: i32 = 0;
const SZF_ERR_NULL_PTR: i32 = -1;
const SZF_ERR_INVALID_UTF8: i32 = -2;
const SZF_ERR_ALLOC_FAILED: i32 = -3;
const SZF_ERR_INVALID_LENGTH: i32 = -4;
const SZF_ERR_NOT_FOUND: i32 = -5;
const SZF_ERR_ALREADY_EXISTS: i32 = -6;
const SZF_ERR_CALLBACK_FAILED: i32 = -7;
const SZF_ERR_NOT_IMPLEMENTED: i32 = -99;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const output_path = if (args.len > 1) args[1] else "include/SwiftZigFFI.h";

    const header = generateHeader();

    const cwd = std.fs.cwd();
    const file = try cwd.createFile(output_path, .{});
    defer file.close();

    try file.writeAll(header);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Generated Swift bridging header: {s}\n", .{output_path});
}

fn generateHeader() []const u8 {
    return std.fmt.comptimePrint(
        \\// SPDX-License-Identifier: AGPL-3.0-or-later
        \\//
        \\// SwiftZigFFI.h - Swift Bridging Header for Zig Library
        \\//
        \\// ┌──────────────────────────────────────────────────────────────────────────┐
        \\// │ AUTO-GENERATED FILE - DO NOT EDIT MANUALLY                              │
        \\// │                                                                          │
        \\// │ Source: src/lib.zig                                                      │
        \\// │ Generator: src/gen_header.zig                                            │
        \\// │ Regenerate: zig build gen-header                                         │
        \\// └──────────────────────────────────────────────────────────────────────────┘
        \\//
        \\// Usage in Swift:
        \\//   1. Add this header as your bridging header
        \\//   2. Link against libswift_zig_ffi.a (static) or .dylib (dynamic)
        \\//   3. Call szf_* functions directly from Swift
        \\
        \\#ifndef SWIFT_ZIG_FFI_H
        \\#define SWIFT_ZIG_FFI_H
        \\
        \\#include <stddef.h>
        \\#include <stdint.h>
        \\#include <stdbool.h>
        \\
        \\// ============================================================================
        \\// ABI Version
        \\// ============================================================================
        \\
        \\#define SZF_VERSION_MAJOR {d}
        \\#define SZF_VERSION_MINOR {d}
        \\#define SZF_VERSION_PATCH {d}
        \\#define SZF_VERSION_STRING "{d}.{d}.{d}"
        \\
        \\#define SZF_VERSION \
        \\    ((SZF_VERSION_MAJOR << 16) | (SZF_VERSION_MINOR << 8) | SZF_VERSION_PATCH)
        \\
        \\#ifdef __cplusplus
        \\extern "C" {{
        \\#endif
        \\
        \\// ============================================================================
        \\// Error Codes
        \\// ============================================================================
        \\
        \\#define SZF_OK                  {d}
        \\#define SZF_ERR_NULL_PTR        {d}
        \\#define SZF_ERR_INVALID_UTF8    {d}
        \\#define SZF_ERR_ALLOC_FAILED    {d}
        \\#define SZF_ERR_INVALID_LENGTH  {d}
        \\#define SZF_ERR_NOT_FOUND       {d}
        \\#define SZF_ERR_ALREADY_EXISTS  {d}
        \\#define SZF_ERR_CALLBACK_FAILED {d}
        \\#define SZF_ERR_NOT_IMPLEMENTED {d}
        \\
        \\// ============================================================================
        \\// Types
        \\// ============================================================================
        \\
        \\/// Opaque context for library state
        \\typedef struct SzfContext SzfContext;
        \\
        \\/// Byte buffer for FFI. Data is NOT NUL-terminated.
        \\typedef struct {{
        \\    const uint8_t* ptr;   ///< Pointer to data (NULL if empty)
        \\    size_t len;           ///< Length in bytes
        \\    size_t cap;           ///< Capacity (for owned buffers)
        \\    uint8_t owned;        ///< Non-zero if caller should free
        \\}} SzfBytes;
        \\
        \\/// NUL-terminated string wrapper
        \\typedef struct {{
        \\    const char* ptr;      ///< NUL-terminated string (NULL if empty)
        \\    size_t len;           ///< Length excluding NUL terminator
        \\}} SzfString;
        \\
        \\/// Result type for operations
        \\typedef struct {{
        \\    int32_t code;         ///< Error code (0 = success)
        \\    const char* message;  ///< Error message (NUL-terminated, library-owned)
        \\    SzfBytes data;        ///< Result data (if successful)
        \\}} SzfResult;
        \\
        \\// ============================================================================
        \\// Callback Types
        \\// ============================================================================
        \\
        \\/// Callback: data notification
        \\typedef void (*SzfDataCallback)(SzfBytes data, void* context);
        \\
        \\/// Callback: result notification
        \\typedef void (*SzfResultCallback)(SzfResult result, void* context);
        \\
        \\/// Callback: progress notification (return false to cancel)
        \\typedef bool (*SzfProgressCallback)(size_t current, size_t total, void* context);
        \\
        \\/// Callback: event notification (Zig → Swift)
        \\typedef void (*SzfEventCallback)(int32_t event_type, SzfBytes data, void* context);
        \\
        \\/// Callback: error notification (Zig → Swift)
        \\typedef void (*SzfErrorCallback)(int32_t code, const char* message, void* context);
        \\
        \\// ============================================================================
        \\// Context Management
        \\// ============================================================================
        \\
        \\/// Return ABI version for compatibility checks
        \\uint32_t szf_version(void);
        \\
        \\/// Create a new context. Returns NULL on failure.
        \\SzfContext* szf_context_new(void);
        \\
        \\/// Free a context and all its allocations. Safe to call with NULL.
        \\void szf_context_free(SzfContext* ctx);
        \\
        \\/// Reset context arena for reuse (invalidates previous allocations)
        \\void szf_context_reset(SzfContext* ctx);
        \\
        \\/// Get last error message from context
        \\const char* szf_context_get_error(SzfContext* ctx);
        \\
        \\// ============================================================================
        \\// String/Bytes Operations
        \\// ============================================================================
        \\
        \\/// Create string wrapper from C string
        \\SzfString szf_string_from_cstr(const char* cstr);
        \\
        \\/// Free an owned string
        \\void szf_string_free(SzfString* str);
        \\
        \\/// Free owned bytes
        \\void szf_bytes_free(SzfBytes* bytes);
        \\
        \\// ============================================================================
        \\// Callback Registration (for Zig → Swift notifications)
        \\// ============================================================================
        \\
        \\/// Register event callback. Pass NULL to unregister.
        \\void szf_register_event_callback(SzfEventCallback callback, void* context);
        \\
        \\/// Register error callback. Pass NULL to unregister.
        \\void szf_register_error_callback(SzfErrorCallback callback, void* context);
        \\
        \\// ============================================================================
        \\// Callback Invocation (Zig calls these to notify Swift)
        \\// ============================================================================
        \\
        \\/// Invoke event callback (internal use or testing)
        \\void szf_invoke_event(int32_t event_type, SzfBytes data);
        \\
        \\/// Invoke error callback (internal use or testing)
        \\void szf_invoke_error(int32_t code, const char* message);
        \\
        \\// ============================================================================
        \\// Data Processing
        \\// ============================================================================
        \\
        \\/// Process data with progress and result callbacks
        \\int32_t szf_process_data(
        \\    SzfContext* ctx,
        \\    SzfBytes input,
        \\    SzfProgressCallback progress_cb,
        \\    void* progress_ctx,
        \\    SzfResultCallback result_cb,
        \\    void* result_ctx
        \\);
        \\
        \\/// Transform data (example: uppercase ASCII)
        \\int32_t szf_transform_data(
        \\    SzfContext* ctx,
        \\    SzfBytes input,
        \\    SzfBytes* out
        \\);
        \\
        \\// ============================================================================
        \\// Swift Helpers (inline)
        \\// ============================================================================
        \\
        \\/// Create SzfBytes from raw pointer and length
        \\static inline SzfBytes szf_bytes_from_raw(const uint8_t* ptr, size_t len) {{
        \\    SzfBytes b = {{ ptr, len, 0, 0 }};
        \\    return b;
        \\}}
        \\
        \\/// Create empty SzfBytes
        \\static inline SzfBytes szf_bytes_empty(void) {{
        \\    SzfBytes b = {{ NULL, 0, 0, 0 }};
        \\    return b;
        \\}}
        \\
        \\/// Check if result is success
        \\static inline bool szf_result_is_ok(SzfResult r) {{
        \\    return r.code == SZF_OK;
        \\}}
        \\
        \\#ifdef __cplusplus
        \\}}
        \\#endif
        \\
        \\#endif // SWIFT_ZIG_FFI_H
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
        SZF_OK,
        SZF_ERR_NULL_PTR,
        SZF_ERR_INVALID_UTF8,
        SZF_ERR_ALLOC_FAILED,
        SZF_ERR_INVALID_LENGTH,
        SZF_ERR_NOT_FOUND,
        SZF_ERR_ALREADY_EXISTS,
        SZF_ERR_CALLBACK_FAILED,
        SZF_ERR_NOT_IMPLEMENTED,
    });
}

comptime {
    _ = generateHeader();
}
