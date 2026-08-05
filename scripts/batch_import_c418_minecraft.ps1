# Batch: Minecraft / C418 PDF piano sheets → OMR draft → catalog omrDraft.
# Usage (repo root):
#   .\scripts\batch_import_c418_minecraft.ps1
#   .\scripts\batch_import_c418_minecraft.ps1 -SkipOmr   # only finish-import if drafts exist
#   .\scripts\batch_import_c418_minecraft.ps1 -OnlyId c418_sweden

param(
  [string]$PdfDir = "",
  [switch]$SkipOmr,
  [switch]$ForceOmr,
  [string]$OnlyId = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
Set-Location $RepoRoot
if (-not $PdfDir) {
  $PdfDir = Join-Path $RepoRoot "third_party\scores_pdf\_c418_incoming"
}
Write-Host "Repo:" $RepoRoot
Write-Host "PDF dir:" $PdfDir

if (-not (Test-Path -LiteralPath $PdfDir)) {
  Write-Error "PDF directory not found: $PdfDir"
}

# Track number → id / title / difficulty (1–5). Artist fixed C418, Genre Game.
$tracks = @(
  @{ N = 1;  Id = "c418_key";                   Title = "Key";                     Diff = 2 }
  @{ N = 2;  Id = "c418_door";                  Title = "Door";                    Diff = 2 }
  @{ N = 3;  Id = "c418_subwoofer_lullaby";     Title = "Subwoofer Lullaby";       Diff = 2 }
  @{ N = 4;  Id = "c418_death";                 Title = "Death";                   Diff = 2 }
  @{ N = 5;  Id = "c418_living_mice";           Title = "Living Mice";             Diff = 2 }
  @{ N = 6;  Id = "c418_dry_hands";             Title = "Dry Hands";               Diff = 1 }
  @{ N = 7;  Id = "c418_moog_city";             Title = "Moog City";               Diff = 2 }
  @{ N = 8;  Id = "c418_haggstrom";             Title = "Haggstrom";               Diff = 2 }
  @{ N = 9;  Id = "c418_minecraft";             Title = "Minecraft";               Diff = 2 }
  @{ N = 10; Id = "c418_equinoxe";              Title = "Équinoxe";                Diff = 3 }
  @{ N = 11; Id = "c418_mice_on_venus";         Title = "Mice on Venus";           Diff = 2 }
  @{ N = 12; Id = "c418_wet_hands";             Title = "Wet Hands";               Diff = 1 }
  @{ N = 13; Id = "c418_clark";                 Title = "Clark";                   Diff = 2 }
  @{ N = 14; Id = "c418_excuse";                Title = "Excuse";                  Diff = 2 }
  @{ N = 15; Id = "c418_sweden";                Title = "Sweden";                  Diff = 2 }
  @{ N = 16; Id = "c418_clark_alt";             Title = "Clark (alt)";             Diff = 2 }
  @{ N = 17; Id = "c418_danny";                 Title = "Danny";                   Diff = 2 }
  @{ N = 18; Id = "c418_droopy_likes_ricochet"; Title = "Droopy likes ricochet";   Diff = 3 }
  @{ N = 19; Id = "c418_beginning";             Title = "Beginning";               Diff = 2 }
)

function Find-PdfByNumber([int]$n) {
  $prefix = "$n."
  $hits = Get-ChildItem -LiteralPath $PdfDir -Filter "*.pdf" | Where-Object {
    $_.Name.StartsWith($prefix)
  }
  if ($hits.Count -eq 0) { return $null }
  if ($hits.Count -gt 1) {
    Write-Warning "Multiple PDFs for $n : $($hits.Name -join ', '); using first"
  }
  return $hits[0].FullName
}

$ok = 0
$fail = 0
$log = Join-Path $RepoRoot "third_party\scores_musicxml\_omr_work\_c418_batch_log.txt"
"=== C418 batch $(Get-Date -Format o) ===" | Out-File -FilePath $log -Encoding utf8

foreach ($t in $tracks) {
  if ($OnlyId -and $t.Id -ne $OnlyId) { continue }

  $pdf = Find-PdfByNumber $t.N
  if (-not $pdf) {
    Write-Host "[SKIP] no PDF for $($t.N) $($t.Id)" -ForegroundColor Yellow
    "[SKIP] $($t.Id) no PDF" | Out-File -FilePath $log -Append -Encoding utf8
    $fail++
    continue
  }

  Write-Host ""
  Write-Host "======== $($t.Id)  ($($t.Title)) ========" -ForegroundColor Cyan
  Write-Host "PDF:" $pdf

  # Archive under scores_pdf for later proofread.
  $pdfArchive = Join-Path $RepoRoot "third_party\scores_pdf\$($t.Id).pdf"
  New-Item -ItemType Directory -Force -Path (Split-Path $pdfArchive) | Out-Null
  Copy-Item -LiteralPath $pdf -Destination $pdfArchive -Force

  if (-not $SkipOmr) {
    & ".\scripts\omr-from-pdf.ps1" -Id $t.Id -Pdf $pdf
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 2) {
      Write-Host "[FAIL] omr-from-pdf $($t.Id) exit $LASTEXITCODE" -ForegroundColor Red
      "[FAIL] omr $($t.Id) exit $LASTEXITCODE" | Out-File -FilePath $log -Append -Encoding utf8
      $fail++
      continue
    }
    if ($LASTEXITCODE -eq 2) {
      Write-Host "[WARN] omr-from-pdf produced no export for $($t.Id)" -ForegroundColor Yellow
      "[WARN] omr no export $($t.Id)" | Out-File -FilePath $log -Append -Encoding utf8
      $fail++
      continue
    }
  }

  $desc = "Minecraft/C418 piano PDF -> Audiveris OMR draft (unproofread). PDF: third_party/scores_pdf/$($t.Id).pdf. omrDraft only — not formal."
  $finishArgs = @{
    Id = $t.Id
    Title = $t.Title
    Artist = "C418"
    Genre = "Game"
    Difficulty = [int]$t.Diff
    Description = $desc
  }
  if ($ForceOmr) {
    & ".\scripts\omr-finish-import.ps1" @finishArgs -ForceOmr
  } else {
    & ".\scripts\omr-finish-import.ps1" @finishArgs
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] omr-finish-import $($t.Id) exit $LASTEXITCODE" -ForegroundColor Red
    "[FAIL] finish $($t.Id) exit $LASTEXITCODE" | Out-File -FilePath $log -Append -Encoding utf8
    $fail++
    continue
  }

  Write-Host "[OK] $($t.Id)" -ForegroundColor Green
  "[OK] $($t.Id)" | Out-File -FilePath $log -Append -Encoding utf8
  $ok++
}

Write-Host ""
Write-Host "Done. OK=$ok FAIL=$fail  log=$log"
exit $(if ($fail -gt 0) { 1 } else { 0 })
