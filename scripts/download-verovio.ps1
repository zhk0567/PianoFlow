# Download Verovio WASM toolkit into this repository (manual OK).
# Usage:
#   Set-Location F:\commercial\Piano
#   .\scripts\download-verovio.ps1
#
# Links (if auto-download fails, save manually):
#   Toolkit: https://www.verovio.org/javascript/latest/verovio-toolkit-wasm.js
#   Mirror:  https://cdn.jsdelivr.net/npm/verovio@5.2.0/dist/verovio-toolkit-wasm.js
# Place as:  assets\verovio\verovio-toolkit-wasm.js

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

$OutDir = Join-Path $RepoRoot "assets\verovio"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Out = Join-Path $OutDir "verovio-toolkit-wasm.js"

$Urls = @(
  "https://www.verovio.org/javascript/latest/verovio-toolkit-wasm.js",
  "https://cdn.jsdelivr.net/npm/verovio@5.2.0/dist/verovio-toolkit-wasm.js"
)

if ((Test-Path $Out) -and (Get-Item $Out).Length -gt 100000) {
  Write-Host "Already present:" $Out ((Get-Item $Out).Length) "bytes"
  exit 0
}

foreach ($url in $Urls) {
  Write-Host "Trying" $url
  try {
    curl.exe -L --retry 3 --max-time 120 -o $Out $url
    if ((Test-Path $Out) -and (Get-Item $Out).Length -gt 100000) {
      Write-Host "OK:" (Get-Item $Out).Length "bytes ->" $Out
      exit 0
    }
  } catch {
    Write-Host "Failed:" $_
  }
}

Write-Host ""
Write-Host "Auto-download failed. Please download manually:"
Write-Host "  https://www.verovio.org/javascript/latest/verovio-toolkit-wasm.js"
Write-Host "Save to:"
Write-Host "  $Out"
exit 1
