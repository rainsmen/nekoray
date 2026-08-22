# nekoray Flutter 迁移具体实施计划

> 基于《Flutter迁移可行性分析报告》编制
> 仓库地址：https://github.com/rainsmen/nekoray
> 构建方式：优先 GitHub Actions 云编译
> 编制日期：2025-08-20

---

## 一、总体策略

### 1.1 核心原则

1. **渐进式迁移**：分三阶段，每阶段独立可交付、可回退。
2. **双轨并行**：迁移期间保留 C++ 版本可用，新功能先在 Go core 实现，老 UI 也能调用。
3. **GitHub 优先**：代码托管、CI/CD、Release、Issue 全部基于 GitHub 生态。
4. **云编译优先**：所有构建走 GitHub Actions，本地仅做开发调试。

### 1.2 仓库与分支策略

```
仓库：https://github.com/rainsmen/nekoray

分支模型：
  main              # 稳定发布分支（当前 C++ 版本继续维护）
  dev               # 开发集成分支
  feature/core-v2   # 阶段一：Go core 升级 + 业务下沉
  feature/flutter   # 阶段二：Flutter UI 重写
  feature/mobile    # 阶段三：移动端适配

Tag 规范：
  v4.x.x            # C++ 版本（过渡期）
  v5.0.0-beta.x     # Flutter 桌面端 beta
  v5.0.0            # Flutter 桌面端正式版
  v5.1.0            # 含移动端
```

### 1.3 阶段总览

| 阶段 | 名称 | 周期 | 交付物 | GitHub 产出 |
|---|---|---|---|---|
| 零 | 仓库初始化与 CI 搭建 | 第 1 周 | fork 整理、CI 验证 | 可用的云编译流水线 |
| 一 | Go core 升级 + 业务下沉 | 第 2-10 周 | 升级版 core，老 UI 可用 | `v4.2.0` Release（C++ + 新 core） |
| 二 | Flutter 桌面端重写 | 第 11-32 周 | Flutter 桌面版 | `v5.0.0-beta` → `v5.0.0` |
| 三 | 移动端适配（可选） | 第 33-48 周 | Android/iOS | `v5.1.0` |

---

## 二、阶段零：仓库初始化与 CI 搭建（第 1 周）

### 2.1 仓库准备

#### 2.1.1 Fork 与整理

```bash
# 1. 已 fork 到 https://github.com/rainsmen/nekoray
# 2. 更新 remote
git remote set-url origin https://github.com/rainsmen/nekoray.git
git remote add upstream https://github.com/Matsuridayo/nekoray.git

# 3. 创建 dev 分支
git checkout -b dev
git push -u origin dev
```

#### 2.1.2 仓库结构调整

当前 `nekoray_flutter/` 为空目录，阶段二启用。阶段一不改动目录结构，保持 C++ 构建可用。

新增以下目录/文件：
```
.github/
  workflows/
    build-nekoray-cmake.yml    # 保留现有 C++ 构建（过渡期）
    build-go-core.yml          # 新增：Go core 独立构建
    build-flutter.yml          # 阶段二新增
    release.yml                # 统一发布流水线
  ISSUE_TEMPLATE/              # 保留
docs/
  Flutter迁移可行性分析报告.md  # 已有
  Flutter迁移实施计划.md        # 本文件
  ARCHITECTURE.md              # 新增：架构说明
```

### 2.2 GitHub Actions 流水线搭建

#### 2.2.1 流水线规划

```
┌──────────────────────────────────────────────────────────────┐
│  阶段零/一 CI（C++ + Go 双轨）                                │
│                                                              │
│  push/PR ─► build-go-core ──┐                                │
│           build-cpp-ui ─────┼─► artifact ─► (手动) release   │
│           lint-test ────────┘                                │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  阶段二 CI（Flutter + Go 双轨）                               │
│                                                              │
│  push/PR ─► build-go-core ──┐                                │
│           build-flutter ────┼─► artifact ─► (手动) release   │
│           analyze-flutter ──┘                                │
└──────────────────────────────────────────────────────────────┘
```

#### 2.2.2 新增工作流：`build-go-core.yml`

独立构建 Go core，用于阶段一快速验证（无需等 C++ 全量编译）：

```yaml
# .github/workflows/build-go-core.yml
name: Build Go Core

on:
  push:
    branches: [main, dev, feature/core-v2]
    paths:
      - 'go/**'
      - 'libs/get_source_env.sh'
      - 'libs/build_go.sh'
      - 'libs/env_deploy.sh'
      - 'nekoray_version.txt'
  pull_request:
    branches: [main, dev]
    paths:
      - 'go/**'
  workflow_dispatch:

jobs:
  build:
    strategy:
      matrix:
        include:
          - goos: windows
            goarch: amd64
            runner: ubuntu-latest
          - goos: linux
            goarch: amd64
            runner: ubuntu-latest
          - goos: darwin
            goarch: amd64
            runner: ubuntu-latest
          - goos: darwin
            goarch: arm64
            runner: ubuntu-latest
      fail-fast: false
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'
          cache: true

      - name: Get sources (sing-box etc.)
        run: ./libs/get_source.sh

      - name: Build nekobox_core
        env:
          GOOS: ${{ matrix.goos }}
          GOARCH: ${{ matrix.goarch }}
        run: ./libs/build_go.sh

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: nekobox_core-${{ matrix.goos }}-${{ matrix.goarch }}
          path: deployment/
          retention-days: 14
```

#### 2.2.3 新增工作流：`lint-test.yml`

```yaml
# .github/workflows/lint-test.yml
name: Lint & Test

on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main, dev]

jobs:
  go-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: ./libs/get_source.sh
      - name: golangci-lint
        uses: golangci/golangci-lint-action@v6
        with:
          working-directory: go/cmd/nekobox_core
      - name: go test
        run: |
          cd go/cmd/nekobox_core
          go test ./... -v -cover

  cpp-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: clang-tidy
        run: |
          sudo apt-get install -y clang-tidy
          clang-tidy --version
          # 选择性检查核心文件
          clang-tidy -p build db/ConfigBuilder.cpp -- -std=c++17 -I. -I3rdparty
```

### 2.3 交付清单（阶段零）

- [ ] fork 整理完成，remote 配置正确
- [ ] `build-go-core.yml` 流水线跑通，产出多平台 core 二进制
- [ ] `lint-test.yml` 流水线跑通
- [ ] 现有 `build-nekoray-cmake.yml` 仍可正常构建（过渡期保留）
- [ ] `dev` 分支保护规则配置（需 PR + CI 通过）
- [ ] Issue 模板更新（新增迁移相关标签）

