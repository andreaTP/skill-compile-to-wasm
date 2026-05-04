#!/usr/bin/env bash
set -euo pipefail

# Tests resolve-versions.sh: validates output format, non-empty values, and optionally URL reachability.
#
# Usage:
#   ./test-resolve-versions.sh              # validate output format only
#   ./test-resolve-versions.sh --check-urls  # also HEAD-check download URLs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/.."
RESOLVE="$REPO_DIR/scripts/resolve-versions.sh"
CHECK_URLS=false

for arg in "$@"; do
    case "$arg" in
        --check-urls) CHECK_URLS=true ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

echo "=== Testing resolve-versions.sh ==="
echo ""

# Step 1: Run and capture output
echo "Step 1: Running resolve-versions.sh..."
OUTPUT=$("$RESOLVE")
echo "$OUTPUT"
echo ""

# Step 2: Validate every KEY=VALUE line has a non-empty value (no hardcoded key list)
echo "Step 2: Validating all keys have values..."
FAIL=0
while IFS='=' read -r key value; do
    if [ -z "$value" ]; then
        echo "  FAIL: $key is empty"
        FAIL=1
    else
        echo "  OK: $key=$value"
    fi
done <<< "$OUTPUT"

if [ "$FAIL" -ne 0 ]; then
    echo "FAIL: some keys have empty values"
    exit 1
fi
echo ""

# Step 3: Verify URLs are reachable (optional, slow)
if [ "$CHECK_URLS" = true ]; then
    echo "Step 3: Verifying download URLs are reachable..."
    eval "$OUTPUT"

    for url in "$WASI_SDK_URL" "$BINARYEN_URL" "$WIZER_URL"; do
        STATUS=$(curl -sI -o /dev/null -w '%{http_code}' -L "$url" || true)
        if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
            echo "  OK ($STATUS): $url"
        else
            echo "  FAIL ($STATUS): $url"
            exit 1
        fi
    done
    echo ""
fi

echo "=== All resolve-versions tests passed ==="
