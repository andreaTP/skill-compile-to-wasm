#!/usr/bin/env bash
set -euo pipefail

# Installs wasm-tools and optionally wasmtime into a local bin/ directory.
#
# Usage:
#   ./install-wasm-tools.sh [--wasmtime]
#
# Installs to ./bin/ relative to CWD. Add to PATH:
#   export PATH="$PWD/bin:$PATH"

INSTALL_WASMTIME=false
for arg in "$@"; do
    case "$arg" in
        --wasmtime) INSTALL_WASMTIME=true ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
    Linux)  OS_SUFFIX="linux" ;;
    Darwin) OS_SUFFIX="macos" ;;
    *)      echo "ERROR: Unsupported OS: $OS" >&2; exit 1 ;;
esac

case "$ARCH" in
    x86_64)         ARCH_SUFFIX="x86_64" ;;
    aarch64|arm64)  ARCH_SUFFIX="aarch64" ;;
    *)              echo "ERROR: Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

AUTH_ARGS=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_ARGS=(-H "Authorization: token $GITHUB_TOKEN")
fi

mkdir -p bin

# Install wasm-tools
if ! command -v wasm-tools &>/dev/null; then
    echo "Installing wasm-tools..."
    VERSION=$(curl -sf "${AUTH_ARGS[@]}" https://api.github.com/repos/bytecodealliance/wasm-tools/releases/latest | grep '"tag_name"' | sed 's/.*"v//;s/".*//')
    curl -sL "https://github.com/bytecodealliance/wasm-tools/releases/latest/download/wasm-tools-${VERSION}-${ARCH_SUFFIX}-${OS_SUFFIX}.tar.gz" | tar xz
    mv wasm-tools-*/wasm-tools bin/
    rm -rf wasm-tools-*
    echo "Installed wasm-tools ${VERSION}"
else
    echo "wasm-tools already available: $(command -v wasm-tools)"
fi

# Install wasmtime
if [ "$INSTALL_WASMTIME" = true ] && ! command -v wasmtime &>/dev/null; then
    echo "Installing wasmtime..."
    VERSION=$(curl -sf "${AUTH_ARGS[@]}" https://api.github.com/repos/bytecodealliance/wasmtime/releases/latest | grep '"tag_name"' | sed 's/.*"v//;s/".*//')
    WASMTIME_ARCH="$ARCH_SUFFIX"
    if [ "$OS_SUFFIX" = "macos" ] && [ "$WASMTIME_ARCH" = "aarch64" ]; then
        WASMTIME_ARCH="aarch64"
    fi
    curl -sL "https://github.com/bytecodealliance/wasmtime/releases/download/v${VERSION}/wasmtime-v${VERSION}-${WASMTIME_ARCH}-${OS_SUFFIX}.tar.xz" | tar xJ
    mv wasmtime-*/wasmtime bin/
    rm -rf wasmtime-*
    echo "Installed wasmtime ${VERSION}"
else
    if [ "$INSTALL_WASMTIME" = true ]; then
        echo "wasmtime already available: $(command -v wasmtime)"
    fi
fi

echo "Tools installed to: $PWD/bin"
