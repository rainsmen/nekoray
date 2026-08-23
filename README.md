# NekoRay

> Cross-platform proxy client built with **Flutter** + **sing-box** Go core.

[![CI: Build Go Core](https://github.com/rainsmen/nekoray/actions/workflows/build-go-core.yml/badge.svg)](https://github.com/rainsmen/nekoray/actions/workflows/build-go-core.yml)
[![CI: Build Flutter](https://github.com/rainsmen/nekoray/actions/workflows/build-flutter.yml/badge.svg)](https://github.com/rainsmen/nekoray/actions/workflows/build-flutter.yml)
[![CI: Lint & Test](https://github.com/rainsmen/nekoray/actions/workflows/lint-test.yml/badge.svg)](https://github.com/rainsmen/nekoray/actions/workflows/lint-test.yml)
[![Release](https://img.shields.io/github/v/release/rainsmen/nekoray?include_prereleases)](https://github.com/rainsmen/nekoray/releases)

A modern, cross-platform proxy configuration manager. The GUI is written in
Flutter (Material 3), and the proxy core is [sing-box](https://github.com/SagerNet/sing-box)
v1.13.19. The two communicate over gRPC.

This is a fork of [MatsuriDayo/nekoray](https://github.com/MatsuriDayo/nekoray)
that has been **fully rewritten** — the legacy C++/Qt UI is replaced by
Flutter, and all business logic (config building, subscription parsing,
rule-set management) has been sunk into the Go core.

## 下载 / Download

[![GitHub Releases](https://img.shields.io/github/downloads/rainsmen/nekoray/total?label=downloads&logo=github)](https://github.com/rainsmen/nekoray/releases)

前往 [Releases](https://github.com/rainsmen/nekoray/releases) 页面下载最新版本：

| 平台 | 文件 |
|------|------|
| Windows | `nekoray-*-windows64.zip` |
| Linux | `nekoray-*-linux64.tar.gz` |
| macOS | `nekoray-*-macos.zip` |
| Android (arm64) | `nekoray-*-android-arm64-v8a.apk` |
| Android (armv7) | `nekoray-*-android-armeabi-v7a.apk` |
| Android (x86_64) | `nekoray-*-android-x86_64.apk` |

## 架构 / Architecture

```
┌─────────────────────────────────────────────┐
│  Flutter UI (Dart)                          │
│  Material 3 · Riverpod · gRPC client        │
└──────────────────┬──────────────────────────┘
                   │ gRPC (localhost)
┌──────────────────▼──────────────────────────┐
│  nekobox_core (Go)                          │
│  sing-box v1.13.19 · ConfigBuilder          │
│  Subscription parser · rule_set manager     │
└─────────────────────────────────────────────┘
```

**核心设计**：Flutter 是瘦客户端，所有代理逻辑在 Go core 中。gRPC 是唯一通信接口。

详见 [ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 代理协议 / Proxy Protocols

- Shadowsocks
- VMess
- VLESS (含 Reality / xtls-rprx-vision)
- Trojan
- Hysteria2
- TUIC
- WireGuard
- SSH
- SOCKS / HTTP
- Custom Outbound / Custom Config

## 功能 / Features

- **节点管理**：增删改查、分组、搜索、延迟测试
- **订阅**：自动解析 (ss/vmess/vless/trojan 链接、Clash YAML、SIP008、Base64)
- **路由**：可视化规则编辑器
- **DNS**：预设方案 (绕过国内 / 全局 / 自定义)
- **连接监控**：实时流量图表 (fl_chart)
- **rule_set**：远程规则集订阅 (MRS 格式)
- **数据迁移**：从旧版 C++ nekoray 导入配置
- **国际化**：中文 / English
- **跨平台**：Windows / Linux / macOS / Android

## 项目结构 / Project Structure

```
nekoray/
├── go/                         # Go core (sing-box + gRPC server)
│   ├── cmd/nekobox_core/       # 核心进程入口
│   ├── cmd/migrator/           # 数据迁移工具 (CLI)
│   ├── cmd/updater/            # 自动更新器
│   └── grpc_server/            # gRPC 服务 + 业务逻辑
│       ├── core/config/        # ConfigBuilder (sing-box 配置生成)
│       ├── core/fmt/            # Bean 数据模型
│       ├── core/sub/            # 订阅解析
│       └── core/ruleset/       # rule_set 管理
├── nekoray_flutter/            # Flutter 桌面/移动端 UI
│   └── lib/
│       ├── core/               # gRPC 客户端、数据模型、存储、i18n
│       └── ui/                 # 页面、组件、主题
├── libs/                       # 构建脚本
├── .github/workflows/          # CI/CD
└── docs/                       # 文档
```

## 编译 / Build

所有编译通过 GitHub Actions 完成，无需本地工具链。

### Go Core

```bash
# 本地编译 (需 Go 1.22+)
cd go/cmd/nekobox_core
go mod tidy
go build -tags "with_clash_api,with_gvisor,with_quic,with_wireguard,with_utls"
```

### Flutter App

```bash
cd nekoray_flutter
flutter pub get
flutter run -d windows   # or linux / macos / chrome
```

### CI 触发

```bash
# 构建 Go core (4 平台)
gh workflow run "Build Go Core" --repo rainsmen/nekoray --ref dev

# 构建 Flutter (3 桌面端)
gh workflow run "Build Flutter" --repo rainsmen/nekoray --ref dev

# 一键发布
gh workflow run "Release" --repo rainsmen/nekoray --ref dev \
  -f tag=v5.0.0 -f prerelease=false
```

## 文档 / Documentation

- [架构说明](docs/ARCHITECTURE.md)
- [技术决策记录](docs/DECISIONS.md)
- [实施进度](docs/实施进度.md)
- [迁移实施计划](docs/Flutter迁移实施计划.md)
- [可行性分析报告](docs/Flutter迁移可行性分析报告.md)
- [变更日志](CHANGELOG.md)

## Credits

**Core:**
- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) v1.13.19

**UI:**
- [Flutter](https://flutter.dev)
- [Riverpod](https://riverpod.dev) (状态管理)
- [fl_chart](https://github.com/imaNNeo/fl_chart) (图表)
- [grpc-dart](https://github.com/grpc/grpc-dart) (gRPC)
- [tray_manager](https://github.com/leanflutter/tray_manager) (系统托盘)
- [window_manager](https://github.com/leanflutter/window_manager) (窗口控制)

**Original project:**
- [MatsuriDayo/nekoray](https://github.com/MatsuriDayo/nekoray) — C++/Qt 原版

## License

GPL-3.0, 继承自上游项目。
