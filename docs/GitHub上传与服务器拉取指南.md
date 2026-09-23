# GitHub 上传与其他服务器拉取完整指南

适用于 passenger-flow-system-codex，2026-09-16。

## 1. 是否先建立 repository？

**推荐先在 GitHub 网页建立一个空 repository（仓库）**，再上传本地源码。仓库名建议 `passenger-flow-system-codex`，初次使用建议 Private。

在 GitHub 点击右上角「+」→「New repository」，选择你的账号并填写名称。**不要勾选 Add a README、Add .gitignore 或 Choose a license**，因为本地已有 README 和忽略规则。创建后记录网页显示的 HTTPS 或 SSH 地址。

GitHub 官方也支持通过 GitHub CLI 创建并推送；本指南采用网页创建，便于检查目标账号和可见性。[官方说明](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)

## 2. 推荐：从干净源码导出目录建立新历史

当前原项目已带独立 `.git`。为了不把旧提交历史中可能存在的配置一起带走，推荐使用导出目录；原项目和原 Git 历史均保留。

1. 安装 Git for Windows 和 Node.js 22/24。
2. 双击项目中的 `export-github.bat`。
3. 记下输出的 `artifacts\passenger-flow-system-codex-时间戳` 目录。
4. 用资源管理器进入导出目录，右键打开 PowerShell。
5. 检查目录内容。导出包含代码、建表脚本、示例配置和文档；没有实际配置、数据、依赖、运行时或 Git 历史。
6. 首次配置 Git 身份，并初始化（姓名、邮箱自行替换，可使用 GitHub 提供的隐私邮箱）：

```powershell
git --version
node --version
git init -b main
git config user.name "你的姓名"
git config user.email "你的GitHub提交邮箱"
git status --short
git add .
git diff --cached --stat
git diff --cached
```

最后两个命令用于审阅即将上传的内容，确认没有密码、客户数据、真实连接信息或不准备公开的文档。程序的白名单导出不是通用的秘密扫描器。源码原有 package.json 声明 MIT，但原仓库未提供完整 LICENSE 文件；公开分发前应核实原作者授权，不能由本次修复代替版权授权。

确认后执行：

```powershell
git commit -m "Initial reviewed passenger flow system"
git remote add origin https://github.com/YOUR_ACCOUNT/passenger-flow-system-codex.git
git push -u origin main
```

`YOUR_ACCOUNT` 必须替换为你的实际账号。回 GitHub 刷新，核对 README、文件目录和提交记录。

## 3. 登录与认证

Windows 的 HTTPS 推送通常由 Git Credential Manager 打开浏览器登录。GitHub 账号密码不能直接代替 Git 操作凭据。需要令牌时，优先创建限定到此仓库、具有 Contents 读写权限、设置到期时间的 fine-grained token；在凭据提示里输入，不要放进代码、脚本、远程 URL 或聊天中。

服务器推荐独立 SSH Deploy Key：仅拉取时保持只读，每台服务器单独生成私钥，不把私钥复制到仓库。公钥添加到仓库 Settings → Deploy keys。主机第一次连接时，核对 GitHub 公布的主机指纹，不关闭主机身份校验。

