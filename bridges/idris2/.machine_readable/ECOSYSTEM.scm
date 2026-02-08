; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2025 Hyperpolymath
;; ECOSYSTEM.scm - idris2-zig-ffi ecosystem relationships
;; How this project relates to and integrates with other projects

(ecosystem
 (version . "1.0")
 (name . "idris2-zig-ffi")
 (type . "ffi-bridge")
 (purpose . "Enable any Idris 2 project to expose a stable C ABI through Zig")

 (position-in-ecosystem
  (role . "infrastructure")
  (layer . "ffi-layer")
  (consumers . ("proven" "idris2-projects" "polyglot-applications"))
  (description
   "This is foundational infrastructure that enables the entire ecosystem
    of verified Idris 2 libraries to be used from any language that can
    call C functions. Without this bridge, Idris 2 code remains isolated."))

 (related-projects
  ((name . "proven")
   (relationship . downstream-consumer)
   (repo . "github.com/hyperpolymath/proven")
   (description . "Verified safe operations library - primary consumer")
   (integration-status . planned))

  ((name . "Idris 2")
   (relationship . upstream-dependency)
   (repo . "github.com/idris-lang/Idris2")
   (description . "The Idris 2 compiler and RefC backend")
   (integration-status . active))

  ((name . "Zig")
   (relationship . build-dependency)
   (repo . "github.com/ziglang/zig")
   (description . "Build system and cross-platform compilation")
   (integration-status . active))

  ((name . "HACL*")
   (relationship . inspiration)
   (repo . "github.com/hacl-star/hacl-star")
   (description . "Verified crypto library with similar FFI approach")
   (integration-status . reference)))

 (what-this-is
  ("Generic FFI bridge for ANY Idris 2 project"
   "Stable C ABI that won't change between versions"
   "Type-safe marshalling between Zig and Idris types"
   "Cross-platform build system (Linux, macOS, Windows, WASM)"
   "Memory management that integrates with Idris GC"))

 (what-this-is-not
  ("Not a specific library implementation"
   "Not tied to any particular Idris 2 project"
   "Not a replacement for Idris 2's native backends"
   "Not a general-purpose Zig library")))
