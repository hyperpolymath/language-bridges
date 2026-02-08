// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath
//! Build system for idris2-zig-ffi
//!
//! This build.zig can be used both as a standalone library and as a
//! dependency in other Zig projects.
//!
//! ## Build Targets
//!
//! - `zig build` - Build native static library
//! - `zig build wasm` - Build WASM library for browsers
//! - `zig build wasi` - Build WASI library for runtimes
//! - `zig build test` - Run unit tests
//! - `zig build docs` - Generate documentation

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // Main library module (for Zig consumers)
    // ========================================================================
    const lib_mod = b.addModule("idris2_zig_ffi", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ========================================================================
    // Native static library (Pure Zig ABI)
    // ========================================================================
    const lib = b.addStaticLibrary(.{
        .name = "idris2_zig_ffi",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // ========================================================================
    // Shared library (for dynamic linking)
    // ========================================================================
    const shared_lib = b.addSharedLibrary(.{
        .name = "idris2_zig_ffi",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const shared_step = b.step("shared", "Build shared library (.so/.dylib/.dll)");
    shared_step.dependOn(&b.addInstallArtifact(shared_lib, .{}).step);

    // ========================================================================
    // WASM (Browser) - wasm32-freestanding
    // ========================================================================
    const wasm_browser = b.addSharedLibrary(.{
        .name = "idris2_zig_ffi",
        .root_source_file = b.path("src/root.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseSmall,
    });
    // Don't link libc for freestanding WASM
    wasm_browser.rdynamic = true;

    const wasm_browser_step = b.step("wasm", "Build WASM library for browsers");
    const wasm_browser_install = b.addInstallArtifact(wasm_browser, .{});
    wasm_browser_step.dependOn(&wasm_browser_install.step);

    // ========================================================================
    // WASI (Server-side WASM) - wasm32-wasi
    // ========================================================================
    const wasm_wasi = b.addSharedLibrary(.{
        .name = "idris2_zig_ffi",
        .root_source_file = b.path("src/root.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
        }),
        .optimize = .ReleaseSmall,
    });
    wasm_wasi.rdynamic = true;

    const wasm_wasi_step = b.step("wasi", "Build WASI library for runtimes");
    const wasm_wasi_install = b.addInstallArtifact(wasm_wasi, .{});
    wasm_wasi_step.dependOn(&wasm_wasi_install.step);

    // ========================================================================
    // All WASM targets
    // ========================================================================
    const all_wasm_step = b.step("all-wasm", "Build all WASM targets");
    all_wasm_step.dependOn(wasm_browser_step);
    all_wasm_step.dependOn(wasm_wasi_step);

    // ========================================================================
    // Tests
    // ========================================================================
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // ========================================================================
    // Documentation
    // ========================================================================
    const docs = b.addStaticLibrary(.{
        .name = "idris2_zig_ffi",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    // Export module for use as dependency
    _ = lib_mod;
}

/// Helper function for projects depending on this library (pure Zig)
pub fn addIdris2ZigFfi(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
) void {
    // Add the FFI module
    const dep = b.dependency("idris2_zig_ffi", .{
        .target = exe.root_module.resolved_target,
        .optimize = exe.root_module.optimize,
    });

    exe.root_module.addImport("idris2_zig_ffi", dep.module("idris2_zig_ffi"));
}
