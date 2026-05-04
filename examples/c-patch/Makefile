PROJECT := wordcount
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

CLANG = $(PWD)/wasi-sdk/bin/clang
SYSROOT = $(PWD)/wasi-sdk/share/wasi-sysroot
WASM_OPT = $(PWD)/binaryen/bin/wasm-opt

COMMON_FLAGS = \
	--sysroot=$(SYSROOT) \
	--target=wasm32-wasip1 \
	-mexec-model=reactor \
	-O3 \
	-fno-stack-protector \
	-Wl,--export=malloc \
	-Wl,--export=free

.PHONY: clean get-versions get-wasisdk get-binaryen approach1 approach2 release test all

clean:
	rm -rf target wasi-sdk binaryen versions.env wasm

get-versions:
	@if [ ! -f "$(PWD)/versions.env" ]; then \
		echo "Resolving latest toolchain versions..."; \
		$(SCRIPTS)/resolve-versions.sh > $(PWD)/versions.env; \
	fi

get-wasisdk: get-versions
	@if [ ! -d "$(PWD)/wasi-sdk" ]; then \
		. $(PWD)/versions.env && \
		echo "Downloading WASI SDK $${WASI_SDK_VERSION}..." && \
		curl -sL "$${WASI_SDK_URL}" | tar xz && \
		mv wasi-sdk-$${WASI_SDK_VERSION}.0-* $(PWD)/wasi-sdk; \
	fi

get-binaryen: get-versions
	@if [ ! -d "$(PWD)/binaryen" ]; then \
		. $(PWD)/versions.env && \
		echo "Downloading Binaryen $${BINARYEN_VERSION}..." && \
		curl -sL "$${BINARYEN_URL}" | tar xz && \
		mv binaryen-$${BINARYEN_TAG} $(PWD)/binaryen; \
	fi

# ─── Approach 1: Disable the feature with -D flag ───────────────────
# Simplest fix. The upstream header checks UPSTREAM_NO_SIGNALS to skip
# signal-dependent code. Many real libraries have similar guards.
approach1: get-wasisdk
	mkdir -p target
	$(CLANG) $(COMMON_FLAGS) \
		-DUPSTREAM_NO_SIGNALS \
		-o target/$(PROJECT)-approach1.wasm \
		wrapper.c

# ─── Approach 2: Use WASI emulation library ─────────────────────────
# When the library has no disable flag, link against wasi-emulated-signal.
# signal() becomes a stub — the linker is satisfied, code compiles,
# but signal handling is a no-op at runtime.
approach2: get-wasisdk
	mkdir -p target
	$(CLANG) $(COMMON_FLAGS) \
		-D_WASI_EMULATED_SIGNAL \
		-lwasi-emulated-signal \
		-o target/$(PROJECT)-approach2.wasm \
		wrapper.c

optimize: get-binaryen
	$(WASM_OPT) -O3 --strip-debug --enable-bulk-memory \
		target/$(PROJECT)-approach1.wasm -o target/$(PROJECT)-opt.wasm

release: approach1 approach2 optimize
	mkdir -p wasm
	cp target/$(PROJECT)-opt.wasm wasm/$(PROJECT).wasm

test: release
	./test.sh

all: release
