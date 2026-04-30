# compile-to-wasm Skill — Roadmap

## Status Legend
- [ ] Not started
- [x] Done
- [~] In progress

---

## Phase 0: Foundation (Done)
- [x] Skill folder structure (`SKILL.md`, `scripts/`, `references/`, `examples/`)
- [x] `scripts/resolve-versions.sh` — auto-detect latest WASI SDK, Binaryen, Wizer from GitHub releases
- [x] `scripts/verify-wasm.sh` — validate .wasm (magic bytes, exports, expected exports)
- [x] `references/compilation-flags.md` — C, Rust, linker, wasm-opt flags
- [x] `references/troubleshooting.md` — common errors and fixes
- [x] `examples/c-docker/` — C library wrapper (cJSON), Docker-based, reactor mode
- [x] `examples/c-local/` — C library wrapper (cJSON), local WASI SDK, cross-platform
- [x] `examples/rust-lib/` — Rust cdylib wrapper (regex crate), reactor mode
- [x] `examples/rust-cli/` — Rust CLI tool (csv2json), command mode
- [x] No hardcoded versions, no Java/Maven/Chicory references
- [x] Cross-platform Linux + macOS (x86_64 + aarch64)

---

## Phase 1: CI Testing
- [x] `.github/workflows/ci.yml` — GitHub Actions workflow
  - [x] **Lint/structure checks**: `scripts/lint-skill.sh` (24 checks) + shellcheck on all scripts
  - [x] **resolve-versions.sh**: runs, validates all KEY=VALUE pairs present, HEAD-checks download URLs
  - [x] **verify-wasm.sh**: positive test (fixture.wat → fixture.wasm), negative test (missing export), bad file test
  - [x] **C local example**: full build + verify exports on Linux + macOS matrix
  - [x] **C Docker example**: full build + verify exports on Linux
  - [x] **Rust lib example**: full build + verify exports on Linux + macOS matrix
  - [x] **Rust CLI example**: full build + verify exports + wasmtime functional test on Linux + macOS matrix
  - [x] **macOS matrix**: c-local, rust-lib, rust-cli all run on macOS
  - [x] Cache toolchain downloads (WASI SDK, Binaryen, cargo) across runs
- [x] `scripts/lint-skill.sh` — validates SKILL.md frontmatter, kebab-case name, no XML, executable scripts, example structure
- [x] `scripts/install-wasm-tools.sh` — self-contained installer for wasm-tools + optional wasmtime (cross-platform)
- [x] `tests/fixture.wat` — minimal WAT test fixture with malloc/free/add/_start exports

---

## Phase 2: Wasm Consumption Examples (Done)
Show how to **use** the produced .wasm modules, not just build them.

- [x] `examples/consume-wasmtime/` — host-side examples using Wasmtime
  - [x] CLI invocation: `wasmtime run` for command-mode modules (test.sh)
  - [x] Programmatic (Rust): load reactor module, call exports, pass data via linear memory
- [x] `examples/consume-chicory/` — host-side examples using Chicory (Java)
  - [x] Load reactor module, call exports, read/write linear memory
  - [x] Maven setup with chicory dependency (runtime, wasm, wasi, compiler)
  - [x] JUnit test demonstrating the full roundtrip: Java → wasm export → result
  - [x] Both interpreter and compiler modes via `@ParameterizedTest` + `@EnumSource`
- [x] Update `SKILL.md` with a "After compilation" section (Step 7) linking to consumption examples
- [x] Update `references/` with a `host-integration.md` covering memory passing conventions from the host side
- [x] CI jobs: `consume-wasmtime` and `consume-chicory` in `.github/workflows/ci.yml`

---

## Phase 3: Incompatible Dependencies & Patching
Demonstrate how to handle libraries that don't compile to wasm out of the box.

- [ ] `examples/c-patch-abseil/` — C/C++ library with platform-specific code (abseil-cpp or similar)
  - [ ] Show the build failure first (document the error)
  - [ ] Patch approach 1: `sed`/`patch` in Dockerfile to stub out incompatible code
  - [ ] Patch approach 2: overlay headers (`sysfix/` pattern from pglite4j)
  - [ ] Patch approach 3: `-D` defines to disable features at compile time
  - [ ] Working build with patches applied
  - [ ] `test.sh` verifying the patched build works
- [ ] `examples/rust-patch-dep/` — Rust crate with an incompatible dependency
  - [ ] Show the build failure first
  - [ ] Patch approach 1: `[patch.crates-io]` in Cargo.toml pointing to a fork/local path
  - [ ] Patch approach 2: feature flags to disable incompatible features (`default-features = false`)
  - [ ] Patch approach 3: `#[cfg(target_arch = "wasm32")]` conditional compilation
  - [ ] Working build with patches applied
  - [ ] `test.sh` verifying the patched build works
