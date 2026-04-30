#!/usr/bin/env bash
set -euo pipefail

# TDD test for the C Docker cJSON wrapper example.
#
# Steps:
#   1. Build the wasm module via Docker
#   2. Verify the .wasm is valid
#   3. Check expected exports are present

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/../../scripts/verify-wasm.sh"
WASM="$SCRIPT_DIR/wasm/cjson.wasm"

echo "=== C Docker Example: cJSON Wrapper ==="
echo ""

# Step 1: Build
echo "Step 1: Building wasm module via Docker..."
make -C "$SCRIPT_DIR" build
echo ""

# Step 2: Verify
echo "Step 2: Verifying wasm module..."
"$VERIFY" "$WASM" malloc free parse_and_pretty_print validate_json minify_json
echo ""

echo "=== All tests passed ==="
