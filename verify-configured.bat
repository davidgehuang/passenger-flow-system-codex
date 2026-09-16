@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
node scripts/check-runtime.js
if errorlevel 1 goto failed
set "ENV_FILE=%~dp0.env"
if not exist "node_modules\mysql2" (
 call npm ci --no-audit --no-fund
 if errorlevel 1 goto failed
)
call npm run verify:configured
if errorlevel 1 goto failed
if not "%~1"=="--no-pause" pause
exit /b 0
:failed
echo 只读验证失败，请检查 .env、数据库权限和连接。
if not "%~1"=="--no-pause" pause
exit /b 1
