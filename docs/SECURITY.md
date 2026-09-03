# 安全模型

## 已落实

- **gRPC 鉴权**：Flutter 拉起 core 时生成 256-bit token，经 `NEKORAY_AUTH_TOKEN` 环境变量传递（不在 argv/进程表暴露），core 读取后立即 unset；每次调用附带 token metadata。
- **本地监听**：core 只监听 `127.0.0.1`。
- **更新包校验**：release 附带 `SHA256SUMS.txt`；updater 无 checksums 时拒绝安装、下载后比对 digest，不一致拒绝写入。
- **存储权限**：POSIX 下数据目录 `700`、文件 `600`（Windows 继承用户目录 ACL）。
  便携模式（程序目录 `data/`）同样适用；与他人共享整个程序文件夹即共享全部节点配置，请注意脱敏。
- **父进程监督**：core 在父进程退出后自行退出（Linux PDEATHSIG / Windows 句柄等待 / 其他平台 PPID 轮询），避免无主代理残留。

## 已知缺口（诚实声明）

- **更新包无发布者签名**：SHA256 只能防传输损坏，源被劫持则校验值可一并伪造。后续需要签名 + provenance。
- **节点密码本地明文存储**：profiles JSON 为明文，依赖文件系统权限；设备被 root/管理员接管即泄露。这是同类工具的常见取舍，暂不引入系统钥匙串。
- **gRPC 明文（loopback）**：同一台机器的其他用户理论可嗅探；token 机制将风险收敛为"本机其他进程"，可接受。

## 报告漏洞

请走 GitHub Issue（公开）或给维护者发邮件（涉及在野利用细节时）。请附：版本、平台、`<appDir>/logs/` 相关行、日志页"导出诊断包"文件（已脱敏，不含节点密码）。
