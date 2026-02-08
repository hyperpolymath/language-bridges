;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Project position in hyperpolymath ecosystem

(ecosystem
  (version "1.0.0")
  (name "zig-ats2-ffi")
  (type "library")
  (purpose "Bidirectional FFI bridge between Zig and ATS2")

  (position-in-ecosystem "FFI infrastructure for proof-carrying cryptographic code")

  (related-projects
    ((zig-spark-ffi (relationship sibling-standard) (note "SPARK Ada variant"))
     (rust-zig-ffi (relationship sibling-standard) (note "Rust FFI variant"))
     (wasm-rescript-bridge (relationship potential-consumer) (note "WASM consumer"))
     (sdp-hkdf-deployment (relationship deployment-target) (note "SDP deployment configs"))))

  (what-this-is
    "Zero-overhead FFI bridge enabling Zig and ATS2 interoperation with dependent type proofs")

  (what-this-is-not
    "Not a general-purpose FFI framework, not a standalone cryptographic library"))
