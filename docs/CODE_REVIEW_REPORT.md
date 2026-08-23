# nekoray 代码评估报告

> 审查日期：2026-08-23 · 分支：dev（2042df9，v5.0.0-beta.3）
> 范围：`go/` 全部非生成代码、`nekoray_flutter/lib` 全部非生成代码、`libs/*.sh`、`.github/workflows/*`
> 性质：只读评估，未修改任何代码。行号以 HEAD 为准。
>
> **⚠️ 本文第一轮评估结论已部分过时**：2026-08-23 晚些时候进行了一轮大规模整改
> （见 `docs/代码评估报告_Claude_2026-08-23.md` 附录「整改记录」，约 4090 行新增/修改，
> 含工作区未提交改动）。**文末新增了第二轮复评章节**，逐项核实修复情况并列出
> 整改新引入的问题，请以复评章节为准。

---

## 一、总体结论

架构方向正确（Flutter 瘦客户端 + Go/sing-box 核心 + localhost gRPC），安全基线（localhost 监听、常量时间 token 比较）、实例生命周期锁纪律、规则集原子写入等做得不错。但存在 **3 个核心功能正确性缺陷、多处可导致静默数据丢失的 UI 层缺陷、更新链路缺完整性校验**，以及 **CI 存在吞掉测试失败、版本错配** 等工程化问题。测试覆盖两端都接近于零，是当前最大的回归风险。

问题统计：高严重度 8 项 · 中严重度 17 项 · 低严重度 35+ 项。

---

## 二、高严重度问题（建议尽快修复）

### Go 核心

**G-H1. 代理 HTTP 客户端 / UDP 拨号注入从未接线 —— 测速与更新实际走直连**
- 位置：`go/grpc_server/fulltest.go:36-45, 196-213`；`go/grpc_server/update.go:24-31`；`go/cmd/nekobox_core/core_box.go:129-138`
- `SetProxyHttpClientFactory()` / `SetUdpDialFunc()` 注入点已定义但全仓库无任何调用；`resolveProxyClient()` 为死代码。后果：`DoFullTest` 的延迟测试、出口 IP 探测、下载测速，以及默认 UDP 拨号（直连 `8.8.8.8:53`）全部绕过 sing-box 实例——代理完全不可用时测速仍可能显示正常，订阅更新也不经代理下载。
- 建议：在 `cmd/nekobox_core` 启动时完成注入，或将 `DoFullTest` 重构为直接接收 `*box.Box` 并内部构造客户端。

**G-H2. `TestMode_FullTest` 分支空指针解引用可 panic 整个核心进程**
- 位置：`go/cmd/nekobox_core/grpc_box.go:115-121`
- UrlTest 分支有 `if in.Config != nil` 保护，FullTest 分支直接 `in.Config.CoreConfig` 无检查；gRPC 服务端未注册 recovery 拦截器，handler panic 会连带杀死所有正在运行的代理实例。
- 建议：补 nil 检查并返回 `ErrorResp`；加 `grpc_recovery` 统一兜底。

**G-H3. 更新包无完整性校验即落盘并被 updater 解压执行（供应链风险）**
- 位置：`go/grpc_server/update.go:101-127`；`go/cmd/updater/updater.go:20-70`、`main.go`
- 下载无 checksum/签名校验；`resp.StatusCode` 未检查（403/404 的 HTML 会存成 zip）；`io.Copy` 无大小上限；写入路径 `../nekoray-update.zip` 依赖进程 CWD。
- 建议：校验 sha256 或 minisign 签名；基于 `os.Executable()` 用绝对路径；`io.LimitReader` 限长。

### Flutter UI

**F-H1. 配置写入非原子 + 加载错误静默吞掉 → 崩溃后节点"凭空消失"**
- 位置：`lib/core/storage/local_store.dart:45, 51-56, 68-82, 105-108`
- 三个 save 方法直接覆盖写文件，进程中途被杀产生截断 JSON；`loadProfiles()` 等 `catch (_) {}` 静默跳过，用户无感知数据丢失。
- 建议：临时文件 + `rename()` 原子替换；加载失败记录日志并上报损坏文件。

**F-H2. Profile ID 生成算法易冲突，静默覆盖已有节点**
- 位置：`lib/core/state/providers.dart:63-66, 98-102`；`lib/ui/pages/profile/profile_edit_dialog.dart:155-156`
- ID = `毫秒时间戳 % 1000000 (+ 字节数 % 1000)`，空间极小；与磁盘已有 ID 冲突时 `saveProfile` 直接覆盖同名 JSON。双击 "Create" 两次即可撞 ID。
- 建议：改用 UUID 或自增 ID；保存前检查目标文件是否存在。

