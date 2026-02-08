; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2025 Hyperpolymath
;; META.scm - idris2-zig-ffi meta-level information
;; Architecture decisions, design rationale, development practices

(define meta
  `((metadata
     (version . "1.0")
     (schema-version . "1.0")
     (media-type . "application/meta+scheme"))

    (architecture-decisions
     ((adr-001
       (title . "Use Zig as FFI bridge language")
       (status . accepted)
       (date . "2025-01-12")
       (context
        "Need a language that can wrap Idris 2 RefC output and provide
         stable C ABI. Options: C, C++, Rust, Zig.")
       (decision
        "Use Zig because it:
         - Has first-class C interop (can import C headers directly)
         - Provides cross-compilation to any target from any host
         - Has no hidden memory allocations or control flow
         - Compiles to actual C ABI (not just compatible)
         - Supports WASM natively
         - Has excellent compile-time features for type marshalling")
       (consequences
        "- Must learn Zig if unfamiliar
         - Zig is pre-1.0 (but ABI-stable for our use case)
         - Excellent cross-platform support
         - WASM support without extra tooling"))

      (adr-002
       (title . "Stable ABI versioning")
       (status . accepted)
       (date . "2025-01-12")
       (context
        "Consumers need to know if they're compatible with a version of
         the FFI bridge. Breaking changes must be detectable.")
       (decision
        "Use explicit ABI version number (uint32) exposed via C function.
         Major version indicates breaking changes. Applications should
         check ABI_VERSION at runtime before calling any functions.")
       (consequences
        "- Must maintain ABI version discipline
         - Breaking changes require version bump
         - Old applications fail gracefully with version mismatch"))

      (adr-003
       (title . "Memory ownership model")
       (status . accepted)
       (date . "2025-01-12")
       (context
        "Memory allocated by Idris, Zig, and consumer languages must be
         managed correctly to prevent leaks and use-after-free.")
       (decision
        "Follow 'allocator frees' principle:
         - Memory allocated by idris2_zig_alloc must be freed by idris2_zig_free
         - Idris strings returned to C must be freed by idris2_zig_string_free
         - Document ownership in function signatures")
       (consequences
        "- Clear ownership semantics
         - Some wrapper overhead for string conversion
         - Safe by default"))))

    (development-practices
     (code-style
      (language . "zig")
      (formatter . "zig fmt")
      (max-line-length . 100))

     (testing
      (framework . "zig-test")
      (coverage-target . 80)
      (integration-tests . "test with proven"))

     (versioning
      (scheme . "semver")
      (abi-version . "separate-from-semver"))

     (documentation
      (format . "asciidoc")
      (api-docs . "zig-autodoc")))

    (design-rationale
     (why-not-rust
      "Rust's C FFI is good but adds complexity with its ownership model.
       Zig's simpler model is better suited for a thin FFI layer.")

     (why-not-plain-c
      "Plain C lacks the compile-time features needed for type-safe
       marshalling. Would require code generation or macros.")

     (why-stable-abi
      "Consumers shouldn't need to recompile when updating the bridge.
       ABI stability enables independent version updates."))))
