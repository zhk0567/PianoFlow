# Sync Windows assets into clients/web for parity practice
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Dest = Join-Path $Root "clients\web"

function Sync-Tree($srcRel, $dstRel) {
  $src = Join-Path $Root $srcRel
  $dst = Join-Path $Dest $dstRel
  if (-not (Test-Path $src)) {
    Write-Host ('[PianoFlow/Web] SKIP missing ' + $src)
    return
  }
  if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
  Write-Host ('[PianoFlow/Web] synced ' + $srcRel + ' -> ' + $dstRel)
}

Sync-Tree "assets\scores" "scores"
Sync-Tree "assets\audio\piano" "audio\piano"
Sync-Tree "assets\verovio" "vendor\verovio"
Write-Host '[PianoFlow/Web] asset sync done'
