# Prepare SwiftF0 model into this repository (manual or optional pip).
# Usage:
#   Set-Location F:\commercial\Piano
#   .\scripts\download-swiftf0.ps1
#
# Expected output:
#   assets/models/swiftf0.onnx
#
# Manual (recommended if pip/network is slow):
#   1. Get model.onnx from swift-f0 0.1.2 wheel / GitHub release
#      https://pypi.org/project/swift-f0/  or  https://github.com/lars76/swift_f0
#   2. Copy/rename to: assets\models\swiftf0.onnx
#   3. Re-run this script to verify.

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot
Write-Host "Repo root: $RepoRoot"

$FetchDir = Join-Path $RepoRoot "third_party\swift_f0\_fetch"
$AssetsDir = Join-Path $RepoRoot "assets\models"
$TpDir = Join-Path $RepoRoot "third_party\swift_f0"
$ModelOut = Join-Path $AssetsDir "swiftf0.onnx"
$LicenseOut = Join-Path $TpDir "LICENSE"

New-Item -ItemType Directory -Force -Path $FetchDir, $AssetsDir, $TpDir | Out-Null

if (Test-Path $ModelOut) {
  $size = (Get-Item $ModelOut).Length
  Write-Host "OK: model already present: $ModelOut ($size bytes)"
} else {
  Write-Host "Model not found at $ModelOut"
  Write-Host "Trying optional pip download into third_party (repo-local)..."

  $WheelName = "swift_f0-0.1.2-py3-none-any.whl"
  $WheelPath = Join-Path $FetchDir $WheelName
  $ZipPath = Join-Path $FetchDir "swift_f0.zip"
  $ExtractDir = Join-Path $FetchDir "extracted"

  if (-not (Test-Path $WheelPath)) {
    pip download "swift-f0==0.1.2" -d $FetchDir --no-deps
  }

  if (-not (Test-Path $WheelPath)) {
    Write-Host ""
    Write-Host "AUTO DOWNLOAD FAILED — place the file yourself:"
    Write-Host "  $ModelOut"
    Write-Host "Source: swift-f0 package model.onnx (PyPI wheel or github.com/lars76/swift_f0)"
    exit 1
  }

  Copy-Item $WheelPath $ZipPath -Force
  if (Test-Path $ExtractDir) { Remove-Item $ExtractDir -Recurse -Force }
  Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force

  $ModelSrc = Join-Path $ExtractDir "swift_f0\model.onnx"
  $LicenseSrc = Join-Path $ExtractDir "swift_f0-0.1.2.dist-info\licenses\LICENSE"
  if (-not (Test-Path $ModelSrc)) {
    throw "model.onnx not found in wheel: $ModelSrc"
  }
  Copy-Item $ModelSrc $ModelOut -Force
  if (Test-Path $LicenseSrc) {
    Copy-Item $LicenseSrc $LicenseOut -Force
  }
  Write-Host "OK: copied $ModelOut"
}

if (-not (Test-Path $LicenseOut)) {
  # Minimal license stub pointer if user only dropped the onnx
  Set-Content -Path $LicenseOut -Value "See https://github.com/lars76/swift_f0 (MIT)" -Encoding UTF8
}

$Notice = @"
# SwiftF0 third-party notice

- Package: swift-f0 0.1.2 (PyPI)
- Upstream: https://github.com/lars76/swift_f0
- Model path in app assets: assets/models/swiftf0.onnx
- License: MIT (see LICENSE in this folder)
- Paper: Nieradzik, SwiftF0: Fast and Accurate Monophonic Pitch Detection, arXiv:2508.18440 (2025)
  https://arxiv.org/abs/2508.18440

Place files only under this repository (assets/models, third_party/swift_f0).
"@
Set-Content -Path (Join-Path $TpDir "NOTICE.md") -Value $Notice -Encoding UTF8
Write-Host "Done."
