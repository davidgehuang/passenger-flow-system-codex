#!/usr/bin/env bash
# 为专用 Rocky 主机安装 Nginx 代理。先备份 /etc/nginx，再替换入口配置；不开放防火墙、不启动未运行的 Nginx。
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "请使用 sudo bash deploy/setup-nginx.sh"; exit 1; }
. /etc/os-release
[[ "${ID:-}" == rocky && "${VERSION_ID%%.*}" =~ ^(8|9)$ ]] || { echo "此脚本仅支持 Rocky Linux 8/9。"; exit 1; }
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SOURCE="$SOURCE_DIR/nginx/nginx.conf"
SITE_SOURCE="$SOURCE_DIR/nginx/passenger-flow.conf"
MAIN_TARGET=/etc/nginx/nginx.conf
SITE_TARGET=/etc/nginx/conf.d/passenger-flow.conf

[[ -f "$MAIN_SOURCE" && -f "$SITE_SOURCE" ]] || { echo "仓库 Nginx 配置不完整。"; exit 1; }
command -v nginx >/dev/null 2>&1 || { echo "请先安装 Nginx：sudo dnf install -y nginx"; exit 1; }
[[ -f "$MAIN_TARGET" && -d /etc/nginx/conf.d ]] || { echo "Nginx 安装不完整：缺少 nginx.conf 或 conf.d。"; exit 1; }
if [[ -L "$MAIN_TARGET" || -L "$SITE_TARGET" ]]; then
  echo "Nginx 目标配置包含符号链接；为避免改写链接目标，未安装。"
  exit 1
fi
if [[ -e "$SITE_TARGET" && ! -f "$SITE_TARGET" ]]; then
  echo "Nginx 站点目标不是普通文件：$SITE_TARGET；未安装。"
  exit 1
fi

if cmp -s "$MAIN_SOURCE" "$MAIN_TARGET" && cmp -s "$SITE_SOURCE" "$SITE_TARGET"; then
  nginx -t
  if systemctl is-active --quiet nginx; then systemctl reload nginx; fi
  echo "Nginx 代理配置已是最新：80 -> 127.0.0.1:3030。"
  exit 0
fi

umask 077
install -d -m 700 /var/backups/passenger-flow
BACKUP_DIR="$(mktemp -d /var/backups/passenger-flow/nginx-$(date +%Y%m%d-%H%M%S)-XXXXXX)"
tar -C /etc -czf "$BACKUP_DIR/nginx.tar.gz" nginx
cp -a "$MAIN_TARGET" "$BACKUP_DIR/nginx.conf"
SITE_EXISTED=false
if [[ -f "$SITE_TARGET" ]]; then
  cp -a "$SITE_TARGET" "$BACKUP_DIR/passenger-flow.conf"
  SITE_EXISTED=true
fi
echo "原 Nginx 配置备份：$BACKUP_DIR/nginx.tar.gz"

restore_previous() {
  cp -a "$BACKUP_DIR/nginx.conf" "$MAIN_TARGET"
  if [[ "$SITE_EXISTED" == true ]]; then
    cp -a "$BACKUP_DIR/passenger-flow.conf" "$SITE_TARGET"
  else
    rm -f -- "$SITE_TARGET"
  fi
}
if ! install -m 644 "$MAIN_SOURCE" "$MAIN_TARGET" || ! install -m 644 "$SITE_SOURCE" "$SITE_TARGET"; then
  restore_previous
  echo "写入 Nginx 配置失败，已恢复原配置；备份保留在 $BACKUP_DIR。"
  exit 1
fi
if ! nginx -t; then
  restore_previous
  echo "新配置未通过 nginx -t，已恢复原配置；备份保留在 $BACKUP_DIR。"
  exit 1
fi
if systemctl is-active --quiet nginx; then
  if ! systemctl reload nginx; then
    restore_previous
    if nginx -t && systemctl reload nginx; then
      echo "Nginx 重载失败，原配置已恢复并重载；备份保留在 $BACKUP_DIR。"
    else
      echo "Nginx 重载失败，原配置文件已恢复，但运行中的配置未能确认；请检查 systemctl status nginx。"
    fi
    exit 1
  fi
  if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 5 http://127.0.0.1:3030/health >/dev/null 2>&1; then
    if ! curl -fsS --max-time 5 http://127.0.0.1/health >/dev/null 2>&1; then
      restore_previous
      if nginx -t && systemctl reload nginx; then
        echo "Node 3030 可用，但 Nginx 80 代理检查失败；原配置已恢复并重载。请检查错误日志与 SELinux。"
      else
        echo "Node 3030 可用，但 Nginx 80 代理检查失败；原配置文件已恢复，运行中的配置未能确认。"
      fi
      exit 1
    fi
    echo "经 Nginx 80 端口访问 /health 已通过。"
  else
    echo "Node /health 尚未就绪；暂时只能确认 Nginx 配置与重载，服务启动后请再检查代理。"
  fi
  echo "Nginx 已重载：默认 80 端口转发到 127.0.0.1:3030。"
else
  echo "配置已安装且通过 nginx -t；应用就绪后执行 sudo systemctl enable --now nginx。"
fi
echo "此专用配置只加载 passenger-flow.conf；原有其他 Nginx 站点文件保留在磁盘及备份中，但暂不生效。"
