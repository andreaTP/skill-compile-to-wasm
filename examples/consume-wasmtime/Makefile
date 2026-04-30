PWD := $(CURDIR)
CJSON_WASM := $(PWD)/../c-local/wasm/cjson.wasm
CSV2JSON_WASM := $(PWD)/../rust-cli/wasm/csv2json.wasm

.PHONY: build-deps build test clean

# Build the wasm modules this example consumes
build-deps:
	$(MAKE) -C ../c-local release
	$(MAKE) -C ../rust-cli release

build:
	cargo build --release

test: build-deps build
	./test.sh

clean:
	cargo clean
