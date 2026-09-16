# 企业连锁门店客流管理系统 V2

**Passenger Flow Management System V2 — 跨云数据库迁移实验平台**

本项目模拟一个真实的企业连锁门店客流管理系统，核心用途是完成：

```
AWS RDS for MySQL 8.0  →  腾讯云 DTS  →  TencentDB for MySQL 8.0
```

的跨云数据库迁移 PoC，并真实验证 Schema 迁移、全量迁移、增量迁移（Binlog/CDC）、INSERT/UPDATE/DELETE 同步、持续业务写入、Migration Marker、Batch Validation 与数据一致性检查。

---

## 一、最终实验架构

### Source 环境（AWS）

```
Browser → AWS EC2 (Rocky Linux 9) → Nginx → Node.js/Express → AWS RDS MySQL 8.0
```

### 迁移链路

```
AWS RDS MySQL 8.0 → 腾讯云 DTS（结构迁移 + 全量迁移 + 增量迁移/CDC）→ TencentDB MySQL 8.0
```

### Target 环境（腾讯云）

```
Browser → 腾讯云 CVM (Rocky Linux 9) → Nginx → 同一套 Node.js Application → TencentDB MySQL 8.0
```

**最重要的架构原则：应用程序与云厂商完全解耦。** 业务代码中不含任何 Endpoint / IP / 账号密码 / 云凭证，一切环境差异只通过 `.env` 切换。迁移到腾讯云后**不修改任何业务代码**，只改 `.env` 中的 `DB_HOST` / `DB_USER` / `DB_PASSWORD` / `APP_ENV_NAME`。

## 二、技术栈

| 层 | 选型 |
| --- | --- |
| Backend | Node.js 18+ / Express / mysql2-promise 连接池 |
| Frontend | EJS / Bootstrap 5 / Chart.js |
| Database | MySQL 8.0（InnoDB / utf8mb4） |
| Linux | Rocky Linux 9 |
| Web Server | Nginx（反代 127.0.0.1:3000） |
| Process | systemd（推荐）/ PM2 兼容 |
| 版本管理 | Git |

**明确不使用**：Docker、Kubernetes、Redis、Kafka、复杂微服务、复杂前端框架——本实验重点是 **Application Rebuild + Database Migration**，而非容器化。

## 三、目录结构

```
passenger-flow-system/
├── app.js                      # Express 入口
├── package.json
├── .env.example                # 环境配置模板（复制为 .env）
├── config/
│   └── database.js             # mysql2 连接池（唯一数据库入口）
├── db/
│   └── schema.sql              # 8 张表建库脚本（InnoDB/utf8mb4）
├── models/                     # 数据访问层（每表一个）
├── services/
│   ├── snapshotService.js      # 快照采集（表统计/业务SUM/样本hash）
│   ├── migrationLabService.js  # 迁移实验室核心（marker/batch/audit）
│   ├── workloadEngine.js       # 持续负载引擎（内存队列）
│   └── workloadService.js      # 持续负载读写逻辑
├── controllers/                # 页面与实验操作控制器
├── routes/                     # 路由
├── views/                      # EJS 视图
├── public/                     # 静态资源（CSS/JS）
├── scripts/                    # CLI 工具（9 个）
│   └── lib/common.js
├── deploy/
│   ├── nginx/passenger-flow.conf
│   ├── systemd/passenger-flow.service
│   └── install.sh              # Rocky Linux 9 一键安装
├── reports/                    # 快照与比对报告输出目录（git 忽略）
└── start-local.bat             # Windows 本地一键启动
```

## 四、数据库表

| 表 | 用途 | 迁移验证角色 |
| --- | --- | --- |
| stores | 门店 | 基础业务表 |
| devices | 门口客流设备 | 基础业务表 |
| flow_events | 客流事件（IN/OUT 明细） | 主验证表：INSERT/UPDATE/DELETE 均发生 |
| flow_hourly | 小时聚合 | 全量数据校验 |
| device_status_logs | 设备状态日志 | 全量数据校验 |
| migration_markers | 迁移标记（含序号） | 验证增量同步顺序完整性 |
| migration_batches | 迁移批次（UUID） | Batch Validation：批次级一致性 |
| migration_operation_audit | 操作审计（before/after 值） | 样本级内容一致性（hash 比对） |

## 五、本地快速开始（Windows）

前置：已安装 Node.js 18+ 与本地 MySQL 8.0，并已创建可登录的账号。

```bat
cd passenger-flow-system
copy .env.example .env     :: 编辑 .env 填入本机 MySQL 账号密码
start-local.bat            # 一键安装依赖 + 建库 + 启动（GBK 编码，直接双击亦可）
```

或手动执行：

```bash
npm install
# 编辑 .env：DB_HOST=127.0.0.1 DB_USER=root DB_PASSWORD=你的密码
npm run db:init            # 建库 + 建表
npm run db:generate        # 生成测试数据（3 门店/6 设备/约 2 万条客流）
npm start                  # http://localhost:3000
```

## 六、环境配置说明（.env）

