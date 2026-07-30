# PianoFlow — one-command formal score import (accurate + fast).
# Prefer MusicXML/MXL/MSCZ that matches the reference PDF. Do NOT use MIDI.
#
# Usage:
#   Set-Location F:\commercial\Piano
#   .\scripts\import-score.ps1 -Id fur_elise_woo59 -Source .\path\score.musicxml -Title "Fur Elise" -Artist "Beethoven"
#   .\scripts\import-score.ps1 -Id my_piece -Source C:\scores\a.mscz -Title "..." -Artist "..." -Pdf C:\scores\a.pdf

param(
  [Parameter(Mandatory = $true)]
  [string]$Id,

  [Parameter(Mandatory = $true)]
  [string]$Source,

  [string]$Title = "",
  [string]$Artist = "",
  [string]$Genre = "Classical",
  [int]$Difficulty = 3,
  [string]$Description = "",
  [ValidateSet("formal", "simplified")]
  [string]$ScoreKind = "formal",
  [string]$Pdf = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot
Write-Host "Repo:" $RepoRoot
Write-Host "cwd:" (Get-Location)

if ($Id -notmatch '^[a-z0-9_]+$') {
  Write-Error "Id must be snake_case ascii: ^[a-z0-9_]+$  (got: $Id)"
}

$srcPath = Resolve-Path -LiteralPath $Source
$ext = [System.IO.Path]::GetExtension($srcPath).ToLowerInvariant()
$allowed = @(".musicxml", ".xml", ".mxl", ".mscz")
if ($allowed -notcontains $ext) {
  Write-Error "Unsupported source '$ext'. Use .musicxml / .xml / .mxl / .mscz (not PDF, not MIDI)."
}

# PDF alone is never a structured score source.
if ($ext -eq ".pdf") {
  Write-Error "PDF cannot be imported as notation. See docs\曲谱导入SOP.md — need MusicXML/MSCZ matching the PDF."
}

function Find-MuseScoreExe {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\MuseScore 4\bin\MuseScore4.exe",
    "$env:ProgramFiles\MuseScore 4\bin\MuseScore4.exe",
    "${env:ProgramFiles(x86)}\MuseScore 4\bin\MuseScore4.exe",
    "$env:ProgramFiles\MuseScore 3\bin\MuseScore3.exe",
    "${env:ProgramFiles(x86)}\MuseScore 3\bin\MuseScore3.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $cmd = Get-Command MuseScore4.exe, MuseScore3.exe, musescore.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { return $cmd.Source }
  return $null
}

$workMusicXml = $null
$tmpDir = $null

try {
  if ($ext -eq ".mscz") {
    $ms = Find-MuseScoreExe
    if (-not $ms) {
      Write-Error @"
.mscz needs MuseScore CLI to export MusicXML, but MuseScore was not found.
Install MuseScore 4, open the .mscz, File → Export → MusicXML, then re-run with -Source that .musicxml.
Docs: docs\曲谱导入SOP.md
"@
    }
    $tmpDir = Join-Path $env:TEMP ("pianoflow_import_" + $Id + "_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $workMusicXml = Join-Path $tmpDir ($Id + ".musicxml")
    Write-Host "Exporting MSCZ via MuseScore:" $ms
    & $ms -o $workMusicXml -- $srcPath
    if (-not (Test-Path -LiteralPath $workMusicXml)) {
      # MuseScore sometimes writes .musicxml next to output stem differently
      $found = Get-ChildItem -LiteralPath $tmpDir -Filter "*.musicxml" -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($found) { $workMusicXml = $found.FullName }
    }
    if (-not (Test-Path -LiteralPath $workMusicXml)) {
      Write-Error "MuseScore did not produce MusicXML at $workMusicXml"
    }
  } else {
    $workMusicXml = $srcPath.Path
  }

  if ($Pdf) {
    $pdfPath = Resolve-Path -LiteralPath $Pdf
    $pdfDir = Join-Path $RepoRoot "third_party\scores_pdf"
    New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null
    $pdfDest = Join-Path $pdfDir ($Id + ".pdf")
    Copy-Item -LiteralPath $pdfPath -Destination $pdfDest -Force
    Write-Host "Archived PDF:" $pdfDest
  }

  $py = $null
  foreach ($c in @("python", "py")) {
    try {
      $v = & $c --version 2>&1
      if ($LASTEXITCODE -eq 0 -or "$v" -match "Python") { $py = $c; break }
    } catch {}
  }
  if (-not $py) { Write-Error "Python not found." }

  $argsList = @(
    ".\scripts\musicxml_to_score.py",
    "--id", $Id,
    "--input", $workMusicXml,
    "--update-catalog",
    "--score-kind", $ScoreKind,
    "--genre", $Genre,
    "--difficulty", "$Difficulty"
  )
  if ($Title) { $argsList += @("--title", $Title) }
  if ($Artist) { $argsList += @("--artist", $Artist) }
  if ($Description) { $argsList += @("--description", $Description) }
  elseif ($Pdf -or $Title) {
    $argsList += @("--description", "Formal MusicXML import for $Id. See docs/曲谱导入SOP.md.")
  }

  Write-Host "Converting..."
  & $py @argsList
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  # Keep convert-scores.ps1 batch list in sync for known formal ids (append comment only if missing).
  Write-Host ""
  Write-Host "OK: $Id imported."
  Write-Host "  third_party\scores_musicxml\$Id.musicxml"
  Write-Host "  assets\scores\musicxml\$Id.musicxml"
  Write-Host "  assets\scores\$Id.json"
  Write-Host "  catalog updated"
  Write-Host "Fully restart the app to load the new score."
  Write-Host "SOP: docs\曲谱导入SOP.md"
}
finally {
  if ($tmpDir -and (Test-Path -LiteralPath $tmpDir)) {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
