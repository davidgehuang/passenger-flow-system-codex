#!/usr/bin/env bash
# 现有部署的只读验证；不建库、不修改数据库内容。
set -euo pipefail
APP_DIR="${APP_DIR:-/opt/passenger-flow-codex}"
export PATH="/usr/local/bin:/usr/bin${PATH:+:$PATH}"
[[ -d "$APP_DIR" ]] || { echo "运行目录不存在：$APP_DIR"; exit 1; }
[[ -d "$APP_DIR/node_modules/dotenv" ]] || { echo "缺少生产依赖。请先执行：sudo bash /当前源码目录/deploy/install.sh"; exit 1; }
cd "$APP_DIR"
export ENV_FILE="${ENV_FILE:-$APP_DIR/.env}"
[[ -f "$ENV_FILE" ]] || { echo "配置文件不存在：$ENV_FILE"; exit 1; }
node scripts/check-runtime.js
node scripts/verify-configured.js
echo "应用及数据库只读检查通过。完整服务部署还需检查 systemd、访问入口与 TLS。"
