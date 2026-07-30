@echo off
chcp 65001 >nul
cd /d "%~dp0"
title PianoFlow - 安装 Windows 编译环境
echo 将安装 Visual Studio 2022 Build Tools（C++ 桌面开发）...
echo 体积较大，请保持网络畅通，完成后即可用「启动.bat」。
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-windows-toolchain.ps1"
pause
