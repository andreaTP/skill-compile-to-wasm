#!/usr/bin/env bash
set -euo pipefail

# TDD test for the Rust CLI (command mode) example.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/../../scripts/verify-wasm.sh"
WASM="$SCRIPT_DIR/wasm/csv2json.wasm"

echo "=== Rust CLI Example: CSV to JSON ==="
echo ""

# Step 1: Build
echo "Step 1: Building wasm module with Cargo..."
make -C "$SCRIPT_DIR" release
echo ""

# Step 2: Verify module structure
echo "Step 2: Verifying wasm module..."
"$VERIFY" "$WASM" _start
echo ""

# Step 3: Functional test (requires wasmtime)
if command -v wasmtime &>/dev/null; then
    echo "Step 3: Running functional test with wasmtime..."
    INPUT="name,age
Alice,30
Bob,25"
    OUTPUT=$(echo "$INPUT" | wasmtime run "$WASM")

    if echo "$OUTPUT" | grep -q '"Alice"'; then
        echo "  PASS: Output contains Alice"
    else
        echo "  FAIL: Expected Alice in output"
        echo "  Got: $OUTPUT"
        exit 1
    fi

    if echo "$OUTPUT" | grep -q '"Bob"'; then
        echo "  PASS: Output contains Bob"
    else
        echo "  FAIL: Expected Bob in output"
        echo "  Got: $OUTPUT"
        exit 1
    fi
    echo ""
else
    echo "Step 3: SKIP (wasmtime not found — install for functional testing)"
    echo ""
fi

echo "=== All tests passed ==="
