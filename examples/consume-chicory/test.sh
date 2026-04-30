#!/usr/bin/env bash
set -euo pipefail

# TDD test for Chicory (Java) consumption example.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CJSON_WASM="$SCRIPT_DIR/../c-local/wasm/cjson.wasm"

echo "=== Chicory (Java) Consumption Example ==="
echo ""

# Step 1: Ensure wasm module is built
if [ ! -f "$CJSON_WASM" ]; then
    echo "Step 1: Building cjson.wasm dependency..."
    make -C "$SCRIPT_DIR/../c-local" release
else
    echo "Step 1: cjson.wasm already built"
fi
echo ""

# Step 2: Run Maven tests
echo "Step 2: Running Chicory integration tests..."
if command -v mvn &>/dev/null; then
    mvn -f "$SCRIPT_DIR/pom.xml" test -Dcjson.wasm.path="$CJSON_WASM"
    echo ""
    echo "  PASS: All Chicory integration tests passed"
else
    echo "  SKIP: Maven not available"
fi
echo ""

echo "=== All tests passed ==="