**F-H3. 编辑 profile 丢失表单未覆盖的字段 —— wireguard/SSH 私钥保存即失效**
- 位置：`lib/ui/pages/profile/profile_edit_dialog.dart:135-190`（`_buildEntity`）
- 编辑时新建对象而非增量合并：原 `StreamSettings` 只回填 5 个字段（`network/security/alpn/wsPath/wsHost/grpcServiceName/certificates` 等全部丢弃）；schema 中 wireguard `privateKey/address/mtu/peer*`、ssh `private_key*/user`、naive/anytls `allowInsecure` 等 key 完全没有映射到 bean/stream。
- 建议：编辑基于 `existing.toJson()` 增量合并；schema 声明字段→bean/stream 映射，未知 key 透传进自定义 outbound JSON。

**F-H4. RoutingConfigNotifier 持久化实际未被 await —— fire-and-forget + 并发丢失更新**
- 位置：`lib/ui/pages/routing/routing_page.dart:167-181, 190-205`
- `await state.whenData((c) async {...})` 对非 Future 的 AsyncValue 只是立即返回自身，内部 async 闭包不被等待：`saveRouting` 异常成为未处理异步错误；快速连续操作对同一份旧 state 读改写导致丢失更新。
- 建议：先 `state.valueOrNull` 同步取值，再 await 保存并 try/catch 反馈。

**F-H5. 两端测试覆盖几乎为零**
- 位置：`test/smoke_test.dart`（唯一断言是 `expect(1+1, 2)`）；Go 侧仅 `link_test.go`、`build_test.go`
- 最易回归的纯逻辑（路由编译 `_compileRuleToSingBox`、模型序列化往返、LocalStore、ID 冲突、makeRule）全部无测试。
- 建议：按 models 序列化 → routing 编译 → LocalStore → provider 逻辑顺序补齐单测。

### 构建脚本 / CI

**C-H1. CI 吞掉 Flutter 测试失败 + 格式检查形同虚设**
- 位置：`.github/workflows/build-flutter.yml`
  - `flutter test --coverage || echo "no tests yet"` —— **测试失败也绿灯**；
  - `dart format --set-exit-if-changed . || dart format .` —— 检查失败时自动改写再通过，检查无效；
  - `codecov-action` 上传的因此是无意义覆盖率。
- 建议：移除两处 `||` 回退。

---

## 三、中严重度问题

### Go 核心

| # | 位置 | 问题 | 建议 |
|---|------|------|------|
| G-M1 | `core/ruleset/manager.go:94`（配合 `ruleset.go:24`） | `tag` 来自 gRPC 请求未校验即拼路径，存在路径穿越（可写缓存目录外文件，固定 `.mrs/.json` 后缀限制了利用面）；默认 cacheDir 相对路径依赖 CWD | 正则 `^[A-Za-z0-9._-]+$` 校验 tag；显式传绝对路径 |
| G-M2 | `update.go:15, 91, 103` | 全局 `update_download_url` Check 写 / Download 读，无锁 → 数据竞争，且并发 Check 可导致下载到别的版本 | mutex 保护或把 URL 作为 Download 入参回传 |
| G-M3 | `fulltest.go:55-90, 122-158` | UDP 测试 goroutine 阻塞在 `pc.Read` 后向无缓冲 channel 发送永久泄漏；测速 goroutine 与主 goroutine 对 `bodyClose` 存在数据竞争；超时路径泄漏并持有 `resp.Body` | channel 缓冲容量 1；关闭逻辑放进 goroutine 内 defer；UDP 读设 deadline |
| G-M4 | `core/config/chain.go:157-208` | `makeRule` 将 nil 切片序列化为 `"ip_cidr":null` 等，sing-box 解析 null 数组报错——含纯 geoip/geosite 规则的配置无法启动 | 仅非空才写 key |
| G-M5 | `grpc.go:29-33` | `Exit` RPC 直接 `os.Exit(0)`，跳过 instance.Close()，TUN/auto_route/系统代理状态可能残留 | 先执行 Stop 清理再退出 |
| G-M6 | `core/config/build.go:83-93` | custom bean `internal-full` 分支解析失败静默返回空配置（无 outbounds/inbounds），下游行为不可预测 | Unmarshal 失败即设置 `result.Error` |

