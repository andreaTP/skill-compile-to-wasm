# Troubleshooting Common Build Errors

## C Compilation Errors

### `undefined symbol: __wasi_*`
**Cause**: Missing WASI sysroot.
**Fix**: Ensure `--sysroot=/path/to/wasi-sdk/share/wasi-sysroot` is set in CFLAGS.

### `undefined symbol: signal` / `mmap` / `getpid`
**Cause**: C library uses POSIX functions not available in WASI by default.
**Fix**: Add the corresponding emulation flags:
```
-D_WASI_EMULATED_SIGNAL -lwasi-emulated-signal
-D_WASI_EMULATED_MMAN -lwasi-emulated-mman
-D_WASI_EMULATED_PROCESS_CLOCKS -lwasi-emulated-process-clocks
-D_WASI_EMULATED_GETPID -lwasi-emulated-getpid
```

### `undefined symbol: __stack_chk_fail`
**Cause**: Stack protector enabled (default on some platforms).
**Fix**: Add `-fno-stack-protector -fno-stack-clash-protection`.

### `wasm-ld: error: initial memory too small`
**Cause**: Default initial memory (1 page = 64KB) too small for the compiled module.
**Fix**: Increase initial memory: `-Wl,--initial-memory=16777216` (16MB) or larger.

### `memory access out of bounds` (at runtime)
**Cause**: Module needs more memory than allocated.
**Fix**:
- Increase `--initial-memory` for known-large workloads
- Set `--max-memory=4294967296` to allow growth up to 4GB
- Add `--stack-first` and increase `--stack-size` if deep recursion is involved

### `wasm-ld: error: undefined symbol: __main_argc_argv`
**Cause**: Using reactor mode (`-mexec-model=reactor`) but code has a `main()` function.
**Fix**: Either remove `main()` for reactor mode, or switch to command mode (remove `-mexec-model=reactor`).

## Rust Compilation Errors

### `error[E0463]: can't find crate for 'std'`
**Cause**: The `wasm32-wasip1` target is not installed.
**Fix**: `rustup target add wasm32-wasip1`

### `error: linker 'cc' not found`
**Cause**: Rust can't find a C linker for cross-compilation (needed for C dependencies).
**Fix**: Set WASI SDK as the C compiler:
```bash
export CC_wasm32_wasip1=/path/to/wasi-sdk/bin/clang
export CFLAGS_wasm32_wasip1="--sysroot=/path/to/wasi-sdk/share/wasi-sysroot"
```

### `error: linking with 'rust-lld' failed`
**Cause**: Usually a missing C library dependency or incompatible crate.
**Fix**: Check that all crate dependencies support `wasm32-wasip1`. Crates using `libc` FFI, networking, or filesystem may not compile.

### Crate doesn't compile for wasm
**Cause**: Crate uses platform-specific features (threads, networking, filesystem).
**Fix**: Look for `wasm` feature flags in the crate. Use `#[cfg(target_arch = "wasm32")]` for conditional compilation.

## wasm-opt Errors

### `Fatal: error parsing wasm`
**Cause**: Version mismatch between compiler output and wasm-opt.
**Fix**: Update Binaryen to latest version. Run `scripts/resolve-versions.sh` to get the latest.

### `Fatal: unknown feature`
**Cause**: wasm-opt doesn't recognize a wasm feature used by the compiler.
**Fix**: Add the corresponding `--enable-*` flag. Common ones:
```
--enable-bulk-memory
--enable-sign-ext
--enable-mutable-globals
--enable-nontrapping-float-to-int
```

### wasm-opt produces larger output
**Cause**: `-O3` optimizes for speed, not size. Some passes can increase size.
**Fix**: Use `-Oz` for size optimization, or `-Os` for balance.

## Docker Build Errors

### Docker build fails on macOS with ARM
**Cause**: WASI SDK Docker images may only support `linux/amd64`.
**Fix**: Add `--platform linux/amd64` to your Docker build command:
```bash
docker build --platform linux/amd64 -t my-wasm-build .
```

### Docker build runs out of disk space
**Cause**: Large C libraries (PostgreSQL, etc.) produce many intermediate files.
**Fix**: Use multi-stage Docker builds, or add cleanup steps (`rm -rf` build artifacts between stages).

## Toolchain Download Errors

### GitHub API rate limiting
**Cause**: Unauthenticated GitHub API requests are limited to 60/hour.
**Fix**: Set `GITHUB_TOKEN` environment variable:
```bash
export GITHUB_TOKEN=ghp_your_token_here
./scripts/resolve-versions.sh
```

### Download URL 404
**Cause**: Release naming convention changed for the tool.
**Fix**: Check the actual release page on GitHub for the correct asset name. The `resolve-versions.sh` script constructs URLs based on known patterns — update it if naming changes.

### WASI SDK tarball extraction fails
**Cause**: macOS `tar` vs GNU `tar` incompatibility, or download was incomplete.
**Fix**:
- Verify the download completed: `file wasi-sdk-*.tar.gz` should say "gzip compressed data"
- On macOS, use `gtar` (from `brew install gnu-tar`) if standard `tar` fails

## Runtime Errors

### `unreachable` trap
**Cause**: Code hit an unreachable instruction (often from a panic or assert).
**Fix**: Check for null pointer dereferences, out-of-bounds array access, or Rust panics. Ensure data passed to the module is valid.

### WASI function not available
**Cause**: Host runtime doesn't implement the WASI function the module calls.
**Fix**: Ensure your host runtime supports WASI Preview 1. For reactor modules, consider if you really need WASI — pure computation modules can target `wasm32-unknown-unknown` instead.
