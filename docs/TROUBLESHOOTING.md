# 故障排查

## 关闭软件后文件夹删不掉（Windows 提示"占用中"）

自 beta.17 起，点 X 默认就是真正退出（"最小化到托盘"默认关闭；可在设置中重新打开）。

如果仍被占用，按顺序排查：

1. 任务管理器检查 `nekoray.exe` / `nekobox_core.exe` 是否残留，残留则结束任务。
2. 若开着"最小化到托盘"：点 X 只是隐藏，托盘图标右键 Quit 才是退出。
3. 日志页（或程序目录 `data/logs/core-YYYY-MM-DD.log`）找退出时的 `[ERROR]` 行。
4. 退出时会等待 core 进程被回收（Windows `taskkill` + 二次补杀），`data/core.pid`
   记录 core 进程号；下次启动会自动清理上次崩溃残留的 core 进程。

## 数据存在哪里（便携模式）

Windows/Linux 默认使用程序目录下的 `data/` 文件夹（`profiles/`、`groups/`、
`settings.json`、`logs/` 等），整个程序文件夹拷走即完成迁移/共享。首次启动会自动把
旧版用户目录数据搬过来；也可用 `NEKORAY_DATA_DIR` 环境变量指定位置。macOS 的
`.app` 包仍用系统 Application Support（整包更新会替换 bundle）。

## TUN 模式启动失败

1. 设置页 → TUN 高级选项 → 提权状态：必须显示"已提权"。Windows 请右键"以管理员身份运行"，Linux/macOS 请用 root 启动。
2. 仍失败：看日志页的 `[HINT] TUN:` 行，按提示调整 MTU（默认 1500）或切换协议栈（gvisor / system / mixed）。
3. TUN 需要系统创建虚拟网卡，虚拟机/受限容器里可能直接不可用，改用系统代理模式。

## core 起不来（"proxy core is not running"）

1. 确认安装目录包含 `nekobox_core`（Windows 为 `nekobox_core.exe`），缺失说明发布包不完整，重新下载对应平台压缩包。
2. 端口冲突：设置 → 核心 gRPC 端口改为 0（自动）或换一个 1024 以上的端口。
3. 日志页搜索 `listening`，没有该行说明 core 在启动期崩溃，把日志页内容附到 issue。

## 订阅导入失败 / 节点数为 0

1. 先用"从剪贴板导入"贴一条单链接，定位是网络问题还是解析问题。
2. 订阅内容超过 8 MiB 会被拒绝；需要更大请拆分订阅。
3. 部分失败会明确提示"成功 N 个，部分条目失败 + 原因"，失败条目原因以 core 日志为准。

## 延迟测试一直失败

节点测速走 core 侧 UrlTest（`https://www.gstatic.com/generate_204`，8 秒超时）。该地址不可达的网络里所有节点都会失败，这不代表节点不可用，换常用网站测速（首页仪表盘）交叉验证。
