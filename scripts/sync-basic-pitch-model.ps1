# Copy Basic Pitch ONNX to Web/Android when present at repo assets/models.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..
$src = Join-Path (Get-Location) 'assets\models\basic_pitch.onnx'
if (-not (Test-Path $src)) {
    Write-Host '[PianoFlow/sync-models] basic_pitch.onnx not found at assets\models — skip'
    Write-Host '[PianoFlow/sync-models] Place model at assets\models\basic_pitch.onnx (from Windows Flutter assets) then re-run.'
    exit 0
}
$webDir = Join-Path (Get-Location) 'clients\web\models'
$androidDir = Join-Path (Get-Location) 'clients\android\app\src\main\assets\models'
New-Item -ItemType Directory -Force -Path $webDir | Out-Null
New-Item -ItemType Directory -Force -Path $androidDir | Out-Null
Copy-Item -Force $src (Join-Path $webDir 'basic_pitch.onnx')
Copy-Item -Force $src (Join-Path $androidDir 'basic_pitch.onnx')
Write-Host '[PianoFlow/sync-models] synced basic_pitch.onnx -> web + android'