| 变量 | 说明 |
| --- | --- |
| NODE_ENV | production / development |
| APP_ENV_NAME | **AWS / TENCENT / LOCAL**——页面右上角环境徽标即来源于此 |
| APP_VERSION | 应用版本，迁移验证时确认两端代码一致 |
| PORT | HTTP 端口，默认 3000 |
| DB_HOST / DB_PORT / DB_NAME | 数据库地址与库名（AWS=RDS Endpoint，腾讯=TencentDB Endpoint） |
| DB_USER / DB_PASSWORD | 数据库账号（两套环境各自配置，禁止入库/入 Git） |
| DB_CONNECTION_LIMIT | 连接池上限，默认 20 |
| MAINTENANCE_MODE | **true 时禁止所有业务写操作**（割接窗口使用） |
| GIT_COMMIT | 部署机无法执行 git 时手工填写，程序优先自动读取 |

> 敏感信息纪律：`.env` 已在 `.gitignore` 中，只提交 `.env.example`。

## 七、功能模块

| 路径 | 模块 | 说明 |
| --- | --- | --- |
| `/` | Dashboard | 今日总客流/进店/离店/当前在店、门店数、设备在线离线、最繁忙门店、高峰时间、当前应用环境、数据库状态 |
| `/stores` | 门店管理 | 门店 CRUD、详情含该店客流统计 |
| `/devices` | 设备管理 | 设备 CRUD、在线/离线状态 |
| `/flow-events` | 客流事件 | 分页明细查询（按门店/方向/时间段筛选） |
| `/migration-check` | 迁移自检 | 当前环境数据库连通性、版本、表结构、行数、marker/batch 状态一览 |
| `/migration-lab` | **迁移实验室** | 可视化执行 INSERT/UPDATE/DELETE 实验操作、打 Marker、启动/停止持续负载 |
| `/system-health` | 系统健康 | 应用版本、Git Commit、数据库详情、连接池状态 |
| `/health` | 健康探针 | JSON 探活端点（供 Nginx/云监控使用） |

### 迁移实验室核心概念

- **Migration Marker**：每次打点写入一条带自增序号的记录，迁移后比对两端 marker 数量与最大序号，验证增量同步无丢失、顺序完整。
- **Migration Batch（UUID）**：每个实验操作归入一个批次 UUID，迁移后可按批次核对两端操作条数。
- **Operation Audit（before/after 值）**：INSERT/UPDATE/DELETE 审计记录包含变更前后值，快照时对受影响行计算 SHA-256 hash，实现**样本级内容一致性验证**。
- **Continuous Workload**：可配置速率的持续混合读写（INSERT 为主 + 定期 UPDATE/DELETE），模拟迁移期间业务不停写。

## 八、CLI 脚本一览

| 命令 | 作用 |
| --- | --- |
| `npm run db:init` | 建库建表（幂等，CREATE IF NOT EXISTS） |
| `npm run db:test` | 数据库连接与功能测试 |
| `npm run db:check` | 数据库健康检查（版本/引擎/字符集/表结构核对） |
| `npm run db:generate` | 生成测试数据 |
| `npm run dts:precheck` | DTS 迁移前置检查（binlog 格式、隔离级别、主键、引擎等） |
| `npm run migration:marker` | 命令行打 Marker（如 `--note "full-sync-done"`） |
| `npm run load:continuous` | 命令行持续负载（`--duration 300 --rate 5`） |
| `npm run db:snapshot` | 生成数据库快照 JSON 到 `reports/` |
| `npm run db:compare` | **比对两份快照，输出一致性结论** |

快照与比对用法：

```bash
# AWS 源库（.env 指向 AWS RDS）
npm run db:snapshot -- --output aws-before-cutover.json

# 切换 .env 指向 TencentDB 后
npm run db:snapshot -- --output tencent-after-cutover.json

# 一致性比对（PASS/WARN/FAIL，exit code 0/1）
npm run db:compare -- --source reports/aws-before-cutover.json --target reports/tencent-after-cutover.json
```

比对维度：8 张表行数与 ID 边界、业务 SUM（总人数/进店/离店）、审计操作计数（INSERT/UPDATE/DELETE）、Marker 总数与序号区间、Batch 数量、INSERT/UPDATE 样本 hash、DELETE 样本存在性。

## 九、Linux 部署（Rocky Linux 9）

适用于 AWS EC2 与腾讯云 CVM，两端流程完全一致（Rebuild 也相同）：

```bash
# 1. 拉取代码（或 scp 上传）
sudo dnf install -y git
git clone <repo> /tmp/passenger-flow-system

# 2. 一键安装（Node.js/Nginx/systemd/用户/依赖全部就绪）
cd /tmp/passenger-flow-system
sudo bash deploy/install.sh

# 3. 编辑数据库配置
sudo vi /opt/passenger-flow/.env
# AWS 端:  APP_ENV_NAME=AWS   DB_HOST=<RDS Endpoint>
# 腾讯端:  APP_ENV_NAME=TENCENT DB_HOST=<TencentDB Endpoint>

# 4. 建库 + 测试数据 + 重启
sudo -u passenger bash -c 'cd /opt/passenger-flow && npm run db:init && systemctl restart passenger-flow'
```

常用运维命令：

