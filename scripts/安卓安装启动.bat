@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo 正在安装并启动 PianoFlow (Android)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1" apk
pause
