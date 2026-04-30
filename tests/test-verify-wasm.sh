#!/usr/bin/env bash
set -euo pipefail

# Tests verify-wasm.sh with the WAT fixture: positive, negative, and bad-file cases.
#
# Requires: wasm-tools (to compile fixture.wat → fixture.wasm)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/.."
VERIFY="$REPO_DIR/scripts/verify-wasm.sh"
FIXTURE_WAT="$SCRIPT_DIR/fixture.wat"
TMPDIR="${TMPDIR:-/tmp}"
FIXTURE_WASM="$TMPDIR/fixture-test-$$.wasm"

trap 'rm -f "$FIXTURE_WASM" "$TMPDIR/bad-test-$$.wasm"' EXIT

echo "=== Testing verify-wasm.sh ==="
echo ""

# Step 0: Compile fixture
echo "Step 0: Compiling test fixture..."
if ! command -v wasm-tools &>/dev/null; then
    echo "  SKIP: wasm-tools not found (install with scripts/install-wasm-tools.sh)"
    exit 0
fi
wasm-tools parse "$FIXTURE_WAT" -o "$FIXTURE_WASM"
echo "  OK: compiled $FIXTURE_WAT → $FIXTURE_WASM"
echo ""

# Step 1: Positive test — all exports present
echo "Step 1: Positive test (all exports present)..."
"$VERIFY" "$FIXTURE_WASM" malloc free add _start
echo "  PASS"
echo ""

# Step 2: Negative test — missing export must fail
echo "Step 2: Negative test (missing export must fail)..."
if "$VERIFY" "$FIXTURE_WASM" nonexistent 2>/dev/null; then
    echo "  FAIL: should have failed for missing export"
    exit 1
fi
echo "  PASS: correctly detected missing export"
echo ""

# Step 3: Bad file test — invalid wasm must fail
echo "Step 3: Bad file test (invalid wasm must fail)..."
BAD_WASM="$TMPDIR/bad-test-$$.wasm"
echo "not wasm" > "$BAD_WASM"
if "$VERIFY" "$BAD_WASM" 2>/dev/null; then
    echo "  FAIL: should have failed for invalid wasm"
    exit 1
fi
echo "  PASS: correctly rejected invalid wasm"
echo ""

echo "=== All verify-wasm tests passed ==="
