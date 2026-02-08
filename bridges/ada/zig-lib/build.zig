// SPDX-License-Identifier: AGPL-3.0-or-later
// Ada-Zig-FFI Build Configuration

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the shared library for FFI
    const lib = b.addSharedLibrary(.{
        .name = "zigffi",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Also build a static library for static linking
    const static_lib = b.addStaticLibrary(.{
        .name = "zigffi",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install artifacts
    b.installArtifact(lib);
    b.installArtifact(static_lib);

    // Run tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
