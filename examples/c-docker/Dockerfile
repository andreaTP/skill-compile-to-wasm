# Build cJSON wrapper as a wasm reactor module.
#
# The WASI SDK version should be passed as a build arg.
# Get the latest version by running: scripts/resolve-versions.sh

ARG WASI_SDK_VERSION=32
FROM ghcr.io/webassembly/wasi-sdk:wasi-sdk-${WASI_SDK_VERSION}

ENV WASI_SDK_PATH=/opt/wasi-sdk

RUN apt-get update && apt-get install -y curl binaryen

WORKDIR /workspace

# Download cJSON source (single-file C library)
ARG CJSON_VERSION=1.7.18
RUN curl -sL "https://github.com/DaveGamble/cJSON/archive/refs/tags/v${CJSON_VERSION}.tar.gz" \
    | tar xz --strip-components=1 -C /workspace

# Copy the wrapper source
COPY wrapper.c /workspace/wrapper.c

# Compile: wrapper.c + cJSON.c → reactor wasm module
RUN ${WASI_SDK_PATH}/bin/clang \
    --target=wasm32-wasip1 \
    --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot \
    -mexec-model=reactor \
    -O3 \
    -fno-stack-protector \
    -Wl,--export=malloc \
    -Wl,--export=free \
    -I/workspace \
    -o cjson.wasm \
    wrapper.c cJSON.c

# Optimize with wasm-opt
RUN wasm-opt -O3 --strip-debug --low-memory-unused --enable-bulk-memory cjson.wasm -o cjson-opt.wasm
