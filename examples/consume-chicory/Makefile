PWD := $(CURDIR)
CJSON_WASM := $(PWD)/../c-local/wasm/cjson.wasm

.PHONY: build-deps build test clean

build-deps:
	$(MAKE) -C ../c-local release

build:
	mvn -f $(PWD)/pom.xml compile -q

test: build-deps
	mvn -f $(PWD)/pom.xml test -Dcjson.wasm.path=$(CJSON_WASM)

clean:
	mvn -f $(PWD)/pom.xml clean -q
