# PianoFlow enterprise one-click gates (P1).
# Usage (repo root):
#   .\scripts\enterprise-gates.ps1
#   .\scripts\enterprise-gates.ps1 -SkipAndroid -SkipFlutterTest
#
# Exit 0 = all selected gates Pass; non-zero = Fail (do not ship).

param(
  [switch]$SkipAndroid,
  [switch]$SkipFlutterTest,
  [switch]$SkipCatalog
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot
. (Join-Path $ScriptDir "piano-flow-common.ps1")
if (-not (Initialize-PianoFlowEnv)) {
  Write-Host "FAIL: Flutter env (see piano-flow-common.ps1 PianoFlowFlutterBin)" -ForegroundColor Red
  exit 1
}

# Prefer JDK 21 for Android Gradle when E:\Java path is broken.
$jdkCandidates = @(
  "C:\Program Files\Java\jdk-21.0.11",
  "C:\Program Files\Java\jdk-21",
  "C:\Program Files\Android\Android Studio\jbr",
  $env:JAVA_HOME
)
foreach ($j in $jdkCandidates) {
  if ($j -and (Test-Path (Join-Path $j "bin\java.exe"))) {
    $env:JAVA_HOME = $j
    $env:PATH = "$(Join-Path $j 'bin');$env:PATH"
    break
  }
}

function Invoke-Gate {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Body
  )
  Write-Host ""
  Write-Host "=== GATE: $Name ===" -ForegroundColor Cyan
  $global:LASTEXITCODE = 0
  & $Body
  $code = $global:LASTEXITCODE
  if ($null -eq $code) { $code = 0 }
  if ($code -ne 0) {
    Write-Host "FAIL: $Name (exit=$code)" -ForegroundColor Red
    exit $code
  }
  Write-Host "PASS: $Name" -ForegroundColor Green
}

Write-Host "Repo:" $RepoRoot
Write-Host "JAVA_HOME:" $env:JAVA_HOME
Write-Host "Enterprise gates starting..."

if (-not $SkipCatalog) {
  Invoke-Gate "catalog_score_kind_guard" { python ".\scripts\catalog_score_kind_guard.py" }
  Invoke-Gate "catalog_integrity_guard" { python ".\scripts\catalog_integrity_guard.py" }
  Invoke-Gate "score_kind_policy_sync --check" { python ".\scripts\score_kind_policy_sync.py" "--check" }
}

if (-not $SkipFlutterTest) {
  Invoke-Gate "flutter test" { & flutter test }
}

if (-not $SkipAndroid) {
  $androidDir = Join-Path $RepoRoot "clients\android"
  if (-not (Test-Path $androidDir)) {
    Write-Host "FAIL: missing $androidDir" -ForegroundColor Red
    exit 1
  }
  Invoke-Gate "android assembleDebug" {
    Push-Location $androidDir
    try {
      if (-not (Test-Path ".\gradlew.bat")) {
        Write-Host "FAIL: gradlew.bat missing" -ForegroundColor Red
        exit 1
      }
      # Gradle writes progress to stderr; do not treat as terminating error.
      $prev = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      & cmd /c "gradlew.bat assembleDebug --quiet"
      $code = $LASTEXITCODE
      $ErrorActionPreference = $prev
      if ($code -ne 0) { exit $code }
    } finally {
      Pop-Location
    }
  }
}

Write-Host ""
Write-Host "ALL SELECTED GATES PASS" -ForegroundColor Green
Write-Host "Restart the app fully after score/catalog changes."
exit 0
