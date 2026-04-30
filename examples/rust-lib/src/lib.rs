//! Wrapper for the regex crate — demonstrates the Rust library wrapping pattern.
//!
//! Exports:
//!   - alloc(len) -> ptr     : allocate len bytes in linear memory
//!   - dealloc(ptr, len)     : free a previous allocation
//!   - regex_match(pattern_ptr, pattern_len, input_ptr, input_len) -> i32
//!
//! The host interacts via linear memory:
//!   1. ptr = alloc(len)
//!   2. Write bytes into memory at ptr
//!   3. Call the function with ptr + len
//!   4. Read result (or use return value)
//!   5. dealloc(ptr, len)

use std::alloc::{alloc as std_alloc, dealloc as std_dealloc, Layout};
use std::slice;
use std::str;

/// Allocate `len` bytes in linear memory. Returns a pointer the host can write to.
#[no_mangle]
pub extern "C" fn alloc(len: i32) -> *mut u8 {
    let layout = Layout::from_size_align(len as usize, 1).unwrap();
    unsafe { std_alloc(layout) }
}

/// Free a previous allocation of `len` bytes at `ptr`.
#[no_mangle]
pub extern "C" fn dealloc(ptr: *mut u8, len: i32) {
    let layout = Layout::from_size_align(len as usize, 1).unwrap();
    unsafe { std_dealloc(ptr, layout) }
}

/// Check if `input` matches the regex `pattern`.
/// Returns 1 if the pattern matches anywhere in the input, 0 otherwise.
/// Returns -1 on invalid pattern or invalid UTF-8.
#[no_mangle]
pub extern "C" fn regex_match(
    pattern_ptr: *const u8,
    pattern_len: i32,
    input_ptr: *const u8,
    input_len: i32,
) -> i32 {
    let pattern = unsafe { slice::from_raw_parts(pattern_ptr, pattern_len as usize) };
    let input = unsafe { slice::from_raw_parts(input_ptr, input_len as usize) };

    let pattern_str = match str::from_utf8(pattern) {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let input_str = match str::from_utf8(input) {
        Ok(s) => s,
        Err(_) => return -1,
    };

    match regex::Regex::new(pattern_str) {
        Ok(re) => {
            if re.is_match(input_str) {
                1
            } else {
                0
            }
        }
        Err(_) => -1,
    }
}
