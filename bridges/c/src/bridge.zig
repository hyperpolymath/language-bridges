// SPDX-License-Identifier: PMLP-1.0-or-later
const std = @import("std");
const c = @cImport({ @cInclude("hkdf.h"); });

pub fn callC(password: []const u8, salt: []const u8) ![64]u8 {
    var key: [64]u8 = undefined;
    c.hkdf_derive(password.ptr, password.len, salt.ptr, salt.len, &key);
    return key;
}

export fn zig_handler(data: [*]const u8, len: usize) callconv(.C) void {
    _ = data; _ = len;
}
