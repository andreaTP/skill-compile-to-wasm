# Compilation Flags Reference

## Execution Models

### Reactor (Library Mode)
Use for modules that export functions and stay alive between calls.
```
-mexec-model=reactor
```
- Exports user-defined functions + `malloc`/`free`
- No `_start` entrypoint — host calls exported functions directly
- Most common pattern for embedding a library

### Command (CLI Mode)
Use for modules that run `_start()`, process input, then exit.
```
# Default mode — no special flag needed
# Optionally add -Wl,--no-entry for pure libraries without _start
```
- Runs `_start()` on instantiation
- Uses WASI for stdin/stdout/stderr and args
- Good for CLI tools, data processors, formatters

## C Compiler Flags (clang)

### Target
```
--target=wasm32-wasip1           # Standard WASI Preview 1
--target=wasm32-wasi-threads     # Only if pthreads needed (rare)
--sysroot=/path/to/wasi-sysroot  # WASI SDK sysroot
```

### Optimization
```
-O3     # Maximum speed (prefer for throughput-critical code)
-Oz     # Minimum size (prefer for smaller .wasm)
-Os     # Balance size/speed
-g0     # No debug info in output (combine with optimization)
-flto   # Link-time optimization (significant size reduction)
```

### Wasm Post-MVP Features
```
-mnontrapping-fptoint    # Non-trapping float-to-int conversions
-msign-ext               # Sign-extension operators
-mbulk-memory            # Bulk memory operations (memcpy/memset)
-mreference-types        # Reference types
-mmultivalue             # Multiple return values
-mmutable-globals        # Mutable globals (import/export)
```

### Stack and Security
```
-fno-stack-protector          # Disable stack protection (not needed in wasm sandbox)
-fno-stack-clash-protection   # Disable stack clash protection
```

### WASI Emulation (needed by many C libraries)
```
-D_WASI_EMULATED_SIGNAL       # Signal handling (signal.h)
-D_WASI_EMULATED_MMAN         # Memory mapping (mmap/mprotect)
-D_WASI_EMULATED_PROCESS_CLOCKS  # Process clocks
-D_WASI_EMULATED_GETPID       # getpid()
```
When using emulated features, link the corresponding library:
```
-lwasi-emulated-signal
-lwasi-emulated-mman
-lwasi-emulated-process-clocks
-lwasi-emulated-getpid
```

## Linker Flags

### Exports
```
-Wl,--export=<fn>           # Export specific function (preferred — explicit)
-Wl,--export=malloc         # Required for host memory allocation
-Wl,--export=free           # Required for host memory deallocation
-Wl,--export-all            # Export everything (quick but exposes internals)
-Wl,--export-dynamic        # Export symbols marked __attribute__((visibility("default")))
```

### Memory Layout
```
-Wl,--initial-memory=<bytes>      # Pre-allocate memory (use for known-large workloads)
-Wl,--max-memory=4294967296       # Allow up to 4GB memory growth
-Wl,--stack-first                 # Place stack before globals (default in WASI SDK 32+)
-Wl,--stack-size=<bytes>          # Set stack size (default 64KB, increase for deep recursion)
```

### Module Type
```
-Wl,--no-entry         # No _start function (pure library, use with reactor)
-Wl,--strip-debug      # Remove debug info from binary
-Wl,--strip-all        # Remove all symbol info
```

### Import Handling
```
-Wl,--import-undefined    # Allow undefined imports (resolved by host at runtime)
-Wl,--import-memory       # Import memory from host instead of defining it
```

## Rust Settings

### Cargo.toml for Library (Reactor) Mode
```toml
[lib]
crate-type = ["cdylib"]

[profile.release]
opt-level = 'z'       # Minimum size ('s' for balance, 3 for speed)
lto = true            # Link-time optimization
codegen-units = 1     # Single codegen unit (slower compile, better optimization)
strip = true          # Strip symbols
panic = "abort"       # No unwinding (smaller binary)
```

### Cargo.toml for Binary (Command) Mode
```toml
# No [lib] section needed — default binary target

[profile.release]
opt-level = 'z'
lto = true
codegen-units = 1
strip = true
panic = "abort"
```

### Build Environment Variables
```bash
WASI_SDK_PATH=/path/to/wasi-sdk
CC_wasm32_wasip1=/path/to/wasi-sdk/bin/clang
CFLAGS_wasm32_wasip1="--sysroot=/path/to/wasi-sdk/share/wasi-sysroot"
```

### Rust FFI Export Pattern
```rust
#[no_mangle]
pub extern "C" fn my_function(ptr: i32, len: i32) -> i32 {
    // ...
}
```

## wasm-opt Flags (Binaryen)

### Speed Optimization
```
-O3                  # Maximum speed optimization
-O4                  # Aggressive (may increase size)
```

### Size Optimization
```
-Oz                  # Maximum size reduction
-Os                  # Balance size/speed
```

### Common Passes
```
--strip-debug          # Remove debug info
--strip-producers      # Remove producers section
--low-memory-unused    # Optimize memory layout
--flatten --rereloop   # Advanced control flow optimization
--converge             # Run passes until no more changes
--vacuum               # Remove unused code
--dce                  # Dead code elimination
--duplicate-function-elimination  # Merge identical functions
```

### Feature Flags
```
--enable-bulk-memory       # Enable bulk memory operations
--enable-sign-ext          # Enable sign extension
--enable-mutable-globals   # Enable mutable globals
--enable-nontrapping-float-to-int
--enable-multivalue
--enable-reference-types
--enable-threads           # Enable threads (for wasm32-wasi-threads)
```