### Flutter UI

| # | 位置 | 问题 | 建议 |
|---|------|------|------|
| F-M1 | `grpc_client.dart:19-44`、`grpc_provider.dart:12-32` | `isConnected => _channel != null` 是假状态（ClientChannel 懒连接，core 不存在也显示已连接）；无重连逻辑、不监听连接错误 | RPC 探活后再置状态；监听 onConnectionError 驱动重连 |
| F-M2 | `connections_page.dart:31-58` | 流量轮询 Timer 挂在非 autoDispose provider 上，整个应用生命周期每秒空转（即使页面未打开、core 未运行） | autoDispose 或由连接状态控制启停 |
| F-M3 | `dns_page.dart` 对照 `routing_page.dart:373-424` | DNS 页所有设置仅存内存不落盘；启动 core 时 `remote_dns` 硬编码 `'8.8.8.8'`——DNS 页是"假 UI" | 设置并入持久化存储并在 toGrpcRouting 读取 |
| F-M4 | `settings_page.dart`、`home_page.dart:46` | 所有设置仅存内存重启归零；`connectToCore` 固定 port 19821，改 "Core gRPC Port" 无效；tunMode/systemProxy 开关无平台实现但用户以为生效了 | 引入 settings 持久化；未实现功能禁用并标注 |
| F-M5 | `home_page.dart:104-110` | `filteredProfilesProvider` 用 `valueOrNull ?? []`，loading/error 渲染成误导性空列表，无重试入口 | 按 `.when` 分支渲染 |
| F-M6 | `home_page.dart:364-369` | 删除节点无确认框、无错误反馈，且可删除正在使用的节点（UI 与 core 状态脱节） | 加确认；await 后反馈；当前连接节点先 stopCore |
| F-M7 | `grpc_provider.dart:17-32` | core 层依赖 `WidgetRef`（反向依赖 UI）；await 之后使用 ref，Widget 销毁时抛异常 | 改接受 `Ref`，封装成 grpcConnectProvider |
| F-M8 | `i18n.dart` 全文 + 各页面 | i18n 体系（含 zh/en JSON 词条）完整存在但零引用，全 app 硬编码英文；静态全局词表与 FutureProvider 缓存并存有竞态 | 统一走 provider 注入或迁移官方 gen-l10n |
| F-M9 | `dns_page.dart:136-146` | `TextFormField(initialValue:)` 在 preset 切换后不随 provider 更新——界面显示旧值、实际已是新值 | 受控 controller 同步，或加 key 强制重建 |
| F-M10 | `dynamic_form.dart:60-77, 104-121` | combo 现值不在 options 时静默回退第一项（一保存就篡改存量值）；`required` 定义了但从不校验；number 非法输入吞成 0 | 保留原值追加 "(current)"；接 Form validator |
| F-M11 | `local_store.dart` 设计 + `grpc_client.dart:29-38` | 凭据（密码/UUID/私钥）明文美化 JSON 落盘；gRPC insecure 且默认 token 为空、UI 无 token 入口——本机其他进程可直连 19821 控制核心 | 目录 chmod 700；默认随机 token；评估 flutter_secure_storage |

---

## 四、低严重度问题（择要）

### Go 核心
| # | 位置 | 问题 |
|---|------|------|
| G-L1 | `sub/link.go:561-576` | IPv6 ss 链接解析后地址带括号存储，序列化双重加括号产出非法配置；port==0 不校验 |
| G-L2 | `fulltest.go:17-27` | `getBetweenStr` start 未命中时截掉开头字符 |
| G-L3 | `update.go:82-84` | 版本比较用子串匹配（"5.0.0" 匹配 "5.0.01"），依赖 releases 返回顺序 |
| G-L4 | `ruleset/manager.go:88` | 固定 `.tmp` 文件名，同 tag 并发下载竞态 |
| G-L5 | `grpc.go:55-60` | 父进程轮询间隔 10s，GUI 死亡后核心最长存活 10s 占用端口/TUN |
| G-L6/L8 | `build.go:100,133`、`outbound.go` | `domain_strategy`/`security`/`packet_encoding` 空字符串仍写入，可能被 sing-box 校验拒绝 |
| G-L7 | `chain.go:229-233` | `if cb, ok := ...; ok { _ = cb }` 死代码；getCustomOutbound 与 CustomOutbound 字段机制重复 |
| G-L9 | `outbound.go parseInt` | 手写解析遇负数静默返回 0（用于 `?ed=` 和 WireGuard reserved），应改 strconv.Atoi |
| G-L10~L12 | `cmd/updater/*`、`grpc.go:104-114` | Copy 错误全忽略且仍继续；Linux 先删 `./usr` 再解压失败留残缺安装；flag.Parse 错误忽略、兼容函数无调用者 |
| G-L13/L14 | `sub/link.go parseAuto`、`filter.go` | base64 探测过宽松误判原始链接；手写 itoa 替代标准库 |
| G-L15/L16 | `migrator/main.go`、`fmt/entity.go` | MkdirAll 错误忽略；DecodeBean 失败仍返回部分填充 bean |

