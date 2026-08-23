# nekoray 代码评估报告

> 审查日期：2026-08-23 · 分支：dev（2042df9，v5.0.0-beta.3）
> 范围：`go/` 全部非生成代码、`nekoray_flutter/lib` 全部非生成代码、`libs/*.sh`、`.github/workflows/*`
> 性质：只读评估，未修改任何代码。行号以当前 HEAD 为准。

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
