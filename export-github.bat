@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
node scripts/export-source.js
set "RESULT=%errorlevel%"
if not "%~1"=="--no-pause" pause
exit /b %RESULT%
