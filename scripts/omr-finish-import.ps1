# Finish PDF→OMR pipeline automatically: MXL → MusicXML → catalog import.
# This does NOT magically proofread against the PDF. It ships the OMR draft.
#
# Usage:
#   .\scripts\omr-finish-import.ps1 -Id toby_fox_megalovania -Title "Megalovania" -Artist "Toby Fox"
#   .\scripts\omr-finish-import.ps1 -Id toby_fox_megalovania -ForceOmr   # overwrite even if formal exists

param(
  [Parameter(Mandatory = $true)][string]$Id,
  [string]$Title = "",
  [string]$Artist = "",
  [string]$Genre = "Classical",
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
  Write-Host "Formal MusicXML already exists: $existing"
  Write-Host "Pass -ForceOmr to overwrite with OMR draft (may reduce accuracy)."
  exit 3
}

if (-not $Description) {
  $Description = "OMR draft from PDF via Audiveris (auto-imported). Proofread against third_party/scores_pdf when possible. Not MIDI."
}

Write-Host "Importing OMR draft:" $mxl
& ".\scripts\import-score.ps1" `
  -Id $Id `
  -Source $mxl `
  -Title $Title `
  -Artist $Artist `
  -Genre $Genre `
  -Difficulty $Difficulty `
  -Description $Description `
  -ScoreKind formal

# Keep a copy of what was imported for audit
$imported = Join-Path $RepoRoot "third_party\scores_musicxml\$Id.musicxml"
if (Test-Path $imported) {
  Copy-Item -Force $imported (Join-Path $work "imported_from_omr.musicxml")
}
Write-Host "Done. Restart app to load $Id."
