# Changelog

## v5.0.0-beta.11 — Bundled libcronet for NaiveProxy & Live Startup Logs Capture (2026-08-24)

### Critical Bug Fixes & Diagnostics Enhancements
- **Bundled `libcronet` Dynamic Libraries for NaiveProxy**:
  - Resolved `cronet: library not found. Place libcronet.dll in the executable directory or PATH` error when starting Naive nodes.
  - Automatically bundled `libcronet.dll` (Windows), `libcronet.so` (Linux), and `libcronet.dylib` (macOS) in the core build and distribution packages alongside `nekobox_core` and `nekoray`.
- **Live Startup & Lifecycle Logs Capture in Logs Page (启动失败日志完整捕获)**:
  - Added real-time error logging to `coreLogProvider` for core connection failures, bootstrap issues, proxy start errors, and proxy stop events.
  - Core process logs all `Start` failures to stdout so all exceptions are immediately visible with high-contrast badge colors on the Logs page.

## v5.0.0-beta.10 — Rule-Sets Upgrade, Modern Theme System, Clean Release Packaging & Windows Process Cleanup (2026-08-24)

### New Features & Enhancements
- **sing-box 1.13 Rule-Sets Architecture Migration (分流与规则集彻底升级)**:
  - Resolved `geosite database is deprecated in sing-box 1.8.0 and removed in sing-box 1.12.0` error.
  - Automatically converted all `geosite:xxx` and `geoip:xxx` references to modern binary `rule_set: ["geosite-xxx", "geoip-xxx"]`.
  - Automatically generated `route.rule_set` download entries pointing to official binary `.srs` repositories.
  - Native private IP detection with `ip_is_private: true`.
- **Modern UI Theme System & Windows Typography Optimization (现代化 UI 与主题模式)**:
  - Redesigned Material 3 theme palette with rich Slate dark mode (`#0F172A` / `#1E293B`) and crisp porcelain light mode.
  - Added Theme Mode selector: **Follow System (跟随系统)**, **Dark Mode (深色模式)**, and **Light Mode (浅色模式)** in Settings.
  - Optimized Windows font rendering and fallback cascade (`Microsoft YaHei UI`, `Segoe UI Variable Display`, `Segoe UI`, `PingFang SC`, `Noto Sans SC`).
- **Release Packaging Clean Folder Structure (发布压缩包解压层级精简)**:
  - Fixed Windows/Linux/macOS release archives so that extracting directly yields a single `nekoray/` root folder with no intermediate build staging path.
- **Process & Directory Lock Cleanup on Windows (进程退出与文件夹占用彻底解决)**:
  - Force-terminate core process tree on Windows with `taskkill /F /T /PID` on shutdown.
  - Cleanly destroy tray manager and window listeners and invoke `exit(0)` on quit to prevent folder lock errors.

## v5.0.0-beta.9 — sing-box 1.13 Migration: Legacy Inbounds & DNS Outbound Clean (2026-08-24)

### Critical Bug Fixes & sing-box 1.13 Migration
- **Migrated Legacy Inbound Fields to Route Rule Actions**:
  - Resolved `legacy inbound fields are deprecated in sing-box 1.11.0 and removed in sing-box 1.13.0` error upon node startup.
  - Stripped deprecated `sniff`, `sniff_override_destination`, and `domain_strategy` fields from `mixed-in` and `tun-in` inbound objects.
  - Migrated sniffing to `route.rules` action rule (`{"action": "sniff"}`).
  - Bound `domain_strategy` to `route.default_domain_resolver` (`{"server": "dns-direct", "strategy": "..."}`).
- **Migrated DNS Outbound to Hijack-DNS Action**:
  - Removed deprecated `{"type": "dns", "tag": "dns-out"}` outbound object.
  - Migrated DNS hijacking rule to `{"protocol": "dns", "action": "hijack-dns"}`.
- **Production Integration Testing**:
  - Verified full live node startup (inbound binding + outbound startup + route execution) across all 14 protocols.

## v5.0.0-beta.8 — Protocol Context Registry Fix, Logs Page, Speed Test & Rule-Sets (2026-08-24)

### New Features & Enhancements
- **Live Logs Viewer Page (日志界面)**:
  - Added dedicated Logs page in Flutter UI (`LogsPage`) with NavigationRail / NavigationBar integration.
  - Log level filter chips (`All`, `Info`, `Warn`, `Error`, `Debug`), search keyword filter, auto-scroll to bottom, one-click copy, and log clear.
  - Monospace font and color-coded level badges for clear debugging.
- **Website Connectivity & Speed Test Dashboard (网站测速与连通性)**:
  - Implemented armwall-inspired website speed test matrix on the Connections page.
  - Tested across Global / Proxy sites (Google, YouTube, GitHub, Cloudflare, ChatGPT, Telegram, Wikipedia) and Domestic / Direct sites (Baidu, Bilibili, Taobao, QQ/Tencent).
  - One-click batch testing, individual site retests, latency measurement (ms), and HTTP status badge feedback.
- **Enhanced Routing & Rule-Sets Management (分流与规则集)**:
  - Added tabbed layout for Routing: Routing Rules and Rule-Sets (`geosite-cn`, `geoip-cn`, `geosite-geolocation-!cn`, `geosite-category-ads-all`, `geosite-google`, `geosite-github`, `geosite-openai`, `geoip-private`).
  - Remote rule-set auto and manual one-click update support with download status and timestamp tracking.
- **Enhanced DNS Page**:
  - Added quick server presets for Remote DNS (Google DoH, Cloudflare DoH, Quad9 DoH, OpenDNS) and Direct DNS (AliDNS DoH, DNSPod DoH, 114DNS, Local).
  - DNS domain strategy selection (`ipv4_only`, `prefer_ipv4`, `prefer_ipv6`, `ipv6_only`).

### Critical Bug Fixes & Risk Mitigations
- **Resolved sing-box Registry Startup Error (`missing DNS transport options registry in context`)**:
  - Injected `include.Context(context.Background())` into `createInstance` in `core_box.go`, ensuring all DNS transports, inbounds, outbounds, endpoints, and services are registered in the sing-box context for all 14 protocols.
- **Full Protocol Safety & Compatibility Fixes**:
  - `build_go.sh` & `build_android.sh`: Added `with_naive_outbound` and `with_purego` build tags to compile sing-box NaiveProxy driver and pure-Go fallback cleanly.
  - Standardized Hysteria2 ALPN: `coreTls["alpn"] = []string{"h3"}`.
  - Upgraded WireGuard to sing-box 1.13 Endpoint model with default `allowed_ips: ["0.0.0.0/0", "::/0"]`.
  - Fixed `getServerAddress` domain extraction for Naive, AnyTLS, SSH, WireGuard, Socks, and Shadowsocks beans preventing empty DNS domain rules.
  - Added default domain resolver `default_domain_resolver: "dns-direct"` to sing-box route object.
- **Comprehensive Regression Test Suite**:
  - Added `go/cmd/nekobox_core/protocols_test.go` verifying end-to-end configuration creation and sing-box instantiation across all 14 proxy protocols.

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