### Flutter
| # | 位置 | 问题 |
|---|------|------|
| F-L1 | `main.dart` | 缺 `WidgetsFlutterBinding.ensureInitialized()` 与全局错误兜底（runZonedGuarded/FlutterError.onError） |
| F-L2 | `home_page.dart:132` | 搜索框无防抖，每键入一字整表 rebuild |
| F-L4 | `home_page.dart:245-248, 337-340` | StatusBar 流量硬编码 0（queryStats→UI 未打通）；startCore 未传 statsOutbounds，core 可能没注册 stats |
| F-L5/L6 | `home_page.dart:47, 305-315` | connectToCore 失败被 `catch (_) {}` 吞掉；selectedGroupProvider（筛选器）语义混用作 group 来源 |
| F-L7 | `local_store.dart:53,80` | 文件名 id 来自外部 JSON 未消毒，理论路径穿越 |
| F-L8~L10 | `profile.dart`、`protocol_schema.dart` | toJson 展开 bean 后又重写 'stream' 键冗余易漂移；`ProxyType.quic='hysteria2'` 命名误导 + 死代码方法；wireguard/naive schema key camelCase 与其余 snake_case 不一致 |
| F-L11/L12 | `routing_page.dart` | port `int.parse` 抛 FormatException 报错难懂；`_detectPresetName` 启发式会误判手工编辑过的规则集 |
| F-L15/L16 | `responsive_layout.dart`、`migration.dart` | 两组件零引用死代码；DataMigration 从未被调用，迁移功能不可达（Windows 下 APPDATA null 还会拼出 "null/nekoray"） |
| F-L18/L19 | `analysis_options.yaml`、`grpc_provider.dart` | 显式关闭 prefer_const 系列 lint；ref.onDispose 返回的 Future 未处理 |

---

## 五、构建脚本与 CI 问题

| # | 位置 | 问题 | 建议 |
|---|------|------|------|
| C-M1 | `go.mod` vs CI | `go/cmd/nekobox_core/go.mod` 要求 `go 1.24.7`，CI 全部装 Go `1.22`（靠 GOTOOLCHAIN 自动下载兜底，慢且不可控）；且 `grpc_server/go.mod` 是 `go 1.22`——双模块版本不一致 | CI 升到 1.24.x；统一两个模块版本 |
| C-M2 | `libs/build_go.sh:40` | 发布构建时执行 `go mod tidy` 改写 go.mod/go.sum——构建产物不可复现；仓库里甚至需要专门的 sync-go-sum.yml 工作流来收拾后果 | tidy 移出构建脚本，依赖变更走 PR |
| C-M3 | `release.yml:143+` | 每次 release 用硬编码模板**覆写仓库 CHANGELOG.md**——破坏性且内容千篇一律 | 从 git log / 标签生成 changelog，不改仓库文件 |
| C-M4 | `release.yml`、`build-mobile.yml` | Android core 构建 `continue-on-error: true` 失败后照常打包 APK——可能发出**不带核心 .so 的空壳 APK**；NDK 版本硬编码 27.0.12077973 | 移除 continue-on-error，缺产物即 fail；NDK 版本参数化 |
| C-M5 | `release.yml` | 发布资产无 sha256sums、无签名（macOS/Windows 未签名公证）——结合 G-H3 放大供应链风险 | 生成 checksums 文件并上传；规划代码签名 |
| C-M6 | `libs/build_go.sh` | darwin 上 updater 从不构建（`[ darwin ] || go build`），而 package_flutter_release.sh 用 `\|\| true` 静默容忍复制失败——**macOS 包静默缺失 updater/migrator**；另 `[ -z $DEST ]` 变量未加引号 | 明确各平台构建矩阵，缺失即报错 |
| C-M7 | `lint-test.yml` | 名为 Lint 实际只有 vet+build+test，无 golangci-lint/staticcheck；`cd ../../grpc_server` 相对路径脆弱 | 引入 golangci-lint；用 working-directory |
| C-M8 | 版本一致性 | `pubspec.yaml` version=5.0.0-beta1 vs `nekoray_version.txt`=5.0.0-beta.3；Android 平台目录（android/）未入库，靠 CI `flutter create` 现场生成——无签名配置、无可控 Manifest | 统一单一版本源；提交 android/ 工程 |
| C-L1 | `libs/get_source*.sh` | `version_standalone` 等死变量残留；注释"# 下次改"遗留 | 清理 |

