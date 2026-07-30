# Prepare Windows ONNX Runtime native libs into this repository.
# Avoids CMake downloading from GitHub during `flutter build windows`.
#
# Manual:
#   Download:
#     https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-win-x64-1.22.0.zip
#   Place zip at:
#     third_party\onnxruntime\_fetch\onnxruntime-win-x64-1.22.0.zip
#   Then run this script (extracts under third_party\onnxruntime\).

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

$FetchDir = Join-Path $RepoRoot "third_party\onnxruntime\_fetch"
$Zip = Join-Path $FetchDir "onnxruntime-win-x64-1.22.0.zip"
$OutRoot = Join-Path $RepoRoot "third_party\onnxruntime"
$Header = Join-Path $OutRoot "onnxruntime-win-x64-1.22.0\include\onnxruntime_cxx_api.h"

New-Item -ItemType Directory -Force -Path $FetchDir, $OutRoot | Out-Null

if (Test-Path $Header) {
  Write-Host "OK: already extracted: $Header"
  exit 0
}

if (-not (Test-Path $Zip)) {
  Write-Host "Missing zip. Download manually into:"
  Write-Host "  $Zip"
  Write-Host "URL:"
  Write-Host "  https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-win-x64-1.22.0.zip"
  exit 1
}

Write-Host "Extracting $Zip ..."
Expand-Archive -Path $Zip -DestinationPath $OutRoot -Force
if (-not (Test-Path $Header)) {
  throw "Extract failed — header not found: $Header"
}
Write-Host "OK: $Header"
