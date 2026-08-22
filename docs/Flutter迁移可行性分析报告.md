# nekoray 方案 B（Flutter 全栈重写）可行性分析报告

> 评估对象：将 nekoray 从 C++/Qt Widgets 迁移至 Flutter 全栈重写（对齐 karing 路线）
> 评估日期：2025-08-20
> 评估依据：nekoray 4.0.1 源码 + sing-box 最新特性 + karing 公开实现

---

## 一、评估背景与目标

### 1.1 项目现状摘要

| 维度 | 现状 |
|---|---|
| 版本 | 4.0.1（2024-12-12，近 1 年未更新） |
| UI 技术栈 | C++ / Qt Widgets（Qt5/Qt6 双支持），18 个 `.ui` 文件 |
| 核心后端 | sing-box 1.13.x，通过 Go 编写的 `nekobox_core` 以 gRPC 桥接 |
| IPC 机制 | 手写 gRPC over HTTP/2（`QNetworkAccessManager`），非官方 grpc 库 |
| 数据存储 | 自定义 `JsonStore` 反射式序列化 + 单文件 JSON（profiles/groups 目录） |
| 平台支持 | Windows / Linux（macOS 代码有 `Q_OS_MACOS` 但非官方构建） |
| 已有 Flutter 目录 | `nekoray_flutter/`（**空目录**，方向曾被考虑但未落地） |

### 1.2 代码量基线（迁移工作量评估依据）

| 模块 | 语言 | 代码量 | 文件数 | 迁移策略 |
|---|---|---:|---:|---|
| `ui/` | C++/Qt | 5,865 行 | 48 | **Dart 重写** |
| `db/` | C++ | 1,756 行 | 11 | 下沉 Go core 或 Dart 重写 |
| `main/` | C++ | 1,648 行 | 11 | 下沉 Go core |
| `fmt/` | C++ | 1,614 行 | 17 | 下沉 Go core |
| `sub/` | C++ | 699 行 | 2 | 下沉 Go core |
| `sys/` | C++ | 613 行 | 10 | 平台插件重写 |
| `rpc/` | C++ | 342 行 | 2 | 替换为 Dart grpc 库 |
| **C++ 业务逻辑合计** | — | **12,537 行** | 101 | — |
| `go/`（nekobox_core） | Go | 2,427 行 | 14 | **保留并扩展** |
| `3rdparty/` | C++ | 4,513 行 | — | 大部分废弃（QHotkey 等仅桌面用） |
| `JsonStore` 字段数 | — | 147 个配置项 | — | 需完整建模 |

### 1.3 方案 B 核心主张

1. 前端用 Flutter（Dart）重写，一套代码覆盖 Win/Linux/macOS/Android/iOS。
2. 后端保留并扩展 Go `nekobox_core`（gRPC 接口已就绪），Flutter 作为瘦客户端。
3. C++ 业务逻辑（ConfigBuilder、GroupUpdater、ProfileFilter、JsonStore）下沉到 Go core。
4. UI 对齐 karing / armwall 的现代风格（卡片化、深色、图表化）。

---

## 二、技术可行性分析

### 2.1 架构迁移路径

