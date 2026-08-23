#!/usr/bin/env bash
# Builds the Go core for Android as a shared library (.so) using gomobile.
#
# Usage: build_android.sh
#
# Produces: deployment/android/{arm64-v8a,armeabi-v7a,x86_64}/libnekobox.so

set -e

source libs/env_deploy.sh
DEST=$DEPLOYMENT/android
rm -rf "$DEST"
mkdir -p "$DEST"

# Android NDK + gomobile required
export CGO_ENABLED=1

# Ensure gomobile is installed
go install golang.org/x/mobile/cmd/gomobile@latest || true
go install golang.org/x/mobile/cmd/gobind@latest || true

pushd go/cmd/nekobox_core

# Tidy and ensure dependencies
go mod tidy

# Build for each Android ABI
for ABI in arm64 arm x86_64; do
  case $ABI in
    arm64)  export GOARCH=arm64; NDK_ARCH=aarch64; ;;
    arm)    export GOARCH=arm;   NDK_ARCH=arm;      ;;
    x86_64) export GOARCH=amd64; NDK_ARCH=x86_64;   ;;
  esac
  export GOOS=android
  export GOARM=7

  echo "==> Building Android $ABI ($NDK_ARCH)"

  # Set NDK toolchain
  if [ -n "$ANDROID_NDK_HOME" ]; then
    export CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/$NDK_ARCH-linux-android24-clang"
    export CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/$NDK_ARCH-linux-android24-clang++"
  fi

  # Build as shared library
  go build -buildmode=c-shared \
    -o "$DEST/$ABI/libnekobox.so" \
    -trimpath -ldflags "-w -s" \
    -tags "with_clash_api,with_gvisor,with_quic,with_wireguard,with_utls" \
    .

  unset CC CXX
done

popd
echo "==> Android core build complete"
ls -la "$DEST"/*/
