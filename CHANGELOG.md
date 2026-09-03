# Changelog

## v5.0.0-beta.15 — TUN 启动修复与 CI 分析门禁清零 (2026-09-04)

### Critical Bug Fixes
- **TUN 模式无法启动**：`build.go` 生成的 TUN inbound 仍使用 sing-box 1.12 已删除的
  `inet4_address`/`inet6_address`（及已废弃的 `endpoint_independent_nat`），core 启动即
  `initialize inbound[1]: legacy tun address fields ...` 失败。现改用合并后的 `address`
  列表（`172.19.0.1/28`，IPv6 可选追加），并经真实 `box.New` 初始化验证（无提权需求）。
  新增两级回归测试：`core/config` 配置断言 + `nekobox_core` 实例构造测试。

### CI
- `flutter analyze --fatal-warnings` 13 个 info 清零（含历史遗留 12 个），Lint & Test 恢复绿色。
- `DropdownButtonFormField(initialValue:)` 改为 `value:`（前者不存在于该组件 API）。
- 迁移页跨 await 的 `BuildContext` 持有改为即用即取 + `mounted` 守卫。

## v5.0.0-beta.14 — 退出残留修复、TUN 收尾、节点批量管理与文档重整 (2026-09-04)

### Bug Fixes
- **退出后文件夹被占用**：Windows 下 `taskkill` 后等待 core 进程被系统回收后再退出；`<appDir>/core.pid` 记录 core 进程号，下次启动自动清理上次崩溃残留的 core 孤儿进程；退出全链路加超时保护，托盘提示明确"关闭窗口≠退出"。
- **节点编辑丢数据**：编辑框 `_formKey` 从未挂载，`_mergeForm()` 恒为 no-op，新建/编辑节点后 bean 为空。现已挂回，编辑正常保存。
- **TUN 参数缺失**：启动/MTU 等 TUN 键缺省导致 Go 侧 MTU=0，TUN inbound 创建失败。Dart 侧补全全部 TUN 键，Go 侧 MTU 非法值兜底 1500。

### New Features
- **节点页**：分组筛选、按延迟排序、单节点/批量延迟测试（core 侧 UrlTest，结果落盘）、多选批量操作（测速/移动分组/删除）、订阅手动全部刷新、分享链接复制、节点重命名。
- **TUN 高级选项**：MTU、协议栈（gvisor/system/mixed）、严格路由、IPv6、FakeIP 可配置；提权状态检测横幅；TUN 启动失败时输出可操作提示（含原始 core 错误）。
- **诊断**：core 日志落盘（`<appDir>/logs/`，2 MiB 轮转），日志页一键导出诊断包（脱敏，不含节点密码）。
- **工程**：`libs/check_version.sh` 强制三处版本号一致并接入 CI。

### Docs
- `docs/archive/` 冻结迁移规划与 2026-08-23 评审报告；`实施进度.md` 改写为现状矩阵；新增 `TROUBLESHOOTING.md`、`SECURITY.md`；`DECISIONS.md` 补 D3～D8。

## v5.0.0-beta.13 — Executable Launcher Fix, macOS Updater, Hot Switch Fix, Real Rule-Set Sync & CI Hardening (2026-09-03)

### Critical Bug Fixes & System Stability
- **Launcher & Updater Target Executable Correction (启动器与更新后重启修复)**:
  - Fixed hardcoded `./nekobox` and `./nekobox.exe` targets in `go/cmd/updater/launcher_linux.go` and `go/cmd/updater/main.go`, changing them to `./nekoray` and `./nekoray.exe`.
  - Fixed Linux `./launcher` crashing on startup and enabled automatic application restart after self-updating on Windows and Linux.
- **macOS Self-Updating & App Bundle Transactional Replacement (macOS 自动更新支持)**:
  - Added support in `go/cmd/updater/updater.go` for `nekoray.app` payload detection and transactional directory replacement with automatic rollback.
  - Added native `.app` bundle launch using `open ./nekoray.app` on macOS.
- **Dashboard Hot-Switch Node Logic Fix (仪表盘节点热切换修复)**:
  - Resolved logic defect where switching an active node from the Dashboard bottom sheet falsely stopped the proxy service.
  - Refactored `_toggleService` into decoupled `_startService` and `_stopService`, seamlessly switching nodes without service interruption.
- **Real Rule-Set Binary Synchronization via gRPC (规则集真实更新)**:
  - Replaced mock `Dio.head()` placeholder in `RoutingPage` with genuine gRPC `updateRuleSet()` calls, downloading and caching `.srs` rule-set binaries in the core.
- **End-to-End In-App Update Checker & Pre-Release Switch (应用内检查更新完整闭环)**:
  - Connected `checkForUpdates` and `downloadUpdate` gRPC calls with interactive update notification dialogs.
  - Added "Check Pre-Releases" toggle switch in Settings.
- **Proxy-Aware Website Latency & Connectivity Testing (测速走本地代理)**:
  - Configured `Dio` with `IOHttpClientAdapter` routing through `127.0.0.1:mixedPort` when proxy is active, ensuring authentic proxy latency measurements in restricted network environments.
- **System Proxy Leak Fix on Exit & Service Stop (系统代理自动清理)**:
  - Added automatic system proxy de-registration on application quit (`_quit()`) and when proxy core stops, eliminating host internet disconnection after proxy shutdown.
- **Argv Auth Token Leak Remediation (进程列表鉴权安全加固)**:
  - Removed plaintext `--token` from command-line arguments in `core_process.dart`, preserving secure environment variable-only authentication via `NEKORAY_AUTH_TOKEN`.
- **Flutter Material Localizations Delegates & Clean Codebase (本地化与工程规范)**:
  - Added `GlobalMaterialLocalizations` and `supportedLocales` in `MaterialApp` for native context menu and widget localization.
  - Removed lingering empty directories (`lib/models`, `lib/app/modules`, `lib/screens`).
  - Added macOS Intel (`macos-amd64`) packaging in release workflow and enabled strict `--set-exit-if-changed` and `gofmt` CI gates.

## v5.0.0-beta.12 — Karing-Style Routing Engine, Armwall Dashboard, Config Backup & Restore (2026-08-25)

### New Features & Enhancements
- **Karing-Inspired Routing Engine (Karing 风格规则分类与预设)**:
  - Added preset routing profiles (Bypass Mainland & Ads, Proxy All, Direct All).
  - Domain, IP CIDR, and Protocol rule filters with custom outbound routing (Direct, Proxy, Block).
- **Armwall Dashboard & Traffic Monitor (全新仪表盘)**:
  - Integrated real-time uplink/downlink throughput graph with `fl_chart`.
  - Node quick selector, speed test matrix, and active status badges.
- **Config Backup & Restore (配置备份与恢复)**:
  - Complete JSON configuration export, import, and reset to defaults from Settings page.
- **Light Theme Contrast & Auto-Start Fixes**:
  - Improved readability in light theme and fixed Windows auto-start registry creation.

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
