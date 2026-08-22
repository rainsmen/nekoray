# nekoray 架构说明

## 当前架构（v4.x，C++/Qt）

```
┌──────────────┐   gRPC(HTTP/2手写)   ┌──────────────┐
│  Qt Widgets   │◄──────────────────►│ nekobox_core │► sing-box
│  (C++)        │   QNetworkAccess    │   (Go)       │
└──────────────┘                     └──────────────┘
```

- **UI 层**：C++ / Qt Widgets，业务逻辑全在 C++ 层（ConfigBuilder/JsonStore/订阅/路由）
- **IPC**：手写 gRPC over HTTP/2（`rpc/gRPC.cpp`）
- **核心**：Go `nekobox_core` 通过 gRPC 桥接 sing-box

## 目标架构（v5.x，Flutter）

```
┌──────────────┐  gRPC(官方库)   ┌──────────────┐
│ Flutter UI    │◄───────────────►│ nekobox_core │► sing-box
│  (Dart)       │                 │   (Go, 扩展)  │
│  - 状态管理    │                 │  +ConfigBuild│
│  - 数据模型    │                 │  +订阅更新    │
│  - 平台插件    │                 │  +路由生成    │
└──────────────┘                 └──────────────┘
```

- **UI 层**：Flutter（Dart），仅做渲染+交互+本地缓存
- **IPC**：官方 gRPC Dart 库
- **核心**：Go `nekobox_core` 扩展，业务逻辑下沉（ConfigBuilder/订阅/路由）

## 迁移阶段

详见 [Flutter迁移实施计划.md](./Flutter迁移实施计划.md)

- **阶段零**：仓库 + CI 搭建
- **阶段一**：Go core 升级 + 业务下沉（C++ UI 不变）
- **阶段二**：Flutter 桌面端重写
- **阶段三**：移动端适配（可选）

## 关键目录

| 目录 | 说明 |
|---|---|
| `main/` | C++ 主程序（过渡期保留） |
| `db/` | C++ 数据存储 + 配置构建（阶段一下沉到 Go） |
| `fmt/` | C++ Bean 数据模型（阶段一 Go 重建） |
| `sub/` | C++ 订阅解析（阶段一下沉到 Go） |
| `ui/` | C++ Qt 界面（阶段二 Flutter 重写） |
| `rpc/` | C++ gRPC 客户端（阶段二废弃，Dart grpc 替代） |
| `go/` | Go core（阶段一扩展） |
| `nekoray_flutter/` | Flutter 工程（阶段二启用） |
| `libs/` | 构建脚本 |
| `res/` | 资源文件 |
