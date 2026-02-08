;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Current project state

(define project-state
  '((metadata
      (version "0.1.0")
      (schema-version "2024-12-01")
      (created "2026-01-23")
      (updated "2026-01-23")
      (project "zig-ats2-ffi")
      (repo "https://github.com/hyperpolymath/zig-ats2-ffi"))

    (project-context
      (name "Zig ↔ ATS2 FFI Bridge")
      (tagline "Bidirectional FFI with zero C dependencies")
      (tech-stack "Zig 0.13, ATS2 Postiats, WASM"))

    (current-position
      (phase "initial")
      (overall-completion 20)
      (components
        ((ffi-layer (completion 30) (status "in-progress"))
         (hkdf-impl (completion 20) (status "in-progress"))
         (tests (completion 10) (status "not-started"))
         (docs (completion 15) (status "in-progress"))))
      (working-features "Basic FFI structure, ATS2/Zig stubs"))

    (route-to-mvp
      (milestones
        ((milestone-1 "Complete HKDF implementation"
          (items "Finish ATS2 crypto" "Zig wrapper" "Bidirectional callbacks"))
         (milestone-2 "Testing & validation"
          (items "Unit tests" "FFI boundary tests" "WASM build"))
         (milestone-3 "Documentation"
          (items "API docs" "Usage examples" "Build instructions")))))

    (blockers-and-issues
      (critical)
      (high
        ("Need ATS2 HKDF implementation"))
      (medium
        ("WASM build testing"))
      (low))

    (critical-next-actions
      (immediate
        ("Complete ATS2 HKDF implementation"
         "Add Zig unit tests"))
      (this-week
        ("Test bidirectional FFI"
         "WASM compilation"))
      (this-month
        ("Full documentation"
         "CI/CD setup")))

    (session-history)))
