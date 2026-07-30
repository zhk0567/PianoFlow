# Convert MusicXML in third_party/scores_musicxml → assets/scores/*.json
# Usage:
#   Set-Location F:\commercial\Piano
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

$ids = @(
  "fur_elise_woo59",
  "pachelbel_canon_d",
  # Needs third_party MusicXML from build_megalovania.py (PDF-matched; never MIDI).
  "toby_fox_megalovania",
  # OMR drafts from user PDFs (Audiveris); not proofread — practice-ready only.
  "radwimps_suzume",
  "ru_yuan",
  "christina_perri_a_thousand_years",
  "haruhikage",
  "rimsky_flight_of_the_bumblebee",
  "beethoven_moonlight_sonata",
  "jay_chou_qing_tian",
  "clayderman_reve_damour",
  "sawano_call_of_silence",
  "xiang_yun_duan",
  "hisaishi_castle_in_the_sky",
  "jue_bie_shu"
)
if ($Id) { $ids = @($Id) }

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

$argsList = @(".\scripts\musicxml_to_score.py", "--update-catalog")
if ($Id) {
  $argsList += @("--id", $Id)
} else {
  $argsList += "--all"
}

& $py @argsList
exit $LASTEXITCODE
