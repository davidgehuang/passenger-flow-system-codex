#!/usr/bin/env bash
# 现有部署的只读验证；不建库、不修改数据库内容。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export ENV_FILE="${ENV_FILE:-$ROOT/.env}"
node scripts/check-runtime.js
node scripts/verify-configured.js
echo "应用及数据库只读检查通过。完整服务部署还需检查 systemd、访问入口与 TLS。"
