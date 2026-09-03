# `docs/CODE_REVIEW_REPORT.md` 复核结论

> **复核日期**：2026-08-23
> **复核基线**：`HEAD=115e4d6`（`5.0.0-beta.4`）以及当前工作区未提交改动。
> **目的**：核对原报告的结论是否仍适用于当前代码，区分 `Confirmed`、`Partial`、`Fixed` 和 `Needs verification`。
> **限制**：当前环境已临时提供 Go 1.22 工具链并完成 Go 测试；仍没有 Dart/Flutter 工具链，Flutter 结论以源码、测试文件、workflow 和脚本静态核对为主。

## 1. 总体判断

原报告同时包含：

- 基于旧提交 `2042df9` 的第一轮问题；
- 基于后续整改中间状态的 R1–R4 复评；
- 当前工作区已经继续修复后的代码状态。

因此，原报告中的“高 8、中 17、低 35+”不能直接当作当前问题统计。当前准确结论如下：

- 第一轮的大部分问题在当时确实成立；
- 当前工作区已经修复了版本比较、Flutter/移动 CI 失败门禁、订阅大小限制、并发 ID、迁移引用、更新重定向、FullTest 部分资源问题等；
- 当前仍开放的重点是：i18n 实际接入、macOS/Windows 实机发布验证、跨层测试，以及发布签名；Update 会话绑定、updater 回滚、构建依赖可复现性和 ruleset 索引已完成源码整改。
- R3 中 N1/N2/N3/N4/N5/N7 是中间快照问题，在当前工作区已不应继续标记为开放缺陷。

## 2. 当前确认仍存在的问题

### 2.1 更新 Check/Download 会话绑定（Fixed，需运行验证）

`go/grpc_server/update.go` 现按 gRPC metadata 中的 session ID 保存 Check 结果，Download 只消费同一 session，并限制 session 数量。Flutter client 提供对应的随机 session ID 和 metadata 发送方法。

**残留**：仍需在真实客户端并发场景运行验证。

### 2.2 更新器替换阶段完整回滚（Fixed，需运行验证）

`updater.go` 现在先解压到唯一 staging 目录并验证 `nekoray` payload，再通过 `replacePayload` 备份目标顶层条目、逐项安装，并在中途失败时恢复备份。

**残留**：仍需在 Windows/macOS 等真实文件系统上验证 rename 权限和异常路径。

### 2.3 Windows 父进程监督（Fixed，需运行验证）

当前增加了 `parent_death_windows.go`，通过 `OpenProcess + WaitForSingleObject` 等待父进程句柄；原先仅靠 PPID 轮询的问题已处理。仍需 Windows 实机验证权限不足、父进程快速退出等边界情况。

### 2.4 macOS updater/架构打包（Mostly fixed，需运行验证）

`build_go.sh` 现在构建 Darwin updater；release workflow 增加 macOS Intel 与 Apple Silicon 两条打包矩阵，package 脚本分别选择 `macos-amd64`/`macos-arm64` 并强制检查 updater。仍需在 CI 实际产物中验证架构和签名。

### 2.5 i18n 调用链部分接通（Partial，P2）

资源位于 `assets/l10n/`，Home/Settings 页面已开始使用 `I18n.t`，locale provider 也会随设置切换更新；其他页面仍有大量硬编码字符串。

**建议**：继续迁移 Routing/DNS/Profile/Connections 页面，最终统一到 `I18n.t()` 或官方 gen-l10n。

### 2.6 构建脚本执行 `go mod tidy`（Fixed，需 CI 验证）

`build_go.sh` 和 `build_android.sh` 已改为 `go mod verify` 与 `-mod=readonly`；依赖整理从构建路径移除。仍需 CI 实跑确认所有 module 的 go.sum 完整。

### 2.7 更新包仍缺发布者签名（Confirmed，P2）

ruleset manager 现将 `items` 原子持久化到 cacheDir/index.json，重启后可恢复已注册条目；更新包当前有 SHA-256，但没有发布者签名或公钥固定。签名缺失是供应链强化缺口，不能与“无 checksum”混为一谈。

## 3. 第一轮问题的状态对照

