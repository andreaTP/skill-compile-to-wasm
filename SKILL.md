---
name: compile-to-wasm
description: Generates build pipelines to compile C, C++, Rust, Go, or Zig source code into optimized .wasm modules, and shows how to consume them from host runtimes (Wasmtime, Chicory). Use when user asks to "compile to wasm", "build wasm module", "create wasm from C/Rust/Go/Zig", "wrap a C library for wasm", "embed a native library in Java/Rust without JNI/FFI", "portable native code", or needs a Makefile/Dockerfile for WebAssembly compilation. Covers library wrapping (reactor mode with malloc/free exports), CLI tools (command mode with stdin/stdout), and host-side integration patterns.
---

# Compile native code to WebAssembly

Generate the build pipeline to compile C or Rust source code into an optimized `.wasm` module.

## Step 1: Gather context

Ask the user:
1. **Source language**: C or Rust?
2. **Source location**: path to the source code or upstream repo URL
3. **Build mode** (see below):
   - **Library wrapper** (reactor) — most common: wrapping an existing library to expose functions
   - **CLI tool** (command) — standalone tool that processes stdin/stdout
4. **Build approach**: Docker-based (reproducible, recommended for C) or local toolchain (simpler, good for Rust)?
5. **Exported functions**: list of functions to export from Wasm, or `--export-all`
6. **Needs Wizer pre-initialization?** (databases, large runtimes with expensive init)
7. **Needs threading?** (`wasm32-wasi-threads` — rare, only if the library uses pthreads)

## Step 2: Resolve toolchain versions

Never hardcode toolchain versions. Always resolve the latest versions dynamically:

```bash
eval "$(./scripts/resolve-versions.sh)"
echo "WASI SDK: $WASI_SDK_VERSION, Binaryen: $BINARYEN_VERSION, Wizer: $WIZER_VERSION"
```

Run `scripts/resolve-versions.sh` at the start of every build pipeline setup. It queries GitHub releases for the latest versions of WASI SDK, Binaryen, and Wizer, and detects the OS/architecture automatically.

If GitHub API rate limiting is hit, set `GITHUB_TOKEN`:
```bash
export GITHUB_TOKEN=ghp_...
```

## Step 3: Choose build mode

### Library wrapper (reactor mode) — most common

Use this when wrapping an existing C/Rust library for use as an embedded wasm module. Examples: wrapping sqlite, jq, cJSON, a regex engine, a parser.

Key characteristics:
- Uses `-mexec-model=reactor` (C) or `crate-type = ["cdylib"]` (Rust)
- **Must export `malloc` and `free`** (C) or `alloc` and `dealloc` (Rust) so the host can allocate and read linear memory
- Exports custom entrypoint functions (e.g., `parse_json`, `regex_match`)
- Module stays alive between function calls

#### Writing the wrapper

The wrapper is a thin layer between the host and the upstream library. It:
1. Receives data from the host via pointers into linear memory
2. Calls the upstream library functions
3. Returns results via linear memory or return values

**Function signature convention** — use pointer+length pairs for strings/buffers:
```c
// C wrapper function signature
__attribute__((export_name("my_function")))
int my_function(const char* input_ptr, int input_len) { ... }
```
```rust
// Rust wrapper function signature
#[no_mangle]
pub extern "C" fn my_function(input_ptr: *const u8, input_len: i32) -> i32 { ... }
```

**Memory ownership conventions**:
- **Caller-allocates**: host allocates memory, writes input, calls function, reads output from same buffer. Simpler but limited.
- **Callee-allocates** (preferred): host writes input into allocated memory, calls function, function allocates new memory for result, returns pointer. Host reads result and frees both buffers.

See `examples/c-docker/wrapper.c` for a complete C wrapper example.
See `examples/rust-lib/src/lib.rs` for a complete Rust wrapper example.

#### C library wrapper — linker flags
```
-mexec-model=reactor
-Wl,--export=malloc
-Wl,--export=free
-Wl,--export=my_function1
-Wl,--export=my_function2
```

#### Rust library wrapper — Cargo.toml
```toml
[lib]
crate-type = ["cdylib"]

[profile.release]
opt-level = 'z'
lto = true
codegen-units = 1
strip = true
panic = "abort"
```

### CLI tool (command mode)

Use this when building a standalone tool that processes input and produces output. Examples: formatters, linters, data converters, query tools.

Key characteristics:
- Uses default command mode (no `-mexec-model=reactor`)
- Has `_start()` entrypoint (Rust `fn main()`, C `int main()`)
- Uses WASI for stdin/stdout/stderr
- Module runs once per invocation, then exits
- No need to export `malloc`/`free` — host doesn't interact with linear memory directly
- Arguments passed via WASI args

See `examples/rust-cli/` for a complete CLI tool example.

## Step 4: Generate the build pipeline

### For C projects: Docker-based build (recommended)

Reference: `examples/c-docker/` for a complete working example.

