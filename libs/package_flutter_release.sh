#!/usr/bin/env bash
# Packages a Flutter release bundle with the Go core binary included.
#
# Usage: package_flutter_release.sh <target>
#   target: linux | windows | macos
#
# Produces: deployment/nekoray-<target>-<version>.zip (or .tar.gz)

set -e

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <linux|windows|macos>"
  exit 1
fi

VERSION=$(cat nekoray_version.txt 2>/dev/null | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
  VERSION="5.0.0-beta1"
fi

echo "==> Packaging nekoray $VERSION for $TARGET"

STAGING="deployment/staging-$TARGET"
rm -rf "$STAGING"
mkdir -p "$STAGING/nekoray"

# 1. Copy Flutter build output
case "$TARGET" in
  linux)
    FLUTTER_OUT="nekoray_flutter/build/linux/x64/release/bundle"
    if [ -d "$FLUTTER_OUT" ]; then
      cp -r "$FLUTTER_OUT/." "$STAGING/nekoray/"
    fi
    ;;
  windows)
    FLUTTER_OUT="nekoray_flutter/build/windows/x64/runner/Release"
    if [ -d "$FLUTTER_OUT" ]; then
      cp -r "$FLUTTER_OUT/." "$STAGING/nekoray/"
    fi
    ;;
  macos)
    FLUTTER_OUT="nekoray_flutter/build/macos/Build/Products/Release"
    if [ -d "$FLUTTER_OUT" ]; then
      cp -r "$FLUTTER_OUT/nekoray.app" "$STAGING/" 2>/dev/null || true
    fi
    ;;
esac

# 2. Copy Go core binary
CORE_DIR=""
case "$TARGET" in
  linux)   CORE_DIR="deployment/linux64" ;;
  windows) CORE_DIR="deployment/windows64" ;;
  macos)   CORE_DIR="deployment/macos-amd64" ;;
esac
if [ -d "$CORE_DIR" ]; then
  cp "$CORE_DIR/nekobox_core" "$STAGING/nekoray/" 2>/dev/null || \
  cp "$CORE_DIR/nekobox_core.exe" "$STAGING/nekoray/" 2>/dev/null || true
  cp "$CORE_DIR/updater" "$STAGING/nekoray/" 2>/dev/null || true
  cp "$CORE_DIR/migrator" "$STAGING/nekoray/" 2>/dev/null || true
fi

# 3. Create archive
mkdir -p deployment
case "$TARGET" in
  linux)
    ARCHIVE="deployment/nekoray-$VERSION-linux64.tar.gz"
    tar -czf "$ARCHIVE" -C "$STAGING" nekoray
    echo "==> Created $ARCHIVE"
    ;;
  windows)
    ARCHIVE="deployment/nekoray-$VERSION-windows64.zip"
    (cd "$STAGING" && powershell Compress-Archive -Path nekoray -DestinationPath "../../$(basename $ARCHIVE)")
    echo "==> Created $ARCHIVE"
    ;;
  macos)
    ARCHIVE="deployment/nekoray-$VERSION-macos.zip"
    (cd "$STAGING" && zip -r "../$(basename $ARCHIVE)" nekoray.app)
    echo "==> Created $ARCHIVE"
    ;;
esac

# Cleanup staging
rm -rf "$STAGING"
echo "==> Done"