---

## 三、阶段一：Go core 升级 + 业务下沉（第 2-10 周）

### 3.1 目标

1. sing-box 从 1.13.19 升级到最新稳定版
2. 将 C++ 的 ConfigBuilder、GroupUpdater、ProfileFilter 下沉到 Go core
3. gRPC proto 扩展，新增连接管理、rule_set 更新等接口
4. **现有 C++ UI 不改动**，通过新 gRPC 接口获得新功能
5. 发布 `v4.2.0`（C++ UI + 新 core）

### 3.2 任务分解

#### 3.2.1 任务 1：sing-box 升级（第 2-4 周）

**目标**：sing-box 1.13.19 → 最新稳定版（当前 1.12.x/1.13.x 主线）

**子任务**：

| 编号 | 任务 | 详情 | 验收标准 |
|---|---|---|---|
| 1.1 | 解除版本锁定 | 更新 `libs/get_source_env.sh`，改为追踪 sing-box upstream 最新 tag | 构建时拉取最新版 |
| 1.2 | 解决 breaking changes | `go/cmd/nekobox_core/grpc_box.go` 中 `boxmain.Create`、`boxapi` API 变更适配 | 编译通过 |
| 1.3 | rule_set 替代 geoip/geosite | `db/ConfigBuilder.cpp` 中 `geoip.db`/`geosite.db` 改为 rule_set（在下沉任务中统一处理，见 3.2.2） | 路由规则生效 |
| 1.4 | sniffer 新结构 | inbound 生成改为 `sniffer` 子对象 | 配置生成正确 |
| 1.5 | route.rules action 字段 | `block`/`outbound` → `action: reject`/`action: route` | 路由动作正确 |
| 1.6 | cache_file 启用 | experimental 增加 cache_file | fakeip 持久化生效 |
| 1.7 | go.mod 依赖更新 | 处理 `sing-quic` 等 replace 指令 | 无编译警告 |

**关键代码位置**：
- `go/cmd/nekobox_core/go.mod`（依赖版本）
- `go/cmd/nekobox_core/grpc_box.go`（boxapi 调用）
- `libs/get_source_env.sh`（版本锁定）
- `libs/get_source.sh`（源码拉取）

**GitHub Actions 验证**：
- `build-go-core.yml` 多平台编译通过
- 新增集成测试 job：用测试 config 启动 core 并验证路由

**风险与应对**：
- sing-box `boxapi` 包可能变更 → 先在 `feature/core-v2` 分支实验，保留旧版回退
- `Matsuridayo/sing-box` fork 可能不再维护 → 评估改为直接用 `SagerNet/sing-box` upstream

#### 3.2.2 任务 2：ConfigBuilder 下沉 Go（第 3-7 周）

**目标**：将 `db/ConfigBuilder.cpp`（~800 行）+ `fmt/Bean2CoreObj_box.cpp`（~250 行）的逻辑用 Go 重写，作为 gRPC 服务。

**这是阶段一最核心的工作。**

**子任务**：

| 编号 | 任务 | C++ 源 | Go 目标 | 工作量 |
|---|---|---|---|---|
| 2.1 | Bean 数据模型重建 | `fmt/*.hpp`（17 文件） | `go/core/fmt/bean.go` | 高 |
| 2.2 | V2RayStreamSettings | `fmt/V2RayStreamSettings.hpp` | `go/core/fmt/stream.go` | 中 |
| 2.3 | outbound 构建器 | `fmt/Bean2CoreObj_box.cpp` | `go/core/fmt/build_outbound.go` | 高 |
| 2.4 | 配置组装 | `db/ConfigBuilder.cpp` | `go/core/config/build.go` | 高 |
| 2.5 | DNS 构建 | `ConfigBuilder.cpp` DNS 部分 | `go/core/config/dns.go` | 中 |
| 2.6 | 路由规则构建 | `ConfigBuilder.cpp` route 部分 | `go/core/config/route.go` | 中 |
| 2.7 | Chain 链式代理 | `ConfigBuilder.cpp` BuildChain | `go/core/config/chain.go` | 高 |
| 2.8 | VPN 配置生成 | `ConfigBuilder.cpp` WriteVPNSingBoxConfig | `go/core/config/vpn.go` | 中 |
| 2.9 | 单元测试 | — | `go/core/config/*_test.go` | 中 |

**新增 gRPC 接口**（proto 扩展）：

```protobuf
// go/grpc_server/gen/libcore.proto 新增
service LibcoreService {
  // ... 现有接口 ...

  // 新增：配置构建（Flutter/前端只发数据，core 生成完整 config）
  rpc BuildConfig(BuildConfigReq) returns (BuildConfigResp) {}
}

message BuildConfigReq {
  bytes profile_json = 1;      // ProxyEntity 序列化
  bytes group_json = 2;        // Group 配置
  bytes routing_json = 3;      // 路由配置
  bytes datastore_json = 4;    // 全局设置
  bool for_test = 5;
  bool for_export = 6;
}

message BuildConfigResp {
  string error = 1;
  string core_config = 2;      // 完整 sing-box config JSON
  bytes  ext_results = 3;       // external core 信息
}
```

**验证方法**：
- 编写对比测试：同一 ProxyEntity，分别用 C++ 和 Go 生成 config，对比 JSON（允许字段顺序差异）
- 通过 `BuildConfig` gRPC 接口，C++ UI 调用新 core 生成配置，验证功能等价

#### 3.2.3 任务 3：订阅解析下沉 Go（第 4-7 周）

**目标**：将 `sub/GroupUpdater.cpp`（665 行）+ `fmt/Link2Bean.cpp` + `fmt/Bean2Link.cpp` 下沉。

**子任务**：

| 编号 | 任务 | C++ 源 | Go 目标 |
|---|---|---|---|
| 3.1 | 链接解析（ss/vmess/vless/trojan/hy2/tuic/naive） | `fmt/Link2Bean.cpp`（~300 行） | `go/core/sub/link_parser.go` |
| 3.2 | Clash YAML 解析 | `sub/GroupUpdater.cpp` updateClash（~400 行） | `go/core/sub/clash_parser.go` |
| 3.3 | 分享链接生成 | `fmt/Bean2Link.cpp`（~250 行） | `go/core/sub/link_builder.go` |
| 3.4 | HTTP 订阅下载 | `sub/GroupUpdater.cpp` AsyncUpdate | `go/core/sub/downloader.go` |
| 3.5 | 去重过滤 | `db/ProfileFilter.cpp`（80 行） | `go/core/sub/filter.go` |
| 3.6 | SIP008 支持（新增） | 无 | `go/core/sub/sip008.go` |

