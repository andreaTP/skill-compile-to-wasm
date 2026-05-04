# skill-compile-to-wasm

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that teaches Claude how to compile C and Rust source code into optimized WebAssembly modules, and how to consume them from host runtimes like Wasmtime and Chicory.

## Install

```bash
claude install-skill https://github.com/andreaTP/skill-compile-to-wasm
```

Once installed, Claude will automatically activate this skill when you ask it to compile code to wasm, wrap a native library, or build a wasm module.

## What it does

When activated, Claude will:

1. Ask what you're building (language, library vs CLI, Docker vs local)
2. Generate a complete build pipeline (Makefile, Cargo.toml, Dockerfile)
3. Resolve toolchain versions dynamically (no hardcoded versions)
4. Handle incompatible dependencies with proven patching strategies
5. Verify the output with export checks
6. Show how to consume the `.wasm` from Java (Chicory) or Rust (Wasmtime)

## Example prompts

```
compile cJSON to wasm as a reactor-mode library
```
```
wrap the jq C library for use from Java via Chicory
```
```
build a Rust CLI tool that converts YAML to JSON, compile to wasm
```
```
I'm getting "undefined symbol: signal" when compiling to wasm — help me fix it
```

## What's included

| Directory | Purpose |
|---|---|
| `SKILL.md` | Main skill instructions (what Claude reads) |
| `scripts/` | Toolchain scripts: version resolution, wasm verification, wasm-tools installer |
| `references/` | Deep-dive docs: compilation flags, host integration, patching guide, troubleshooting |
| `examples/` | 8 working, tested examples (see below) |
| `tests/` | Test harness for local and CI validation |

### Examples

| Example | What it demonstrates |
|---|---|
| `c-local/` | C library wrapper (cJSON) with local WASI SDK, cross-platform |
| `c-docker/` | Same library, Docker-based build |
| `c-patch/` | Handling incompatible C code: `-D` flags and WASI emulation libraries |
| `rust-lib/` | Rust cdylib wrapper (regex crate), reactor mode |
| `rust-cli/` | Rust CLI tool (CSV to JSON), command mode |
| `rust-patch/` | Handling incompatible Rust deps: `default-features = false`, `#[cfg]` |
| `consume-wasmtime/` | Consuming wasm from Rust via Wasmtime API |
| `consume-chicory/` | Consuming wasm from Java via Chicory (interpreter + compiler modes) |

Every example has a `Makefile`, a `test.sh`, and builds a real dependency — not toy code.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for repo structure, local development setup, and how to add new examples.

Quick start:

```bash
./scripts/install-wasm-tools.sh --wasmtime
export PATH="$PWD/bin:$PATH"
./tests/test-all.sh --skip-docker --skip-consume
```

## License

Apache 2.0
