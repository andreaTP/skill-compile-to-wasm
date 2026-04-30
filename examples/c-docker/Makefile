PROJECT := cjson

.PHONY: clean build test

clean:
	rm -rf wasm

build:
	rm -rf wasm
	mkdir -p wasm
	docker build --platform linux/amd64 -t wasm-$(PROJECT) .
	docker create --name dummy-$(PROJECT)-wasm wasm-$(PROJECT)
	docker cp dummy-$(PROJECT)-wasm:/workspace/cjson-opt.wasm wasm/$(PROJECT).wasm
	docker rm -f dummy-$(PROJECT)-wasm

test:
	./test.sh
