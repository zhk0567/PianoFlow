# PDF → Audiveris OMR → MusicXML draft (Windows / PowerShell)
#
# Constraint: source is PDF-only; this produces a FIRST DRAFT that must be
# proofread against the PDF before formal catalog import.
#
# Usage (from repo root):
#   Set-Location F:\commercial\Piano
#   .\scripts\omr-from-pdf.ps1 -Id toby_fox_megalovania -Pdf .\third_party\scores_pdf\megalovania.pdf
#   .\scripts\omr-from-pdf.ps1 -Id fur_elise_woo59 -Pdf .\third_party\scores_pdf\fur_elise_woo59.pdf -InstallAudiveris
#
# After OMR:
#   1. Open the MusicXML in MuseScore / Audiveris UI
#   2. Diff visually against the PDF (required — OMR is never 100%)
#   3. .\scripts\import-score.ps1 -Id ... -Source <corrected.musicxml> ...

param(
  [Parameter(Mandatory = $true)][string]$Id,
  [Parameter(Mandatory = $true)][string]$Pdf,
  [switch]$InstallAudiveris,
  [string]$AudiverisExe = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot
Write-Host "Repo:" $RepoRoot

$PdfPath = Resolve-Path $Pdf
if (-not (Test-Path $PdfPath)) {
  Write-Error "PDF not found: $Pdf"
}

$OmrRoot = Join-Path $RepoRoot "third_party\omr"
$Work = Join-Path $RepoRoot "third_party\scores_musicxml\_omr_work\$Id"
$OutDir = Join-Path $Work "audiveris_out"
New-Item -ItemType Directory -Force -Path $OmrRoot, $Work, $OutDir | Out-Null

# Archive a copy of the PDF next to the work folder for proofreading.
$PdfCopy = Join-Path $Work "source.pdf"
Copy-Item -Force $PdfPath $PdfCopy
Write-Host "PDF archived:" $PdfCopy

function Find-Audiveris {
  param([string]$Preferred)
  if ($Preferred -and (Test-Path $Preferred)) { return (Resolve-Path $Preferred).Path }

  $candidates = @(
    (Join-Path $OmrRoot "Audiveris\Audiveris.exe"),
    (Join-Path $OmrRoot "audiveris\Audiveris.exe"),
    (Join-Path $OmrRoot "Audiveris-5.11.0-windows-x86_64\SourceDir\Audiveris\Audiveris.exe"),
    "${env:ProgramFiles}\Audiveris\Audiveris.exe",
    "${env:ProgramFiles(x86)}\Audiveris\Audiveris.exe",
    "$env:LOCALAPPDATA\Audiveris\Audiveris.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }

  $cmd = Get-Command Audiveris.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Install-AudiverisFromMsi {
  $msiLocal = Join-Path $OmrRoot "Audiveris-5.11.0-windows-x86_64.msi"
  $msiCandidate = Join-Path $RepoRoot "third_party\scores_musicxml\_omr_work\megalovania\candidates\Audiveris-5.11.0-windows-x86_64.msi"
  if (-not (Test-Path $msiLocal) -and (Test-Path $msiCandidate)) {
    Copy-Item -Force $msiCandidate $msiLocal
  }
  if (-not (Test-Path $msiLocal)) {
    Write-Host "Downloading Audiveris 5.11.0 MSI into third_party\omr ..."
    $url = "https://github.com/Audiveris/audiveris/releases/download/5.11.0/Audiveris-5.11.0-windows-x86_64.msi"
    Invoke-WebRequest -Uri $url -OutFile $msiLocal -UseBasicParsing
  }

  $target = Join-Path $OmrRoot "Audiveris"
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  Write-Host "Extracting MSI to $target (msiexec ADMIN) ..."
  # Administrative install extracts files without full system registration.
  $log = Join-Path $OmrRoot "msiexec_admin.log"
  $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
    "/a", "`"$msiLocal`"",
    "TARGETDIR=`"$target`"",
    "/qn",
    "/l*v", "`"$log`""
  ) -Wait -PassThru
  if ($p.ExitCode -ne 0) {
    Write-Warning "msiexec /a exit $($p.ExitCode). See $log"
  }
  $exe = Get-ChildItem -Path $target -Recurse -Filter "Audiveris.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
  if (-not $exe) {
    Write-Error "Audiveris.exe not found after MSI extract. Install Audiveris manually, then re-run with -AudiverisExe."
  }
  return $exe
}

$exe = Find-Audiveris -Preferred $AudiverisExe
if (-not $exe) {
  if ($InstallAudiveris) {
    $exe = Install-AudiverisFromMsi
  } else {
    Write-Host ""
    Write-Host "Audiveris not found. Either:"
    Write-Host "  1) Install from https://github.com/Audiveris/audiveris/releases"
    Write-Host "  2) Re-run with -InstallAudiveris  (extracts MSI under third_party\omr)"
    Write-Host "  3) Pass -AudiverisExe 'C:\Path\Audiveris.exe'"
    Write-Error "Audiveris.exe missing"
  }
}

Write-Host "Audiveris:" $exe
Write-Host "Running batch OMR (this can take several minutes) ..."

# Audiveris batch: -batch -export -output <dir> <input.pdf>
# See handbook: headless/batch processing.
$argList = @(
  "-batch",
  "-export",
  "-output", $OutDir,
  $PdfCopy
)

$proc = Start-Process -FilePath $exe -ArgumentList $argList -Wait -PassThru -NoNewWindow
Write-Host "Audiveris exit code:" $proc.ExitCode

$xmls = @()
$xmls += Get-ChildItem -Path $OutDir -Recurse -Include *.musicxml,*.xml,*.mxl -ErrorAction SilentlyContinue
$xmls += Get-ChildItem -Path $Work -Recurse -Include *.musicxml,*.xml,*.mxl -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -like "*audiveris*" -or $_.DirectoryName -like "*audiveris_out*" }

$xmls = $xmls | Sort-Object FullName -Unique
if ($xmls.Count -eq 0) {
  Write-Host ""
  Write-Host "No MusicXML exported yet. Open Audiveris GUI on:"
  Write-Host "  $PdfCopy"
  Write-Host "Then File → Export → MusicXML into:"
  Write-Host "  $OutDir"
  Write-Host "Docs: docs\PDF识谱与FlowKey对齐.md"
  exit 2
}

Write-Host ""
Write-Host "OMR draft(s):"
foreach ($x in $xmls) { Write-Host " -" $x.FullName }

$best = $xmls | Select-Object -First 1
$ext = $best.Extension
if (-not $ext) { $ext = ".musicxml" }
$canonical = Join-Path $Work ("omr_draft" + $ext)
Copy-Item -Force $best.FullName $canonical
Write-Host ""
Write-Host "Canonical draft:" $canonical
Write-Host ""
Write-Host "NEXT (required for formal accuracy):"
Write-Host "  1. Proofread in MuseScore / Audiveris GUI against $PdfCopy"
Write-Host "  2. Save corrected file as $Work\corrected.musicxml"
Write-Host "  3. .\scripts\import-score.ps1 -Id $Id -Source $Work\corrected.musicxml -Title '...' -Artist '...'"
Write-Host ""
Write-Host "Do NOT import the raw OMR draft as formal without proofreading."
exit 0
