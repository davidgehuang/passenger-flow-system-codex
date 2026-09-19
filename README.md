# 客流管理与数据库迁移实验系统

版本：0.3.2；交付目录：`passenger-flow-system-codex`。

这是基于 Node.js、Express、EJS、MySQL/MariaDB 的客流管理及数据库迁移实验应用。包含门店、设备、客流明细、统计看板、造数、持续负载、迁移标记、停写保护和全表一致性检查。当前没有真实摄像头接入、访客去重算法、企业级权限分工或高可用集群。

## Windows 11 直接使用

先安装 Node.js 22.2 以上或 24，推荐已实测的 24。进入本目录：

| 入口 | 用途 |
|---|---|
| 双击 `start-local.bat` | 启动项目专用便携 MySQL 8.0 和应用，浏览器打开 http://127.0.0.1:3030 |
| 双击 `verify-local.bat` | 自动准备本地数据库，执行代码检查、单元与真实数据库集成测试 |
| 双击 `start-configured.bat` | 使用已有 `.env` 连接 MariaDB/MySQL，启动应用；不自动建库 |
| 双击 `verify-configured.bat` | 对 `.env` 指定数据库执行只读检查 |
| 双击 `stop-local-db.bat` | 停止本项目便携 MySQL，保留全部数据 |
| 双击 `export-github.bat` | 在 `artifacts` 导出可审阅的纯源码目录，不自动上传 |

首次便携启动需要联网下载依赖和官方 MySQL。无需 Docker，不注册数据库系统服务。端口为应用 3030、便携数据库 33317。原 `.env` 保持独立；本地便携环境使用自动生成的 `.env.local`。

关闭应用窗口或按 Ctrl+C 停止应用后，再运行停库脚本。**不要在应用或数据库运行中移动、改名项目目录。**

## 文档

1. [使用手册](docs/使用手册.md)：Windows、VMware/Rocky 8、AWS、腾讯云 DTS、日常操作与排错。
2. [修复说明与验证报告](docs/修复说明与验证报告.md)：需求、问题根因、修复范围、实测证据和未验证边界。
3. [GitHub 上传与服务器拉取指南](docs/GitHub上传与服务器拉取指南.md)：新建仓库、首次推送、后续更新、其他服务器拉取与部署。

## 运行与验证状态

Windows 11 + Node.js 24 + 便携 MySQL 8.0.46 已完成真实运行与集成验证。现有 MariaDB 10.3.39 已完成只读页面验证。Rocky Linux 8.10 的系统版本、Node.js 与脚本语法已核验。MariaDB 10.3.39 的独立写入回归和真实 Chrome 验收均已通过，详见修复报告。

AWS 资源创建、腾讯云 DTS 真实迁移和 VMware 服务器完整安装需要对应环境操作；本次未将本地两库复制冒充云迁移成功。

## 数据与 Git

不要提交 `.env*`（`.env.example` 除外）、`.local-mysql`、`node_modules`、`reports`、数据库备份或私钥。源码导出不会带入旧 Git 历史。当前项目已有独立 Git 仓库，未经你的操作不会自动推送。

测试会创建并保留本次专用的 `pf_test_*` 数据库。生成数据、批量更新、批量删除和持续负载会真实写入当前配置的数据库，请仅对实验库使用。

容量自动刷新及本次代码审查：[修复、部署与验收说明](docs/容量修复与代码审查说明-20260918.md)。只读诊断运行 `npm run db:storage`，Windows 可双击 `diagnose-storage.bat`。

## 批量门店／设备扩容

进入 Stores 或 Devices → **批量初始化／扩容**，支持目标补齐、新增门店和指定门店加设备。命令行：`npm run db:base-data -- --mode ensure --stores 50 --devices-per-store 4 --dry-run`；Windows 提供 `base-data.bat` 参数入口。详见 [使用与重试说明](docs/基础资料初始化与扩容-20260919.md) 和 [实测报告](docs/基础资料扩容测试报告-20260919.md)。
