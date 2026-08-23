# nekoray 架构说明

## 当前架构（v5.x，Flutter + Go core）

```
┌─────────────────────────────────────────────┐
│  Flutter UI (Dart)                           │
│  Material 3 · Riverpod · gRPC client        │
│  - 节点管理 / 订阅 / 路由 / DNS / 设置        │
│  - 平台插件 (系统代理/TUN/托盘)              │
└──────────────────┬──────────────────────────┘
                   │ gRPC (localhost)
┌──────────────────▼──────────────────────────┐
│  nekobox_core (Go)                           │
│  sing-box v1.13.19 · ConfigBuilder           │
│  订阅解析 · rule_set · 连接管理              │
└─────────────────────────────────────────────┘
```

- **UI 层**：Flutter（Dart），仅做渲染 + 交互 + 本地 JSON 存储
- **IPC**：官方 gRPC（go-grpc ↔ grpc-dart），通过 localhost
- **核心**：Go `nekobox_core`，所有代理逻辑在此执行

## 组件

### Go Core (`go/`)

| 包 | 说明 |
|---|---|
| `cmd/nekobox_core` | 核心进程入口，管理 sing-box 实例 |
| `cmd/migrator` | 数据迁移工具（从旧 C++ nekoray 导入） |
| `grpc_server` | gRPC 服务端 |
| `grpc_server/core/config` | ConfigBuilder（sing-box 配置生成） |
| `grpc_server/core/fmt` | Bean 数据模型（协议实体） |
| `grpc_server/core/sub` | 订阅解析 + 链接生成 |
| `grpc_server/core/ruleset` | rule_set 远程规则集管理 |

### Flutter UI (`nekoray_flutter/`)

| 目录 | 说明 |
|---|---|
| `lib/core/grpc` | gRPC 客户端 + Riverpod providers |
| `lib/core/models` | Dart 数据模型 |
| `lib/core/storage` | JSON 文件存储 + 数据迁移 |
| `lib/core/state` | Riverpod 状态管理 |
| `lib/core/i18n` | 国际化（JSON 加载器） |
| `lib/ui/pages` | 各功能页面 |
| `lib/ui/schema` | 协议表单 schema（��态渲染） |
| `lib/ui/widgets` | 可复用组件 |

## 支持的代理协议

Go core 使用 sing-box v1.13.19 原生构建器，支持以下协议：

| 协议 | Bean 类型 | 说明 |
|---|---|---|
| Shadowsocks | `ShadowSocksBean` | SS + SIP003 插件 |
| VMess | `VMessBean` | V2Ray VMess |
| VLESS | `TrojanVLESSBean` | Reality / xtls-rprx-vision |
| Trojan | `TrojanVLESSBean` | |
| Hysteria2 | `QUICBean` | QUIC 协议 |
| TUIC | `QUICBean` | QUIC 协议 |
| **NaiveProxy** | `NaiveBean` | sing-box 原生支持 |
| **AnyTLS** | `AnyTLSBean` | sing-box 原生支持 |
| **SSH** | `SSHBean` | sing-box 原生支持 |
| **WireGuard** | `WireGuardBean` | sing-box 原生支持 |
| SOCKS / HTTP | `SocksHttpBean` | SOCKS4/5, HTTP(S) |
| Custom | `CustomBean` | 自定义 sing-box JSON |
| Chain | `ChainBean` | 前置代理链 |

## 构建标签

Go core 编译时使用以下 sing-box 构建标签：

```
with_clash_api,with_gvisor,with_quic,with_wireguard,with_utls
```

> ⚠️ 不要使用 `with_ech`（在 v1.13.19 上会导致编译失败）

## CI/CD

所有构建通过 GitHub Actions：

| 工作流 | 说明 |
|---|---|
| `build-go-core.yml` | 4 平台 Go core 交叉编译 |
| `build-flutter.yml` | 3 桌面端 Flutter 构建 |
| `build-mobile.yml` | Android 构建 |
| `lint-test.yml` | Go vet + Go test + Flutter analyze |
| `generate-proto.yml` | Go + Dart gRPC 存根生成 |
| `sync-go-sum.yml` | go mod tidy 自动同步 |
| `release.yml` | 一键发布（6 产物） |
