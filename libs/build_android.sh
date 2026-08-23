#!/usr/bin/env bash
# Builds the Go core for Android as a shared library (.so).
#
# Usage: build_android.sh
#
# Produces: deployment/android/{arm64-v8a,armeabi-v7a,x86_64}/libnekobox.so
#
# Requires: ANDROID_NDK_HOME or ANDROID_NDK_ROOT set, Go 1.22+

set -euo pipefail

source libs/env_deploy.sh
DEST=$DEPLOYMENT/android
rm -rf "$DEST"
mkdir -p "$DEST"

export CGO_ENABLED=1

# --- Locate NDK ---
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
  # Try common locations
  for cand in \
    "$ANDROID_HOME/ndk"/* \
    "$ANDROID_SDK_ROOT/ndk"/* \
    /usr/local/lib/android/sdk/ndk/*; do
    if [ -d "$cand" ]; then
      NDK="$cand"
      break
    fi
  done
fi
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
  echo "ERROR: Android NDK not found. Set ANDROID_NDK_HOME."
  exit 1
fi
echo "==> Using NDK: $NDK"

# Find the prebuilt dir (handle version + host variations)
PREBUILT="$NDK/toolchains/llvm/prebuilt"
HOST_DIR=""
for h in linux-x86_64 darwin-x86_64 windows-x86_64; do
  if [ -d "$PREBUILT/$h" ]; then
    HOST_DIR="$h"
    break
  fi
done
if [ -z "$HOST_DIR" ]; then
  echo "ERROR: NDK prebuilt host dir not found in $PREBUILT"
  exit 1
fi
TOOLCHAIN="$PREBUILT/$HOST_DIR/bin"
echo "==> Toolchain: $TOOLCHAIN"

pushd go/cmd/nekobox_core
go mod tidy

# ABI → GOARCH → NDK arch triple
build_abi() {
  local ABI=$1 GOARCH=$2 NDK_ARCH=$3 API=${4:-24}
  echo "==> Building Android $ABI ($NDK_ARCH, API $API)"

  export GOOS=android
  export GOARCH=$GOARCH
  [ "$GOARCH" = "arm" ] && export GOARM=7 || unset GOARM

  local TRIPLE="${NDK_ARCH}-linux-android"
  [ "$NDK_ARCH" = "armv7a" ] && TRIPLE="armv7a-linux-androideabi"

  export CC="$TOOLCHAIN/${TRIPLE}${API}-clang"
  export CXX="$TOOLCHAIN/${TRIPLE}${API}-clang++"

  if [ ! -f "$CC" ]; then
    echo "WARNING: $CC not found, trying API 21"
    export CC="$TOOLCHAIN/${TRIPLE}21-clang"
    export CXX="$TOOLCHAIN/${TRIPLE}21-clang++"
  fi

  mkdir -p "$DEST/$ABI"
  go build -buildmode=c-shared \
    -o "$DEST/$ABI/libnekobox.so" \
    -trimpath -ldflags "-w -s" \
    -tags "with_clash_api,with_gvisor,with_quic,with_wireguard,with_utls" \
    .

  # Also copy the generated header for native bindings
  [ -f go/cmd/nekobox_core/libnekobox.h ] && \
    cp go/cmd/nekobox_core/libnekobox.h "$DEST/$ABI/" 2>/dev/null || \
    cp libnekobox.h "$DEST/$ABI/" 2>/dev/null || true

  unset CC CXX
}

build_abi arm64  arm64  aarch64
build_abi arm    arm    armv7a  24
build_abi x86_64 amd64  x86_64

popd
echo "==> Android core build complete"
ls -la "$DEST"/*/
