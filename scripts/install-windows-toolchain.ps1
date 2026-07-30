# Install VS 2022 Build Tools + C++ workload for Flutter Windows
$ErrorActionPreference = "Stop"

Write-Host "Checking C++ toolchain..." -ForegroundColor Cyan
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $existing = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($existing) {
        Write-Host "Already installed: $existing" -ForegroundColor Green
        Write-Host "You can double-click 启动.bat now."
        exit 0
    }
}

Write-Host "Installing Visual Studio 2022 Build Tools via winget..." -ForegroundColor Cyan
Write-Host "Workload: VCTools (+ Windows SDK). This may take a while." -ForegroundColor DarkGray
Write-Host ""

$override = "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
& winget install -e --id Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --override $override
$code = $LASTEXITCODE
$alreadyOk = -1978335189
if (($code -ne 0) -and ($code -ne $alreadyOk)) {
    Write-Host "winget exit code: $code" -ForegroundColor Yellow
    Write-Host "Manual install: https://visualstudio.microsoft.com/downloads/ -> Build Tools -> Desktop development with C++" -ForegroundColor Yellow
    exit $code
}

Write-Host ""
Write-Host "Done. Double-click 启动.bat to run PianoFlow." -ForegroundColor Green