| 编号 | 当前状态 | 核验结论 |
|---|---|---|
| G-H1 代理注入 | Fixed in current worktree | HTTP 在 `main.go:24`、UDP 在 `main.go:25` 均已接线。 |
| G-H2 FullTest nil panic | Fixed | `grpc_box.go:129-132` 已检查 `in.Config == nil`。未配置 recovery 仍是独立改进项。 |
| G-H3 更新包无完整性校验 | Mostly fixed | 已有 HTTPS/host 白名单、状态码、大小上限、SHA-256、临时文件和绝对路径；代码签名仍缺。 |
| F-H1 配置非原子写 | Fixed | `_writeAtomic` 和损坏文件上报已加入。 |
| F-H2 时间戳 ID 冲突 | Fixed/Needs verification | 当前有串行分配和保留游标，`saveProfiles` 可恢复被覆盖旧文件。 |
| F-H3 编辑丢字段 | Mostly fixed | bean 增量合并和 schema 映射已补齐；应继续用 round-trip 测试覆盖所有协议字段。 |
| F-H4 routing 异步保存 | Fixed | 已改为显式 await。 |
| F-H5 测试接近于零 | Outdated | 当前已有 Go/Flutter 单元测试，但跨层和跨平台集成测试仍少。 |
| C-H1 CI 吞掉 Flutter 失败 | Fixed in current worktree | `build-flutter.yml` 和 `lint-test.yml` 已移除测试/格式吞错；仍需 CI 实跑确认。 |
| G-M1 ruleset 路径穿越 | Fixed | tag 白名单、绝对 cacheDir 和 `filepath.Rel` 校验已加入。 |
| G-M2 update 全局数据竞争/会话绑定 | Fixed in current worktree | mutex、session map 和 metadata session ID 已加入；仍需运行验证。 |
| G-M3 FullTest goroutine/竞态 | Mostly fixed | UDP channel/deadline、测速 body 生命周期已修复；`urlLatency` 仍使用 `context.Background()`，可继续改进。 |
| G-M4 nil slice | Fixed | 仅非空 slice 写入规则字段。 |
| G-M5 Exit 直接 os.Exit | Fixed/Needs verification | Exit 调度 GracefulStop，并通过 shutdown hook 释放 sing-box instance；仍需运行验证。 |
| G-M6 internal-full 吞错 | Fixed | JSON 解析错误写入 `BuildResult.Error`。 |
| F-M1 假在线状态 | Fixed | 连接后执行真实认证 RPC，并提供 health check。 |
| F-M2 流量 provider 全局空转 | Fixed/low residual | provider 已 autoDispose；断开 core 时暂停轮询仍可优化。 |
| F-M3/F-M4 DNS/Settings 假 UI | Mostly fixed | 已加入持久化和系统集成；各平台实际能力仍需构建运行验证。 |
| F-M8 i18n 未接线 | Confirmed | 资源加载与页面使用脱节，仍开放。 |
| C-M1 Go 版本错配 | Fixed | module 与 CI 已统一到 Go 1.24.x/1.24.7 系列。 |
| C-M2 构建期间 tidy | Fixed in current worktree | 构建脚本已改用 `go mod verify`/`-mod=readonly`。 |
| C-M3 覆写 CHANGELOG | Fixed | release workflow 使用临时 `RELEASE_NOTES.md`。 |
| C-M4 空壳 APK | Fixed in current worktree | 构建失败会阻断，artifact 缺失会失败；仍需 CI 实跑。 |
| C-M5 无 checksum | Fixed/partial | SHA256SUMS 已生成并由 updater 使用；签名仍缺。 |
| C-M6 macOS updater | Mostly fixed | updater 已构建，发布矩阵已拆分 Intel/Apple Silicon；仍需 CI 产物验证。 |
| C-M7 缺少高级 lint | Partial | vet/race/govulncheck 已有，golangci-lint/staticcheck 仍未强制。 |
| C-M8 版本不一致 | Fixed in current worktree | pubspec、version 文件和 Go 当前均为 beta.4；仍建议建立单一版本源。 |

## 4. 原报告中已经过时或明显过度的结论

1. **G-H1“HTTP/UDP 全部直连”**：HTTP 后续已接线，当前 UDP 也已接线；只能保留为历史问题。
2. **F-H2“连续双击即可撞 ID”**：算法有碰撞风险，但不是稳定必现故障；当前分配器已改进。
3. **F-M2“整个应用生命周期每秒空转”**：当前 provider 已 autoDispose。
4. **F-M5/F-M6 旧版 loading/error、删除无确认**：当前 home 页面已有错误提示、确认框和反馈。
5. **F-M11“无 token 可直接控制核心”**：当前有 localhost + token 认证；剩余风险是 token 参数泄漏、明文 loopback 和凭据存储策略。
6. **API 兼容性猜测**：`initialValue`、`withValues` 与最低 SDK 的关系必须用实际 Flutter 版本构建验证，不能静态断言必然失败。
7. **R3 N1/N2/N3/N4/N5/N7**：这些是中间快照中的缺陷，当前工作区已分别通过 `formKey`、SemVer、环境继承、逐跳重定向、`O_EXCL` 和空字段收集路径处理；不应继续列为当前开放问题。

## 5. 当前需要验证而非直接定性的项目

- Go 已执行 `go test ./...`、`go test -race ./...`、`go vet ./...`，并完成 Windows/macOS/Linux 交叉编译检查；Dart/Flutter 仍需执行 format/analyze/test；
- macOS/Android/Windows/Linux 实际产物内容与架构；
- Windows Job Object/父进程退出行为；
- profile 编辑、迁移、批量导入失败回滚的 round-trip；
- sing-box 对空字符串、规则字段和自定义配置的真实校验行为。

## 6. 最终结论

原报告第一轮的主要风险识别总体有效，但状态已经明显滞后。当前不应再把已修复的 N1/N2/C-H1/G-M6 等项目列为 P0；当前发布前优先级应调整为：

1. 验证 updater 事务回滚和跨平台 rename 边界；
2. Windows 父进程监督；
3. macOS updater 与 arm64/universal 发布；
4. 更新 Check/Download 会话绑定；
5. i18n 全页面接线与 updater 完整回滚；
6. 在完整工具链环境执行全量验证。

## 7. 本轮代码状态记录

本报告只描述当前代码，不声称本地工具链验证通过。当前工作区已有的代码改动包括：SemVer、更新重定向、FullTest 资源处理/UDP 接线、internal-full 错误、CI 失败门禁、环境变量继承、并发 ID、迁移引用、ruleset HTTPS、动态表单字段清理、StatusBar 流量和 updater `O_EXCL` 等。