参考：[远程仓库 HTTPS/SSH](https://docs.github.com/en/get-started/git-basics/about-remote-repositories)、[个人令牌说明](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)。

## 4. 如果确实需要保留原有 Git 历史

仅在审查过原仓库历史后使用此路线；不要在上级 codex-tools 仓库误操作。先进入实际项目根目录：

```powershell
git rev-parse --show-toplevel
git status --short
git log --oneline -5
git remote -v
git ls-files .env .env.local
```

最后一条应该没有输出；即使当前没跟踪，也不代表旧历史中没有秘密。若发现历史泄露，应先轮换凭据并清理历史，再考虑发布。不要直接覆盖已有 origin，也不要强推。

可以为新仓库使用独立名称：

```powershell
git add .
git diff --cached
git commit -m "Fix runtime and add cross-platform verification"
git remote add publish https://github.com/YOUR_ACCOUNT/passenger-flow-system-codex.git
git push -u publish HEAD:main
```

若名称已存在，先检查其地址；不要重复添加。若目标仓库已有 README 等提交，推荐重新建立空仓库，或先 clone 后把审阅后的源码复制进去提交；不要用 force 抹掉目标历史。

## 5. Windows 其他电脑首次拉取

```powershell
git clone https://github.com/YOUR_ACCOUNT/passenger-flow-system-codex.git
cd passenger-flow-system-codex
npm ci
.\verify-local.bat
.\start-local.bat
```

便携数据库在每台电脑单独创建，不随 Git 迁移。连接现有 MariaDB 时，从 `.env.example` 复制为 `.env`，填写本机/服务器可达地址、库名与专用账号，然后运行 `verify-configured.bat` 与 `start-configured.bat`。

## 6. Rocky 8、VMware、AWS 服务器首次拉取

安装 Git 后，用普通运维账号拉取；私有仓库按上一节配置服务器认证：

```bash
sudo dnf install -y git
git clone git@github.com:YOUR_ACCOUNT/passenger-flow-system-codex.git
cd passenger-flow-system-codex
git log -1 --oneline
node --version
sudo bash deploy/install.sh
```

安装脚本把应用准备到 `/opt/passenger-flow-codex`，先备份 `/etc/nginx`，再将仓库 `deploy/nginx/nginx.conf` 和 `deploy/nginx/passenger-flow.conf` 分别安装到 `/etc/nginx/nginx.conf`、`/etc/nginx/conf.d/passenger-flow.conf`（80 → 本机 3030）。这会让专用 Nginx 只加载客流系统站点；同机其他站点需先核对影响。服务部署目录和 Git 工作目录可以不同，这是有意设计的：配置和运行数据留在部署目录。按照《使用手册》填写服务器专属 `.env`、验证连接，先启动 `passenger-flow`，再执行 `sudo nginx -t && sudo systemctl enable --now nginx`。通过 `curl -fsS http://127.0.0.1/health` 检查代理。不要复制 Windows 的 `node_modules`、便携数据库或 `.env.local` 到 Linux；不要对公网开放明文 HTTP 登录。

首次安装**源端新库**才执行初始化和种子；**DTS 目标端**不得提前生成演示数据。

## 7. 后续修改、上传与更新

建议上传后，把克隆仓库作为后续开发的唯一工作目录，避免导出目录与原目录分别修改后混乱。先从远端同步：

```powershell
git status --short
git pull --ff-only
# 完成修改并验证后
git add .
git diff --cached
git commit -m "Describe the change"
git push
```

如果你继续在原项目改代码，则重新导出，审阅差异后把源码同步到克隆仓库再提交；不要把导出的新目录每次重新 git init 作为日常流程。

服务器更新：

```bash
cd ~/passenger-flow-system-codex
git status --short
git pull --ff-only
git log -1 --oneline
sudo systemctl stop passenger-flow
sudo bash deploy/install.sh
sudo -u passenger env ENV_FILE=/opt/passenger-flow-codex/.env node /opt/passenger-flow-codex/scripts/verify-configured.js
sudo systemctl start passenger-flow
sudo systemctl status passenger-flow --no-pager
curl -fsS http://127.0.0.1:3030/health
sudo nginx -t
curl -fsS http://127.0.0.1/health
```

先在测试环境验证新提交，再更新正式环境。存在持续负载时先停止并等在途操作归零。若 Git 报本地修改或不能 fast-forward，先保存并解决差异，**不要执行 reset --hard、clean -fd 或强推**来跳过问题。

Git 只同步代码。数据库内容通过备份/恢复或 DTS 迁移；服务器密码、证书和环境配置分别管理。安装脚本保留现有 `.env`，但修改参数后需要重新启动应用。

## 8. 常见错误

| 情况 | 处理 |
|---|---|
| repository not found | 检查账号、仓库名、私有仓库权限与认证账号 |
| remote origin already exists | 检查现有地址，使用独立 remote 名称；不要盲目覆盖 |
| failed to push / non-fast-forward | 先检查目标历史，拉取合并或使用空仓库；不要强推 |
| Permission denied (publickey) | 检查部署公钥是否加入正确仓库、私钥权限和 SSH 用户 |
| npm ci 失败 | 确认 Node 22/24、网络可达、package-lock.json 与 package.json 同一提交 |
| 拉取后页面缺样式 | 正常执行 npm ci，postinstall 会生成本地前端资源 |
| 拉取后没有数据库数据 | 正常现象；Git 不包含数据库，按对应场景初始化或迁移 |
