// SPDX-License-Identifier: AGPL-3.0-or-later
//// Gleam-Zig-FFI - Core module for Zig FFI bindings
////
//// This module provides the foundation for calling Zig libraries from Gleam.
////
//// ## Architecture
////
//// - On BEAM: Uses Zigler for direct Zig-to-NIF compilation
//// - On JS: Uses Deno FFI for loading shared libraries
////
//// ## Usage
////
//// ```gleam
//// import gleam_zig_ffi
////
//// let version = gleam_zig_ffi.get_version()
//// ```

import gleam/result

/// Result type for FFI operations
pub type FfiResult(a) {
  FfiOk(a)
  FfiError(String)
}

/// Convert FfiResult to Gleam Result
pub fn to_result(ffi_result: FfiResult(a)) -> Result(a, String) {
  case ffi_result {
    FfiOk(value) -> Ok(value)
    FfiError(msg) -> Error(msg)
  }
}

/// Library version as packed u32
@external(erlang, "gleam_zig_ffi_nif", "get_version")
@external(javascript, "./ffi.mjs", "getVersion")
pub fn get_version() -> Int

/// Add two integers (example function)
@external(erlang, "gleam_zig_ffi_nif", "add")
@external(javascript, "./ffi.mjs", "add")
pub fn add(a: Int, b: Int) -> Int

/// Multiply two integers (example function)
@external(erlang, "gleam_zig_ffi_nif", "multiply")
@external(javascript, "./ffi.mjs", "multiply")
pub fn multiply(a: Int, b: Int) -> Int

/// Calculate factorial (example function)
@external(erlang, "gleam_zig_ffi_nif", "factorial")
@external(javascript, "./ffi.mjs", "factorial")
pub fn factorial(n: Int) -> Int

/// Compute fibonacci number (example function)
@external(erlang, "gleam_zig_ffi_nif", "fibonacci")
@external(javascript, "./ffi.mjs", "fibonacci")
pub fn fibonacci(n: Int) -> Int
