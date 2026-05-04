#!/usr/bin/env bash
set -euo pipefail

# Tests patching approaches for wasm-incompatible C libraries.
#
# Demonstrates two strategies:
#   1. -D flag to disable the incompatible feature
#   2. WASI emulation library to stub the missing function

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/../../scripts/verify-wasm.sh"

echo "=== C Patching Example: Handling Incompatible Dependencies ==="
echo ""

# Step 1: Build both approaches
echo "Step 1: Building with both patching approaches..."
make -C "$SCRIPT_DIR" release
echo ""

# Step 2: Verify approach 1 (define flag)
echo "Step 2: Verifying approach 1 (-D flag to disable feature)..."
"$VERIFY" "$SCRIPT_DIR/target/wordcount-approach1.wasm" malloc free wasm_word_count
echo ""

# Step 3: Verify approach 2 (emulation library)
echo "Step 3: Verifying approach 2 (WASI emulation library)..."
"$VERIFY" "$SCRIPT_DIR/target/wordcount-approach2.wasm" malloc free wasm_word_count
echo ""

# Step 4: Verify optimized release
echo "Step 4: Verifying optimized release..."
"$VERIFY" "$SCRIPT_DIR/wasm/wordcount.wasm" malloc free wasm_word_count
echo ""

echo "=== All patching tests passed ==="
