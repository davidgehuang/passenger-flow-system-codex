@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
node scripts/check-runtime.js
if errorlevel 1 goto failed
if not exist ".env" (
  echo 请先复制 .env.example 为 .env 并填写数据库配置。
  pause
  exit /b 1
)
if not exist "node_modules\mysql2" (
  call npm ci --no-audit --no-fund
  if errorlevel 1 exit /b 1
)
set "ENV_FILE=%~dp0.env"
echo 正在检查并补齐 .env 指定数据库的业务表；不会创建数据库、用户或演示数据。
call npm run db:init
if errorlevel 1 (
  pause
  exit /b 1
)
call npm run db:ready
if errorlevel 1 (
  pause
  exit /b 1
)
call npm start
exit /b %errorlevel%
:failed
echo 启动失败，请检查 Node.js 版本和上方错误。
pause
exit /b 1
