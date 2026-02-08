// SPDX-License-Identifier: AGPL-3.0-or-later
//! Swift-Zig FFI - Build Configuration
//!
//! Usage:
//!   zig build                    # Build for host
//!   zig build -Dtarget=aarch64-macos  # macOS ARM64
//!   zig build -Dtarget=aarch64-ios    # iOS ARM64
//!   zig build -Dtarget=x86_64-ios-simulator  # iOS Simulator
//!   zig build test               # Run tests
//!   zig build gen-header         # Generate Swift bridging header

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build shared library
    const lib = b.addLibrary(.{
        .name = "swift_zig_ffi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });

    // Build static library (preferred for iOS)
    const static_lib = b.addLibrary(.{
        .name = "swift_zig_ffi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    b.installArtifact(lib);
    b.installArtifact(static_lib);

    // Install header
    b.installFile("include/SwiftZigFFI.h", "include/SwiftZigFFI.h");

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Header generator
    const gen_header = b.addExecutable(.{
        .name = "gen_header",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen_header.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run_gen_header = b.addRunArtifact(gen_header);
    run_gen_header.addArg("include/SwiftZigFFI.h");

    const gen_header_step = b.step("gen-header", "Generate Swift bridging header");
    gen_header_step.dependOn(&run_gen_header.step);
}
