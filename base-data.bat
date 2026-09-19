@echo off
cd /d "%~dp0"
if "%~1"=="" (
  echo Usage: base-data.bat --mode ensure --stores 50 --devices-per-store 4 --dry-run
  pause
  exit /b 1
)
node scripts\base-data.js %*
exit /b %errorlevel%
