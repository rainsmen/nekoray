#!/bin/bash
set -euo pipefail
# nekobox_core build script (phase 1: sing-box v1.13.19 upgrade)

source libs/env_deploy.sh
[ "$GOOS" == "windows" ] && [ "$GOARCH" == "amd64" ] && DEST=$DEPLOYMENT/windows64 || true
[ "$GOOS" == "windows" ] && [ "$GOARCH" == "arm64" ] && DEST=$DEPLOYMENT/windows-arm64 || true
[ "$GOOS" == "linux" ] && [ "$GOARCH" == "amd64" ] && DEST=$DEPLOYMENT/linux64 || true
[ "$GOOS" == "linux" ] && [ "$GOARCH" == "arm64" ] && DEST=$DEPLOYMENT/linux-arm64 || true
[ "$GOOS" == "darwin" ] && [ "$GOARCH" == "amd64" ] && DEST=$DEPLOYMENT/macos-amd64 || true
[ "$GOOS" == "darwin" ] && [ "$GOARCH" == "arm64" ] && DEST=$DEPLOYMENT/macos-arm64 || true
if [ -z "${DEST:-}" ]; then
  echo "Please set GOOS GOARCH"
  exit 1
fi
rm -rf "$DEST"
mkdir -p "$DEST"

export CGO_ENABLED=0

#### Go: updater ####
pushd go/cmd/updater
go build -o "$DEST" -trimpath -ldflags "-w -s"
if [ "$GOOS" == "linux" ]; then mv "$DEST/updater" "$DEST/launcher"; fi
popd

#### Go: nekobox_core ####
pushd go/cmd/nekobox_core
go mod tidy
go build -v -o "$DEST" -trimpath -ldflags "-w -s" -tags "with_clash_api,with_gvisor,with_quic,with_wireguard,with_utls"
popd

#### Go: migrator (phase 1 data migration tool) ####
pushd go/cmd/migrator
go build -v -o "$DEST" -trimpath -ldflags "-w -s"
popd