**新增 gRPC 接口**：

```protobuf
service LibcoreService {
  // ... 现有接口 ...

  rpc ParseSubscription(ParseSubReq) returns (ParseSubResp) {}
  rpc GenerateShareLink(ShareLinkReq) returns (ShareLinkResp) {}
}

message ParseSubReq {
  string content = 1;
  string format = 2;  // "auto", "raw", "clash", "sip008", "base64"
}
message ParseSubResp {
  string error = 1;
  repeated bytes profiles = 2;  // ProxyEntity JSON 数组
}

message ShareLinkReq {
  bytes profile_json = 1;
  string format = 2;  // "nekoray", "v2rayn", "clash"
}
message ShareLinkResp {
  string error = 1;
  string link = 2;
}
```

#### 3.2.4 任务 4：连接管理实现（第 6-8 周）

**目标**：实现当前为空实现的 `ListConnections`。

**现状**：`grpc_box.go` 中 `ListConnections` 返回空（注释 `TODO upstream api`）。

**方案**：接入 sing-box 的 V2Ray API 连接追踪（或 Clash API `/connections`）。

```go
// go/cmd/nekobox_core/grpc_box.go 改造
func (s *server) ListConnections(ctx context.Context, in *gen.EmptyReq) (*gen.ListConnectionsResp, error) {
    out := &gen.ListConnectionsResp{}
    if instance != nil {
        // 方案A: 通过 V2Ray API
        if ss, ok := instance.Router().V2RayServer().(*boxapi.SbV2rayServer); ok {
            // 获取连接统计
        }
        // 方案B: 通过 Clash API
        // 请求 http://127.0.0.1:9090/connections
    }
    return out, nil
}
```

**验收**：UI 连接列表能显示实时连接（需 C++ UI 同步适配，或留到阶段二）。

#### 3.2.5 任务 5：rule_set 远程更新机制（第 7-8 周）

**目标**：支持远程 rule_set（MRS 格式）的订阅与自动更新。

**新增 gRPC 接口**：

```protobuf
service LibcoreService {
  rpc UpdateRuleSet(UpdateRuleSetReq) returns (ErrorResp) {}
  rpc ListRuleSets(EmptyReq) returns (ListRuleSetsResp) {}
}

message UpdateRuleSetReq {
  string url = 1;
  string tag = 2;
  string format = 3;  // "source" or "binary"
}
message ListRuleSetsResp {
  repeated RuleSetInfo rule_sets = 1;
}
message RuleSetInfo {
  string tag = 1;
  string type = 2;
  string format = 3;
  int64  updated_at = 4;
  int64  size = 5;
}
```

#### 3.2.6 任务 6：数据迁移工具（第 8-9 周）

**目标**：现有用户的 `profiles/*.json`、`groups/*.json`、路由配置可平滑迁移到新格式（阶段二 Flutter 用）。

**实现**：Go 编写的独立工具 `go/cmd/migrator/`，读取老格式，输出新格式（JSON 或 SQLite）。

```bash
# 使用方式
./migrator -src ~/.config/nekoray/ -dst ./new_config/
```

**注意**：此阶段保持 JSON 格式不变，迁移工具主要做格式规范化和字段补全。

### 3.3 阶段一 CI/CD 增强

#### 3.3.1 集成测试流水线

```yaml
# .github/workflows/integration-test.yml（阶段一新增）
name: Integration Test

on:
  push:
    branches: [feature/core-v2]
  pull_request:
    branches: [dev]

jobs:
  config-equivalence-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: ./libs/get_source.sh

      - name: Build core
        run: |
          cd go/cmd/nekobox_core
          go build -o ../../../../nekobox_core

      - name: Run equivalence tests
        run: |
          cd go/core/config
          go test -v -run TestConfigEquivalence
          # 对比 C++ 生成的 config 与 Go 生成的 config
```

#### 3.3.2 发布流水线（阶段一）

```yaml
# .github/workflows/release.yml（阶段一版本）
name: Release

on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Release Tag (e.g. v4.2.0)"
        required: true
      prerelease:
        description: "Prerelease? (true/false)"
        required: false
        default: "true"

jobs:
  build-go-core:
    # ... 同 build-go-core.yml，产出多平台 core

  build-cpp-ui:
    # ... 现有 build-nekoray-cmake.yml 的 build-cpp job

  package:
    needs: [build-go-core, build-cpp-ui]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Package
        run: |
          # 合并 C++ UI + 新 Go core + geo data
          ./libs/package_release.sh ${{ github.event.inputs.tag }}

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.event.inputs.tag }}
          prerelease: ${{ github.event.inputs.prerelease }}
          files: |
            deployment/*.zip
            deployment/*.deb
            deployment/*.AppImage
          body_path: CHANGELOG.md
```

### 3.4 阶段一里程碑

| 里程碑 | 时间 | 交付 |
|---|---|---|
| M1.1 | 第 4 周末 | sing-box 升级完成，`build-go-core.yml` 通过，旧 UI 可启动 |
| M1.2 | 第 7 周末 | ConfigBuilder + 订阅解析下沉完成，gRPC 新接口可用 |
| M1.3 | 第 9 周末 | 连接管理 + rule_set 更新 + 迁移工具完成 |
| **M1.0** | **第 10 周末** | **发布 `v4.2.0`：C++ UI + 新 core，含 sing-box 新特性** |

### 3.5 阶段一验收标准

- [ ] sing-box 升级到最新稳定版，rule_set/sniffer/action 全部生效
- [ ] Go core 通过 gRPC 暴露 `BuildConfig`/`ParseSubscription`/`ListConnections`/`UpdateRuleSet`
- [ ] C++ UI 调用新 core，现有功能全部正常
- [ ] 新增 SSH/WireGuard/AnyTLS/ShadowTLS v3 协议支持（通过 Bean 扩展）
- [ ] GitHub Actions 多平台构建通过（win/linux/macos）
- [ ] 发布 `v4.2.0` Release

---

## 四、阶段二：Flutter 桌面端重写（第 11-32 周）

### 4.1 目标