---

## 六、API 兼容性风险（需运行工具链验证）

- `DropdownButtonFormField(initialValue:)` 出现于 `dynamic_form.dart:117`、`profile_edit_dialog.dart:71`、`routing_page.dart:513,527`——该参数是较新 Flutter（约 3.32+）才引入的；pubspec 声明 `sdk: >=3.3.0`，在下界 SDK 上**预计编译失败**。同类：`Color.withValues()`（proxy_card.dart:59，需 3.27+）、`scheme.surfaceContainer*`（需 3.22+）。
- pubspec 已开 `generate: true` 但 l10n 资产是 .json 非 .arb，`flutter gen-l10n` 是否报错未验证。
- 建议：environment 提升到实际支持的 SDK 下界，并在 CI 用下界版本跑一次 `flutter analyze && flutter build` 验证。

## 七、值得肯定的地方

1. **安全基线扎实**（Go）：gRPC 仅监听 127.0.0.1；token 强制必填；`crypto/subtle.ConstantTimeCompare` 常量时间比较；认证拦截器覆盖 Stream/Unary 全部 RPC。
2. **父进程死亡检测双平台方案合理**：Linux PDEATHSIG + 其他平台轮询回退。
3. **实例生命周期锁纪律好**：全局 instance 读写均在 mutex 下，createInstance 各失败路径正确 cancel+Close。
4. **规则集原子写入**：.tmp + rename，失败清理；List 返回拷贝。
5. **订阅解析防御式处理**：clash YAML 多标量类型兼容，多格式链接解析，配套 round-trip 单测。
6. **Flutter 分层清晰**：core/ui 职责分明（除 F-M7 一处外无反向依赖）；schema 驱动动态表单扩展性好；AsyncValue error+stacktrace 用法规范；资源 dispose 意识良好；迁移设计支持 dryRun 且逐文件容错。

## 八、修复优先级建议（路线图）

1. **P0（正确性/安全，1-2 天量级）**：G-H1 注入接线、G-H2 nil panic + recovery、F-H3 编辑丢字段（用户数据破坏）、C-H1 CI 吞测试失败、C-M4 空壳 APK。
2. **P1（数据完整性）**：F-H1 原子写、F-H2 ID 冲突、G-H3 更新校验、G-M4 null 数组、F-H4 whenData。
3. **P2（体验/一致性）**：F-M1 连接真实性、F-M3/M4 设置落盘生效、F-M8 i18n 接线、C-M1/M2/M3 工程化。
4. **P3（长期）**：配置构建迁移到 sing-box 强类型 option（根治 G-M4/G-L6/G-L8 类问题）；补测试金字塔；代码签名与发布加固。

---
*本报告由只读评估生成，未修改项目任何代码与配置文件。*


---

# 第二轮复评：整改验证与新问题（2026-08-23）

> 复评对象:`docs/代码评估报告_Claude_2026-08-23.md` 附录「整改记录」声称的修复 + 工作区未提交改动（51 个文件，+4090/-1528 行）。
> 方式:两个并行审查子代理逐文件核实 Go / Flutter 侧全部声明；本人复核 CI 工作流与构建脚本。未运行工具链（本机无 Go/Flutter），但发现两处**静态即可判定"自带测试必失败"的矛盾**。
> 本章节只评估，除本文件外未修改任何代码。

## R1. 总体结论

整改**覆盖面广、大部分质量不错**。第一轮报告的 9 项高严重度问题中 **6 项实质修复、2 项部分修复、1 项未动**；17 项中严重度多数已处理。Claude 自行发现的 B0（Dart/Go 线格式不兼容导致所有节点构建失败）与 B1（主链路断裂：从不拉起 core、从不传 token）是比第一轮清单更根本的问题，修复方向正确。

