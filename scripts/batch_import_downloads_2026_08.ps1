# Batch PDF → Audiveris OMR → catalog as omrDraft (NOT formal).
# ASCII-only script body; PDF paths may contain Unicode (use -LiteralPath).
#
# Usage (repo root):
#   .\scripts\batch_import_downloads_2026_08.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $RepoRoot

$AudiverisExe = Join-Path $RepoRoot "third_party\omr\Audiveris-5.11.0-windows-x86_64\SourceDir\Audiveris\Audiveris.exe"
if (-not (Test-Path -LiteralPath $AudiverisExe)) {
  Write-Error "Audiveris not found: $AudiverisExe"
}

$pdfDir = Join-Path $RepoRoot "third_party\scores_pdf"
New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null

# Pdf paths under Downloads; all imported as omrDraft.
$jobs = @(
  @{
    Id = "rush_e"
    Pdf = "C:\Users\32834\Downloads\Rush E.pdf"
    Title = "Rush E"
    Artist = "Sheet Music Boss / Andrew Wrangell"
    Genre = "Classical"
    Difficulty = 5
  },
  @{
    Id = "blowin_in_the_wind"
    Pdf = "C:\Users\32834\Downloads\Blowin' In The Wind.pdf"
    Title = "Blowin' In The Wind"
    Artist = "Bob Dylan"
    Genre = "Pop"
    Difficulty = 2
  },
  @{
    Id = "when_you_wish_upon_a_star"
    Pdf = "C:\Users\32834\Downloads\When You Wish Upon a Star.pdf"
    Title = "When You Wish Upon a Star"
    Artist = "Leigh Harline / Ned Washington"
    Genre = "Pop"
    Difficulty = 2
  },
  @{
    Id = "whistle"
    Pdf = "C:\Users\32834\Downloads\Whistle.pdf"
    Title = "Whistle"
    Artist = "Unknown"
    Genre = "Pop"
    Difficulty = 3
  },
  @{
    Id = "bella_ciao"
    Pdf = "C:\Users\32834\Downloads\Bella Ciao.pdf"
    Title = "Bella Ciao"
    Artist = "Traditional / Italian folk"
    Genre = "Pop"
    Difficulty = 2
  },
  @{
    Id = "pure_imagination"
    Pdf = "C:\Users\32834\Downloads\Pure Imagination.pdf"
    Title = "Pure Imagination"
    Artist = "Leslie Bricusse / Anthony Newley"
    Genre = "Pop"
    Difficulty = 3
  },
  @{
    Id = "fen_shua_jiang"
    Pdf = "C:\Users\32834\Downloads\粉刷匠.pdf"
    Title = "粉刷匠"
    Artist = "Traditional / Chinese children's song"
    Genre = "Pop"
    Difficulty = 1
  },
  @{
    Id = "ye_de_gang_qin_qu_5"
    Pdf = "C:\Users\32834\Downloads\夜的钢琴曲五.pdf"
    Title = "夜的钢琴曲五"
    Artist = "石进"
    Genre = "Classical"
    Difficulty = 3
  },
  @{
    Id = "ju_hua_tai"
    Pdf = "C:\Users\32834\Downloads\菊花台.pdf"
    Title = "菊花台"
    Artist = "周杰伦"
    Genre = "Pop"
    Difficulty = 3
  },
  @{
    Id = "an_he_qiao"
    Pdf = "C:\Users\32834\Downloads\安和桥.pdf"
    Title = "安和桥"
    Artist = "宋冬野"
    Genre = "Pop"
    Difficulty = 2
  },
  @{
    Id = "xiao_xing_xing"
    Pdf = "C:\Users\32834\Downloads\小星星.pdf"
    Title = "小星星"
    Artist = "Traditional / Twinkle Twinkle Little Star"
    Genre = "Classical"
    Difficulty = 1
  }
)

$ok = @()
$failed = @()

foreach ($j in $jobs) {
  $id = $j.Id
  $pdf = $j.Pdf
  Write-Host ""
  Write-Host "======== $id ========" -ForegroundColor Cyan
  if (-not (Test-Path -LiteralPath $pdf)) {
    Write-Host "MISSING PDF: $pdf" -ForegroundColor Red
    $failed += $id
    continue
  }

  $pdfDest = Join-Path $pdfDir ($id + ".pdf")
  Copy-Item -LiteralPath $pdf -Destination $pdfDest -Force
  Write-Host "Archived PDF: $pdfDest"

  & ".\scripts\omr-from-pdf.ps1" -Id $id -Pdf $pdfDest -AudiverisExe $AudiverisExe
  if ($LASTEXITCODE -ne 0) {
    Write-Host "OMR failed for $id (exit $LASTEXITCODE)" -ForegroundColor Red
    $failed += $id
    continue
  }

  $desc = "OMR draft from user PDF via Audiveris (batch 2026-08-05). Not proofread. Not MIDI. Local practice only."
  & ".\scripts\omr-finish-import.ps1" `
    -Id $id `
    -Title $j.Title `
    -Artist $j.Artist `
    -Genre $j.Genre `
    -Difficulty $j.Difficulty `
    -Description $desc `
    -ForceOmr
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Finish-import failed for $id (exit $LASTEXITCODE)" -ForegroundColor Red
    $failed += $id
    continue
  }

  $ok += $id
  Write-Host "OK: $id as omrDraft" -ForegroundColor Green
}

Write-Host ""
Write-Host "======== SUMMARY ========"
Write-Host ("OK ({0}): {1}" -f $ok.Count, ($ok -join ", "))
Write-Host ("FAILED ({0}): {1}" -f $failed.Count, ($failed -join ", "))
if ($failed.Count -gt 0) { exit 1 }
exit 0
