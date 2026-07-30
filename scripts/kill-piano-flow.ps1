# Kill leftover PianoFlow processes (fast path). ASCII-only for PS 5.1.
# Usage: powershell -File .\scripts\kill-piano-flow.ps1 [-Quiet]

param([switch]$Quiet)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\piano-flow-common.ps1"

if (-not $Quiet) {
    Write-Host "Cleaning leftover PianoFlow..." -ForegroundColor Cyan
}

$ok = Stop-PianoFlow -Quiet:$Quiet
if ($ok) { exit 0 } else { exit 1 }
