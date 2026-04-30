#!/usr/bin/env bash
set -euo pipefail

# TDD test for the Rust library wrapper example.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/../../scripts/verify-wasm.sh"
WASM="$SCRIPT_DIR/wasm/regex_wasm.wasm"

echo "=== Rust Library Example: regex wrapper ==="
echo ""

# Step 1: Build
echo "Step 1: Building wasm module with Cargo + WASI SDK..."
make -C "$SCRIPT_DIR" release
echo ""

# Step 2: Verify
echo "Step 2: Verifying wasm module..."
"$VERIFY" "$WASM" alloc dealloc regex_match
echo ""

echo "=== All tests passed ==="
