PROJECT := regex_wasm
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

.PHONY: clean get-versions get-wasisdk get-binaryen ensure-target build optimize release test all

clean:
	rm -rf wasi-sdk binaryen versions.env
	cargo clean

get-versions:
	@if [ ! -f "$(PWD)/versions.env" ]; then \
		echo "Resolving latest toolchain versions..."; \
		$(SCRIPTS)/resolve-versions.sh > $(PWD)/versions.env; \
	fi

get-wasisdk: get-versions
	@if [ ! -d "$(PWD)/wasi-sdk" ]; then \
		. $(PWD)/versions.env && \
		echo "Downloading WASI SDK $${WASI_SDK_VERSION} for $(OS_NAME)/$(ARCH_NAME)..." && \
		curl -sL "https://github.com/WebAssembly/wasi-sdk/releases/download/$${WASI_SDK_TAG}/wasi-sdk-$${WASI_SDK_VERSION}.0-$(ARCH_NAME)-$(OS_NAME).tar.gz" | tar xz && \
		mv wasi-sdk-$${WASI_SDK_VERSION}.0-$(ARCH_NAME)-$(OS_NAME) $(PWD)/wasi-sdk; \
	fi

get-binaryen: get-versions
	@if [ ! -d "$(PWD)/binaryen" ]; then \
		. $(PWD)/versions.env && \
		echo "Downloading Binaryen $${BINARYEN_VERSION} for $(OS_NAME)/$(ARCH_NAME)..." && \
		curl -sL "https://github.com/WebAssembly/binaryen/releases/download/$${BINARYEN_TAG}/binaryen-$${BINARYEN_TAG}-$(ARCH_NAME)-$(OS_NAME).tar.gz" | tar xz && \
		mv binaryen-$${BINARYEN_TAG} $(PWD)/binaryen; \
	fi

ensure-target:
	@rustup target add wasm32-wasip1 2>/dev/null || true

build: get-wasisdk ensure-target
	WASI_SDK_PATH=$(PWD)/wasi-sdk \
	CC_wasm32_wasip1=$(PWD)/wasi-sdk/bin/clang \
	CFLAGS_wasm32_wasip1="--sysroot=$(PWD)/wasi-sdk/share/wasi-sysroot" \
	cargo build --target wasm32-wasip1 --release

optimize: get-binaryen
	$(PWD)/binaryen/bin/wasm-opt -Oz --strip-debug --enable-bulk-memory \
		target/wasm32-wasip1/release/$(PROJECT).wasm \
		-o target/wasm32-wasip1/release/$(PROJECT)-opt.wasm

release: build optimize
	mkdir -p wasm
	cp target/wasm32-wasip1/release/$(PROJECT)-opt.wasm wasm/$(PROJECT).wasm

test: release
	./test.sh

all: release
