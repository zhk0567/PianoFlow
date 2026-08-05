# PianoFlow console launcher (ASCII-only, PS 5.1).
# Default mode: auto (exe if built, else flutter run).
# Usage:
#   .\scripts\run-console.ps1           # auto
#   .\scripts\run-console.ps1 auto
#   .\scripts\run-console.ps1 run       # flutter run (full Dart logs)
#   .\scripts\run-console.ps1 exe       # require existing exe
#   .\scripts\run-console.ps1 build     # build debug then run exe
#
# CRITICAL: Never assign flutter/cmd stdout into a variable ($x = flutter ...).
# PowerShell treats native stdout as function output → $code becomes Object[].

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\piano-flow-common.ps1"

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Project: $script:PianoFlowRoot"

if (-not (Initialize-PianoFlowEnv)) { exit 1 }

$mode = "auto"
if ($args.Count -gt 0) {
    $mode = ([string]$args[0]).ToLowerInvariant()
}

# Exit codes go here — NEVER capture cmd/flutter output into $code.
$script:RunExitCode = 0

function Invoke-FlutterRun {
    Write-Host "flutter run -d windows --no-pub" -ForegroundColor Green
    # Direct console attach — do NOT redirect stdout/stderr (breaks flutter run,
    # exit 5, empty log). audioplayers spam is reduced by lazy AudioPlayer bind;
    # AXTree spam by ExcludeSemantics in main.dart.
    $p = Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c", "flutter run -d windows --no-pub" `
        -NoNewWindow -Wait -PassThru
    if ($null -ne $p -and $p.ExitCode -eq 0) {
        $script:RunExitCode = 0
        return
    }
    Write-Host "Retry without --no-pub..." -ForegroundColor Yellow
    $p2 = Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c", "flutter run -d windows" `
        -NoNewWindow -Wait -PassThru
    if ($null -eq $p2) {
        $script:RunExitCode = 1
    } else {
        $script:RunExitCode = [int]$p2.ExitCode
    }
}

function Invoke-ExeForeground {
    param([Parameter(Mandatory = $true)][string]$ExePath)
    Write-Host ("exe: {0}" -f $ExePath) -ForegroundColor Green
    $dir = Split-Path $ExePath
    Push-Location $dir
    try {
        $p = Start-Process -FilePath $ExePath -NoNewWindow -Wait -PassThru
        if ($null -eq $p) {
            $script:RunExitCode = 1
        } else {
            $script:RunExitCode = [int]$p.ExitCode
        }
    } finally {
        Pop-Location
    }
}

Write-Host ("Mode: {0}" -f $mode) -ForegroundColor Cyan
Write-Host "Cleanup..." -ForegroundColor Cyan
Stop-PianoFlow | Out-Null
Write-Host ("Ready in {0:N1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor DarkGray
Write-Host "----------------------------------------"
Write-Host "Close the app or Ctrl+C to stop. Search console for [PianoFlow/ (Pitch/Audio/Practice/Library/Verovio/...)." -ForegroundColor DarkGray
Write-Host "----------------------------------------"

try {
    switch ($mode) {
        "run" {
            Invoke-FlutterRun
        }
        "exe" {
            $exe = Get-PianoFlowExe -Prefer PreferDebug
            if (-not $exe) {
                Write-Host "No exe. Use: build  or  run" -ForegroundColor Red
                $script:RunExitCode = 1
                break
            }
            Invoke-ExeForeground -ExePath $exe
        }
        "build" {
            Write-Host "Building debug..." -ForegroundColor Yellow
            $bp = Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/c", "flutter build windows --debug" `
                -NoNewWindow -Wait -PassThru
            if ($null -eq $bp -or $bp.ExitCode -ne 0) {
                Write-Host "Build failed." -ForegroundColor Red
                $script:RunExitCode = if ($null -eq $bp) { 1 } else { [int]$bp.ExitCode }
                break
            }
            Stop-PianoFlow -Quiet | Out-Null
            $exe = Get-PianoFlowExe -Prefer PreferDebug
            if (-not $exe) {
                Write-Host "exe not found after build" -ForegroundColor Red
                $script:RunExitCode = 1
                break
            }
            Invoke-ExeForeground -ExePath $exe
        }
        default {
            # auto — prefer flutter run so Verovio Dart logs are visible.
            # Pass "exe" explicitly if you want the stale built binary.
            Write-Host "auto -> flutter run (Dart logs). For stale exe: run-console.ps1 exe" -ForegroundColor Yellow
            Invoke-FlutterRun
        }
    }
} finally {
    Write-Host "----------------------------------------"
    Write-Host "Cleanup on exit..." -ForegroundColor Cyan
    $null = Stop-PianoFlow
    $sw.Stop()
    # Never print/exit a raw Object[] (happens if stdout was ever assigned into RunExitCode).
    $code = 0
    try {
        if ($script:RunExitCode -is [Array]) {
            $code = 1
        } else {
            $code = [int]$script:RunExitCode
        }
    } catch {
        $code = 1
    }
    $script:RunExitCode = $code
    Write-Host ("Total {0:N1}s, exit {1}" -f $sw.Elapsed.TotalSeconds, $code) -ForegroundColor $(if ($code -eq 0) { "Green" } else { "Red" })
}

exit $script:RunExitCode
