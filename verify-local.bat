@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
node scripts/check-runtime.js
if errorlevel 1 goto failed
where node >nul 2>nul
if errorlevel 1 goto failed
if not exist "node_modules\eslint" (
 call npm ci --include=dev --no-audit --no-fund
 if errorlevel 1 goto failed
)
if not exist ".local-mysql\runtime-manifest.json" (
 call npm run local:download
 if errorlevel 1 goto failed
)
call npm run local:db
if errorlevel 1 goto failed
set "ENV_FILE=%~dp0.env.local"
call npm run lint
if errorlevel 1 goto failed
call npm test
if errorlevel 1 goto failed
call npm run test:integration
if errorlevel 1 goto failed
echo 全部本地验证通过。
if not "%~1"=="--no-pause" pause
exit /b 0
:failed
echo 验证失败，查看 reports 中的报告和上方错误。
if not "%~1"=="--no-pause" pause
exit /b 1