```
┌─────────────────────────────────────────────────────────────┐
│  现状架构                                                    │
│  ┌──────────┐   gRPC(HTTP/2手写)   ┌──────────────┐         │
│  │ Qt Widgets│◄──────────────────►│ nekobox_core │► sing-box│
│  │  (C++)    │   QNetworkAccess    │   (Go)       │         │
│  └──────────┘                     └──────────────┘         │
│   业务逻辑全在 C++ 层：ConfigBuilder/JsonStore/订阅/路由     │
└─────────────────────────────────────────────────────────────┘
                            ↓ 迁移
┌─────────────────────────────────────────────────────────────┐
│  目标架构（方案 B）                                          │
│  ┌──────────────┐  gRPC(官方库)   ┌──────────────┐        │
│  │ Flutter UI    │◄───────────────►│ nekobox_core │►sing-box│
│  │  (Dart)       │                  │   (Go, 扩展)  │        │
│  │  - 状态管理    │                  │  +ConfigBuild│        │
│  │  - 数据模型    │                  │  +订阅更新    │        │
│  │  - 平台插件    │                  │  +路由生成    │        │
│  └──────────────┘                  └──────────────┘        │
│   业务逻辑下沉 Go，Flutter 仅做渲染+交互+本地缓存            │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心模块迁移逐项分析

#### 2.2.1 gRPC 通信层 ✅ 低风险

| 项 | 现状 | 目标 | 可行性 |
|---|---|---|---|
| proto 定义 | `go/grpc_server/gen/libcore.proto`（7 个 RPC 方法） | 保持兼容并扩展 | ✅ proto 已存在，直接用 `protoc` 生成 Dart stub |
| C++ 客户端 | 手写 `Http2GrpcChannelPrivate`（342 行，依赖 `QEventLoop` 阻塞） | 替换为官方 `grpc` Dart 包 | ✅ 风险消除（现有实现较脆弱） |
| 接口完备性 | `Start/Stop/Test/QueryStats/ListConnections/Update/Exit` | 需新增：连接管理、rule_set 更新、订阅解析 | ⚠️ 需扩展 proto |

**评估**：gRPC 层是最适合迁移的部分。proto 已定义，Dart 官方 grpc 库成熟。现有 C++ 手写实现反而是技术债，迁移即收益。

#### 2.2.2 数据存储层 ⚠️ 中风险

| 项 | 现状 | 目标 | 可行性 |
|---|---|---|---|
| 配置存储 | `JsonStore` 反射式，147 个字段，每个 profile 一个 JSON 文件 | Dart 数据类 + JSON 序列化 | ✅ 逻辑直接 |
| Profile/Group ���储 | `profiles/{id}.json` + `groups/{id}.json` + 索引文件 | 保持兼容或迁移到 SQLite | ⚠️ 需决定格式 |
| 数据迁移 | 现有用户数据需保留 | 需编写迁移工具 | ⚠️ 必须处理 |

**评估**：`JsonStore` 的反射式序列化（`configItem` 注册机制）在 Dart 中可用 `json_serializable` 等价替换。147 个字段需逐个建模为 Dart 数据类，工作量大但机械化。

**关键决策点**：是否保持 JSON 文件格式以兼容老用户数据？建议**保持兼容**，并提供一次性迁移工具读取老 `profiles/` 目录。

#### 2.2.3 配置构建层（ConfigBuilder）⚠️ 中高风险

这是迁移最复杂的部分。`db/ConfigBuilder.cpp`（33KB，约 800 行）负责：

- 把 `ProxyEntity`（bean）转换为 sing-box outbound JSON
- 构建 DNS / 路由规则 / inbound / experimental
- 处理 chain（链式代理）、front proxy、external core
- VPN 模式配置生成（`WriteVPNSingBoxConfig`）

**迁移方案**：

```
方案 B-1（推荐）：下沉到 Go core
  - ConfigBuilder.cpp 的逻辑用 Go 重写，作为 gRPC 服务
  - Flutter 只发 Profile 列表 → core 返回完整 sing-box config JSON
  - 优点：单一数据源，移动端/桌面端共用
  - 缺点：Go 侧需重建 bean 模型（约 1614 行 fmt/ 代码）

方案 B-2：Dart 侧重写
  - 直接在 Dart 中实现配置生成
  - 优点：离线可用，无 IPC 开销
  - 缺点：双份代码（Go core 也要懂 sing-box config）
