#!/usr/bin/env bash
# 将仓库中的反向代理片段安装到 Rocky 默认 Nginx 站点；不开放防火墙、不启动 Nginx。
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "请使用 sudo bash deploy/setup-nginx.sh"; exit 1; }
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SOURCE_DIR/nginx/passenger-flow.conf"
TARGET=/etc/nginx/default.d/passenger-flow.conf

[[ -f "$SOURCE" ]] || { echo "缺少仓库配置：$SOURCE"; exit 1; }
command -v nginx >/dev/null 2>&1 || { echo "请先安装 Nginx：sudo dnf install -y nginx"; exit 1; }
[[ -f /etc/nginx/nginx.conf ]] || { echo "未找到 /etc/nginx/nginx.conf"; exit 1; }
[[ -d /etc/nginx/default.d ]] || { echo "未找到 Rocky 默认站点目录 /etc/nginx/default.d；未改动配置。"; exit 1; }
if [[ -L "$TARGET" || ( -e "$TARGET" && ! -f "$TARGET" ) ]]; then
  echo "目标路径不是普通配置文件：$TARGET；未改动配置。"
  exit 1
fi
if ! grep -Eq '^[[:space:]]*include[[:space:]]+/etc/nginx/default\.d/\*\.conf;' /etc/nginx/nginx.conf; then
  echo "当前 Nginx 不是 Rocky 默认站点结构：未包含 /etc/nginx/default.d/*.conf；未改动配置。"
  exit 1
fi
if [[ -e "$TARGET" ]] && ! grep -q '^# passenger-flow managed default-site snippet$' "$TARGET"; then
  echo "已有非本项目管理的 $TARGET；为避免覆盖，未改动配置。"
  exit 1
fi
nginx -t || { echo "现有 Nginx 配置本来就未通过检查；未改动配置。"; exit 1; }

if [[ -f "$TARGET" ]] && cmp -s "$SOURCE" "$TARGET"; then
  if systemctl is-active --quiet nginx; then systemctl reload nginx; fi
  echo "Nginx 代理配置已是最新：$TARGET"
  exit 0
fi

BACKUP=""
if [[ -e "$TARGET" ]]; then
  BACKUP="$(mktemp "${TARGET}.bak-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
  cp -p "$TARGET" "$BACKUP"
  echo "原 Nginx 配置备份：$BACKUP"
fi
install -D -m 644 "$SOURCE" "$TARGET"

restore_previous() {
  if [[ -n "$BACKUP" ]]; then cp -p "$BACKUP" "$TARGET"; else rm -f -- "$TARGET"; fi
}
if ! nginx -t; then
  restore_previous
  echo "新配置未通过 nginx -t，已恢复原配置；请检查默认站点是否已有 location /。"
  exit 1
fi
if systemctl is-active --quiet nginx; then
  if ! systemctl reload nginx; then
    restore_previous
    nginx -t && systemctl reload nginx || true
    echo "Nginx 重载失败，已恢复原配置；请检查 systemctl status nginx。"
    exit 1
  fi
  echo "Nginx 已重载：默认 80 端口转发到 127.0.0.1:3030。"
else
  echo "配置已安装且通过 nginx -t；应用就绪后执行 sudo systemctl enable --now nginx。"
fi
if [[ -f /etc/nginx/conf.d/passenger-flow.conf ]]; then
  echo "提示：旧版 /etc/nginx/conf.d/passenger-flow.conf 仍存在；未自动修改，请核对其监听端口。"
fi
