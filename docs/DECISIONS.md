# 阶段一技术决策记录

## 决策 D1：sing-box 来源切换（2025-08-20 确定）

### 背景
- 当前使用 `MatsuriDayo/sing-box` fork（commit 06557f6，基于很老的 sing-box）
- 该 fork 最后更新于 2023-03-31，已停更 2 年多
- 上游 `SagerNet/sing-box` 最新版 v1.13.19（2026-08-17 发布）

### 调查发现
MatsuriDayo fork 提供了三个定制包，上游 v1.13.19 的等价实现如下：

| MatsuriDayo 定制 | 用途 | 上游 v1.13.19 等价 |
|---|---|---|
| `boxmain.Create(config)` | 从 JSON 创建 Box 实例 | `option.Options.UnmarshalJSON()` + `box.New()`（上游 `box.New` 已含 Start 逻辑，需手动调 `.Start()`） |
| `boxapi.DialContext/DialUDP/CreateProxyHttpClient` | 通过 Box 实例拨号 | `dialer.NewRouter(router).DialContext()` 等（上游 `common/dialer` 包） |
| `boxapi.SbV2rayServer` + `option.V2RayStatsServiceOptions` | 流量统计 | 上游 `experimental/v2rayapi`，通过 `option.V2RayAPIOptions` + `experimental.NewV2RayServer()` |
| `boxapi.NewSbV2rayServer` + `Router().SetV2RayServer()` | 注入统计服务 | 上游在 `box.New()` 内自动创建，通过 `service.MustRegister[adapter.V2RayServer]` 注册，用 `service.FromContext[adapter.V2RayServer](ctx)` 获取 |

### 决策
**切换到 SagerNet/sing-box upstream v1.13.19**，放弃 MatsuriDayo fork。

### 理由
1. fork 已停更 2 年，无法获得 rule_set/sniffer 新结构/endpoint 等关键特性
2. 上游 v1.13.19 已包含等价 API，只是接口形态不同（用 service 注册而非 Router 方法）
3. 上游有完善的 `experimental/v2rayapi`（含 stats gRPC），无需自建统计服务

### 影响代码
- `go/cmd/nekobox_core/core_box.go`：重写 setupCore（DialContext/DialUDP/HttpClient）
- `go/cmd/nekobox_core/grpc_box.go`：重写 Start/Stop/Test/QueryStats/ListConnections
- `go/cmd/nekobox_core/go.mod`：改为 `github.com/sagernet/sing-box v1.13.19`，移除 replace
- `libs/get_source_env.sh`：更新 commit 或改为直接用 release tag
- `libs/get_source.sh`：改为 clone SagerNet/sing-box

### 风险
- `libneko` 仍依赖 MatsuriDayo（`neko_common`/`neko_log`/`speedtest`），需评估是否保留或内联
  - `neko_common.GetCurrentInstance/DialContext/DialUDP/CreateProxyHttpClient`：可在 core_box.go 重新实现
  - `neko_log`：日志可换用 sing-box 自带 logger
  - `speedtest`：URL 测试可自行实现（逻辑简单）或保留 libneko

### 状态
- ✅ 已完成（2025-08-22）：sing-box 从 MatsuriDayo fork 切换到上游 v1.13.19
- ✅ 多平台 CI 编译通过（windows/linux/darwin amd64+arm64）
- ✅ go vet / go build 通过
- 关键发现：上游已废弃 `with_ech` build tag（迁移到 stdlib），需从 build_go.sh 移除
- 关键发现：上游 `cmd/sing-box` 是 package main 无导出 Main()，nekobox_core 不再委托 CLI
- go.sum 由 `sync-go-sum` workflow 自动生成并提交回仓库

## 决策 D2：libneko 处理（2025-08-20 确定）

### 决策
**阶段一暂时保留 libneko，但内联其必要逻辑到 nekobox_core，中期目标是移除 libneko 依赖。**

### 理由
- libneko 提供 `neko_common`（实例管理）、`neko_log`（日志）、`speedtest`（测速）
- 这些功能可逐步用上游 sing-box API 替代
- 但立即移除会破坏 grpc_server 和 fulltest.go，工作量大
- 分步走：先让 core 能用上游 sing-box 编译，再逐步清理 libneko

### 计划
1. 阶段一 M1.1：保留 libneko，但 core_box.go 改用上游 dialer API
2. 阶段一 M1.2：评估 `speedtest` 能否用 sing-box 内置 URL test 替代
3. 阶段一 M1.3：移除 libneko 依赖，或将其合并进 nekobox_core 仓库

### 实际结局（2026-08-23，beta.3 已落实）
libneko 已彻底移除（32,139 行旧 C++/Qt 代码一并删除），core 改用原生 Go 拨号与测速。本决策关闭。

## 决策 D3：ConfigBuilder 下沉 Go（2026-08 确定，已落实）

sing-box 是 Go 库，配置生成放在 Go core 是单一真相源；Flutter 只拼 profile/group/routing/datastore 四段 JSON 发 `BuildConfig`。避免两套实现漂移。

## 决策 D4：JSON 文件存储，不用 Hive（2026-08 确定，已落实）

与旧版 C++ nekoray 磁盘布局兼容（profiles/groups/routing），迁移工具可直接读写；原子写（tmp + rename）保证崩溃不丢半截文件。

## 决策 D5：手写 Dart 数据类，不用 freezed（2026-08 确定，已落实）

避免 build_runner 代码生成冲突；bean 负载保持原始 map 透传——UI 不认识的协议字段也能 round-trip，编辑节点不再丢传输配置。

## 决策 D6：token 只走环境变量（2026-09 确定，已落实）

argv 全局可读，`--token` 明文会进进程表；改为 `NEKORAY_AUTH_TOKEN` 环境变量，core 读取后 unset。

## 决策 D7：rule_set 替代 geosite/geoip（2026-08 确定，已落实）

sing-box 1.12+ 移除了 geosite 数据库，全部引用迁移为二进制 `.srs` rule_set，core 负责下载缓存。

## 决策 D8：日志内存 + 文件双通道（2026-09 确定，已落实）

内存 500 行供日志页实时查看；同时 append 到 `<appDir>/logs/core-YYYY-MM-DD.log`（2 MiB 轮转），重启后仍可排查 TUN/启动失败。
