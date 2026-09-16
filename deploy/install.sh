#!/usr/bin/env bash
# 仅准备应用文件与依赖：不建库、不启动服务、不修改防火墙。
set -euo pipefail
APP_DIR="${APP_DIR:-/opt/passenger-flow-codex}"
APP_USER="passenger"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $EUID -eq 0 ]] || { echo "请使用 sudo bash deploy/install.sh"; exit 1; }
. /etc/os-release
[[ "${ID:-}" == "rocky" && "${VERSION_ID%%.*}" =~ ^(8|9)$ ]] || { echo "此安装脚本仅支持 Rocky Linux 8/9"; exit 1; }
if ! command -v node >/dev/null; then
  echo "请先安装 Node.js 22/24，并保证 /usr/bin/node 可用；参见使用手册。"
  exit 1
fi
node "$SOURCE_DIR/scripts/check-runtime.js" || { echo "需要 Node.js 22 或 24"; exit 1; }
[[ "$(command -v node)" == "/usr/bin/node" ]] || { echo "systemd 使用 /usr/bin/node，请先配置系统级 Node.js"; exit 1; }
dnf install -y nginx rsync
if ! id "$APP_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /var/lib/passenger --shell /sbin/nologin "$APP_USER"
fi
mkdir -p "$APP_DIR" /var/lib/passenger
chown "$APP_USER:$APP_USER" /var/lib/passenger
if [[ "$SOURCE_DIR" != "$APP_DIR" ]]; then
  if [[ -f "$APP_DIR/package.json" ]]; then
    BACKUP="/opt/passenger-flow-codex-code-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar --exclude='.env*' --exclude='node_modules' --exclude='.local-mysql' --exclude='reports' -czf "$BACKUP" -C "$APP_DIR" .
    echo "原代码备份：$BACKUP"
  fi
  rsync -a --include='.env.example' --exclude='.env*' --exclude='.maintenance' --exclude='node_modules' --exclude='.local-mysql' --exclude='.git' --exclude='reports' --exclude='artifacts' "$SOURCE_DIR/" "$APP_DIR/"
fi
if [[ ! -f "$APP_DIR/.env" ]]; then
  cp "$APP_DIR/.env.example" "$APP_DIR/.env"
fi
mkdir -p "$APP_DIR/reports"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
chmod 600 "$APP_DIR/.env"
runuser -u "$APP_USER" -- env HOME=/var/lib/passenger npm ci --omit=dev --prefix "$APP_DIR"
install -m 644 "$APP_DIR/deploy/systemd/passenger-flow.service" /etc/systemd/system/passenger-flow.service
systemctl daemon-reload
# 配置先写为样例，用户确认端口与现有 Nginx 后再启用。
install -m 644 "$APP_DIR/deploy/nginx/passenger-flow.conf" /etc/nginx/conf.d/passenger-flow.conf.example
echo "准备完成。未执行建库、种子生成或服务启动。"
echo "下一步填写 $APP_DIR/.env，按 docs/使用手册.md 的源端或目标端流程操作。"