**但存在一个流程性红旗**——新代码中有两处与其自带测试直接矛盾的缺陷：

1. vmess schema `'sec'` 键重复，而新增的 `dynamic_form_test.dart:98` 恰好断言 schema key 唯一性 → **该测试当前必失败**；
2. `compareVersions` 预发布号按字典序比较（`beta.10 < beta.2`），而 `update_test.go:21` 用例期望 `-1` → **该测试当前必失败**。

两者均无需运行工具即可静态判定，说明**本批改动从未跑过任何测试**（Claude 报告也自认"未经编译验证"）。合并前必须先执行 R4 的验证命令。

## R2. 修复验证总结（对照第一轮报告编号）

### 已确认修复 ✅

| 原编号 | 内容 | 验证证据 |
|---|---|---|
| G-H2 | FullTest nil panic + err 遮蔽 | `grpc_box.go:116-133`:`in.Config` 判空已加，`:=` 改 `=`，defer 捕获命名返回值 err |
| G-H3 | 更新链路完整性 | updater 弃用 codeclysm/extract 改标准库（safeJoin + 拒符号链接 + 大小预算）；update.go 强制 SHA-256、https+主机白名单、`.part` 原子落盘、基于 os.Executable() 的绝对路径 |
| G-M1 | 规则集路径穿越 | `manager.go:76-90` tag 白名单正则 + Rel 二次校验；缓存目录绝对化；下载限流 32MiB |
| G-M5 | Exit 直接 os.Exit | 改 GracefulStop（先回包再延迟停机）；token 走 `NEKORAY_AUTH_TOKEN` 环境变量并读取后 unset |
| G-L4 | 固定 .tmp 竞态 | CreateTemp 唯一名 |
| F-H1 | 配置非原子写+错误吞噬 | `_writeAtomic`（临时文件→flush→rename）；损坏文件进 corrupt 列表并弹 SnackBar |
| F-H4 | whenData 未 await | routing_page 重写为同步取值 + await + 错误反馈 |
| F-M1 | 假连接状态/无重连 | isConnected 基于握手探活；checkHealth；三档 deadline(5s/15s/90s)，updateRuleSet 用 90s > core 的 60s |
| F-M3/M4 | DNS/设置假 UI | AppSettings(settings.json) 持久化 + SystemIntegration 实现系统代理(Win注册表/networksetup/gsettings)与开机自启；不支持平台禁用开关并说明原因 |
| F-M6 | 删除无确认无反馈 | `_confirmDelete` AlertDialog |
| F-M9/F-M10 | DNS initialValue 脱钩、combo 校验缺失 | didUpdateWidget 同步；required/combo/port 校验接入 |
| F-H5 | 测试为零 | 新增 8 个测试文件（Go×4、Dart×4），整体质量好（但其中两个用例与实现矛盾，见 R3-N1/N2） |
| C-M1 | CI Go 版本错配 | 全部 workflow `go-version: '1.24.7'`；四个 module go 指令统一 1.24.7；grpc_server 升级 grpc v1.79.1/protobuf v1.36.11；updater go.sum 删除合法（纯标准库模块） |
| C-M2 | 构建时 go mod tidy | 改 `go mod verify` + `-mod=readonly` |
| C-M3 | 覆写 CHANGELOG.md | 改为 RELEASE_NOTES.md，仓库文件不再被改写 |
| C-M4 | 空壳 APK 风险 | Android continue-on-error 移除；无 APK 即 exit 1；`if-no-files-found: error`；打包脚本 set -euo pipefail、缺核心二进制即 fatal |
| Claude-B0 | Dart/Go 线格式不兼容 | profile.dart 重写为 bean 透传模型 `{type,id,gid,latency,bean:{...}}`，保留 beta 扁平格式兼容读取；Group.archive bool 对齐 |
| Claude-B1 | 主链路断裂 | 新增 core_process.dart:Process.start 拉起 core、CSPRNG token 经环境变量传递、解析监听端口、SIGTERM→SIGKILL 升级停止 |
| 其他 | H7 Stop 清 instanceCtx、H10 migration 异步化、H11 main 初始化+关闭拦截、H14 流量速率差值、F-L15/L16/L19、go/.gitignore `*.json`、lint-test 加 main 分支、gofmt 强制/govulncheck/-race/concurrency/permissions 等 | 均逐项核实属实 |

### 部分修复 ⚠️

