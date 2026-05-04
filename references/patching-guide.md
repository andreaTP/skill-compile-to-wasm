# Patching Guide: Making Libraries Wasm-Compatible

Strategies for compiling upstream C/Rust libraries to WebAssembly when they don't work out of the box, ordered from simplest to most invasive.

## Strategy 1: Compile-Time Feature Flags

Disable features the library doesn't need in a wasm context. No source changes required.

```bash
# Disable threading (most common — wasm is single-threaded)
-DSQLITE_THREADSAFE=0

# Disable dynamic loading (sandboxed, no dlopen)
-DSQLITE_ENABLE_LOAD_EXTENSION=0

# Disable features that pull in POSIX deps
-DPRISM_EXCLUDE_PRETTYPRINT
-DSQLITE_OMIT_SHARED_CACHE=1
```

**When to use:** The library has `#ifdef` guards around problematic features. Check the library's build docs for configure options or `HAVE_*`/`ENABLE_*` defines.

**Real example:** sqlite4j disables threading, shared cache, and extension loading — all features that need POSIX APIs unavailable in WASI.

## Strategy 2: WASI Emulation Libraries

WASI SDK ships emulation libraries for commonly missing POSIX APIs. Link against them with matching defines:

| Missing API | Define | Link flag |
|---|---|---|
| `mmap`, `munmap` | `-D_WASI_EMULATED_MMAN` | `-lwasi-emulated-mman` |
| `signal`, `sigaction` | `-D_WASI_EMULATED_SIGNAL` | `-lwasi-emulated-signal` |
| `clock_gettime` (process) | `-D_WASI_EMULATED_PROCESS_CLOCKS` | `-lwasi-emulated-process-clocks` |
| `getpid` | `-D_WASI_EMULATED_GETPID` | `-lwasi-emulated-getpid` |

```makefile
CFLAGS += -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_SIGNAL
LDFLAGS += -lwasi-emulated-mman -lwasi-emulated-signal
```

**When to use:** Build fails with `undefined symbol: signal`, `undefined symbol: mmap`, etc. These are stub implementations — they satisfy the linker and provide basic behavior, but don't fully implement the POSIX semantics.

**Real examples:**
- jq4j: `-D_WASI_EMULATED_SIGNAL -lwasi-emulated-signal`
- prism: `-D_WASI_EMULATED_MMAN -lwasi-emulated-mman`
- pglite4j: all four emulation libraries

## Strategy 3: Wrapper Code

Leave upstream source completely untouched. Write a thin C or Rust wrapper that provides the API you need:

```c
// wrapper.c — transforms library API into wasm-friendly exports
#include "upstream_library.h"
#include <stdlib.h>

__attribute__((export_name("process")))
int process(const char* input_ptr, int input_len) {
    // Call upstream library functions
    // Return result via linear memory
}
```

**When to use:** You're wrapping a library that compiles cleanly but has an API not suitable for wasm (e.g., a CLI tool you want as a reactor-mode library). This is what `examples/c-local/` and `examples/rust-lib/` already demonstrate.

**Real examples:**
- jq4j: `jq_wrapper.c` transforms jq's CLI interface into a reactor-mode `process(input, filter)` API
- sqlite4j: `sqlite3_helpers.c` adds callback bridge functions with `__import_module__` attributes

## Strategy 4: Compiler Flag Filtering

When building complex projects with autoconf/cmake, the configure step may inject flags that break wasm compilation. Use a compiler wrapper script:

```bash
#!/bin/bash
# wasi-cc — wrapper that filters incompatible flags
ARGS=()
for arg in "$@"; do
    case "$arg" in
        -pthread|-latomic) ;; # skip — WASI doesn't support these
        -I/usr/*|-L/usr/*) ;; # skip — host system paths break cross-compilation
        -Wl,--start-group|-Wl,--end-group) ;; # skip — not supported by wasm-ld
        *) ARGS+=("$arg") ;;
    esac
done
exec ${WASI_SDK_PATH}/bin/clang "${ARGS[@]}"
```

Then configure with `CC=./wasi-cc`.

**When to use:** Building a project with `./configure && make` that probes the host system and adds flags incompatible with wasm.

**Real example:** pglite4j's `wasi-c` wrapper (140 lines) filters `-pthread`, `-latomic`, host system include paths, and linker group flags while adding WASI emulation defines and libraries.

## Strategy 5: Sysroot Header Overlays

WASI SDK's libc headers may be missing types or structs that the upstream library expects. Create overlay headers and inject them into the sysroot:

```
sysfix/
├── bits/alltypes.h    # add missing types (e.g., pthread_barrier_t)
├── sys/mman.h         # memory mapping stubs
└── setjmp.h           # custom setjmp implementation
```

Apply with:
```bash
cp -r sysfix/* ${WASI_SDK_PATH}/share/wasi-sysroot/include/
```

Or without modifying the SDK, use `-isystem`:
```bash
clang -isystem ./sysfix --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot ...
```

**When to use:** Compilation fails because a header is missing or a type/struct is incomplete. Check the error — if it says `unknown type name 'pthread_barrier_t'`, you need an overlay.

