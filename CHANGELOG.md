# Changelog

## v5.0.0-beta1 — Phase 2 Flutter Desktop (2025-08-23)

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
