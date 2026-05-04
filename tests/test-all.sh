#!/usr/bin/env bash
set -euo pipefail

# Runs the full compile-to-wasm test suite locally.
#
# Usage:
#   ./test-all.sh                           # run everything
#   ./test-all.sh --skip-docker             # skip Docker-based examples
#   ./test-all.sh --skip-consume            # skip consumption examples (Java/Rust host)
#   ./test-all.sh --skip-docker --skip-consume  # fast local loop

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/.."
REPO_SCRIPTS="$REPO_DIR/scripts"
EXAMPLES_DIR="$REPO_DIR/examples"

SKIP_DOCKER=false
SKIP_CONSUME=false

for arg in "$@"; do
    case "$arg" in
        --skip-docker)  SKIP_DOCKER=true ;;
        --skip-consume) SKIP_CONSUME=true ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

PASSED=0
FAILED=0
SKIPPED=0
FAILURES=()

run_test() {
    local name="$1"
    local cmd="$2"
    echo ""
    echo "━━━ $name ━━━"
    if eval "$cmd"; then
        PASSED=$((PASSED + 1))
        echo "→ PASSED"
    else
        FAILED=$((FAILED + 1))
        FAILURES+=("$name")
        echo "→ FAILED"
    fi
}

skip_test() {
    local name="$1"
    local reason="$2"
    echo ""
    echo "━━━ $name ━━━"
    echo "→ SKIPPED: $reason"
    SKIPPED=$((SKIPPED + 1))
}

# ─── Lint ──────────────────────────────────────────────────────────
run_test "lint-skill" "$REPO_SCRIPTS/lint-skill.sh"
run_test "shellcheck" "shellcheck $REPO_SCRIPTS/*.sh $SCRIPT_DIR/*.sh $EXAMPLES_DIR/*/test.sh"

# ─── Script tests ─────────────────────────────────────────────────
run_test "test-resolve-versions" "$SCRIPT_DIR/test-resolve-versions.sh"
run_test "test-verify-wasm" "$SCRIPT_DIR/test-verify-wasm.sh"

# ─── Build examples ───────────────────────────────────────────────
run_test "c-local" "$EXAMPLES_DIR/c-local/test.sh"

if [ "$SKIP_DOCKER" = true ]; then
    skip_test "c-docker" "--skip-docker"
else
    run_test "c-docker" "$EXAMPLES_DIR/c-docker/test.sh"
fi

run_test "rust-lib" "$EXAMPLES_DIR/rust-lib/test.sh"
run_test "rust-cli" "$EXAMPLES_DIR/rust-cli/test.sh"

# ─── Patching examples ────────────────────────────────────────────
run_test "c-patch" "$EXAMPLES_DIR/c-patch/test.sh"
run_test "rust-patch" "$EXAMPLES_DIR/rust-patch/test.sh"

# ─── Consumption examples ─────────────────────────────────────────
if [ "$SKIP_CONSUME" = true ]; then
    skip_test "consume-wasmtime" "--skip-consume"
    skip_test "consume-chicory" "--skip-consume"
else
    run_test "consume-wasmtime" "$EXAMPLES_DIR/consume-wasmtime/test.sh"
    if command -v mvn &>/dev/null; then
        run_test "consume-chicory" "$EXAMPLES_DIR/consume-chicory/test.sh"
    else
        skip_test "consume-chicory" "mvn not found"
    fi
fi

# ─── Summary ──────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASSED passed, $FAILED failed, $SKIPPED skipped"

if [ ${#FAILURES[@]} -gt 0 ]; then
    echo ""
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