#### Dockerfile template
```dockerfile
ARG WASI_SDK_VERSION=<from resolve-versions.sh>
FROM ghcr.io/webassembly/wasi-sdk:wasi-sdk-${WASI_SDK_VERSION}

ENV WASI_SDK_PATH=/opt/wasi-sdk

RUN apt-get update && apt-get install -y curl binaryen

WORKDIR /workspace

# Download upstream library source
# ARG LIB_VERSION=x.y.z
# RUN curl -sL "https://github.com/org/lib/archive/refs/tags/v${LIB_VERSION}.tar.gz" | tar xz

# Copy wrapper source
COPY wrapper.c /workspace/wrapper.c

# Compile: wrapper + library → reactor wasm module
RUN ${WASI_SDK_PATH}/bin/clang \
    --target=wasm32-wasip1 \
    --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot \
    -mexec-model=reactor \
    -O3 \
    -fno-stack-protector \
    -Wl,--export=malloc \
    -Wl,--export=free \
    # Add project-specific exports:
    # -Wl,--export=<function_name> \
    -o output.wasm \
    wrapper.c library.c

# Optimize
RUN wasm-opt -O3 --strip-debug --low-memory-unused --enable-bulk-memory output.wasm -o optimized.wasm
```

#### Makefile template (Docker-based)
```makefile
PROJECT := <name>

.PHONY: clean build test

clean:
	rm -rf wasm

build:
	rm -rf wasm
	mkdir -p wasm
	docker build --platform linux/amd64 -t wasm-$(PROJECT) .
	docker create --name dummy-$(PROJECT)-wasm wasm-$(PROJECT)
	docker cp dummy-$(PROJECT)-wasm:/workspace/optimized.wasm wasm/$(PROJECT).wasm
	docker rm -f dummy-$(PROJECT)-wasm

test:
	./test.sh
```

### For C projects: Local toolchain

Reference: `examples/c-local/` for a complete working example.

#### Makefile template
```makefile
PROJECT := <name>
PWD := $(CURDIR)
SCRIPTS := $(PWD)/../../scripts

# Auto-detect OS and arch
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Linux)
  OS_NAME := linux
endif
ifeq ($(UNAME_S),Darwin)
  OS_NAME := macos
endif

ifeq ($(UNAME_M),x86_64)
  ARCH_NAME := x86_64
endif
ifeq ($(UNAME_M),aarch64)
  ARCH_NAME := aarch64
endif
ifeq ($(UNAME_M),arm64)
  ARCH_NAME := aarch64
endif

.PHONY: clean get-versions get-wasisdk get-binaryen build optimize release all

clean:
	rm -rf target wasi-sdk binaryen versions.env

get-versions:
	@if [ ! -f "$(PWD)/versions.env" ]; then \
		$(SCRIPTS)/resolve-versions.sh > $(PWD)/versions.env; \
	fi

get-wasisdk: get-versions
	@if [ ! -d "$(PWD)/wasi-sdk" ]; then \
		. $(PWD)/versions.env && \
		curl -sL "$${WASI_SDK_URL}" | tar xz && \
		mv wasi-sdk-$${WASI_SDK_VERSION}.0-$(ARCH_NAME)-$(OS_NAME) $(PWD)/wasi-sdk; \
	fi

get-binaryen: get-versions
	@if [ ! -d "$(PWD)/binaryen" ]; then \
		. $(PWD)/versions.env && \
		curl -sL "$${BINARYEN_URL}" | tar xz && \
		mv binaryen-$${BINARYEN_TAG} $(PWD)/binaryen; \
	fi

build: get-wasisdk
	mkdir -p target
	$(PWD)/wasi-sdk/bin/clang \
		--sysroot=$(PWD)/wasi-sdk/share/wasi-sysroot \
		--target=wasm32-wasip1 \
		-mexec-model=reactor \
		-O3 \
		-fno-stack-protector \
		-Wl,--global-base=1024 \
		-Wl,--export=malloc \
		-Wl,--export=free \
		-o target/$(PROJECT).wasm \
		$(SOURCES)

optimize: get-binaryen
	$(PWD)/binaryen/bin/wasm-opt -O3 --strip-debug --low-memory-unused \
		target/$(PROJECT).wasm -o target/$(PROJECT)-opt.wasm

release: build optimize
	mkdir -p wasm
	cp target/$(PROJECT)-opt.wasm wasm/$(PROJECT).wasm

all: get-wasisdk get-binaryen release
```

### For Rust projects: Library wrapper

Reference: `examples/rust-lib/` for a complete working example.

#### Cargo.toml template
```toml
[package]
name = "<project>"
version = "0.1.0"
edition = "2021"

[lib]
name = "<project>"
crate-type = ["cdylib"]

[dependencies]
# Add library dependencies here

[profile.release]
opt-level = 'z'
lto = true
codegen-units = 1
strip = true
panic = "abort"
```

