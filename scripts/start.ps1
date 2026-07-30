# PianoFlow quick launcher (ASCII-only, PS 5.1).
# Usage: .\scripts\start.ps1 windows
# Kills leftovers once, then opens existing exe (or builds debug first).

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\piano-flow-common.ps1"

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Project: $script:PianoFlowRoot"

if (-not (Initialize-PianoFlowEnv)) { exit 1 }

$arg = "windows"
if ($args.Count -gt 0) {
    $arg = ([string]$args[0]).ToLowerInvariant()
}
if ($arg -ne "windows") {
    Write-Host "Only windows is supported."
    exit 1
}

Write-Host "Cleanup..." -ForegroundColor Cyan
Stop-PianoFlow | Out-Null

$exe = Get-PianoFlowExe -Prefer PreferRelease
if (-not $exe) {
    Write-Host "No exe yet. Building debug (may take several minutes)..." -ForegroundColor Yellow
    & flutter build windows --debug
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed. Try: flutter doctor" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    $exe = Get-PianoFlowExe -Prefer PreferDebug
    if (-not $exe) {
        Write-Host "Build finished but piano_flow.exe not found" -ForegroundColor Red
        exit 1
    }
}

Write-Host ("Open: {0}" -f $exe) -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
$sw.Stop()
Write-Host ("Started in {0:N1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
exit 0
