@echo off
REM ASCII-only launcher (avoid cmd encoding/pipe bugs with Chinese).
cd /d "%~dp0"
title PianoFlow
echo PianoFlow quick start (existing exe, no Flutter logs)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1" windows
set ERR=%ERRORLEVEL%
echo.
if %ERR% neq 0 (
  echo Failed, exit code %ERR%
) else (
  echo Started. Close this window when done.
)
pause
exit /b %ERR%
