# Changelog

## v5.0.0-beta.7 — Core Startup & Process Parameter Fix (2026-08-24)

### Bug Fixes
- **Core Startup Exit Code 2 Fix**:
  - `nekobox_core`: Added flexible argument parsing supporting both `nekobox` subcommand prefix and direct flags (`--port`, `--token`, `--debug`).
  - `nekoray_flutter`: Restored `'nekobox'` subcommand in `CoreProcess._start` and ensured `--port` is always explicitly passed (enabling ephemeral port binding with `--port 0`).
  - Fixed Windows/Linux child process startup failure `proxy core is not running:core exited with code 2 during startup`.
  - Added unit test coverage in `go/cmd/nekobox_core/main_test.go` for argument parsing.

## v5.0.0-beta.3 — New Protocols + Codebase Cleanup (2026-08-23)

### New Features
- **4 new proxy protocols**: NaiveProxy, AnyTLS, SSH, WireGuard (sing-box native)
  - Full end-to-end support: Go Bean models → ConfigBuilder → subscription parsing → Flutter UI forms
  - Link parsing: `naive+https://`, `anytls://`, `ssh://`, `wireguard://` / `wg://`
  - Clash YAML parsing for all 4 protocols
  - Link generation (round-trip compatible)
  - 9 new unit tests (4 outbound build + 4 link parse + 1 round-trip)
- **Total 14 proxy protocols** now supported

### Codebase Cleanup
- **Removed 32,139 lines of legacy C++/Qt code** (12 directories: fmt/db/sub/rpc/ui/main/sys/3rdparty/res/cmake/translations/test)
- **Dropped libneko dependency**: Go core is now fully independent (no C++ library dependency)
  - `core_box.go`: native Go dialing (net/http) replaces libneko callbacks
  - `grpc_box.go`: native `urlTest`/`tcpPing` replaces `speedtest`
  - `update.go`/`fulltest.go`: injectable HTTP client factory
  - `go.mod`: removed libneko/sing-quic replace directives
- **Removed legacy build files**: CMakeLists.txt, .clang-format, .clang-tidy, .gitmodules
- **Removed legacy CI**: build-nekoray-cmake.yml, update-pkgbuild.yml, cpp-check job
- **Removed legacy scripts**: Qt SDK/deploy/appimage/debian (9 scripts removed)
- **Rewrote README**: reflects Flutter + Go core architecture, CI badges, 6-platform download table
- **Rewrote ARCHITECTURE.md**: v5.x current architecture with full protocol table

### Current Protocol Support (14 protocols)
| Protocol | Bean Type | sing-box Native |
|---|---|---|
| Shadowsocks | ShadowSocksBean | ✅ |
| VMess | VMessBean | ✅ |
| VLESS | TrojanVLESSBean | ✅ (Reality/vision) |
| Trojan | TrojanVLESSBean | ✅ |
| Hysteria2 | QUICBean | ✅ |
| TUIC | QUICBean | ✅ |
| **NaiveProxy** | NaiveBean | ✅ NEW |
| **AnyTLS** | AnyTLSBean | ✅ NEW |
| **SSH** | SSHBean | ✅ NEW |
| **WireGuard** | WireGuardBean | ✅ NEW |
| SOCKS4/5 | SocksHttpBean | ✅ |
| HTTP(S) | SocksHttpBean | ✅ |
| Custom | CustomBean | ✅ |
| Chain | ChainBean | ✅ |

## v5.0.0-beta.2 — Mobile + Release Fixes (2026-08-23)

### New Features
- **Android build**: gomobile cross-compile (arm64/arm/x86_64)
- **Responsive layout**: desktop NavigationRail / mobile BottomBar
- **Windows packaging fix**: absolute paths + 7z priority
- **Release pipeline**: Android APKs in release assets

## v5.0.0-beta.1 — Phase 2 Flutter Desktop (2026-08-23)

### Breaking Changes
- Complete UI rewrite from C++/Qt to Flutter
- New gRPC-based architecture (Go core + Flutter thin client)
- Configuration format backward-compatible (profiles/groups/routing JSON unchanged)

### New Features
- **Modern Flutter Material 3 UI**: dark-first theme, card-based layout, navigation rail
- **sing-box v1.13.19**: switched from dead MatsuriDayo fork to upstream
- **Schema-driven protocol editor**: 11 protocols (vmess/vless/trojan/ss/hysteria2/tuic/socks/http/wireguard/ssh/custom), add protocols without UI code changes
- **Subscription parsing**: link parsing (ss/vmess/vless/trojan/hy2/tuic), Clash YAML, SIP008
- **ConfigBuilder in Go**: single source of truth for sing-box config generation
- **Routing rules editor**: visual rule list + add/delete
- **DNS presets**: bypass CN / global / custom
- **Traffic charts**: real-time up/down speed via fl_chart (60s rolling)
- **rule_set management**: remote rule_set download + local cache (MRS format)
- **Data migration tool**: import from old C++ nekoray config
- **Internationalization**: zh (default) + en

### CI/CD
- Build Go Core: 4 platforms (windows/linux/darwin amd64+arm64)
- Build Flutter: 3 platforms (linux/windows/macos) with analyze + test
- Generate Proto: auto Go + Dart gRPC stubs
- Lint & Test: go vet + go test + cpp-check + flutter analyze
- Release workflow: one-click tag → build → package → GitHub Release

### Technical Decisions
- **D1**: Switch to upstream sing-box (MatsuriDayo fork dead since 2023)
- **D2**: ConfigBuilder in Go (not Dart) — sing-box is Go, single source of truth
- **D3**: Plain Dart data classes (no freezed) — avoids build_runner codegen conflicts
- **D4**: JSON file storage (no hive) — simpler, backward-compatible

### Migration from v4.x
1. Run `migrator -src <old_config_dir> -dst <new_config_dir>` (CLI)
2. Or use Settings → Import in the Flutter app (task 16)

### Known Limitations
- Connection listing requires Clash API (Phase 3)
- TUN mode requires admin/root (platform scripts)
- Mobile (Android/iOS) planned for Phase 3
