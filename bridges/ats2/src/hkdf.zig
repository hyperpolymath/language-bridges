// SPDX-License-Identifier: PMLP-1.0-or-later
// Zig FFI bridge to ATS2 HKDF implementation

const std = @import("std");

// ATS2 exports
extern fn hkdf_derive(
    password: [*]const u8,
    password_length: usize,
    salt: [*]const u8,
    salt_length: usize,
    output_key: [*]u8,
) void;

extern fn register_callback(callback: *const fn ([*]const u8, usize) callconv(.C) void) void;

/// Derive key using HKDF via ATS2
pub fn deriveKey(password: []const u8, salt: []const u8) ![64]u8 {
    var key: [64]u8 = undefined;
    hkdf_derive(password.ptr, password.len, salt.ptr, salt.len, &key);
    return key;
}

/// Callback handler for ATS2 → Zig communication
export fn zig_callback(data: [*]const u8, length: usize) callconv(.C) void {
    _ = data;
    _ = length;
    // Handle callback from ATS2
}

/// Initialize FFI bridge
pub fn init() void {
    register_callback(@ptrCast(&zig_callback));
}

test "hkdf derivation" {
    const password = "test-password";
    const salt = "test-salt";
    const key = try deriveKey(password, salt);
    try std.testing.expect(key.len == 64);
}
