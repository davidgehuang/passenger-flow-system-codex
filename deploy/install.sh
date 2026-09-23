#!/usr/bin/env bash
# 准备应用、systemd 和 Rocky 默认 Nginx 代理：不建库、不启动服务、不修改防火墙。
set -euo pipefail
APP_DIR="${APP_DIR:-/opt/passenger-flow-codex}"
APP_USER="passenger"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/usr/local/bin:/usr/bin${PATH:+:$PATH}"
[[ $EUID -eq 0 ]] || { echo "请使用 sudo bash deploy/install.sh"; exit 1; }
. /etc/os-release
[[ "${ID:-}" == "rocky" && "${VERSION_ID%%.*}" =~ ^(8|9)$ ]] || { echo "此安装脚本仅支持 Rocky Linux 8/9"; exit 1; }
NODE_BIN="$(command -v node || true)"
if [[ -z "$NODE_BIN" ]]; then
  echo "请先安装 Node.js 22/24 到系统路径 /usr/bin 或 /usr/local/bin；参见使用手册。"
  exit 1
fi
case "$NODE_BIN" in
  /usr/bin/node|/usr/local/bin/node) ;;
  *)
    echo "检测到 Node.js 位于 $NODE_BIN；这是个人或非系统路径，systemd 无法可靠使用。请安装到 /usr/bin 或 /usr/local/bin。"
    exit 1
    ;;
esac
"$NODE_BIN" "$SOURCE_DIR/scripts/check-runtime.js" || { echo "需要 Node.js 22 或 24"; exit 1; }
NODE_DIR="$(dirname "$NODE_BIN")"
NPM_BIN="$NODE_DIR/npm"
[[ -x "$NPM_BIN" ]] || { echo "未找到与 $NODE_BIN 配套的 npm：$NPM_BIN"; exit 1; }
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
runuser -u "$APP_USER" -- env HOME=/var/lib/passenger PATH="$NODE_DIR:/usr/bin" "$NPM_BIN" ci --omit=dev --prefix "$APP_DIR"
install -m 644 "$APP_DIR/deploy/systemd/passenger-flow.service" /etc/systemd/system/passenger-flow.service
systemctl daemon-reload
bash "$APP_DIR/deploy/setup-nginx.sh"
echo "准备完成。未执行建库、种子生成、服务启动或防火墙开放。"
echo "下一步填写 $APP_DIR/.env，启动 passenger-flow，再启用 Nginx；参见 docs/使用手册.md。"
