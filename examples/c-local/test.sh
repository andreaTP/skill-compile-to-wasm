#!/usr/bin/env bash
set -euo pipefail

# TDD test for the C local toolchain cJSON wrapper example.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/../../scripts/verify-wasm.sh"
WASM="$SCRIPT_DIR/wasm/cjson.wasm"

echo "=== C Local Toolchain Example: cJSON Wrapper ==="
echo ""

# Step 1: Build
echo "Step 1: Building wasm module with local WASI SDK..."
make -C "$SCRIPT_DIR" release
echo ""

# Step 2: Verify
echo "Step 2: Verifying wasm module..."
"$VERIFY" "$WASM" malloc free parse_and_pretty_print validate_json minify_json
echo ""

echo "=== All tests passed ==="
