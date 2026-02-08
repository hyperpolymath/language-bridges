// SPDX-License-Identifier: AGPL-3.0-or-later
//! Zig FFI bindings for document text extraction (i18n workflows)
//! Inspired by: hyperpolymath/polyglot-i18n

const std = @import("std");

pub const Error = error{
    ParseFailed,
    UnsupportedFormat,
    AllocationFailed,
};

pub const Format = enum {
    plain_text,
    markdown,
    asciidoc,
    html,
    json,
    yaml,
};

pub const TextSegment = struct {
    text: []const u8,
    line: usize,
    column: usize,
    context: ?[]const u8,
};

/// Extract translatable text segments from a document
pub fn extract(allocator: std.mem.Allocator, content: []const u8, format: Format) Error![]TextSegment {
    _ = content;
    _ = format;
    _ = allocator;
    // TODO: Implement extraction per format
    return &[_]TextSegment{};
}

// C FFI exports
export fn polyglot_extract(content: [*:0]const u8, format: u32) ?[*]TextSegment {
    _ = content;
    _ = format;
    return null;
}