| 原编号 | 缺口 |
|---|---|
| **G-H1 代理注入** | HTTP 侧已接线（`main.go:24 SetProxyHttpClientFactory(resolveProxyClient)`，测速/出口 IP/更新走代理 ✅）；但 **`SetUdpDialFunc` 仍无任何调用**，FullTest 的 UDP 延迟测试依旧直连 `8.8.8.8:53`（fulltest.go 默认实现原样保留） |
| **F-H2 ID 冲突/批量导入** | 单调 ID 分配 ✅；但批量回滚不完整——中途失败只删除"本次新建"的文件，**被覆写的已有节点不还原**，回滚自身失败静默吞掉（local_store.dart:135-151） |
| **F-H3 编辑丢字段** | bean 原地合并 + didUpdateWidget ✅，wireguard/ssh 等字段齐全 ✅；但引入两个新问题（R3-N1/N7），且可选字段一旦有值无法清空 |
| **G-M4 makeRule null** | 整条规则为空时跳过 ✅；但单类目列表下成员切片仍可为 nil——只含 geoip 时 `"ip_cidr":null`、只含 keyword 时 `"geosite":null`（chain.go:204-214） |
| G-M2 update 全局竞争 | URL 快照已有锁保护 ✅；并发 Download 未串行化（最后者胜出，危害低） |
| B6 token 泄漏面 | env 通道已加 ✅；但 `--token` CLI 通道保留（main.go），调用方若继续用 flag，token 仍在 ps 可见 |
| F-M2 流量轮询 Timer | 改速率差值+防排队 ✅；provider 仍非 autoDispose，断连时空转（开销极小） |
| F-M5 AsyncValue 态 | routing/dns 页 `.when` 完整 ✅；profiles tab 仍经 `valueOrNull ?? []` 吞掉 loading/error |
| F-M11 凭据安全 | 目录 700/文件 600 ✅、随机 token ✅；gRPC 仍 insecure 明文通道（本机场景可接受），flutter_secure_storage 未引入 |
| F-M8/H15 i18n | assets 声明+loadError ✅；但 `I18n.t(` 在 lib 下仍零调用，语言切换不生效，翻译体系本质仍是死代码 |
| C-M5 发布校验和 | SHA256SUMS.txt 已生成且 updater 强制依赖 ✅（完整性解决）；代码签名仍缺（来源真实性未解决） |
| C-M7 Lint | golangci-lint 仍缺；但加了 gofmt 强制检查 + govulncheck job + -race + 三模块分别 vet/test，大幅改善 |
| C-M8 版本一致性 | pubspec version 仍 5.0.0-beta.1 vs version.txt beta.3；pubspec.lock 仍未提交（Claude 自列"仍需人工处理"） |

### 未修复 ❌（历史遗留，仍然开放）

- **C-H1（高）CI 吞测试失败**:build-flutter.yml 两处 `||` 回退原样保留（`flutter test --coverage || echo "no tests yet"`、`dart format --set-exit-if-changed . || dart format .`）；analyze/test 触发分支仍不含 main。**R3-N1/N2 正是"测试失败被发现不了"的现成例证，此项应提到最高优先级**。
- C-M6 darwin updater:build_go.sh 仍跳过 macOS 构建，打包脚本将 helper 视为可选 → macOS 包静默缺 updater（核心二进制缺失现在会 fatal，算部分改善）。
- G-M3 fulltest goroutine 泄漏 + bodyClose 数据竞争。
- G-M6 build.go internal-full 吞错返回空配置。
- F-M7 grpc_provider 仍签名 WidgetRef;F-L2 搜索无防抖。
- domain_strategy/packet_encoding/security 空字符串无条件写入；getBetweenStr、migrator 错误忽略等低危项。
- API 兼容性风险未消除:`DropdownButtonFormField(initialValue:)`(需 Flutter≥3.29)/`Color.withValues`(≥3.27) 与 pubspec `sdk >=3.3.0` 下界矛盾依旧。

## R3. 整改新引入的问题

### 高严重度

**N1. vmess schema `'sec'` 键重复 —— 功能回归级缺陷，且暴露测试未运行**
- `protocol_schema.dart:50`（stream 组 Security）与 `:72`（vmess bean 组 Encryption）同 key `'sec'`。后果:(a) DynamicForm 中两个下拉共享同一 controller，改一个另一个跟着变;(b) `_mergeForm` 后者覆盖前者，Encryption 值被写进 `stream['sec']` 污染 TLS security 字段，bean 层加密永远设不上;(c) 项目自带的唯一性断言（dynamic_form_test.dart:98-102）必然失败。
- 建议:Encryption 键改名并对齐 Go bean 的 JSON tag；跑一次 flutter test 即可发现。

