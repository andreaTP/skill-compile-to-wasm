#!/usr/bin/env bash
set -euo pipefail

# Resolves latest versions of WebAssembly toolchain components from GitHub releases.
# Outputs shell-sourceable KEY=VALUE pairs. Also detects OS and architecture.
#
# Usage:
#   eval "$(./resolve-versions.sh)"
#   echo "WASI SDK: $WASI_SDK_VERSION"
#
# Set GITHUB_TOKEN to avoid API rate limiting:
#   export GITHUB_TOKEN=ghp_...

AUTH_HEADER=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
fi

gh_latest_tag() {
    local repo="$1"
    local url="https://api.github.com/repos/${repo}/releases/latest"
    local tag

    if [ -n "$AUTH_HEADER" ]; then
        tag=$(curl -sf -H "$AUTH_HEADER" "$url" | grep '"tag_name"' | head -1 | sed 's/.*: *"//;s/".*//')
    else
        tag=$(curl -sf "$url" | grep '"tag_name"' | head -1 | sed 's/.*: *"//;s/".*//')
    fi

    if [ -z "$tag" ]; then
        echo "ERROR: Failed to fetch latest release for $repo" >&2
        return 1
    fi
    echo "$tag"
}

# Detect OS
OS=$(uname -s)
case "$OS" in
    Linux)  OS_NAME="linux" ;;
    Darwin) OS_NAME="macos" ;;
    *)      echo "ERROR: Unsupported OS: $OS" >&2; exit 1 ;;
esac

# Detect architecture — most tools now use "arm64", Wizer still uses "aarch64"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)         ARCH_NAME="x86_64" ;;
    aarch64|arm64)  ARCH_NAME="arm64" ;;
    *)              echo "ERROR: Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Resolve WASI SDK (tag format: "wasi-sdk-25")
WASI_SDK_TAG=$(gh_latest_tag "WebAssembly/wasi-sdk")
WASI_SDK_VERSION="${WASI_SDK_TAG#wasi-sdk-}"
WASI_SDK_URL="https://github.com/WebAssembly/wasi-sdk/releases/download/${WASI_SDK_TAG}/wasi-sdk-${WASI_SDK_VERSION}.0-${ARCH_NAME}-${OS_NAME}.tar.gz"

# Resolve Binaryen (tag format: "version_125")
BINARYEN_TAG=$(gh_latest_tag "WebAssembly/binaryen")
BINARYEN_VERSION="${BINARYEN_TAG#version_}"
BINARYEN_URL="https://github.com/WebAssembly/binaryen/releases/download/${BINARYEN_TAG}/binaryen-${BINARYEN_TAG}-${ARCH_NAME}-${OS_NAME}.tar.gz"

# Resolve Wizer (tag format: "v10.0.0") — still uses "aarch64" in asset names
WIZER_TAG=$(gh_latest_tag "bytecodealliance/wizer")
WIZER_VERSION="${WIZER_TAG#v}"
WIZER_ARCH="${ARCH_NAME}"
if [ "$ARCH_NAME" = "arm64" ]; then
    WIZER_ARCH="aarch64"
fi
WIZER_URL="https://github.com/bytecodealliance/wizer/releases/download/${WIZER_TAG}/wizer-${WIZER_TAG}-${WIZER_ARCH}-${OS_NAME}.tar.xz"

# Output shell-sourceable variables
cat <<EOF
OS_NAME=${OS_NAME}
ARCH_NAME=${ARCH_NAME}
WASI_SDK_VERSION=${WASI_SDK_VERSION}
WASI_SDK_TAG=${WASI_SDK_TAG}
WASI_SDK_URL=${WASI_SDK_URL}
BINARYEN_VERSION=${BINARYEN_VERSION}
BINARYEN_TAG=${BINARYEN_TAG}
BINARYEN_URL=${BINARYEN_URL}
WIZER_VERSION=${WIZER_VERSION}
WIZER_TAG=${WIZER_TAG}
WIZER_URL=${WIZER_URL}
EOF
