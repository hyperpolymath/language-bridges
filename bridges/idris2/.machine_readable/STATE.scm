; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2025 Hyperpolymath
;; STATE.scm - idris2-zig-ffi project state
;; Machine-readable project status for AI assistants and tooling

(define state
  `((metadata
     (version . "0.2.1")
     (schema-version . "1.0")
     (created . "2025-01-12")
     (updated . "2025-01-12")
     (project . "idris2-zig-ffi")
     (repo . "github.com/hyperpolymath/idris2-zig-ffi"))

    (project-context
     (name . "idris2-zig-ffi")
     (tagline . "Pure Zig FFI bridge for Idris 2 - no C required")
     (tech-stack . (zig idris2 pure-zig-abi ffi wasm wasi)))

    (current-position
     (phase . "pure-zig-complete")
     (overall-completion . 80)
     (components
      ((core-bridge (status . complete) (completion . 100))
       (memory-management (status . complete) (completion . 100))
       (type-conversions (status . complete) (completion . 100))
       (idris-rts-integration (status . complete) (completion . 90))
       (error-handling (status . complete) (completion . 100))
       (build-system (status . complete) (completion . 100))
       (native-abi (status . complete) (completion . 100))
       (wasm-abi (status . complete) (completion . 100))
       (wasi-abi (status . complete) (completion . 100))
       (bidirectional-callbacks (status . complete) (completion . 100))
       (documentation (status . pending) (completion . 30))
       (examples (status . pending) (completion . 0))
       (tests (status . pending) (completion . 20))))
     (working-features
      (type-marshalling . "Zig ↔ Idris type conversions")
      (memory-bridge . "Safe allocation with cleanup")
      (error-handling . "Result types for Either handling")
      (native-abi . "Pure Zig ABI with versioning - no C required")
      (wasm-abi . "Browser WASM with JS interop")
      (wasi-abi . "WASI runtime with file/env/random/clock")
      (bidirectional-callbacks . "Zig ↔ Idris callback registry for cross-language calls")))

    (route-to-mvp
     ((milestone . "v0.1.0 - Core Bridge")
      (status . complete)
      (items
       ((item . "Memory management") (done . #t))
       ((item . "Type conversions") (done . #t))
       ((item . "Error handling") (done . #t))
       ((item . "Build system") (done . #t))
       ((item . "Basic tests") (done . #f))
       ((item . "Example project") (done . #f))))

     ((milestone . "v0.2.0 - All ABIs Complete")
      (status . complete)
      (items
       ((item . "Native Zig ABI layer") (done . #t))
       ((item . "WASM browser ABI") (done . #t))
       ((item . "WASI runtime ABI") (done . #t))
       ((item . "Build targets for all ABIs") (done . #t))
       ((item . "JavaScript interop stubs") (done . #t))
       ((item . "ABI versioning") (done . #t))))

     ((milestone . "v0.2.1 - Pure Zig Conversion")
      (status . complete)
      (items
       ((item . "Remove C header (idris2_zig.h)") (done . #t))
       ((item . "Rename c.zig to native.zig") (done . #t))
       ((item . "Remove linkLibC from build") (done . #t))
       ((item . "Add bidirectional callback system") (done . #t))
       ((item . "Fix IdrisValue circular dependency") (done . #t))
       ((item . "Update root.zig with Zig exports") (done . #t))))

     ((milestone . "v0.3.0 - Production Ready")
      (status . pending)
      (items
       ((item . "GC integration") (done . #f))
       ((item . "Performance benchmarks") (done . #f))
       ((item . "Comprehensive tests") (done . #f))
       ((item . "API documentation") (done . #f))
       ((item . "Real-world example with proven") (done . #f)))))

    (blockers-and-issues
     (critical . ())
     (high
      ((issue . "Need real Idris 2 project to test against")
       (impact . "Cannot verify integration works")
       (resolution . "Use proven as test case")))
     (medium . ())
     (low . ()))

    (critical-next-actions
     (immediate
      ((action . "Test with real Idris 2 output") (priority . 1))
      ((action . "Wire proven to use idris2-zig-ffi") (priority . 2)))
     (this-week
      ((action . "Write integration tests") (priority . 3))
      ((action . "Create example project") (priority . 4)))
     (this-month
      ((action . "GC integration") (priority . 5))
      ((action . "Performance benchmarks") (priority . 6))))

    (session-history
     ((date . "2025-01-12")
      (session . "initial-creation")
      (accomplishments
       ("Created GitHub repository"
        "Implemented core Zig bridge (root.zig)"
        "Implemented memory management (memory.zig)"
        "Implemented type conversions (types.zig)"
        "Implemented Idris RTS integration (idris_rts.zig)"
        "Implemented error handling (errors.zig)"
        "Created build system (build.zig, build.zig.zon)"
        "Created documentation (README.adoc)")))
     ((date . "2025-01-12")
      (session . "abi-completion")
      (accomplishments
       ("Fixed SPDX identifiers to PMPL-1.0"
        "Added LICENSES/PMPL-1.0.txt for REUSE compliance"
        "Implemented initial ABI layer (src/abi/c.zig) with stable types"
        "Implemented WASM browser ABI (src/abi/wasm.zig) with JS interop"
        "Implemented WASI runtime ABI (src/abi/wasi.zig) with file/env/random/clock"
        "Updated build.zig with wasm, wasi, shared targets"
        "Added ABI versioning and compatibility checking"
        "Created CString, CResult, COption, CArray extern types"
        "Created callback registry for async WASM operations")))
     ((date . "2025-01-12")
      (session . "pure-zig-conversion")
      (accomplishments
       ("Deleted C header file (include/idris2_zig.h)"
        "Renamed src/abi/c.zig to src/abi/native.zig"
        "Removed linkLibC and C header installation from build.zig"
        "Added bidirectional callback system (Zig ↔ Idris)"
        "Added callback registry with register/unregister/lookup/invoke"
        "Added Zig exports: idris2_zig_init, idris2_zig_deinit, idris2_zig_abi_version"
        "Added idris2_zig_invoke_callback for Idris → Zig calls"
        "Fixed IdrisValue circular dependency using pointers"
        "Changed IdrisMaybeValue and IdrisEitherValue to use ?*anyopaque"
        "Updated helper function addIdris2ZigFfi for pure Zig consumption"
        "Project is now pure Zig with no C/C++ code or headers")))))))
