# Finish PDF→OMR pipeline automatically: MXL → MusicXML → catalog import.
# This does NOT magically proofread against the PDF. It ships an **omrDraft**.
# NEVER marks formal — proofread first (docs/曲谱导入SOP.md), then import with
# .\scripts\import-score.ps1 -ScoreKind formal
#
# Usage:
#   .\scripts\omr-finish-import.ps1 -Id hisaishi_castle_in_the_sky -Title "天空之城" -Artist "Joe Hisaishi"
#   .\scripts\omr-finish-import.ps1 -Id toby_fox_megalovania -ForceOmr   # overwrite existing with OMR draft

param(
  [Parameter(Mandatory = $true)][string]$Id,
  [string]$Title = "",
  [string]$Artist = "",
  [ValidateSet("Classical", "Anime", "Pop", "Game")]
  [string]$Genre = "Classical",
  [ValidateRange(1, 5)]
  [int]$Difficulty = 3,
  [string]$Description = "",
  [switch]$ForceOmr
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $RepoRoot
Write-Host "Repo:" $RepoRoot

$work = Join-Path $RepoRoot "third_party\scores_musicxml\_omr_work\$Id"
$mxl = Join-Path $work "omr_draft.mxl"
if (-not (Test-Path $mxl)) {
  $mxl = Join-Path $work "audiveris_out\source.mxl"
}
if (-not (Test-Path $mxl)) {
  Write-Error "No OMR draft for $Id. Run .\scripts\omr-from-pdf.ps1 first."
}

$existing = Join-Path $RepoRoot "third_party\scores_musicxml\$Id.musicxml"
if ((Test-Path $existing) -and -not $ForceOmr) {
  Write-Host "MusicXML already exists: $existing"
  Write-Host "Pass -ForceOmr to overwrite with OMR draft (stays omrDraft; may reduce accuracy)."
  exit 3
}

if (-not $Description) {
  $Description = "OMR draft from PDF via Audiveris (auto-imported; BPM may be a practice default). Proofread against third_party/scores_pdf when possible. Not MIDI. Local practice only — not claimed 100% accurate."
}

Write-Host "Importing OMR draft as scoreKind=omrDraft (NOT formal):" $mxl
& ".\scripts\import-score.ps1" `
  -Id $Id `
  -Source $mxl `
  -Title $Title `
  -Artist $Artist `
  -Genre $Genre `
  -Difficulty $Difficulty `
  -Description $Description `
  -ScoreKind omrDraft
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Lock id against accidental formal promotion (JSON + Dart mirror).
Write-Host "Registering OMR provenance id in score_kind_policy..."
python ".\scripts\score_kind_policy_sync.py" --add-id $Id
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Keep a copy of what was imported for audit
$imported = Join-Path $RepoRoot "third_party\scores_musicxml\$Id.musicxml"
if (Test-Path $imported) {
  Copy-Item -Force $imported (Join-Path $work "imported_from_omr.musicxml")
}

Write-Host "Running OMR audit report..."
python ".\scripts\omr_audit_score.py" --id $Id --fail-on-drift
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Running catalog scoreKind guard..."
python ".\scripts\catalog_score_kind_guard.py"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Running catalog integrity guard..."
python ".\scripts\catalog_integrity_guard.py"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Running score_kind_policy JSON↔Dart check..."
python ".\scripts\score_kind_policy_sync.py" "--check"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Done. Restart app to load $Id. Do NOT set formal until PDF proofread passes."
Write-Host "To promote later: remove id from assets/scores/score_kind_policy.json (+ sync Dart) after SOP checklist."
