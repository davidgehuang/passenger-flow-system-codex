@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 goto node_missing
node scripts/check-runtime.js
if errorlevel 1 goto node_missing
if not exist "node_modules\mysql2" (
  call npm ci --no-audit --no-fund
  if errorlevel 1 goto failed
)
if not exist ".local-mysql\runtime-manifest.json" (
  echo 正在下载官方 MySQL 8.0 便携运行文件，首次启动需要联网。
  call npm run local:download
  if errorlevel 1 goto failed
)
call npm run local:db
if errorlevel 1 goto failed
set "ENV_FILE=%~dp0.env.local"
call npm run db:init
if errorlevel 1 goto failed
call npm run db:seed
if errorlevel 1 goto failed
call npm run db:ready
if errorlevel 1 goto failed
echo 本地测试地址请以 .env.local 中的 PORT 为准；新建本地配置默认是 http://127.0.0.1:3030
echo 首次生成演示客流：在另一终端设置 ENV_FILE=.env.local 后运行 npm run db:generate
call npm start
exit /b %errorlevel%
:node_missing
echo 需要先安装 Node.js 22 或 24 LTS：https://nodejs.org/
goto failed
:failed
echo 启动未完成，请根据上面的错误处理。未修改原 .env。
pause
exit /b 1
