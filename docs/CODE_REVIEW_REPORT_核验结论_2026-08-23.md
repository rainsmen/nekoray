# `CODE_REVIEW_REPORT.md` 评估结论核验（统一状态版）

> **核验日期**：2026-08-23
> **对象**：`docs/CODE_REVIEW_REPORT.md`、`docs/CODE_REVIEW_REPORT_复核_2026-08-23.md`、`docs/代码与项目评估报告_2026-08-23.md`
> **基线**：`HEAD=115e4d6`（`5.0.0-beta.4`）+ 当前工作区未提交改动。
> **说明**：本文用于解释三份报告之间的差异；不替代源码测试。当前环境已临时提供 Go 1.22 工具链并完成 Go 测试；仍没有 Dart/Flutter 工具链。

## 1. 统一结论

三份报告曾混用旧提交 `2042df9`、整改提交 `668baa2`/`115e4d6` 和当前未提交工作区，导致同一问题同时出现“已修复”和“仍存在”两种说法。统一口径如下：

- **Confirmed**：当前源码仍能直接证明的问题；
- **Partial**：已有修复，但仍有残留或业务层缺口；
- **Fixed**：当前源码已覆盖原问题，仍需工具链运行验证；
- **Needs verification**：只能静态推测，不能直接判定。

## 2. 当前 Confirmed / Partial

| 项目 | 状态 | 证据与结论 |
|---|---|---|
| updater 失败回滚 | Fixed/Needs verification | 已先 staging 解压并验证 payload，并通过备份目录和失败恢复处理替换中途错误；仍需跨平台运行验证。 |
| Windows 父进程监督 | Fixed/Needs verification | 新增 Windows 父进程句柄等待；仍需 Windows 实机验证。 |
| macOS updater/arm64 打包 | Mostly fixed/Needs verification | updater 已构建，release/package 已拆分 Intel 与 Apple Silicon；需 CI 产物验证。 |
| Update Check/Download 会话绑定 | Fixed/Needs verification | session metadata + per-session map 已替代单一槽位；需并发集成测试。 |
| 构建期间 `go mod tidy` | Fixed/Needs verification | build_go/build_android 已改用 verify/readonly。 |
| i18n 实际使用 | Partial | Home/Settings 已调用 `I18n.t`，其他页面仍有硬编码。 |
| ruleset 索引持久化 | Fixed/Needs verification | manager 通过 cacheDir/index.json 原子持久化注册信息；仍需运行验证重启恢复。 |
| 发布签名/SBOM/provenance | Confirmed | SHA256SUMS 已有，发布者签名和 provenance 未建立。 |
| 批量导入旧文件恢复 | Fixed/Needs verification | saveProfiles 已备份并恢复被覆盖文件，新增 Flutter 测试。 |

## 3. 当前 Fixed、不可继续列为开放缺陷

| 原报告项目 | 当前状态依据 |
|---|---|
| N1 vmess `sec` 重复键 | `protocol_schema.dart` 已引入 `formKey/inputKey`，vmess encryption 使用独立表单键。 |
| N2 SemVer 字典序错误 | `update.go` 已按预发布标识符比较数字段并忽略 build metadata。 |
| N3 子进程环境被整体替换 | `core_process.dart` 使用 `{...Platform.environment, token}`。 |
| N4 更新重定向绕过 host 白名单 | `clientWithUpdateRedirectPolicy` 对每一跳校验。 |
| N5 updater 注释与 O_EXCL 不符 | `writeEntry` 已实际使用 `os.O_EXCL`。 |
| N7 可选字段完全无法清空 | `collect(includeEmptyOptional: true)` 已提供清空路径；仍需 round-trip 测试边界字段。 |
| FullTest nil panic | `grpc_box.go` 已检查 `in.Config == nil`。 |
| 配置非原子写、规则集 tag 穿越、固定 `.tmp` | 分别已有 `_writeAtomic`、tag 白名单/Rel 校验、`CreateTemp`。 |
| 旧时间戳 ID、迁移引用缺失 | 当前有 ID 分配 gate，migration 重写 group order/frontProxyId。 |
| CI 吞测试/格式失败、移动 CI 空壳 | 当前 workflow 已移除吞错和 `continue-on-error`，artifact 缺失失败。 |
| 版本 beta.3/beta.4 与测试覆盖接近零 | 当前版本文件已 beta.4；已有 Go/Flutter 单元测试。 |

## 4. 原报告中过度或错误的表述

1. **“HTTP 和 UDP 全部直连”**：HTTP 后续已接线，当前 UDP 也已接线；只能作为历史快照描述。
2. **“双击即可撞 ID”**：算法曾有碰撞风险，但不是必现；当前已改进分配器。
3. **“整个应用每秒空转”**：traffic history provider 当前 autoDispose，最多是断开 core 后的低成本优化。
4. **“无 token 可直接控制核心”**：当前有 localhost token 鉴权；剩余是 CLI token 泄漏、loopback 明文和密钥存储风险。
5. **“API 必然编译失败”**：Flutter API 兼容性需要最低版本构建验证。
6. **“无签名就是已发生漏洞”**：应描述为供应链强化缺口；checksum 已解决传输损坏检测，不等于发布者身份认证。

## 5. 当前需工具链验证

- Go modules 已执行 `gofmt`、`go vet`、`go test ./...`、`go test -race ./...`，并完成 grpc_server 的 Windows/macOS/Linux 交叉编译检查；
- Windows/macOS release workflow 的实际产物和父进程监督；
- Flutter `dart format`、`flutter analyze`、`flutter test`；
- Android/macOS/Windows/Linux 产物中的 core、updater、ABI；
- Windows 父进程监督；
- profile round-trip、迁移失败回滚和 Update session 并发行为；
- sing-box 对生成配置的实际 validate 结果。

## 6. 维护建议

后续评估报告必须在每个条目中同时写明：

- 基线提交；
- 当前状态（Confirmed/Partial/Fixed/Needs verification）；
- 当前源码证据；
- 是否已经由工具链验证。

这样可以避免把中间快照问题（N1/N2/N3/N4/N5/N7）继续当作当前问题，也避免把已修复项目计入 P0/P1 统计。
