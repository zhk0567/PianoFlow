# 将 Windows 主端曲库/钢琴采样/Verovio 同步到 clients/android assets
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root "pubspec.yaml"))) {
  Write-Host "[PianoFlow/Android] run from repo; expected pubspec at $Root"
  exit 1
}

$Dest = Join-Path $Root "clients\android\app\src\main\assets"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

function Sync-Tree($srcRel, $dstRel) {
  $src = Join-Path $Root $srcRel
  $dst = Join-Path $Dest $dstRel
  if (-not (Test-Path $src)) {
    Write-Host "[PianoFlow/Android] SKIP missing $src"
    return
  }
  if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
  Write-Host "[PianoFlow/Android] synced $srcRel -> assets/$dstRel"
}

Sync-Tree "assets\scores" "scores"
Sync-Tree "assets\audio\piano" "audio\piano"
Sync-Tree "assets\verovio" "verovio"

# Basic Pitch ONNX (Android follow mic)
& (Join-Path $PSScriptRoot "sync-basic-pitch-model.ps1")

# Keep contracts sample folder if present (optional legacy)
Write-Host "[PianoFlow/Android] asset sync done"