**Real example:** pglite4j provides overlay headers for `pthread_barrier_t`, `sockaddr_un` (with `sun_path`), and `setjmp.h` — types PostgreSQL expects that WASI SDK's headers don't define.

## Strategy 6: Force-Included Compatibility Headers

For libraries with many scattered POSIX calls, create a single compatibility header that stubs everything out, and force-include it:

```c
// compat.h — POSIX stubs for WASI
#ifdef __wasi__
#include <stdlib.h>
#include <time.h>

static inline int popen(const char* cmd, const char* mode) { return 0; }
static inline int pclose(int fd) { return 0; }
static inline int getuid(void) { return 1000; }
static inline int umask(int mask) { return 0; }
static inline int chmod(const char* path, int mode) { return 0; }
#endif
```

Force-include at compile time:
```bash
clang -include compat.h -D__wasi__ ...
```

**When to use:** The library calls many POSIX functions scattered across many files. Patching each call site would be too many changes. The stubs don't need to work correctly — just satisfy the linker and provide safe no-op behavior.

**Important:** Skip the force-include during `./configure` so feature detection sees the real libc:
```bash
if [ "$CONFIGURE_MODE" != "true" ]; then
    CFLAGS+=" -include compat.h"
fi
```

**Real example:** pglite4j's `patch.h` stubs `popen`, `pclose`, `geteuid` (returns 1000), `umask`, `chmod`, `mkstemp`, and more. It's force-included during compilation but skipped during configure.

## Strategy 7: Source Patches

When none of the above work, patch the upstream source directly. Use `#if defined(__wasi__)` guards so patches coexist with native builds:

```diff
--- a/src/network.c
+++ b/src/network.c
@@ -42,7 +42,9 @@
 void send_notification(int pid) {
+#if !defined(__wasi__)
     kill(pid, SIGUSR1);
+#else
+    handle_notification_directly();
+#endif
 }
```

Apply patches in your build pipeline:
```bash
# Download upstream source
curl -sL "https://github.com/org/lib/archive/v1.0.tar.gz" | tar xz

# Apply patches
for patch in patches/*.patch; do
    patch -p1 -d upstream-src < "$patch"
done
```

**When to use:** A specific code path uses an API that can't be stubbed (e.g., `fork()` in a critical path where the return value matters). Organize patches in tiers:
1. Platform-shared patches (work on both emscripten and WASI)
2. WASI-specific patches
3. Application-specific patches

**Real example:** pglite4j maintains 21 `.diff` files in three tiers to patch PostgreSQL. Key patterns: guarding `fork()` calls (returns -1), stubbing semaphores, replacing signal-based IPC with direct function calls.

## Strategy 8: Post-Compilation Fixups

Some issues only appear after compilation — the wasm module is valid but too large or hits runtime limits:

```bash
# Split functions that exceed runtime instruction limits
wasm-opt --split-large-functions \
    --pass-arg=split-func-threshold@13000 \
    input.wasm -o output.wasm
```

**When to use:** The wasm module compiles and links but:
- A function is too large (>13K expressions) — common with SQLite's amalgamation
- The module fails validation in some runtimes due to function size

**Real example:** sqlite4j uses Binaryen's `--split-large-functions` pass to break up SQLite's monolithic parser function (~19K expressions) into smaller helper functions.

## Decision Flowchart

```
Build fails with "undefined symbol: X"
├── X is signal/mmap/getpid/clock?
│   └── Strategy 2: WASI emulation library
├── X is a library feature you don't need?
│   └── Strategy 1: -D flag to disable it
├── X is scattered across many files?
│   └── Strategy 6: force-included compat header
└── X is in a specific code path?
    └── Strategy 7: source patch with #if !defined(__wasi__)

Build fails with "unknown type: T"
├── T is a POSIX type (pthread_*, sockaddr_*)?
│   └── Strategy 5: sysroot header overlay
└── T is library-specific?
    └── Strategy 1: check for HAVE_T / ENABLE_T define

Build fails with "unsupported flag: F"
└── Strategy 4: compiler wrapper that filters F

Build succeeds but runtime fails
├── Function too large?
│   └── Strategy 8: split-large-functions
└── Wrong API shape for wasm?
    └── Strategy 3: wrapper code
```

## Common Error Messages → Fixes

| Error | Strategy | Fix |
|---|---|---|
| `undefined symbol: signal` | 2 | `-D_WASI_EMULATED_SIGNAL -lwasi-emulated-signal` |
| `undefined symbol: mmap` | 2 | `-D_WASI_EMULATED_MMAN -lwasi-emulated-mman` |
| `undefined symbol: getpid` | 2 | `-D_WASI_EMULATED_GETPID -lwasi-emulated-getpid` |
| `undefined symbol: fork` | 7 | Patch: `#if !defined(__wasi__)` guard |
| `undefined symbol: pthread_create` | 1 | `-DLIB_THREADSAFE=0` or equivalent |
| `unknown type name 'pthread_barrier_t'` | 5 | Overlay header defining the type |
| `incompatible flag: -pthread` | 4 | Compiler wrapper filtering the flag |
| `wasm-validator error in function N` | 8 | `wasm-opt --split-large-functions` |
| `memory access out of bounds` | — | `-Wl,--initial-memory=<bytes>` |
