# Convert MusicXML in third_party/scores_musicxml → assets/scores/*.json
# Ids come from assets/scores/catalog.json (no hardcoded list).
# Usage:
#   Set-Location F:\commercial\PianoFlow
#   .\scripts\convert-scores.ps1
#   .\scripts\convert-scores.ps1 -Id fur_elise_woo59

param(
  [string]$Id = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

Write-Host "Repo:" $RepoRoot

$py = $null
foreach ($c in @("python", "py")) {
  try {
    $v = & $c --version 2>&1
    if ($LASTEXITCODE -eq 0 -or $v -match "Python") {
      $py = $c
      break
    }
  } catch {}
}
if (-not $py) {
  Write-Error "Python not found. Install Python 3 and retry."
}

$Src = Join-Path $RepoRoot "third_party\scores_musicxml"
New-Item -ItemType Directory -Force -Path $Src | Out-Null

if ($Id) {
  $ids = @($Id)
} else {
  $ids = @(
    & $py -c "import json; from pathlib import Path; d=json.loads(Path('assets/scores/catalog.json').read_text(encoding='utf-8')); print('\n'.join(s['id'] for s in d.get('songs') or [] if s.get('id')))"
  )
  if ($ids.Count -eq 0) {
    Write-Error "No song ids in assets/scores/catalog.json"
  }
  Write-Host ("Catalog ids: {0}" -f $ids.Count)
}

$missing = @()
foreach ($sid in $ids) {
  $found = $false
  foreach ($ext in @(".musicxml", ".xml", ".mxl", ".MusicXML")) {
    $p = Join-Path $Src ($sid + $ext)
    if (Test-Path $p) { $found = $true; break }
  }
  if (-not $found) { $missing += $sid }
}

if ($missing.Count -gt 0) {
  Write-Host ""
  Write-Host "Missing MusicXML (place under $Src):"
  foreach ($m in $missing) { Write-Host "  - $m.musicxml" }
  Write-Host "Download links: docs\曲谱来源.md"
  Write-Host ""
}

$failed = 0
if ($Id) {
  & $py ".\scripts\musicxml_to_score.py" "--update-catalog" "--id" $Id
  if ($LASTEXITCODE -ne 0) { $failed = 1 }
} else {
  foreach ($sid in $ids) {
    if ($missing -contains $sid) {
      Write-Host "Skip missing MusicXML: $sid" -ForegroundColor Yellow
      continue
    }
    Write-Host "---- convert $sid ----" -ForegroundColor Cyan
    & $py ".\scripts\musicxml_to_score.py" "--update-catalog" "--id" $sid
    if ($LASTEXITCODE -ne 0) { $failed = 1 }
  }
}

if ($failed -ne 0) { exit $failed }

Write-Host "Running catalog scoreKind guard..."
& $py ".\scripts\catalog_score_kind_guard.py"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Running catalog integrity guard..."
& $py ".\scripts\catalog_integrity_guard.py"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Running score_kind_policy JSON↔Dart check..."
& $py ".\scripts\score_kind_policy_sync.py" "--check"
exit $LASTEXITCODE