#### Makefile template
```makefile
PROJECT := <name>
PWD := $(CURDIR)
SCRIPTS := $(PWD)/../../scripts

# (include OS/arch detection block from C local template above)

.PHONY: clean get-versions get-wasisdk get-binaryen ensure-target build optimize release all

clean:
	rm -rf wasi-sdk binaryen versions.env wasm
	cargo clean

# (include get-versions, get-wasisdk, get-binaryen targets from C local template)

ensure-target:
	@rustup target add wasm32-wasip1 2>/dev/null || true

build: get-wasisdk ensure-target
	WASI_SDK_PATH=$(PWD)/wasi-sdk \
	CC_wasm32_wasip1=$(PWD)/wasi-sdk/bin/clang \
	CFLAGS_wasm32_wasip1="--sysroot=$(PWD)/wasi-sdk/share/wasi-sysroot" \
	cargo build --target wasm32-wasip1 --release

optimize: get-binaryen
	$(PWD)/binaryen/bin/wasm-opt -Oz --strip-debug \
		target/wasm32-wasip1/release/$(PROJECT).wasm \
		-o target/wasm32-wasip1/release/$(PROJECT)-opt.wasm

release: build optimize
	mkdir -p wasm
	cp target/wasm32-wasip1/release/$(PROJECT)-opt.wasm wasm/$(PROJECT).wasm

all: release
```

### For Rust projects: CLI tool

Reference: `examples/rust-cli/` for a complete working example.

Same as library wrapper Makefile, but:
- No `get-wasisdk` needed (pure Rust, no C dependencies) unless the crate has C dependencies
- No `crate-type = ["cdylib"]` in Cargo.toml — it's a binary
- Build produces a binary with `_start` entrypoint

```makefile
build: ensure-target
	cargo build --target wasm32-wasip1 --release
```

## Step 5: Verify the output

After compilation, always verify the `.wasm` module:

```bash
# Basic verification
./scripts/verify-wasm.sh wasm/<project>.wasm

# With expected exports (library wrapper)
./scripts/verify-wasm.sh wasm/<project>.wasm malloc free my_function1 my_function2

# With expected exports (CLI tool)
./scripts/verify-wasm.sh wasm/<project>.wasm _start
```

The verification script checks:
1. File exists and has valid wasm magic bytes
2. Reports file size
3. Lists all exports (if `wasm-tools` is installed)
4. Validates expected exports are present

## Step 6: TDD workflow

Always follow the build-verify-test cycle:

1. **Build**: `make release` (or `make build` for Docker)
2. **Verify exports**: `./scripts/verify-wasm.sh wasm/<project>.wasm <expected_exports>`
3. **Check size**: is the `.wasm` reasonably sized? (optimize with `-Oz` / `wasm-opt -Oz` if too large)
4. **Functional test**: run `test.sh` which combines all checks

Create a `test.sh` for every project. See the examples for the pattern.

## Step 7: Consume the wasm module

After building and verifying, integrate the `.wasm` module into a host application.
For detailed API examples and code patterns, consult `references/host-integration.md`.

### Wasmtime (Rust / CLI)

**CLI** — for command-mode modules:
```bash
echo "input" | wasmtime run module.wasm
```

**Rust API** — for reactor-mode modules:
```rust
let instance = linker.instantiate(&mut store, &module)?;
let malloc = instance.get_typed_func::<i32, i32>(&mut store, "malloc")?;
let ptr = malloc.call(&mut store, input.len() as i32)?;
memory.write(&mut store, ptr as usize, input)?;
let result = my_func.call(&mut store, (ptr, input.len() as i32))?;
```

See `examples/consume-wasmtime/` for a complete working example.

### Chicory (Java)

Supports two execution modes — same API, swap one line:

**Interpreter** (pure Java, no native code):
```java
var instance = Instance.builder(module).build();
```

**Compiler** (JIT to JVM bytecode, ~10x faster):
```java
var instance = Instance.builder(module)
        .withMachineFactory(MachineFactoryCompiler::compile)
        .build();
```

**Calling exports**:
```java
var malloc = instance.export("malloc");
long ptr = malloc.apply(input.length)[0];
instance.memory().write((int) ptr, inputBytes);
long result = myFunc.apply(ptr, input.length)[0];
String output = instance.memory().readCString((int) result);
```

See `examples/consume-chicory/` for a complete working example with JUnit tests covering both modes.

## Compilation flags reference

For detailed C compiler flags, Rust settings, linker flags, and `wasm-opt` options, consult `references/compilation-flags.md`.

Key decisions:
- **Speed vs size**: `-O3`/`wasm-opt -O3` for speed, `-Oz`/`wasm-opt -Oz` for size
- **Reactor vs command**: `-mexec-model=reactor` for libraries, default for CLI tools
- **Explicit vs all exports**: `-Wl,--export=<fn>` (preferred) vs `-Wl,--export-all`
- **Memory layout**: modern WASI SDK uses `--stack-first` by default

## Troubleshooting

For common build errors and solutions, consult `references/troubleshooting.md`.

Most frequent issues:
- `undefined symbol: signal/mmap` → add `-D_WASI_EMULATED_*` flags
- `memory access out of bounds` → increase `--initial-memory`
- Rust `can't find crate for 'std'` → `rustup target add wasm32-wasip1`
- Docker build fails on macOS → add `--platform linux/amd64`
