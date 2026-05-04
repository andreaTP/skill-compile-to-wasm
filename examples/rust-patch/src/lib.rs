//! Demonstrates Rust patching strategies for wasm32 compatibility.
//!
//! Two strategies shown here:
//!
//! 1. **default-features = false** in Cargo.toml
//!    The `chrono` crate's default features pull in platform-specific
//!    clock code. Disabling defaults avoids the incompatibility.
//!
//! 2. **#[cfg(target_arch)]** conditional compilation
//!    Platform-specific code paths are guarded so they only compile
//!    on the target they support.

use std::alloc::{alloc, dealloc, Layout};

use chrono::NaiveDate;

#[no_mangle]
pub extern "C" fn wasm_alloc(size: i32) -> *mut u8 {
    let layout = Layout::from_size_align(size as usize, 1).unwrap();
    unsafe { alloc(layout) }
}

#[no_mangle]
pub extern "C" fn wasm_dealloc(ptr: *mut u8, size: i32) {
    let layout = Layout::from_size_align(size as usize, 1).unwrap();
    unsafe { dealloc(ptr, layout) }
}

#[no_mangle]
pub extern "C" fn days_between(
    y1: i32, m1: u32, d1: u32,
    y2: i32, m2: u32, d2: u32,
) -> i64 {
    let date1 = NaiveDate::from_ymd_opt(y1, m1, d1);
    let date2 = NaiveDate::from_ymd_opt(y2, m2, d2);

    match (date1, date2) {
        (Some(d1), Some(d2)) => (d2 - d1).num_days(),
        _ => -1,
    }
}

// Strategy 2: #[cfg] conditional compilation
// This function only exists on native — on wasm, we provide a stub.
#[cfg(not(target_arch = "wasm32"))]
pub fn get_system_time_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(-1)
}

#[cfg(target_arch = "wasm32")]
#[no_mangle]
pub extern "C" fn get_system_time_ms() -> i64 {
    -1
}
