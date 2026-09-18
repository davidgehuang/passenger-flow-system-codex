@echo off
setlocal
cd /d "%~dp0"
node scripts/db-storage-diagnose.js
set "RESULT=%ERRORLEVEL%"
if not "%~1"=="--no-pause" pause
exit /b %RESULT%
