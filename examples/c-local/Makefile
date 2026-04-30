PROJECT := cjson
CJSON_VERSION := 1.7.18
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

.PHONY: clean get-versions get-wasisdk get-binaryen get-cjson build optimize test all

clean:
	rm -rf target wasi-sdk binaryen cjson-src versions.env

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

get-cjson:
	@if [ ! -d "$(PWD)/cjson-src" ]; then \
		echo "Downloading cJSON $(CJSON_VERSION)..." && \
		curl -sL "https://github.com/DaveGamble/cJSON/archive/refs/tags/v$(CJSON_VERSION).tar.gz" | tar xz && \
		mv cJSON-$(CJSON_VERSION) $(PWD)/cjson-src; \
	fi

build: get-wasisdk get-cjson
	mkdir -p target
	$(PWD)/wasi-sdk/bin/clang \
		--sysroot=$(PWD)/wasi-sdk/share/wasi-sysroot \
		--target=wasm32-wasip1 \
		-mexec-model=reactor \
		-O3 \
		-fno-stack-protector \
		-Wl,--export=malloc \
		-Wl,--export=free \
		-I$(PWD)/cjson-src \
		-o target/$(PROJECT).wasm \
		wrapper.c cjson-src/cJSON.c

optimize: get-binaryen
	$(PWD)/binaryen/bin/wasm-opt -O3 --strip-debug --low-memory-unused --enable-bulk-memory \
		target/$(PROJECT).wasm -o target/$(PROJECT)-opt.wasm

release: build optimize
	mkdir -p wasm
	cp target/$(PROJECT)-opt.wasm wasm/$(PROJECT).wasm

test: release
	./test.sh

all: release