1. 用 Flutter 重写桌面端 UI，功能对齐当前 nekoray + 新特性
2. UI 风格对齐 karing / armwall（现代、卡片化、深色优先）
3. Go core 作为后端，Flutter 通过 gRPC 调用
4. 覆盖 Windows / Linux / macOS 桌面三端

### 4.2 Flutter 项目结构

```
nekoray_flutter/
  lib/
    main.dart
    app.dart                      # MaterialApp 配置
    core/
      grpc/                       # gRPC 客户端
        grpc_client.dart
        generated/                # protoc 生成的 Dart stub
      models/                     # 数据模型（对应 JsonStore）
        profile.dart
        group.dart
        routing.dart
        datastore.dart
        bean/
          vmess.dart
          vless.dart
          trojan.dart
          shadowsocks.dart
          hysteria2.dart
          tuic.dart
          custom.dart
          ...
      services/
        config_service.dart       # 调用 core BuildConfig
        subscription_service.dart # 调用 core ParseSubscription
        connection_service.dart   # 调用 core ListConnections
        stats_service.dart        # 流量统计轮询
      storage/
        local_store.dart          # 本地存储（Hive/Isar）
        migration.dart            # 数据迁移（调用 migrator 工具）
    ui/
      pages/
        home/
          home_page.dart          # 主页面（节点列表）
          home_view_model.dart
        profile/
          profile_edit_page.dart  # 协议编辑器（动态表单）
          profile_view_model.dart
        routes/
          routes_page.dart        # 路由设置
        dns/
          dns_page.dart           # DNS 设置
        vpn/
          vpn_page.dart           # VPN 设置
        subscription/
          subscription_page.dart # 订阅管理
        connections/
          connections_page.dart   # 连接管理
          connections_view_model.dart
        settings/
          settings_page.dart     # 基础设置
      widgets/
        proxy_card.dart           # 节点卡片（armwall 风格）
        group_list.dart
        traffic_chart.dart        # 流量图表（fl_chart）
        latency_chart.dart        # 延迟图表
        status_bar.dart
        theme/
          app_theme.dart          # Material 3 主题
          dark_theme.dart
          light_theme.dart
      components/
        dynamic_form.dart         # schema 驱动动态表单
        json_editor.dart          # JSON 编辑器
      navigation/
        nav_scaffold.dart         # 侧边导航
    platform/
      windows/
        system_proxy.dart         # MethodChannel → C++/Win32
        auto_run.dart
      linux/
        system_proxy.dart
        tun_helper.dart
      macos/
        system_proxy.dart
  pubspec.yaml
  test/                           # 单元测试 + widget 测试
  integration_test/               # 集成测试
```

### 4.3 任务分解

#### 4.3.1 任务 7：Flutter 工程脚手架（第 11-12 周）

| 编号 | 任务 | 详情 |
|---|---|---|
| 7.1 | 初始化 Flutter 工程 | `flutter create --org com.nekoray --platforms=windows,linux,macos nekoray_flutter` |
| 7.2 | 依赖配置 | `pubspec.yaml`：grpc, provider/riverpod, json_serializable, freezed, dio, yaml, fl_chart, hive, tray_manager, hotkey_manager, launch_at_startup |
| 7.3 | 状态管理搭建 | Riverpod（推荐）或 Provider，定义全局状态 |
| 7.4 | 主题系统 | Material 3 + 深色优先，对齐 armwall |
| 7.5 | 侧边导航 | NavigationRail，对齐 armwall |

#### 4.3.2 任务 8：gRPC 客户端接入（第 12-13 周）

```dart
// lib/core/grpc/grpc_client.dart
class GrpcClient {
  late ClientChannel _channel;
  late LibcoreServiceClient _stub;

  void connect(String host, int port, String token) {
    _channel = ClientChannel(
      host,
      port: port,
      options: CallOptions(
        metadata: {'nekoray_auth': token},
        timeout: Duration(seconds: 10),
      ),
    );
    _stub = LibcoreServiceClient(_channel);
  }

  Future<BuildConfigResp> buildConfig(BuildConfigReq req) async {
    return await _stub.buildConfig(req);
  }

  Future<ParseSubResp> parseSubscription(ParseSubReq req) async {
    return await _stub.parseSubscription(req);
  }

  Stream<QueryStatsResp> queryStats(QueryStatsReq req) async* {
    // 流式统计
  }
}
```

**proto 生成 Dart 代码**：
```bash
protoc --dart_out=grpc:nekoray_flutter/lib/core/grpc/generated \
  go/grpc_server/gen/libcore.proto
```

#### 4.3.3 任务 9：数据模型层（第 13-15 周）

将 C++ 的 `JsonStore`（147 字段）+ 各 Bean 类映射为 Dart 数据类。

```dart
// lib/core/models/profile.dart
@freezed
class ProxyEntity with _$ProxyEntity {
  const factory ProxyEntity({
    required int id,
    required int gid,
    required String type,
    required String name,
    required AbstractBean bean,
    @Default(0) int latency,
    @Default(0) int trafficUp,
    @Default(0) int trafficDown,
  }) = _ProxyEntity;

  factory ProxyEntity.fromJson(Map<String, dynamic> json) =>
      _$ProxyEntityFromJson(json);
}

@freezed
class AbstractBean with _$AbstractBean {
  const factory AbstractBean({
    required String serverAddress,
    required int serverPort,
    V2rayStreamSettings? stream,
    String? customConfig,
    String? customOutbound,
  }) = _AbstractBean;

  factory AbstractBean.fromJson(Map<String, dynamic> json) =>
      _$AbstractBeanFromJson(json);
}
```

**验证**：能正确读写现有 `profiles/*.json` 文件（兼容性测试）。

#### 4.3.4 任务 10：主界面 - 节点列表（第 15-18 周）

**对齐 armwall 风格**：

- 左侧：分组列表（可折叠）
- 中间：节点卡片列表（显示名称、类型、地址、延迟、流量）
- 右侧/底部：状态栏（当前连接、流量统计）
- 顶部：搜索框 + 操作按钮

```dart
// lib/ui/pages/home/home_page.dart
class HomePage extends ConsumerWidget {
  Widget build(context, ref) {
    final profiles = ref.watch(profileListProvider);
    final groups = ref.watch(groupListProvider);

    return Scaffold(
      body: Row(
        children: [
          // 左侧导航 + 分组
          NavRail(groups: groups),
          // 中间节点列表
          Expanded(
            child: Column(
              children: [
                SearchBar(),
                Expanded(
                  child: ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (_, i) => ProxyCard(profile: profiles[i]),
                  ),
                ),
                StatusBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 4.3.5 任务 11：协议编辑器 - 动态表单（第 18-21 周）

**核心改进**：不再每个协议一个表单文件，改为 schema 驱动。

```dart
// lib/ui/components/dynamic_form.dart
class DynamicForm extends StatelessWidget {
  final List<FieldSchema> fields;
  final Map<String, dynamic> values;