```bash
systemctl status passenger-flow        # 服务状态
journalctl -u passenger-flow -f        # 实时日志
systemctl restart passenger-flow       # 重启
```

## 十、完整迁移实验流程

### 阶段 1：AWS 源环境（EC2 + RDS）

1. RDS MySQL 8.0 开启自动备份（启用 binlog），创建库账号。
2. EC2 部署本系统（`install.sh`），`.env` 指向 RDS，`APP_ENV_NAME=AWS`。
3. `npm run db:init && npm run db:generate`，Web UI 验证业务正常。
4. `npm run dts:precheck`——确认 binlog_format=ROW、事务隔离级别、全表主键等迁移前提。

### 阶段 2：腾讯云目标环境（CVM + TencentDB）

1. 创建 TencentDB MySQL 8.0（规格 ≥ 源库），安全组放通 CVM 内网访问。
2. CVM 部署同一份代码（git 同一 commit），`.env` 指向 TencentDB，`APP_ENV_NAME=TENCENT`，但**暂不启动服务**（割接前目标端应用不写库）。

### 阶段 3：DTS 迁移任务

1. 腾讯云 DTS 控制台创建迁移任务：源=AWS RDS，目标=TencentDB。
2. 任务类型：**结构迁移 + 全量迁移 + 增量迁移**。
3. 源库前置条件（`dts:precheck` 已验证）：binlog_format=ROW、binlog_row_image=FULL、长事务避免。
4. 启动任务，等待结构 + 全量完成，进入增量同步（CDC 运行中）。

### 阶段 4：增量验证（业务不停写）

```bash
# AWS 端持续写入（Web UI 启动或命令行）
npm run load:continuous -- --duration 600 --rate 5
# 写入期间插入 UPDATE/DELETE 实验（migration-lab 页面操作），并打 Marker
npm run migration:marker -- --note "incremental-verified"
```

DTS 增量延迟归零后，随机抽查：TencentDB 中应能查到最新 marker 与对应序号。

### Cutover Runbook（割接步骤）

> 目标：业务停写窗口内完成切换，数据零丢失。

1. **宣布维护窗口**，通知用户。
2. AWS 端开启只读：`.env` 设 `MAINTENANCE_MODE=true`，`systemctl restart passenger-flow`。此时所有业务写接口返回 503，页面显示维护横幅。
3. 等待 DTS 增量延迟 = 0（控制台确认），停止持续负载。
4. AWS 端打最终标记：`npm run migration:marker -- --note "cutover-final"`。
5. 再次确认 DTS 延迟 = 0，marker 已同步到目标库。
6. AWS 端生成源库快照：`npm run db:snapshot -- --output aws-before-cutover.json`。
7. 暂停 DTS 增量任务（或直接结束任务）。
8. 腾讯 CVM 端 `.env` 确认 `MAINTENANCE_MODE=true`（先保持维护模式上线），启动服务：`systemctl start passenger-flow`。
9. 腾讯端生成目标库快照：`npm run db:snapshot -- --output tencent-after-cutover.json`。
10. **执行一致性比对**（在任一端，指向两份文件）：
    ```bash
    npm run db:compare -- --source reports/aws-before-cutover.json --target reports/tencent-after-cutover.json
    ```
11. 比对 **PASS**（允许 WARN）→ 腾讯端 `.env` 设 `MAINTENANCE_MODE=false`，重启服务，正式对外。
12. 观察腾讯端 Dashboard / system-health 至少 30 分钟，业务正常后关闭 AWS 侧资源（建议保留 RDS 7 天再释放）。

### Rollback（回退方案）

> 触发条件：割接后发现数据不一致或业务异常。

1. 腾讯端立即 `.env` 设 `MAINTENANCE_MODE=true` 并重启（停止一切写入）。
2. DNS/负载均衡切回 AWS EC2。
3. AWS 端 `.env` 设 `MAINTENANCE_MODE=false`，重启服务恢复业务（源库数据在割接前已冻结，无脏数据）。
4. 排查 DTS 任务日志与 `db:compare` 报告定位差异。
5. 修复后重跑阶段 4 → Cutover 流程。

**关键安全设计**：割接期间源库处于维护模式（只读），保证回退时源库仍是权威数据；DTS 增量任务在快照前未停止，保证不漏 binlog。

## 十一、常见问题

| 问题 | 处理 |
| --- | --- |
| `dts:precheck` 提示 binlog_format 非 ROW | AWS RDS 参数组设置 `binlog_format=ROW`、`binlog_row_image=FULL` 后重启实例 |
| DTS 增量延迟不下降 | 检查源库长事务 `SHOW PROCESSLIST`，避免大事务；提高 DTS 规格或暂停负载 |
| db:compare 出现 FAIL | 禁止割接。检查 DTS 任务是否处于同步中、marker 序号断档则说明增量丢失 |
| 页面 503 + 维护横幅 | `MAINTENANCE_MODE=true` 所致，割接完成后改回 false 重启 |
| 连接池耗尽 | 调大 `.env` 的 `DB_CONNECTION_LIMIT`，确认 MySQL `max_connections` |

## 十二、许可证

MIT
