#!/usr/bin/env bash
set -euo pipefail

# Validates the compile-to-wasm skill structure and content.
#
# Checks:
#   1. SKILL.md exists with valid YAML frontmatter
#   2. All scripts are executable
#   3. No hardcoded toolchain versions (WASI SDK, Binaryen, Wizer) outside examples
#   4. Every example has a Makefile and test.sh
#   5. No XML angle brackets in frontmatter

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
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

echo "Linting skill: $SKILL_DIR"
echo "---"

# 1. SKILL.md exists
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    check "SKILL.md exists" 0
else
    check "SKILL.md exists" 1
fi

# 2. SKILL.md has YAML frontmatter with name and description
if head -1 "$SKILL_DIR/SKILL.md" | grep -q '^---$'; then
    check "SKILL.md starts with YAML frontmatter" 0
else
    check "SKILL.md starts with YAML frontmatter" 1
fi

FRONTMATTER=$(sed -n '1,/^---$/p' "$SKILL_DIR/SKILL.md" | tail -n +2 | head -n -1)

if echo "$FRONTMATTER" | grep -q '^name:'; then
    check "Frontmatter has 'name' field" 0
    NAME=$(echo "$FRONTMATTER" | grep '^name:' | sed 's/name: *//')
    if echo "$NAME" | grep -qE '^[a-z0-9-]+$'; then
        check "Name is kebab-case: $NAME" 0
    else
        check "Name is kebab-case: $NAME" 1
    fi
else
    check "Frontmatter has 'name' field" 1
fi

if echo "$FRONTMATTER" | grep -q '^description:'; then
    check "Frontmatter has 'description' field" 0
else
    check "Frontmatter has 'description' field" 1
fi

# 3. No XML angle brackets in frontmatter
if echo "$FRONTMATTER" | grep -q '[<>]'; then
    check "No XML angle brackets in frontmatter" 1
else
    check "No XML angle brackets in frontmatter" 0
fi

# 4. All scripts are executable
for script in "$SKILL_DIR"/scripts/*.sh; do
    if [ -x "$script" ]; then
        check "$(basename "$script") is executable" 0
    else
        check "$(basename "$script") is executable" 1
    fi
done

# 5. Every example directory has Makefile and test.sh
for example_dir in "$SKILL_DIR"/examples/*/; do
    example_name=$(basename "$example_dir")
    if [ -f "$example_dir/Makefile" ]; then
        check "examples/$example_name has Makefile" 0
    else
        check "examples/$example_name has Makefile" 1
    fi
    if [ -f "$example_dir/test.sh" ]; then
        check "examples/$example_name has test.sh" 0
    else
        check "examples/$example_name has test.sh" 1
    fi
    if [ -x "$example_dir/test.sh" ]; then
        check "examples/$example_name/test.sh is executable" 0
    else
        check "examples/$example_name/test.sh is executable" 1
    fi
done

# 6. No hardcoded toolchain versions in SKILL.md (only in examples and templates)
HARDCODED=$(grep -nE 'WASI_SDK_VERSION\s*:?=\s*[0-9]+|BINARYEN_VERSION\s*:?=\s*[0-9]+|WIZER_VERSION\s*:?=\s*[0-9]' "$SKILL_DIR/SKILL.md" || true)
if [ -z "$HARDCODED" ]; then
    check "No hardcoded toolchain versions in SKILL.md" 0
else
    check "No hardcoded toolchain versions in SKILL.md (found: $HARDCODED)" 1
fi

# 7. References directory exists with expected files
for ref in compilation-flags.md troubleshooting.md host-integration.md; do
    if [ -f "$SKILL_DIR/references/$ref" ]; then
        check "references/$ref exists" 0
    else
        check "references/$ref exists" 1
    fi
done

echo "---"
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
