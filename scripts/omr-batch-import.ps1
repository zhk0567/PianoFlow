# Enterprise batch / single OMR import (omrDraft only — never formal).
#
# Examples:
#   .\scripts\omr-batch-import.ps1 -Id demo -Pdf .\third_party\scores_pdf\demo.pdf -Title "Demo"
#   .\scripts\omr-batch-import.ps1 -Manifest .\docs\omr_audit\_batch_manifest.json
#   .\scripts\omr-batch-import.ps1 -Resume
#
# Resume re-runs fail list from docs/omr_audit/_omr_batch_report.json

param(
  [string]$Id = "",
  [string]$Pdf = "",
  [string]$Title = "",
  [string]$Artist = "Unknown",
  [ValidateSet("Classical", "Anime", "Pop", "Game")]
  [string]$Genre = "Classical",
  [ValidateRange(1, 5)]
  [int]$Difficulty = 3,
  [string]$Manifest = "",
  [switch]$Resume,
  [switch]$OmrOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $RepoRoot

$args = @(".\scripts\omr_batch_import.py")
if ($Resume) {
  $args += @("--resume", ".\docs\omr_audit\_omr_batch_report.json")
} elseif ($Manifest) {
  $args += @("--manifest", $Manifest)
} elseif ($Id -and $Pdf) {
  $args += @("--id", $Id, "--pdf", $Pdf, "--title", $Title, "--artist", $Artist, "--genre", $Genre, "--difficulty", "$Difficulty")
} else {
  Write-Error "Need -Id/-Pdf, -Manifest, or -Resume"
}

if ($OmrOnly) { $args += "--omr-only" }

Write-Host "Repo:" $RepoRoot
Write-Host "Running:" ($args -join " ")
python @args
exit $LASTEXITCODE