**N2. compareVersions 预发布号按字典序比较 —— 与自带测试矛盾**
- `update.go:380-384`:字符串比较导致 `beta.10 < beta.2` 被误判；`splitPreRelease` 还把 `+build` 元数据当预发布参与比较（semver 规定忽略）。`update_test.go:21` 用例 `{"5.0.0-beta.2","5.0.0-beta.10", -1}` 按当前实现返回 1 → 测试必失败。
- 后果:升级检查可能把旧版判新/新版判旧。建议预发布段按 `.` 拆分后逐段数值比较。

> N1+N2 共同表明本批改动未经编译与测试验证，属流程缺陷而非单点疏忽。

### 中严重度

- **N3. CoreProcess 子进程环境变量被整体替换**（core_process.dart:109）—— `environment: {'NEKORAY_AUTH_TOKEN': token}` 丢弃 PATH/HOME/**Windows SystemRoot** 等，Windows 上大概率影响 core 运行。应为 `{...Platform.environment, 'NEKORAY_AUTH_TOKEN': token}`。
- **N4. 更新下载重定向不受白名单约束**（update.go:274-286）—— 只校验初始 URL host；http.Client 默认跟随任意跨域重定向。应设 CheckRedirect 对每一跳复用 validateUpdateURL。
- **N5. writeEntry 注释声称 O_EXCL 但代码没有**（updater.go:90-94）—— OpenFile 无 O_EXCL，所宣称的 symlink-swap 防护不存在；因上游已拒绝符号链接条目实际风险有限，但安全注释失实必须修正。
- **N6. Windows 孤儿进程检测失效**（grpc.go:89-107）—— Windows 子进程不被 reparent，ppid 永不变 → ppid 变化检测永假；Windows 分支又跳过 Signal(0) 探测。GUI 崩溃后 Windows 上 core 成为永久孤儿——恰是本轮要修的问题在该平台依旧存在。
- **N7. 可选表单字段一旦有值无法清除**（dynamic_form collect 省略空值 + merge 不删除旧值）—— 用户清空 SNI/path 等后保存，bean 中旧值静默存留。

### 低严重度

| # | 问题 | 位置 |
|---|---|---|
| N9 | splitHostPort 对裸 IPv6（无括号无端口）误切为 host:port 且 ok=true | link.go |
| N10 | GracefulStop 无超时兜底，卡住的 RPC 可延迟 Exit | grpc.go |
| N11 | proxyHttpClient/udpDial/Debug 包级全局在 race detector 下属未定义（实践中 Serve 前写后只读；建议 sync.Once 或注释契约） | update.go / fulltest.go |
| N12 | 并发 downloadUpdate 最后者胜出（各自验过 checksum，仅浪费带宽） | update.go |
| N13 | tray 从未 setIcon；settings_page 部分 controller 未 dispose；_guard await 后使用 Theme.of(context)；settings `_persist` 先改 state 后写盘，失败不一致 | app.dart / settings_page.dart |
| N14 | pubspec `generate:true` 无 l10n.yaml/arb 空转；flutter_localizations/integration_test 未使用 | pubspec.yaml |

## R4. 结论与合并前置条件

整改批次**方向正确、兑现度高**，P0/P1 清单（主链路、线格式、ZipSlip/路径穿越/更新校验、原子写、ID 冲突、协议切换崩溃）基本落地。但按现状**不建议直接合入**，需先完成:

1. 【必须】在有工具链的环境跑完并通过:`go/grpc_server` 与其他两模块 `go build/vet/test ./...`（预期 TestCompareVersions 失败）、`flutter analyze && flutter test`（预期 schema 唯一性用例失败）。
2. 【必须】修复 N1（'sec' 键冲突）、N2（版本比较）、N3（环境变量合并）。
3. 【强烈建议】修复 C-H1（去掉 build-flutter.yml 两处 `||` 回退）——否则下一批"未跑测试"的改动依然会被绿灯放行；同时处理 N4/N6。
4. 【排期】G-H1 UDP 注入接线、G-M4 剩余 null 成员、F-H2 批量回滚还原覆写文件、i18n 接线或移除、darwin updater、代码签名与 pubspec.lock。

*复评由只读评估生成，除本报告外未修改任何代码与配置文件。行号以工作区当前状态为准，合入后可能漂移。*
