// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
//
// build.zig - Build the Bebop-V-FFI shared library
//
// Usage:
//   zig build              # Debug build
//   zig build -Drelease    # Release build
//   zig build test         # Run tests
//   zig build gen-header   # Regenerate C header from Zig definitions

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the shared library
    const lib = b.addLibrary(.{
        .name = "bebop_v_ffi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });

    // Also build static library for linking flexibility
    const static_lib = b.addLibrary(.{
        .name = "bebop_v_ffi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    // Install both artifacts
    b.installArtifact(lib);
    b.installArtifact(static_lib);

    // Install the header for consumers
    b.installFile("../../include/bebop_v_ffi.h", "include/bebop_v_ffi.h");

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // C header generator
    const gen_header = b.addExecutable(.{
        .name = "gen_header",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen_header.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run_gen_header = b.addRunArtifact(gen_header);
    run_gen_header.addArg("../../include/bebop_v_ffi.h");
    run_gen_header.setCwd(b.path("src"));

    const gen_header_step = b.step("gen-header", "Regenerate C header from Zig definitions");
    gen_header_step.dependOn(&run_gen_header.step);
}
