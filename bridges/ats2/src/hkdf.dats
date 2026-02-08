// SPDX-License-Identifier: PMLP-1.0-or-later
// ATS2 HKDF implementation with FFI exports for Zig

%{^
// Zig-compatible header (embedded in ATS2)
#include <stdint.h>
extern void hkdf_derive(uint8_t* password, size_t password_length,
                        uint8_t* salt, size_t salt_length,
                        uint8_t* output_key);
extern void zig_callback(uint8_t* data, size_t length);
%}

staload "libatscc/SATS/basics.sats"

extern fun hkdf_derive: (!ptr, size_t, !ptr, size_t, !ptr) -> void = "mac#hkdf_derive"
extern fun zig_callback: (!ptr, size_t) -> void = "mac#zig_callback"

// ATS2 HKDF implementation
implement hkdf_derive(password_ptr, password_length, salt_ptr, salt_length, output_key_ptr) = {
  // Simple HKDF derivation (simplified for demonstration)
  // In production, use a proper HKDF implementation
  val () = $extfcall(void, "memcpy", output_key_ptr, password_ptr, 32)
  val () = zig_callback(output_key_ptr, 32)
}

// Export for Zig
extern fun register_callback: ((!ptr, size_t) -> void) -> void = "mac#register_callback"
