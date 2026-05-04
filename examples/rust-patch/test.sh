#!/usr/bin/env bash
set -euo pipefail

# Tests Rust patching strategies for wasm-incompatible dependencies.
#
# Demonstrates:
#   1. default-features = false to avoid platform-specific deps (chrono)
#   2. #[cfg(target_arch = "wasm32")] conditional compilation

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/../../scripts/verify-wasm.sh"
WASM="$SCRIPT_DIR/wasm/rust_patch_example.wasm"

echo "=== Rust Patching Example: Handling Incompatible Dependencies ==="
echo ""

# Step 1: Build
echo "Step 1: Building with patching strategies applied..."
make -C "$SCRIPT_DIR" release
echo ""

# Step 2: Verify exports
echo "Step 2: Verifying wasm module..."
"$VERIFY" "$WASM" wasm_alloc wasm_dealloc days_between get_system_time_ms
echo ""

echo "=== All patching tests passed ==="
