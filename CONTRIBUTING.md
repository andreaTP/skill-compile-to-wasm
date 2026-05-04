# Contributing

## Repository structure

```
.
├── SKILL.md                      # Entry point — YAML frontmatter + instructions
├── scripts/                      # Toolchain scripts used by the skill
├── references/                   # Deep-dive docs (linked from SKILL.md)
├── examples/                     # Working, self-contained examples
├── tests/                        # Test harness
│   ├── test-all.sh               # Runs the full suite locally
│   └── fixture.wat               # Minimal WAT fixture for script testing
└── .github/workflows/ci.yml      # CI — calls the same scripts you run locally
```

## Local development

### Prerequisites

- Bash, curl, tar
- [shellcheck](https://github.com/koalaman/shellcheck)
- Language-specific: Rust toolchain with `wasm32-wasip1` target, Docker, Java + Maven — depending on which examples you want to run

### Quick start

```bash
# Install wasm-tools (+ wasmtime) locally
./scripts/install-wasm-tools.sh --wasmtime
export PATH="$PWD/bin:$PATH"

# Run the full test suite (skip what you don't have)
./tests/test-all.sh --skip-docker --skip-consume

# Run everything
./tests/test-all.sh
```

### Running individual examples

Each example is self-contained and runnable from any directory:

```bash
./examples/c-local/test.sh
```

Or from the example directory:

```bash
cd examples/c-local
make release     # build
./test.sh        # build + verify
```

### Linting

```bash
./scripts/lint-skill.sh
shellcheck scripts/*.sh tests/*.sh examples/*/test.sh
```

## CI

CI runs the same scripts you run locally. Every CI job delegates to a `test.sh` — there is no inline test logic in the workflow file.

To reproduce a CI failure, find the failing job name and run the matching `examples/<name>/test.sh` or `tests/test-*.sh` script.

Set `GITHUB_TOKEN` if you hit GitHub API rate limits:

```bash
export GITHUB_TOKEN=ghp_...
```

## Adding a new example

1. Create `examples/<name>/` with at minimum:
   - `Makefile` — must have a `release` (or `build`) target
   - `test.sh` — must be executable, self-contained, runnable from any directory
2. `test.sh` should call `make` to build and `../../scripts/verify-wasm.sh` to validate the output
3. Run `./scripts/lint-skill.sh` — it auto-detects new example directories
4. Add a CI job in `.github/workflows/ci.yml` that calls your `test.sh`
5. Run `shellcheck` on your new scripts

### Example test.sh template

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/../../scripts/verify-wasm.sh"
WASM="$SCRIPT_DIR/wasm/<project>.wasm"

echo "=== <Example Name> ==="
make -C "$SCRIPT_DIR" release
"$VERIFY" "$WASM" <expected_exports>
echo "=== All tests passed ==="
```

## Conventions

- **No hardcoded toolchain versions** — always use `resolve-versions.sh`
- **Scripts are the source of truth** — CI calls scripts, never the other way around
- **Examples are self-contained** — each can be copied out of the repo and still work
- **test.sh runs from anywhere** — use `SCRIPT_DIR` for path resolution, not `$PWD`
- **shellcheck clean** — all `.sh` files must pass shellcheck
