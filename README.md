# skill-compile-to-wasm

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that teaches Claude how to compile native source code into optimized WebAssembly modules, and how to consume them from host runtimes like Wasmtime and Chicory.

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
6. Show how to consume the `.wasm` from a host runtime

## Example prompts

```
compile cJSON to wasm as a reactor-mode library
```
```
wrap the jq library for use from Java via Chicory
```
```
build a Rust CLI tool that converts YAML to JSON, compile to wasm
```
```
I'm getting "undefined symbol: signal" when compiling to wasm — help me fix it
```

The `examples/` directory contains working, tested examples covering compilation, patching strategies, and host-side consumption. Each has a `Makefile` and `test.sh`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for repo structure, local development, and how to add new examples.

## License

Apache 2.0
