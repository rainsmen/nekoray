#!/usr/bin/env bash
# Verifies the version single-source-of-truth: nekoray_version.txt must match
# the Flutter pubspec and the Go core constant. These three have drifted more
# than once (beta.11/beta.13), shipping a core that reports a different
# version than the package it rides in.
set -euo pipefail

die() { echo "::error::$*" >&2; exit 1; }

VERSION=$(tr -d '[:space:]' < nekoray_version.txt 2>/dev/null || true)
[ -n "$VERSION" ] || die "nekoray_version.txt is missing or empty"

PUBSPEC=$(grep -E '^version:' nekoray_flutter/pubspec.yaml | awk '{print $2}' || true)
[ -n "$PUBSPEC" ] || die "no version: in nekoray_flutter/pubspec.yaml"
[ "$VERSION" = "$PUBSPEC" ] || die "version drift: nekoray_version.txt=$VERSION pubspec=$PUBSPEC"

CORE=$(grep -E 'CoreVersion = ' go/cmd/nekobox_core/core_box.go | sed 's/.*"\(.*\)".*/\1/' || true)
[ -n "$CORE" ] || die "CoreVersion not found in go/cmd/nekobox_core/core_box.go"
[ "$VERSION" = "$CORE" ] || die "version drift: nekoray_version.txt=$VERSION CoreVersion=$CORE"

DARTVER=$(grep -E "^const appVersion = " nekoray_flutter/lib/core/version.dart | sed "s/.*'\(.*\)'.*/\1/" || true)
[ -n "$DARTVER" ] || die "appVersion not found in nekoray_flutter/lib/core/version.dart"
[ "$VERSION" = "$DARTVER" ] || die "version drift: nekoray_version.txt=$VERSION appVersion=$DARTVER"

echo "version OK: $VERSION (version.txt = pubspec = CoreVersion = appVersion)"
