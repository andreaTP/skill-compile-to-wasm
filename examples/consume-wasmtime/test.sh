#!/usr/bin/env bash
set -euo pipefail

# TDD test for wasmtime consumption examples.
#
# Tests both:
#   1. CLI usage: wasmtime run for command-mode modules (csv2json)
#   2. Rust API: programmatic call to reactor-mode module (cJSON)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CJSON_WASM="$SCRIPT_DIR/../c-local/wasm/cjson.wasm"
CSV2JSON_WASM="$SCRIPT_DIR/../rust-cli/wasm/csv2json.wasm"

echo "=== Wasmtime Consumption Examples ==="
echo ""

# Build wasm dependencies if missing
if [ ! -f "$CJSON_WASM" ]; then
    echo "Building cjson.wasm dependency..."
    make -C "$SCRIPT_DIR/../c-local" release
fi
if [ ! -f "$CSV2JSON_WASM" ]; then
    echo "Building csv2json.wasm dependency..."
    make -C "$SCRIPT_DIR/../rust-cli" release
fi
echo ""

# ─── Test 1: CLI usage (command-mode module) ───────────────────────
echo "Test 1: wasmtime CLI — csv2json (command mode)"
if command -v wasmtime &>/dev/null && [ -f "$CSV2JSON_WASM" ]; then
    INPUT=$'name,age\nAlice,30\nBob,25'
    OUTPUT=$(echo "$INPUT" | wasmtime run "$CSV2JSON_WASM")

    if echo "$OUTPUT" | grep -q '"Alice"' && echo "$OUTPUT" | grep -q '"Bob"'; then
        echo "  PASS: CSV→JSON conversion via wasmtime CLI"
    else
        echo "  FAIL: unexpected output: $OUTPUT"
        exit 1
    fi
else
    echo "  SKIP: wasmtime or csv2json.wasm not available"
fi
echo ""

# ─── Test 2: Rust API (reactor-mode module) ────────────────────────
echo "Test 2: wasmtime Rust API — cJSON (reactor mode)"
if [ -f "$CJSON_WASM" ]; then
    OUTPUT=$(cargo run --manifest-path "$SCRIPT_DIR/Cargo.toml" --release -- "$CJSON_WASM" '{"name":"Alice","age":30}')

    if echo "$OUTPUT" | grep -q '"Alice"' && echo "$OUTPUT" | grep -q '"age"'; then
        echo "  PASS: JSON pretty-print via wasmtime Rust API"
    else
        echo "  FAIL: unexpected output: $OUTPUT"
        exit 1
    fi
else
    echo "  SKIP: cjson.wasm not available (run 'make -C ../c-local release' first)"
fi
echo ""

echo "=== All tests passed ==="