```

**评估**：**推荐方案 B-1**。理由：
1. sing-box 本身是 Go，Go 侧操作 `option.Options` 更自然（已有 `github.com/sagernet/sing-box/option` 引用）。
2. karing 也是类似架构（核心逻辑在 native/core 侧）。
3. 避免配置生成逻辑在 Dart/Go 双份维护。

但 `fmt/` 下 17 个 Bean 类（VMess/VLESS/Trojan/SS/Hysteria2/TUIC/Custom 等）的建模需在 Go 侧重建，这是主要工作量。

#### 2.2.4 订阅解析层（GroupUpdater）⚠️ 中风险

`sub/GroupUpdater.cpp`（665 行）负责：

- 解析多种订阅格式：Raw（ss/vmess/vless/trojan/hysteria2/tuic/naive 链接）、Clash YAML、Base64
- HTTP 下载订阅
- 去重、过滤（配合 `ProfileFilter`）

**迁移方案**：

```
- HTTP 下载：Dart http 包（成熟）
- Clash YAML：yaml 包（成熟）
- 链接解析：需 Dart 重写解析逻辑（Link2Bean.cpp 约 12KB）
- 去重逻辑：ProfileFilter.cpp 逻辑简单，Dart 重写无难度
```

**评估**：Clash YAML 解析（约 400 行）和链接解析（约 300 行）需 Dart 重写，但逻辑清晰、无复杂依赖。**建议下沉 Go core**，与 ConfigBuilder 一起，避免重复。

#### 2.2.5 平台相关层（sys/）⚠️ 高风险（移动端新增）

| 平台功能 | 现状 | Flutter 方案 | 风险 |
|---|---|---|---|
| Windows 系统代理 | `QvProxyConfigurator` + WinINet `InternetSetOption` | Flutter 无直接 API，需 MethodChannel + 原生 Kotlin/Swift 或 C++ | ⚠️ 高 |
| Linux TUN/路由 | `vpn-run-root.sh`（iptables + ip route） | Flutter 调用进程，保留脚本 | ✅ 低 |
| 开机自启 | `QSettings` 写注册表 / Linux desktop entry | `launch_at_startup` 包 | ✅ 低 |
| 全局热键 | `QHotkey`（3rdparty） | `hotkey_manager` 包 | ✅ 低 |
| TUN 模式 | sing-box 内置 + root 脚本 | 桌面端保留方案；移动端用 VpnService（Android）/ NetworkExtension（iOS） | 🔴 高（移动端全新） |
| 托盘图标 | `QSystemTrayIcon` | `tray_manager` 包 | ✅ 低 |

**评估**：
- **桌面端**：平台功能均有成熟 Flutter 包替代，风险可控。
- **移动端**：VPN 是最大挑战。Android 需实现 `VpnService` + sing-box for Android（gomobile 或独立进程）；iOS 需 NetworkExtension。**这是方案 B 最大的新增工作量**，但 karing 已验证可行（karing 支持 Android/iOS）。

#### 2.2.6 UI 层 ✅ 低风险（重写即可）

| 现状 | 目标 | Flutter 方案 |
|---|---|---|
| `mainwindow.cpp` 70KB 巨石 | 拆分为多页面 + ViewModel | `provider`/`riverpod` 状态管理 |
| 18 个 `.ui` 表单文件 | 动态表单（schema 驱动） | Flutter Form + 动态字段 |
| QSS 静态主题 | Material 3 + 动态主题 | `flex_seed_scheme` / `dynamic_color` |
| 无图表 | 流量/延迟图表 | `fl_chart` |
| 顶部 Tab | 侧边导航 + 卡片列表 | 自定义 NavigationRail |

**评估**：UI 层是 Flutter 的主场，反而是迁移中**最容易**的部分。karing 的 UI 实现可直接参考。

---

### 2.3 依赖与生态评估

#### 2.3.1 Flutter 端核心依赖

| 用途 | 包名 | 成熟度 | 备注 |
|---|---|---|---|
| 状态管理 | `riverpod` / `provider` | ⭐⭐⭐⭐⭐ | karing 用 provider |
| gRPC 客户端 | `grpc` | ⭐⭐⭐⭐ | 官方支持，替换手写 C++ gRPC |
| JSON 序列化 | `json_serializable` + `freezed` | ⭐⭐⭐⭐⭐ | 替代 JsonStore |
| HTTP | `dio` | ⭐⭐⭐⭐⭐ | 订阅下载 |
| YAML | `yaml` | ⭐⭐⭐⭐ | Clash 订阅解析 |
| 图表 | `fl_chart` | ⭐⭐⭐⭐ | 流量/延迟图 |
| 本地存储 | `hive` / `isar` | ⭐⭐⭐⭐⭐ | 替代 JSON 文件 |
| 托盘 | `tray_manager` | ⭐⭐⭐⭐ | 桌面端 |
| 热键 | `hotkey_manager` | ⭐⭐⭐ | 桌面端 |
| 开机自启 | `launch_at_startup` | ⭐⭐⭐⭐ | 桌面端 |
| 系统代理 | 需自行实现 MethodChannel | — | 桌面端 |
| 二维码 | `mobile_scanner` / `qr_flutter` | ⭐⭐⭐⭐ | 扫码导入 |

#### 2.3.2 Go core 侧依赖

| 用途 | 包 | 现状 |
|---|---|---|
| sing-box | `github.com/sagernet/sing-box` v1.13.19 | **需升级到最新**（rule_set 等新特性） |
| gRPC | `google.golang.org/grpc` v1.63.2 | 可用 |
| libneko | 本地 replace | 需评估是否保留还是合并进 core |

---

### 2.4 sing-box 升级兼容性分析（迁移同时必须处理）

当前 `go.mod` 锁定 sing-box 1.13.19，而最新版已大幅演进。**Flutter 重写必须同步升级 sing-box**，否则失去意义。

| sing-box 变更 | 影响 | 处理 |
|---|---|---|
| `rule_set`（MRS 格式）替代 geoip/geosite | `ConfigBuilder.cpp` 硬编码 `geoip.db`/`geosite.db` 将失效 | Go 侧重写路由生成 |
| `sniffer` 新结构（替代 `sniff`/`sniff_override_destination`） | inbound 生成需改 | Go 侧 |
| `route.rules` 的 `action` 字段（route/reject/hijack-dns） | 旧 `outbound` 字段废弃 | Go 侧 |
| `endpoint` 抽象（统一 inbound/outbound） | 架构性变更 | 中期迁移 |
| `experimental.clash_api` 新结构 | 旧 `clash_api` 兼容但功能受限 | Go 侧 |
| `cache_file` | 未启用 | Go 侧新增 |

**评估**：sing-box 升级与 Flutter 迁移**强耦合**，建议在 Go core 侧重写配置生成时一并完成。

---

## 三、工作量与时间线估算

### 3.1 工作量分解

| 工作项 | 复杂度 | 人月估算 | 备注 |
|---|---|---:|---|
| **阶段一：Go core 扩展** | | | |
| 1. sing-box 升级到最新 + rule_set/sniffer/action 迁移 | 高 | 1.5 | 必须先做 |
| 2. ConfigBuilder 下沉 Go（bean 模型 + 配置生成） | 高 | 2.0 | fmt/ 17 文件逻辑 |
| 3. 订阅解析下沉 Go（Clash YAML + 链接解析） | 中 | 1.0 | sub/ 665 行 |
| 4. gRPC proto 扩展（新增接口） | 低 | 0.5 | 连接管理/rule_set 更新 |
| 5. 连接管理实现（ListConnections 接入 V2Ray API） | 中 | 1.0 | 当前是空实现 |
| **阶段二：Flutter 前端** | | | |
| 6. 项目脚手架 + 路由 + 状态管理 | 低 | 0.5 | 标准 Flutter 工程 |
| 7. 数据模型层（147 字段 JsonStore → Dart 数据类） | 中 | 1.0 | 机械化但量大 |
| 8. gRPC 客户端接入 | 低 | 0.5 | 官方 grpc 包 |
| 9. 主界面（节点列表 + 分组 + 状态栏） | 中 | 1.5 | 对齐 karing/armwall |
| 10. 协议编辑器（schema 驱动动态表单） | 中 | 1.5 | 替代 18 个 .ui |
| 11. 路由/DNS/VPN 设置页面 | 中 | 1.0 | 对话框迁移 |
| 12. 订阅管理页面 | 低 | 0.5 | |
| 13. 连接管理 + 流量图表 | 中 | 1.0 | fl_chart |
| 14. 主题系统（Material 3 + 深色） | 低 | 0.5 | |
| 15. 系统代理 / TUN / 托盘 / 热键（桌面端） | 中 | 1.5 | 平台插件 |
| 16. 国际化（zh_CN/ru_RU/fa_IR + 新增 en） | 低 | 0.5 | |
| **阶段三：移动端（可选增量）** | | | |
| 17. Android VpnService 集成 | 高 | 2.0 | gomobile 或独立进程 |
| 18. iOS NetworkExtension | 高 | 2.0 | 需 Apple 开发者账号 |
| **阶段四：质量保障** | | | |
| 19. 数据迁移工具（老 JSON → 新格式） | 中 | 0.5 | |
| 20. 测试 + CI/CD（多平台构建） | 中 | 1.0 | |
| 21. 文档 + 打包发布 | 低 | 0.5 | |
| **合计（桌面端）** | | **17.5 人月** | 阶段一+二+四 |
| **合计（含移动端）** | | **21.5 人月** | 全平台 |

### 3.2 时间线建议（按团队规模）

| 团队配置 | 桌面端 MVP | 桌面端完整版 | 移动端 |
|---|---:|---:|---:|
| 1 人全职 | 10 个月 | 14 个月 | +6 个月 |
| 2 人（1 Go + 1 Flutter） | 6 个月 | 9 个月 | +4 个月 |
| 3 人（1 Go + 2 Flutter） | 5 个月 | 7 个月 | +3 个月 |

**里程碑**：
- M1（第 2 月）：Go core 升级完成，sing-box rule_set 生效，老 C++ UI 可用（过渡态）。
- M2（第 5 月）：Flutter 桌面端 MVP（节点管理 + 启停 + 基本路由）。
- M3（第 8 月）：Flutter 桌面端功能对齐当前 nekoray。
- M4（第 10 月）：桌面端正式发布，移动端开始。

---

## 四、风险与应对

### 4.1 技术风险

| 风险 | 概率 | 影响 | 应对 |
|---|---|---|---|
| **sing-box 升级 breaking changes** | 高 | 高 | 阶段一优先处理，先在 Go core 升级并用旧 UI 验证 |
| **ConfigBuilder 下沉 Go 出错** | 中 | 高 | 保留 C++ 版本作为对照测试，逐协议迁移并对比生成的 JSON |
| **移动端 VPN 集成复杂** | 高 | 高 | 桌面端先行，移动端作为独立阶段；参考 karing 实现 |
| **gRPC Dart 库在移动端兼容性** | 低 | 中 | 备选方案：HTTP/JSON API 替代 gRPC（Go core 增加 REST 网关） |
| **性能（Flutter 桌面端内存占用）** | 中 | 中 | Flutter 桌面端内存略高于 Qt（约 +50MB），但现代设备可接受；注意大列表虚拟化 |
| **老用户数据迁移失败** | 中 | 高 | 提供迁移工具 + 旧版本保留 6 个月过渡期 |

### 4.2 项目风险

| 风险 | 概率 | 影响 | 应对 |
|---|---|---|---|
| **人力不足** | 高 | 致命 | 方案 B 工作量大，单人需 14+ 月；建议至少 2 人或分阶段 |
| **中途 sing-box 架构再变** | 中 | 高 | Go core 升级时尽量贴合 sing-box 主线，减少自定义层 |
| **与 karing 生态重叠** | 中 | 中 | 差异化：nekoray 保持桌面优先 + 轻量；karing 偏全平台通用 |
| **开源社区贡献断层** | 中 | 中 | 迁移期间保持 C++ 版本可用的过渡发布 |

### 4.3 回退方案

- **若 Flutter 迁移停滞**：阶段一（Go core 升级 + ConfigBuilder 下沉）本身即有价值，可让现有 C++ UI 直接调用新 core，获得 sing-box 新特性。这等于退化为「方案 A（Qt 模块化）」。
- **若移动端不可行**：桌面端独立交付，移动端延后或放弃。

---

## 五、收益评估

### 5.1 功能收益

| 收益 | 现状 | 迁移后 |
|---|---|---|
| sing-box 升级 | 1.13（旧） | 最新（rule_set/logical rules/sniffer 新结构） |
| 新协议 | 缺 SSH/WireGuard/AnyTLS/ShadowTLS/ECH | 可快速接入（Go core 扩展） |
| 连接管理 | 空实现 | 实时连接列表 + 流量追踪 |
| 自动选择分组 | 无 | selector/urltest outbound |
| 移动端 | 无 | Android/iOS |
| UI 现代化 | QSS 旧主题 | Material 3 + 深色 + 图表 |

### 5.2 架构收益

| 收益 | 说明 |
|---|---|
| **消除技术债** | 移除 70KB 巨石 `mainwindow.cpp`、手写 gRPC、每协议一套 .ui |
| **单一数据源** | 配置生成逻辑统一在 Go core，避免 Dart/Go 双份 |
| **可测试性** | Go core 可单元测试；Flutter UI 可 widget 测试 |
| **社区友好** | Dart/Flutter 贡献门槛低于 C++/Qt |
| **可持续维护** | karing 已验证路线，有参照 |

### 5.3 成本对比

| 维度 | 方案 A（Qt 模块化） | 方案 B（Flutter 重写） |
|---|---|---|
| 工作量 | 中（~8 人月） | 高（~17.5 人月桌面端） |
| 移动端支持 | ❌ | ✅ |
| UI 现代化上限 | 中（QML） | 高 |
| 长期维护成本 | 高（C++/Qt 老化） | 中（Flutter 活跃） |
| 技术债清除 | 部分 | 彻底 |

---

## 六、可行性结论

### 6.1 总体判定

> **方案 B 技术可行，但工作量大，建议分阶段实施。**

- **技术可行性**：✅ 高。karing 已验证 Flutter + sing-box 路线；gRPC proto 已就绪；Go core 可平滑扩展。
- **资源可行性**：⚠️ 中。桌面端 17.5 人月，需至少 2 人团队 9 个月；单人需 14 个月。
- **风险可控性**：✅ 中高。阶段一（Go core 升级）有独立价值，可回退为方案 A。

### 6.2 推荐实施策略

**分三阶段，每阶段都有独立可交付价值：**

1. **阶段一（M1-M2，必做基础）**：Go core 升级 sing-box + ConfigBuilder/订阅下沉 Go + gRPC 扩展。
   - 交付物：升级后的 core，**现有 C++ UI 可直接使用**，获得 rule_set 等新特性。
   - 价值：即使不继续 Flutter，这一步也解决了最紧迫的 sing-box 落后问题。

2. **阶段二（M3-M8，Flutter 桌面端）**：Flutter 重写桌面 UI，对齐 karing/armwall。
   - 交付物：Flutter 桌面版 nekoray，功能对齐当前版本 + 新特性。
   - 前置条件：阶段一完成。

3. **阶段三（M9-M12，移动端，可选）**：Android/iOS 适配。
   - 交付物：移动端 nekoray。
   - 前置条件：阶段二桌面端稳定；团队有移动端经验。

### 6.3 关键决策点

| 决策 | 建议 | 理由 |
|---|---|---|
| ConfigBuilder 放 Go 还是 Dart | **Go** | sing-box 是 Go，单一数据源 |
| 数据格式保持 JSON 还是换 SQLite | **保持 JSON + 迁移工具** | 兼容老用户 |
| 移动端是否纳入首期 | **否** | 先稳桌面，移动端风险高 |
| 是否保留 C++ 过渡版本 | **保留 6 个月** | 数据迁移 + 用户适应 |
| gRPC 还是 HTTP API | **先 gRPC，移动端有问题再考虑 HTTP** | gRPC 已就绪 |

### 6.4 最终建议

**采纳方案 B，但采用渐进式路径**：

1. **立即启动阶段一**（Go core 升级 + 业务逻辑下沉），这是无论选择哪个 UI 方案都必须做的，且能立即让现有 C++ 版本恢复活力。
2. **阶段一完成后评估**：若团队资源充足（≥2 人），启动阶段二 Flutter 重写；若资源不足，阶段一本身已退化为可接受的方案 A，不会浪费。
3. **移动端作为战略储备**，不列入近期硬指标。

这样既避免「全部推倒重来」的风险，又锁定了 Flutter 的长期方向，且每个阶段都有可交付价值。

---

## 附录 A：关键源码文件迁移对照表

| 现有文件 | 行数 | 迁移目标 | 迁移方式 |
|---|---:|---|---|
| `db/ConfigBuilder.cpp` | ~800 | Go core | 重写为 Go，操作 sing-box option |
| `fmt/Bean2CoreObj_box.cpp` | ~250 | Go core | 随 ConfigBuilder 下沉 |
| `fmt/Bean2Link.cpp` + `Link2Bean.cpp` | ~700 | Go core | 链接解析/生成下沉 |
| `sub/GroupUpdater.cpp` | 665 | Go core | 订阅解析下沉 |
| `db/ProfileFilter.cpp` | 80 | Go core | 去重逻辑下沉 |
| `main/NekoGui.cpp` + `NekoGui_DataStore.hpp` | ~600 | Dart 数据类 + Go core | 配置建模拆分 |
| `db/Database.cpp` | ~400 | Dart + 迁移工具 | JSON 文件读写 |
| `rpc/gRPC.cpp` | 342 | Dart grpc 包 | 废弃 C++ 手写实现 |
| `ui/mainwindow.cpp` | 70KB | Flutter 多页面 | 重写，拆分 |
| `ui/edit/*.ui` (18 个) | — | Flutter 动态表单 | schema 驱动重写 |
| `sys/windows/` + `3rdparty/qv2ray/.../QvProxyConfigurator` | ~300 | Flutter MethodChannel | 平台插件 |
| `res/vpn/vpn-run-root.sh` | — | 保留 | Linux TUN 脚本不变 |
| `go/grpc_server/gen/libcore.proto` | — | 扩展 | 新增 RPC 方法 |

## 附录 B：sing-box 必须补齐的新特性清单

| 特性 | 优先级 | 当前状态 |
|---|---|---|
| rule_set（MRS 格式）替代 geoip/geosite | P0 | 硬编码旧 dat，将失效 |
| sniffer 新结构（sniff+timeout+tls_fragment） | P0 | 旧 sniff 字段 |
| route.rules 的 action 字段 | P0 | 旧 outbound 字段 |
| cache_file 启用 | P0 | 未启用 |
| 连接管理（V2Ray API / Clash API v2） | P0 | 空实现 |
| selector / urltest outbound | P1 | 无 |
| SSH / WireGuard / AnyTLS / ShadowTLS v3 / ECH | P1 | 无 |
| experimental.clash_api 新结构 | P1 | 旧结构 |
| endpoint 抽象 | P2 | 旧模型 |
| platform 选项（auto_redirect 等） | P2 | 无 |

---

*报告结束*
