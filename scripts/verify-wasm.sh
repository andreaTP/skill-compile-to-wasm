#!/usr/bin/env bash
set -euo pipefail

# Verifies a compiled .wasm module is valid.
#
# Usage:
#   ./verify-wasm.sh path/to/module.wasm [expected_export1 expected_export2 ...]
#
# Checks:
#   1. File exists and is non-empty
#   2. Starts with wasm magic bytes (\0asm)
#   3. Reports file size
#   4. Lists exports (if wasm-tools is available)
#   5. Validates expected exports are present (if specified)
#
# Exit codes:
#   0 = all checks passed
#   1 = validation failed

WASM_FILE="${1:-}"
shift || true
EXPECTED_EXPORTS=("$@")

if [ -z "$WASM_FILE" ]; then
    echo "Usage: $0 <file.wasm> [expected_export1 ...]"
    exit 1
fi

PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "Verifying: $WASM_FILE"
echo "---"

# Check 1: File exists and is non-empty
if [ -f "$WASM_FILE" ] && [ -s "$WASM_FILE" ]; then
    check "File exists and is non-empty" 0
else
    check "File exists and is non-empty" 1
    echo ""
    echo "Result: FAIL ($FAIL failed)"
    exit 1
fi

# Check 2: Wasm magic bytes (\0asm = 00 61 73 6d)
MAGIC=$(xxd -l 4 -p "$WASM_FILE")
if [ "$MAGIC" = "0061736d" ]; then
    check "Valid wasm magic bytes" 0
else
    check "Valid wasm magic bytes (got: $MAGIC)" 1
fi

# Check 3: File size
SIZE=$(stat -c%s "$WASM_FILE" 2>/dev/null || stat -f%z "$WASM_FILE" 2>/dev/null)
SIZE_KB=$((SIZE / 1024))
if [ "$SIZE_KB" -gt 1024 ]; then
    SIZE_MB=$((SIZE_KB / 1024))
    echo "  INFO: File size: ${SIZE_MB} MB (${SIZE} bytes)"
else
    echo "  INFO: File size: ${SIZE_KB} KB (${SIZE} bytes)"
fi

# Check 4: List exports (if wasm-tools available)
EXPORTS=""
if command -v wasm-tools &>/dev/null; then
    EXPORTS=$(wasm-tools print "$WASM_FILE" 2>/dev/null | grep '(export' | sed 's/.*"\(.*\)".*/\1/' || true)
    EXPORT_COUNT=$(echo "$EXPORTS" | grep -c . || true)
    check "Exports found: $EXPORT_COUNT" 0
    if [ -n "$EXPORTS" ]; then
        echo "  INFO: Exports:"
        echo "$EXPORTS" | while read -r exp; do
            echo "    - $exp"
        done
    fi
elif command -v wasm-objdump &>/dev/null; then
    EXPORTS=$(wasm-objdump -x "$WASM_FILE" 2>/dev/null | grep ' - ' | grep -E '(func|memory|table|global)\[' | sed 's/.*<\(.*\)>.*/\1/' || true)
    EXPORT_COUNT=$(echo "$EXPORTS" | grep -c . || true)
    check "Exports found: $EXPORT_COUNT" 0
else
    echo "  SKIP: No wasm-tools or wasm-objdump found (install for export inspection)"
fi

# Check 5: Validate expected exports
if [ ${#EXPECTED_EXPORTS[@]} -gt 0 ]; then
    if [ -z "$EXPORTS" ]; then
        echo "  SKIP: Cannot check expected exports (no wasm inspection tool available)"
    else
        for exp in "${EXPECTED_EXPORTS[@]}"; do
            if echo "$EXPORTS" | grep -qw "$exp"; then
                check "Expected export '$exp' present" 0
            else
                check "Expected export '$exp' present" 1
            fi
        done
    fi
fi

echo "---"
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