- [ ] `references/patching-guide.md` — general strategies for making code wasm-compatible

---

## Phase 4: C++ Examples
- [ ] `examples/cpp-lib/` — C++ library wrapper (e.g., nlohmann/json or a small C++ lib)
  - [ ] Makefile with `clang++` targeting wasm32-wasip1
  - [ ] `extern "C"` wrapper functions for FFI
  - [ ] Handle C++ runtime considerations (exceptions, RTTI, static constructors)
  - [ ] `test.sh` with export verification
- [ ] `examples/cpp-docker/` — Docker-based C++ build
  - [ ] More complex C++ project with multiple translation units
  - [ ] Static linking of libcxx
- [ ] Update `references/compilation-flags.md` with C++-specific flags
  - [ ] `-fno-exceptions` (smaller binary, required for some wasm runtimes)
  - [ ] `-fno-rtti` (smaller binary)
  - [ ] `-stdlib=libc++` with WASI SDK
  - [ ] Static constructor handling (`__wasm_call_ctors`)
- [ ] Update `SKILL.md` with C++ section

---

## Phase 5: Go Examples
- [ ] `examples/go-tinygo/` — TinyGo → wasm (preferred for small modules)
  - [ ] Library mode: `//export` directives, reactor build
  - [ ] CLI mode: standard main with stdin/stdout
  - [ ] Makefile with TinyGo target `wasi`
  - [ ] `test.sh` with export verification + wasmtime functional test
- [ ] `examples/go-standard/` — Standard Go → wasm
  - [ ] `GOOS=wasip1 GOARCH=wasm go build`
  - [ ] Limitations: larger binary, GC included, no reactor mode
  - [ ] When to use standard Go vs TinyGo
  - [ ] `test.sh` with wasmtime functional test
- [ ] Update `references/compilation-flags.md` with Go/TinyGo flags
  - [ ] TinyGo: `-target=wasi`, `-target=wasm`, scheduler options
  - [ ] Standard Go: `GOOS=wasip1 GOARCH=wasm`
- [ ] Update `SKILL.md` with Go section

---

## Phase 6: Zig Examples
- [ ] `examples/zig-lib/` — Zig library → wasm (reactor mode)
  - [ ] Zig as a first-class wasm compiler (built-in wasm target)
  - [ ] `zig build-lib -target wasm32-wasi` or `build.zig` with wasm target
  - [ ] `export` keyword for function exports
  - [ ] Consuming C libraries from Zig (Zig's C interop)
  - [ ] `test.sh` with export verification
- [ ] `examples/zig-crosscompile-c/` — Using Zig as a C/C++ cross-compiler to wasm
  - [ ] `zig cc` as a drop-in replacement for clang with wasm target
  - [ ] Advantage: no separate WASI SDK download needed
  - [ ] `test.sh` with verification
- [ ] Update `SKILL.md` with Zig section

---

## Phase 7: Debugging Wasm
- [ ] `references/debugging.md`
  - [ ] Keeping DWARF debug info: compile with `-g`, skip `--strip-debug` in wasm-opt
  - [ ] `wasm-tools dump` / `wasm-tools print` for inspection
  - [ ] `wasm-tools strip` to remove debug info for release
  - [ ] Source-level debugging with Chrome DevTools (for browser wasm)
  - [ ] Debugging with `wasmtime --debug` and LLDB
  - [ ] Adding `name` section for readable stack traces: `wasm-opt --debuginfo`
  - [ ] Dev vs release build profiles (Makefile targets)
- [ ] Update example Makefiles to include a `debug` target alongside `release`
- [ ] Update `SKILL.md` with debugging section

---

## Phase 8: WASI Preview 2 / Component Model
- [ ] `examples/component-rust/` — Rust component with WIT interface
  - [ ] `.wit` interface definition
  - [ ] `wit-bindgen` code generation
  - [ ] `cargo build --target wasm32-wasip2`
  - [ ] `wasm-tools component new` to create component
  - [ ] `test.sh` verifying component structure
- [ ] `examples/component-compose/` — composing multiple components
  - [ ] Two components linked via shared WIT interface
  - [ ] `wasm-tools compose` to link
- [ ] `references/component-model.md` — P1 vs P2, when to use components, WIT basics
- [ ] Update `SKILL.md` with Component Model section

---

## Notes
- Each new example follows the same TDD pattern: `Makefile` + `test.sh` + `verify-wasm.sh`
- All examples must pass in CI before merging
- `SKILL.md` grows incrementally — each phase adds a section and links to new examples/references
- Progressive disclosure: SKILL.md body → references/ → examples/
- No hardcoded versions anywhere — always `resolve-versions.sh` or equivalent
