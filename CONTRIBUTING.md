# Contributing

## Repository structure

```
.
├── SKILL.md                      # Entry point — YAML frontmatter + instructions
├── scripts/                      # Toolchain scripts used by the skill
│   ├── resolve-versions.sh       # Queries GitHub for latest WASI SDK, Binaryen, Wizer
│   ├── verify-wasm.sh            # Validates a .wasm file (magic bytes, exports)
│   ├── install-wasm-tools.sh     # Installs wasm-tools + optional wasmtime locally
│   └── lint-skill.sh             # Structural checks on the skill
├── references/                   # Deep-dive docs (linked from SKILL.md)
│   ├── compilation-flags.md
│   ├── host-integration.md
│   └── troubleshooting.md
├── examples/                     # Working, self-contained examples
│   ├── c-local/                  # C library wrapper (local WASI SDK)
│   ├── c-docker/                 # C library wrapper (Docker-based)
│   ├── rust-lib/                 # Rust cdylib wrapper (regex crate)
│   ├── rust-cli/                 # Rust CLI tool (CSV→JSON, command mode)
│   ├── consume-wasmtime/         # Host-side: Wasmtime Rust API
│   └── consume-chicory/          # Host-side: Chicory Java (interpreter + compiler)
├── tests/                        # Test harness
│   ├── test-all.sh               # Runs the full suite locally
│   ├── test-resolve-versions.sh  # Tests resolve-versions.sh output
│   ├── test-verify-wasm.sh       # Tests verify-wasm.sh with fixture
│   └── fixture.wat               # Minimal WAT fixture for script testing
├── .github/workflows/ci.yml      # CI — calls the same scripts you run locally
└── plan.md                       # Roadmap (phases 0–12)
```

## Local development

### Prerequisites

- Bash, curl, tar
- [Rust toolchain](https://rustup.rs/) with `wasm32-wasip1` target
- [shellcheck](https://github.com/koalaman/shellcheck)
- Optional: Docker (for `c-docker` example), Java 17 + Maven (for `consume-chicory`)

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

Each example is self-contained. From the example directory:

```bash
cd examples/c-local
make release     # build
./test.sh        # build + verify
```

Or from anywhere:

```bash
./examples/c-local/test.sh
```

### Testing a single script

```bash
./tests/test-resolve-versions.sh              # validate output format
./tests/test-resolve-versions.sh --check-urls  # also check download URLs (slower)
./tests/test-verify-wasm.sh                    # positive/negative/bad-file tests
```

### Linting

```bash
# Structural checks (frontmatter, executability, examples have Makefile+test.sh, etc.)
./scripts/lint-skill.sh

# Shell script quality
shellcheck scripts/*.sh tests/*.sh examples/*/test.sh
```

## CI

CI (`.github/workflows/ci.yml`) runs the same scripts you run locally. Every CI job delegates to a `test.sh` or `tests/*.sh` script — there is no inline test logic in the workflow file.

To reproduce a CI failure locally, find the failing job and run the corresponding script:

| CI job | Local equivalent |
|---|---|
| `lint` | `./scripts/lint-skill.sh` + `shellcheck ...` |
| `test-scripts` | `./tests/test-resolve-versions.sh --check-urls` + `./tests/test-verify-wasm.sh` |
| `build-c-local` | `./examples/c-local/test.sh` |
| `build-c-docker` | `./examples/c-docker/test.sh` |
| `build-rust-lib` | `./examples/rust-lib/test.sh` |
| `build-rust-cli` | `./examples/rust-cli/test.sh` |
| `consume-wasmtime` | `./examples/consume-wasmtime/test.sh` |
| `consume-chicory` | `./examples/consume-chicory/test.sh` |

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
