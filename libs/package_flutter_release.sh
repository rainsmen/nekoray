#!/usr/bin/env bash
# Packages a Flutter release bundle with the Go core binary included.
#
# Usage: package_flutter_release.sh <linux|windows|macos>
#
# Every step that could produce an incomplete bundle is fatal. The previous
# version used `|| true` and `if [ -d ]` throughout, so a missing core binary
# produced a well-formed archive containing a GUI that could not proxy anything.

set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <linux|windows|macos>" >&2
  exit 1
fi

die() { echo "::error::$*" >&2; exit 1; }

VERSION=$(tr -d '[:space:]' < nekoray_version.txt 2>/dev/null || true)
[ -n "$VERSION" ] || die "nekoray_version.txt is missing or empty"

echo "==> Packaging nekoray $VERSION for $TARGET"

STAGING="deployment/staging-$TARGET"
rm -rf "$STAGING"
mkdir -p "$STAGING/nekoray"

# 1. Flutter build output
case "$TARGET" in
  linux)   FLUTTER_OUT="nekoray_flutter/build/linux/x64/release/bundle" ;;
  windows) FLUTTER_OUT="nekoray_flutter/build/windows/x64/runner/Release" ;;
  macos)   FLUTTER_OUT="nekoray_flutter/build/macos/Build/Products/Release" ;;
  *)       die "unknown target: $TARGET" ;;
esac

[ -d "$FLUTTER_OUT" ] || die "Flutter build output not found at $FLUTTER_OUT"

if [ "$TARGET" = "macos" ]; then
  [ -d "$FLUTTER_OUT/nekoray.app" ] || die "nekoray.app not found in $FLUTTER_OUT"
  cp -R "$FLUTTER_OUT/nekoray.app" "$STAGING/"
else
  cp -r "$FLUTTER_OUT/." "$STAGING/nekoray/"
fi

# 2. Go core binary — mandatory
case "$TARGET" in
  linux)   CORE_DIR="deployment/linux64";     CORE_BIN="nekobox_core" ;;
  windows) CORE_DIR="deployment/windows64";   CORE_BIN="nekobox_core.exe" ;;
  macos)   CORE_DIR="deployment/macos-amd64"; CORE_BIN="nekobox_core" ;;
esac

[ -d "$CORE_DIR" ] || die "core output directory $CORE_DIR is missing — did build_go.sh run?"
[ -f "$CORE_DIR/$CORE_BIN" ] || die "core binary $CORE_DIR/$CORE_BIN is missing"

if [ "$TARGET" = "macos" ]; then
  CORE_DEST="$STAGING/nekoray.app/Contents/MacOS"
  mkdir -p "$CORE_DEST"
else
  CORE_DEST="$STAGING/nekoray"
fi

cp "$CORE_DIR/$CORE_BIN" "$CORE_DEST/"
chmod +x "$CORE_DEST/$CORE_BIN" 2>/dev/null || true

# Optional helpers: absent is fine, but a failed copy is not.
for helper in updater launcher migrator updater.exe migrator.exe; do
  if [ -f "$CORE_DIR/$helper" ]; then
    cp "$CORE_DIR/$helper" "$CORE_DEST/"
  fi
done

# 3. Archive
mkdir -p deployment
case "$TARGET" in
  linux)
    ARCHIVE="deployment/nekoray-$VERSION-linux64.tar.gz"
    tar -czf "$ARCHIVE" -C "$STAGING" nekoray
    ;;
  windows)
    ARCHIVE="$PWD/deployment/nekoray-$VERSION-windows64.zip"
    if command -v 7z >/dev/null 2>&1; then
      7z a -tzip "$ARCHIVE" "$STAGING/nekoray" -mx=5 >/dev/null
    else
      powershell.exe -NoProfile -Command \
        "Compress-Archive -Path '$(cygpath -w "$STAGING/nekoray" 2>/dev/null || echo "$STAGING/nekoray")' -DestinationPath '$(cygpath -w "$ARCHIVE" 2>/dev/null || echo "$ARCHIVE")' -Force"
    fi
    ;;
  macos)
    ARCHIVE="deployment/nekoray-$VERSION-macos.zip"
    (cd "$STAGING" && zip -qr "../$(basename "$ARCHIVE")" nekoray.app)
    ;;
esac

[ -f "$ARCHIVE" ] || die "archive $ARCHIVE was not created"
echo "==> Created $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

rm -rf "$STAGING"
echo "==> Done"
