# PianoFlow Web 本地静态服务（Windows PowerShell）
# 浏览器打开：http://127.0.0.1:8765/
# 勿用 file://

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$sync = Join-Path $PSScriptRoot "..\..\scripts\sync-web-assets.ps1"
$sync = [System.IO.Path]::GetFullPath($sync)
if (Test-Path $sync) {
  Write-Host '[PianoFlow/Web] syncing assets...'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $sync
}

Write-Host ('[PianoFlow/Web] serving ' + $PWD)
Write-Host '[PianoFlow/Web] open: http://127.0.0.1:8765/'
python -m http.server 8765 --bind 127.0.0.1
