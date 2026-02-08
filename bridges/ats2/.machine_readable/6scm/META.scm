;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Architectural decisions and design rationale

(meta
  (version "1.0.0")
  (schema-version "2024-12-01")

  (architecture-decisions
    ((adr-001
      (status accepted)
      (date "2026-01-23")
      (context "Need bidirectional FFI between Zig and ATS2 without C intermediary")
      (decision "Use direct ABI mapping via extern C calling convention")
      (consequences "Zero overhead FFI, careful ABI alignment required"))

     (adr-002
      (status accepted)
      (date "2026-01-23")
      (context "HKDF cryptographic primitive demonstration")
      (decision "Implement core crypto in ATS2 with dependent type proofs")
      (consequences "Mathematical correctness guaranteed, Zig handles I/O"))))

  (development-practices
    (code-style "Zig stdlib conventions, ATS2 Postiats style")
    (security "FFI boundaries validated, linear types prevent UAF")
    (testing "Zig unit tests, ATS2 proof checking")
    (versioning "Semantic versioning")
    (documentation "AsciiDoc with inline FFI documentation"))

  (design-rationale
    ((why-ats2 "Dependent types provide correctness proofs")
     (why-zig "Comptime enables zero-cost WASM compilation")
     (why-no-c "Eliminate translation overhead"))))
