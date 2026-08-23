# 校验微信降级端工程完整性（不依赖微信开发者工具 GUI）
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$required = @(
  "app.js",
  "app.json",
  "project.config.json",
  "sitemap.json",
  "data/catalog.json",
  "data/staff/fur_elise_woo59.json",
  "data/staff/hisaishi_castle_in_the_sky.json",
  "pages/library/library.js",
  "pages/library/library.wxml",
  "pages/library/library.wxss",
  "pages/library/library.json",
  "pages/practice/practice.js",
  "pages/practice/practice.wxml",
  "pages/practice/practice.wxss",
  "pages/practice/practice.json"
)

$fail = 0
foreach ($rel in $required) {
  if (-not (Test-Path -LiteralPath $rel)) {
    Write-Host "[PianoFlow/WeChat] MISSING $rel"
    $fail++
  }
}

$catalog = Get-Content -LiteralPath "data/catalog.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $catalog.songs -or $catalog.songs.Count -lt 2) {
  Write-Host "[PianoFlow/WeChat] catalog songs < 2"
  $fail++
}

foreach ($s in $catalog.songs) {
  $staffPath = "data/staff/$($s.id).json"
  if (-not (Test-Path -LiteralPath $staffPath)) {
    Write-Host "[PianoFlow/WeChat] missing staff $staffPath"
    $fail++
    continue
  }
  $staff = Get-Content -LiteralPath $staffPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $staff.notes -or $staff.notes.Count -lt 8) {
    Write-Host "[PianoFlow/WeChat] staff too short $($s.id) count=$($staff.notes.Count)"
    $fail++
  } else {
    Write-Host "[PianoFlow/WeChat] OK $($s.id) notes=$($staff.notes.Count) kind=$($s.scoreKindLabel)"
  }
  if (-not $s.honesty -or $s.honesty -notmatch "Windows|Android") {
    Write-Host "[PianoFlow/WeChat] honesty missing redirect $($s.id)"
    $fail++
  }
}

$practiceJs = Get-Content -LiteralPath "pages/practice/practice.js" -Raw -Encoding UTF8
if ($practiceJs -notmatch "toggleMetro" -or $practiceJs -notmatch "vibrateShort") {
  Write-Host "[PianoFlow/WeChat] metronome not wired"
  $fail++
}
if ($practiceJs -notmatch "staffNotes") {
  Write-Host "[PianoFlow/WeChat] staffNotes not wired"
  $fail++
}

if ($fail -gt 0) {
  Write-Host "[PianoFlow/WeChat] VERIFY FAIL count=$fail"
  exit 1
}
Write-Host "[PianoFlow/WeChat] VERIFY PASS"
exit 0
