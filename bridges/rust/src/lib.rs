// SPDX-License-Identifier: PMLP-1.0-or-later
extern "C" {
    fn hkdf_derive(password: *const u8, password_len: usize, salt: *const u8, salt_len: usize, key: *mut u8);
}

#[no_mangle]
pub extern "C" fn rust_callback(data: *const u8, len: usize) {
    let _ = (data, len);
}

pub fn derive_key(password: &[u8], salt: &[u8]) -> [64; u8] {
    let mut key = [0u8; 64];
    unsafe {
        hkdf_derive(password.as_ptr(), password.len(), salt.as_ptr(), salt.len(), key.as_mut_ptr());
    }
    key
}