  Widget build(context) {
    return Column(
      children: fields.map((f) {
        switch (f.type) {
          case FieldType.text:
            return TextFormField(
              decoration: InputDecoration(labelText: f.label),
              initialValue: values[f.key],
            );
          case FieldType.combo:
            return DropdownButtonFormField(...);
          case FieldType.bool:
            return CheckboxListTile(...);
          case FieldType.tls:
            return TlsSettingsField(schema: f);
          // ...
        }
      }).toList(),
    );
  }
}

// 协议 schema 注册
final protocolSchemas = {
  'vmess': VmessSchema(),
  'vless': VlessSchema(),
  'trojan': TrojanSchema(),
  'shadowsocks': ShadowsocksSchema(),
  'hysteria2': Hysteria2Schema(),
  'tuic': TuicSchema(),
  'ssh': SshSchema(),           // 新增
  'wireguard': WireGuardSchema(), // 新增
  'anytls': AnyTlsSchema(),     // 新增
  'custom': CustomSchema(),
};
```

**收益**：新增协议只需注册一个 schema，无需改 UI 代码。

#### 4.3.6 任务 12：路由/DNS/VPN 设置页面（第 21-24 周）

迁移 `dialog_manage_routes`、`dialog_vpn_settings`、`dialog_basic_settings` 为 Flutter 页面。

关键改进：
- 路由规则编辑器：可视化规则列表 + JSON 高级编辑
- DNS 配置：预设方案（bypass CN / global / custom）
- rule_set 管理：远程 rule_set 订阅 + 本地导入

#### 4.3.7 任务 13：连接管理 + 图表（第 24-26 周）

```dart
// lib/ui/pages/connections/connections_page.dart
class ConnectionsPage extends ConsumerWidget {
  Widget build(context, ref) {
    final connections = ref.watch(connectionListProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Connections')),
      body: Column(
        children: [
          // 流量图表
          TrafficChart(data: ref.watch(trafficHistoryProvider)),
          // 连接列表
          Expanded(
            child: DataTable(
              columns: ['Source', 'Destination', 'Network', 'Outbound', 'Traffic'],
              rows: connections.map(...).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 4.3.8 任务 14：平台功能（第 26-30 周）

| 编号 | 平台功能 | Flutter 方案 |
|---|---|---|
| 14.1 | Windows 系统代理 | MethodChannel → C++ DLL 或 PowerShell 调用 |
| 14.2 | Linux 系统代理 | gsettings / 环境变量 |
| 14.3 | macOS 系统代理 | networksetup 命令 |
| 14.4 | TUN 模式 | 调用 Go core 启动（桌面端保留 root 脚本） |
| 14.5 | 系统托盘 | `tray_manager` 包 |
| 14.6 | 全局热键 | `hotkey_manager` 包 |
| 14.7 | 开机自启 | `launch_at_startup` 包 |
| 14.8 | 二维码扫描 | `mobile_scanner`（桌面端摄像头）+ `qr_flutter`（显示） |

#### 4.3.9 任务 15：国际化（第 30-31 周）

- `zh_CN`（默认）、`en_US`、`ru_RU`、`fa_IR`
- 使用 Flutter `intl` 包 + ARB 文件
- 迁移现有 `translations/*.ts` 内容

#### 4.3.10 任务 16：数据迁移工具集成（第 31 周）

```dart
// lib/core/storage/migration.dart
class DataMigration {
  Future<void> migrateFromCppVersion(String oldDir) async {
    // 1. 读取 profiles/*.json
    // 2. 字段映射（C++ JsonStore → Dart 数据类）
    // 3. 写入新格式
    // 4. 迁移路由配置、分组
    // 5. 迁移 geoip/geosite → rule_set（调用 core）
  }
}
```

### 4.4 阶段二 CI/CD

#### 4.4.1 Flutter 构建流水线

```yaml
# .github/workflows/build-flutter.yml
name: Build Flutter

on:
  push:
    branches: [feature/flutter, dev]
    paths:
      - 'nekoray_flutter/**'
      - 'go/**'
  pull_request:
    branches: [dev]
  workflow_dispatch:

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: cd nekoray_flutter && flutter pub get
      - run: cd nekoray_flutter && flutter analyze
      - run: cd nekoray_flutter && dart format --set-exit-if-changed .

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: cd nekoray_flutter && flutter test --coverage
      - uses: codecov/codecov-action@v4
        with:
          directory: nekoray_flutter/coverage

  build:
    strategy:
      matrix:
        include:
          - platform: windows-latest
            target: windows
          - platform: ubuntu-latest
            target: linux
          - platform: macos-latest
            target: macos
      fail-fast: false
    runs-on: ${{ matrix.platform }}
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      # 构建 Go core
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: ./libs/get_source.sh
      - name: Build Go core
        env:
          GOOS: ${{ matrix.target == 'windows' && 'windows' || matrix.target == 'linux' && 'linux' || 'darwin' }}
          GOARCH: amd64
        run: ./libs/build_go.sh

      # 构建 Flutter
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Generate gRPC stubs
        run: |
          cd nekoray_flutter
          dart pub global activate protoc_plugin
          protoc --dart_out=grpc:lib/core/grpc/generated ../go/grpc_server/gen/libcore.proto
      - run: cd nekoray_flutter && flutter pub get
      - name: Build Flutter app
        run: |
          cd nekoray_flutter
          if [ "${{ matrix.target }}" == "windows" ]; then
            flutter build windows --release
          elif [ "${{ matrix.target }}" == "linux" ]; then
            flutter build linux --release
          else
            flutter build macos --release
          fi

      # 合并 core + UI + 资源
      - name: Package
        shell: bash
        run: ./libs/package_flutter_release.sh ${{ matrix.target }}

      - uses: actions/upload-artifact@v4
        with:
          name: nekoray-flutter-${{ matrix.target }}
          path: deployment/
          retention-days: 14
```

#### 4.4.2 阶段二发布流水线

```yaml
# .github/workflows/release.yml（阶段二版本）
name: Release

on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Release Tag (e.g. v5.0.0-beta.1)"
        required: true
      prerelease:
        description: "Prerelease?"
        default: "true"

jobs:
  build-go-core:
    strategy:
      matrix:
        include:
          - goos: windows
            goarch: amd64
          - goos: linux
            goarch: amd64
          - goos: darwin
            goarch: amd64
          - goos: darwin
            goarch: arm64
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: ./libs/get_source.sh
      - name: Build
        env:
          GOOS: ${{ matrix.goos }}
          GOARCH: ${{ matrix.goarch }}
        run: ./libs/build_go.sh
      - uses: actions/upload-artifact@v4
        with:
          name: core-${{ matrix.goos }}-${{ matrix.goarch }}
          path: deployment/

  build-flutter:
    strategy:
      matrix:
        include:
          - platform: windows-latest
            target: windows
          - platform: ubuntu-22.04
            target: linux
          - platform: macos-latest
            target: macos
    runs-on: ${{ matrix.platform }}
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: cd nekoray_flutter && flutter pub get
      - name: Build
        run: |
          cd nekoray_flutter
          flutter build ${{ matrix.target }} --release
      - uses: actions/upload-artifact@v4
        with:
          name: flutter-${{ matrix.target }}
          path: nekoray_flutter/build/

  package-release:
    needs: [build-go-core, build-flutter]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Package all platforms
        run: ./libs/package_flutter_release.sh all

      - name: Download geo data
        run: ./libs/download_geodata.sh

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.event.inputs.tag }}
          prerelease: ${{ github.event.inputs.prerelease }}
          files: |
            deployment/nekoray-*.zip
            deployment/nekoray-*.tar.gz
          body_path: CHANGELOG.md
```

### 4.5 阶段二里程碑

| 里程碑 | 时间 | 交付 |
|---|---|---|
| M2.1 | 第 15 周末 | Flutter 脚手架 + gRPC + 数据模型，能连接 core 并显示节点列表 |
| M2.2 | 第 21 周末 | 节点管理 + 协议编辑器（动态表单）+ 启停代理 |
| M2.3 | 第 26 周末 | 路由/DNS/VPN 设置 + 连接管理 + 图表 |
| M2.4 | 第 30 周末 | 平台功能（托盘/热键/系统代理/自启）完整 |
| **M2.0** | **第 32 周末** | **发布 `v5.0.0`：Flutter 桌面端正式版（Windows/Linux/macOS）** |

### 4.6 阶段二验收标准

- [ ] Flutter 桌面端功能对齐 C++ 版本，且支持新协议/新特性
- [ ] Windows / Linux / macOS 三端 GitHub Actions 构建通过
- [ ] 数据迁移工具能正确迁移老用户配置
- [ ] UI 风格现代化（Material 3 + 深色 + 卡片 + 图表）
- [ ] 性能：节点列表 1000+ 条流畅滚动
- [ ] 内存占用合理（< 200MB）
- [ ] 发布 `v5.0.0` Release

---

## 五、阶段三：移动端适配（第 33-48 周，可选）

### 5.1 目标

1. Android 端：通过 VpnService 集成 sing-box
2. iOS 端：通过 NetworkExtension 集成（需 Apple 开发者账号）
3. 复用 Flutter UI（90%+ 代码复用）

### 5.2 任务分解

| 编号 | 任务 | 周期 | 说明 |
|---|---|---|---|
| 17 | Android 工程初始化 | 第 33-34 周 | Flutter Android 平台 + gomobile 交叉编译 core |
| 18 | VpnService 集成 | 第 35-40 周 | sing-box for Android，TUN 走 VpnService |
| 19 | Android 平台适配 | 第 40-42 周 | 前台服务、通知栏、开机自启 |
| 20 | iOS 工程初始化 | 第 43-44 周 | Flutter iOS 平台 + NetworkExtension |
| 21 | iOS NetworkExtension | 第 44-47 周 | sing-box for iOS（需开发者账号） |
| 22 | 移动端 UI 适配 | 第 47-48 周 | 响应式布局、手势 |

### 5.3 阶段三 CI/CD

```yaml
# .github/workflows/build-mobile.yml
name: Build Mobile

on:
  push:
    branches: [feature/mobile]
  workflow_dispatch:

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      # 交叉编译 Android core (gomobile)
      - name: Build Android core
        run: |
          ./libs/get_source.sh
          cd go/cmd/nekobox_core
          # gomobile bind 或独立 .so
          ./build_android.sh

      # 构建 APK
      - run: cd nekoray_flutter && flutter build apk --release --split-per-abi
      - run: cd nekoray_flutter && flutter build appbundle --release

      - uses: actions/upload-artifact@v4
        with:
          name: nekoray-android
          path: |
            nekoray_flutter/build/app/outputs/flutter-apk/*.apk
            nekoray_flutter/build/app/outputs/bundle/release/*.aab
```

### 5.4 阶段三里程碑

| 里程碑 | 时间 | 交付 |
|---|---|---|
| M3.1 | 第 42 周末 | Android Beta（APK Release） |
| **M3.0** | **第 48 周末** | **`v5.1.0`：Android + iOS 正式版** |

---

## 六、GitHub 专项配置

### 6.1 分支保护规则

```yaml
# 对 main 和 dev 分支配置
分支保护:
  - 要求 PR 后才能合并
  - 要求 CI 通过（build-go-core, build-flutter, lint-test）
  - 要求至少 1 人 review
  - 禁止 force push
  - 分支自动删除（合并后删 head）
```

### 6.2 Issue / PR 模板

更新 `.github/ISSUE_TEMPLATE/`：
- 新增 `migration-issue.md`（迁移相关问题）
- 新增 `flutter-bug.md`

PR 模板 `.github/pull_request_template.md`：
```markdown
## 变更类型
- [ ] 阶段一（Go core）
- [ ] 阶段二（Flutter UI）
- [ ] 阶段三（移动端）
- [ ] Bug 修复
- [ ] 新功能
- [ ] 文档

## 关联 Issue
Closes #

## 变更说明

## 测试方式
- [ ] 本地构建通过
- [ ] CI 通过
- [ ] 功能测试通过

## Checklist
- [ ] 代码符合项目规范
- [ ] 已更新相关文档
```

### 6.3 项目看板

GitHub Projects 配置：
- **看板**：nekoray Flutter 迁移
- **列**：Backlog / Sprint / In Progress / Review / Done
- **标签**：`阶段一` `阶段二` `阶段三` `core` `flutter` `android` `ios` `bug` `feature`

### 6.4 缓存策略优化

现有 CI 缓存（`actions/cache@v3`）需升级：

| 缓存项 | key 策略 | 大小 |
|---|---|---|
| Go 模块 | `go-mod-${{ hashFiles('**/go.sum') }}` | ~500MB |
| Flutter pub | `flutter-pub-${{ hashFiles('**/pubspec.lock') }}` | ~200MB |
| Go core 构建 | `core-build-${{ matrix.goos }}-${{ hashFiles('go/**') }}` | ~50MB |
| sing-box 源码 | `singbox-src-${{ env.COMMIT_SING_BOX }}` | ~100MB |
| Gradle（Android） | `gradle-${{ hashFiles('**/*.gradle*') }}` | ~500MB |

### 6.5 Release 自动化

```yaml
# .github/workflows/auto-release.yml
# tag 推送时自动构建并发布
on:
  push:
    tags:
      - 'v*'

jobs:
  determine-version:
    runs-on: ubuntu-latest
    outputs:
      is_flutter: ${{ steps.check.outputs.is_flutter }}
    steps:
      - uses: actions/checkout@v4
      - id: check
        run: |
          if [[ "${{ github.ref_name }}" =~ ^v5 ]]; then
            echo "is_flutter=true" >> $GITHUB_OUTPUT
          else
            echo "is_flutter=false" >> $GITHUB_OUTPUT
          fi

  # 根据 is_flutter 调用不同构建流水线
```

---

## 七、风险管理

### 7.1 关键风险登记册

| ID | 风险 | 概率 | 影响 | 应对措施 | 触发条件 | 责任人 |
|---|---|---|---|---|---|---|
| R1 | sing-box 升级 breaking change 导致 core 无法编译 | 高 | 高 | 在 feature 分支实验；保留旧版回退；订阅 sing-box 更新日志 | 阶段一 M1.1 前 | core 开发 |
| R2 | ConfigBuilder 下沉 Go 生成配置不一致 | 中 | 高 | 编写等价性测试；逐协议迁移对比 | 阶段一 M1.2 前 | core 开发 |
| R3 | Flutter 桌面端性能不达预期（大列表卡顿） | 中 | 中 | 使用 ListView.builder 虚拟化；性能 profiling | 阶段二 M2.2 前 | Flutter 开发 |
| R4 | gRPC Dart 包桌面端兼容问题 | 低 | 中 | 备选 HTTP/JSON API（Go core 增加网关） | 阶段二 M2.1 前 | core 开发 |
| R5 | 移动端 VPN 集成受阻 | 高 | 高 | 桌面端先行；参考 karing 实现；Android 优先 iOS 次之 | 阶段三 M3.1 前 | 移动端开发 |
| R6 | 人力不足导致进度延期 | 高 | 致命 | 阶段一可独立交付；灵活调整阶段二范围 | 每月 review | 项目负责人 |
| R7 | 老用户数据迁移失败 | 中 | 高 | 提供迁移工具 + 旧版本保留 6 个月 | 阶段二 M2.4 前 | 全栈 |
| R8 | sing-box `boxapi` 包不再维护 | 中 | 高 | 评估直接用 upstream sing-box | 阶段一 M1.1 | core 开发 |

### 7.2 回退预案

| 场景 | 回退方案 |
|---|---|
| 阶段一 sing-box 升级失败 | 保留 1.13.19，先只做 ConfigBuilder 下沉（不依赖新版 API 的部分） |
| 阶段二 Flutter 进度严重滞后 | 阶段一成果（新 core + C++ UI）作为 v4.2.0 长期维护，等资源到位再启动 Flutter |
| 阶段三移动端不可行 | 桌面端独立交付，移动端无限期搁置 |

---

## 八、资源需求

### 8.1 人员配置（建议）

| 角色 | 人数 | 职责 | 阶段 |
|---|---|---|---|
| Go core 开发 | 1 | sing-box 升级、ConfigBuilder 下沉、gRPC 扩展 | 阶段一全程 |
| Flutter 开发 | 1-2 | UI 重写、状态管理、平台适配 | 阶段二全程 |
| 移动端开发 | 1 | Android/iOS VPN 集成 | 阶段三 |
| 测试 / QA | 0.5 | 等价性测试、回归测试、CI 维护 | 全程 |

**最小配置**：2 人（1 Go + 1 Flutter），桌面端约 9 个月。
**理想配置**：3 人（1 Go + 2 Flutter），桌面端约 7 个月。

### 8.2 GitHub 资源

| 资源 | 用途 | 额度需求 |
|---|---|---|
| GitHub Actions 分钟数 | CI/CD 构建 | ~3000 分钟/月（多平台矩阵） |
| Actions Cache | 依赖缓存 | ~3GB |
| Artifact 存储 | 构建产物 | ~5GB（14 天保留） |
| Release 存储 | 发布产物 | ~2GB/版本 |
| Packages（可选） | Docker 镜像（Linux 构建环境） | — |

**建议**：GitHub Pro（$4/月）或 Team 计划，确保 Actions 额度充足。

### 8.3 其他资源

| 资源 | 用途 | 说明 |
|---|---|---|
| sing-box 测试服务器 | 验证协议功能 | 自建或机场 |
| Apple Developer 账号 | iOS 构建 | $99/年（阶段三） |
| 代码签名证书 | Windows/macOS | 可选，社区版可不签名 |

---

## 九、质量保障

### 9.1 测试策略

| 层级 | 范围 | 工具 | 覆盖目标 |
|---|---|---|---|
| Go 单元测试 | ConfigBuilder、链接解析、路由生成 | `go test` | 核心逻辑 > 80% |
| Go 集成测试 | 配置等价性（C++ vs Go） | 对比 JSON | 关键路径 100% |
| Flutter 单元测试 | 数据模型、状态管理 | `flutter test` | 模型层 > 80% |
| Flutter Widget 测试 | UI 组件 | `flutter test` | 关键组件 100% |
| 集成测试 | 端到端流程 | `integration_test` | 核心流程 |
| 手动测试 | 多平台回归 | Checklist | 每次发版 |

### 9.2 配置等价性测试（关键）

```go
// go/core/config/equivalence_test.go
func TestConfigEquivalence(t *testing.T) {
    tests := []struct {
        name    string
        profile ProxyEntity
    }{
        {"vmess-basic", vmessProfile()},
        {"vless-reality", vlessRealityProfile()},
        {"trojan-ws", trojanWsProfile()},
        {"ss-plugin", ssPluginProfile()},
        {"hysteria2", hysteria2Profile()},
        {"tuic", tuicProfile()},
        {"chain", chainProfile()},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            goConfig := BuildConfig(&tt.profile, false, false)
            cppConfig := loadCppReference(tt.name) // 从 C++ 生成的参考 JSON
            assertConfigEquivalent(t, goConfig, cppConfig)
        })
    }
}
```

### 9.3 CI 质量门禁

每个 PR 必须通过：
- Go：`go vet` + `golangci-lint` + `go test`
- Flutter：`flutter analyze` + `flutter test` + `dart format --set-exit-if-changed`
- C++（过渡期）：`clang-tidy`（选择性）
- 构建验证：至少一个平台编译通过

---

## 十、总结与下一步

### 10.1 计划总结

| 阶段 | 周期 | 核心交付 | GitHub 产出 |
|---|---|---|---|
| 零 | 第 1 周 | 仓库 + CI 搭建 | 可用流水线 |
| 一 | 第 2-10 周 | Go core 升级 + 业务下沉 | `v4.2.0` |
| 二 | 第 11-32 周 | Flutter 桌面端 | `v5.0.0` |
| 三 | 第 33-48 周 | 移动端 | `v5.1.0` |

### 10.2 立即可执行的下一步

1. **本周内**：
   - [ ] Fork 仓库到 `rainsmen/nekoray`，配置 remote
   - [ ] 创建 `dev` 分支，配置分支保护
   - [ ] 验证现有 `build-nekoray-cmake.yml` 在新仓库可运行
   - [ ] 创建 `build-go-core.yml` 并验证多平台构建
   - [ ] 创建 GitHub Project 看板，导入阶段一任务

2. **第 2-4 周**：
   - [ ] 创建 `feature/core-v2` 分支
   - [ ] 解除 sing-box 版本锁定，升级到最新
   - [ ] 修复编译错误，CI 通过
   - [ ] 评估 `Matsuridayo/sing-box` fork 是否继续使用

3. **第 5-10 周**：
   - [ ] ConfigBuilder 逐模块下沉 Go
   - [ ] gRPC proto 扩展
   - [ ] 等价性测试编写
   - [ ] 发布 `v4.2.0`

### 10.3 关键决策点（需尽早确认）

| 决策 | 选项 | 建议 | 截止时间 |
|---|---|---|---|
| sing-box 来源 | `Matsuridayo/sing-box` fork vs `SagerNet/sing-box` upstream | 评估 fork 活跃度，不活跃则切 upstream | 阶段一第 2 周 |
| libneko 处理 | 保留独立 vs 合并进 nekobox_core | 评估耦合度，倾向合并 | 阶段一第 3 周 |
| 状态管理 | Provider vs Riverpod | Riverpod（更现代） | 阶段二第 11 周 |
| 数据存储格式 | JSON 文件 vs SQLite/Hive | 保持 JSON 兼容 + Hive 缓存 | 阶段二第 13 周 |
| 移动端是否做 | 做vs不做 | 桌面端稳定后再定 | 阶段二结束后 |

---

## 附录 A：完整任务清单（甘特图视角）

```
任务                     第1  5  10  15  20  25  30  35  40  45 48
                         |---|---|---|---|---|---|---|---|---|---|
阶段零 仓库+CI               ███
阶段一 Go core 升级+下沉          █████████
  1 sing-box 升级                   ███
  2 ConfigBuilder 下沉                ██████
  3 订阅解析下沉                      ████
  4 连接管理                           ██
  5 rule_set 更新                       ██
  6 迁移工具                             ██
  M1.0 发布 v4.2.0                        █
阶段二 Flutter 桌面端                       ███████████████████
  7 脚手架                                 ██
  8 gRPC 接入                               ██
  9 数据模型                                 ██
  10 主界面                                   ████
  11 协议编辑器                                   ███
  12 路由/DNS/VPN                                    ███
  13 连接+图表                                          ██
  14 平台功能                                            ████
  15 国际化                                                █
  16 迁移工具集成                                           █
  M2.0 发布 v5.0.0                                          █
阶段三 移动端                                                  ████████████
  17-22 Android/iOS                                             ████████████
  M3.0 发布 v5.1.0                                                   █
```

## 附录 B：GitHub Actions 工作流清单

| 工作流 | 文件 | 触发 | 用途 | 阶段 |
|---|---|---|---|---|
| Build Go Core | `build-go-core.yml` | push/PR/manual | 多平台编译 nekobox_core | 零+一+二+三 |
| Lint & Test | `lint-test.yml` | push/PR | 代码检查 + 单元测试 | 全程 |
| Build C++ UI | `build-nekoray-cmake.yml` | manual | 过渡期 C++ 版本构建 | 零+一 |
| Integration Test | `integration-test.yml` | push (feature分支) | 配置等价性测试 | 一 |
| Build Flutter | `build-flutter.yml` | push/PR/manual | Flutter 桌面端构建 | 二 |
| Build Mobile | `build-mobile.yml` | push/manual | Android/iOS 构建 | 三 |
| Release | `release.yml` | manual/tag | 统一发布流水线 | 一+二+三 |
| AUR CI | `update-pkgbuild.yml` | push (main) | AUR 包更新 | 过渡期 |

## 附录 C：关键文件索引

| 文件 | 用途 |
|---|---|
| `libs/get_source_env.sh` | sing-box 版本锁定（阶段一需修改） |
| `libs/build_go.sh` | Go core 构建脚本 |
| `libs/env_deploy.sh` | 部署环境变量 |
| `go/cmd/nekobox_core/go.mod` | Go 依赖（sing-box 版本） |
| `go/cmd/nekobox_core/grpc_box.go` | gRPC 服务实现（核心） |
| `go/grpc_server/gen/libcore.proto` | gRPC 接口定义（阶段一扩展） |
| `db/ConfigBuilder.cpp` | 配置构建逻辑（阶段一下沉到 Go） |
| `sub/GroupUpdater.cpp` | 订阅解析逻辑（阶段一下沉到 Go） |
| `fmt/*.hpp` | Bean 数据模型（阶段一Go重建） |
| `.github/workflows/build-nekoray-cmake.yml` | 现有 C++ 构建（过渡期保留） |
| `docs/Flutter迁移可行性分析报告.md` | 可行性分析依据 |

---

*计划结束*
