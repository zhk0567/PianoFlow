# Shared helpers for PianoFlow Windows launchers (ASCII-only, PS 5.1).
# Dot-source: . "$PSScriptRoot\piano-flow-common.ps1"

$script:PianoFlowRoot = Split-Path -Parent $PSScriptRoot
$script:PianoFlowFlutterBin = "F:\Other\flutter\bin"
$script:PianoFlowDebugExe = Join-Path $script:PianoFlowRoot "build\windows\x64\runner\Debug\piano_flow.exe"
$script:PianoFlowReleaseExe = Join-Path $script:PianoFlowRoot "build\windows\x64\runner\Release\piano_flow.exe"
$script:PianoFlowNugetDir = Join-Path $script:PianoFlowRoot "third_party\nuget"
$script:PianoFlowNugetExe = Join-Path $script:PianoFlowNugetDir "nuget.exe"
# Must match webview_windows windows/CMakeLists.txt NUGET_SHA256.
$script:PianoFlowNugetSha256 = "852B71CC8C8C2D40D09EA49D321FF56FD2397B9D6EA9F96E532530307BBBAFD3"
$script:PianoFlowNugetUrl = "https://dist.nuget.org/win-x86-commandline/v5.10.0/nuget.exe"

function Ensure-PianoFlowNuget {
    if (-not (Test-Path $script:PianoFlowNugetDir)) {
        New-Item -ItemType Directory -Force -Path $script:PianoFlowNugetDir | Out-Null
    }
    $needFetch = $true
    if (Test-Path $script:PianoFlowNugetExe) {
        try {
            $hash = (Get-FileHash -Path $script:PianoFlowNugetExe -Algorithm SHA256).Hash
            if ($hash -eq $script:PianoFlowNugetSha256) { $needFetch = $false }
        } catch {
            $needFetch = $true
        }
    }
    if ($needFetch) {
        Write-Host "Downloading nuget.exe (webview_windows)..." -ForegroundColor DarkGray
        try {
            Invoke-WebRequest -Uri $script:PianoFlowNugetUrl -OutFile $script:PianoFlowNugetExe -UseBasicParsing
        } catch {
            Write-Host ("WARN: nuget download failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
            return $false
        }
        $hash = (Get-FileHash -Path $script:PianoFlowNugetExe -Algorithm SHA256).Hash
        if ($hash -ne $script:PianoFlowNugetSha256) {
            Write-Host "WARN: nuget.exe hash mismatch" -ForegroundColor Yellow
            return $false
        }
    }
    $env:PATH = "$script:PianoFlowNugetDir;$env:PATH"
    return $true
}

function Initialize-PianoFlowEnv {
    Set-Location $script:PianoFlowRoot
    $env:PATH = "$script:PianoFlowFlutterBin;$env:PATH"
    if (-not (Test-Path "$script:PianoFlowFlutterBin\flutter.bat")) {
        Write-Host "Flutter not found: $script:PianoFlowFlutterBin" -ForegroundColor Red
        return $false
    }
    # Put nuget on PATH before flutter/cmake so webview_windows does not
    # print "Nuget is not installed." on every configure.
    $null = Ensure-PianoFlowNuget
    return $true
}

function Get-PianoFlowExe {
    param([ValidateSet("PreferDebug", "PreferRelease")][string]$Prefer = "PreferDebug")
    if ($Prefer -eq "PreferRelease") {
        if (Test-Path $script:PianoFlowReleaseExe) { return $script:PianoFlowReleaseExe }
        if (Test-Path $script:PianoFlowDebugExe) { return $script:PianoFlowDebugExe }
    } else {
        if (Test-Path $script:PianoFlowDebugExe) { return $script:PianoFlowDebugExe }
        if (Test-Path $script:PianoFlowReleaseExe) { return $script:PianoFlowReleaseExe }
    }
    return $null
}

function Stop-PianoFlow {
    param([switch]$Quiet)

    $killed = 0
    $buildPrefix = (Join-Path $script:PianoFlowRoot "build").ToLowerInvariant()

    # Fast path: taskkill tree
    $null = & taskkill.exe /F /IM piano_flow.exe /T 2>&1
    if ($LASTEXITCODE -eq 0) { $killed++ }

    Get-Process -Name "piano_flow" -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $Quiet) {
            Write-Host ("  kill PID {0}" -f $_.Id) -ForegroundColor Yellow
        }
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        $killed++
    }

    # Only if still alive: light path scan via MainModule (no WMI by default)
    $left = @(Get-Process -Name "piano_flow" -ErrorAction SilentlyContinue)
    if ($left.Count -gt 0) {
        foreach ($p in $left) {
            $path = $null
            try { $path = $p.Path } catch { }
            if (-not $path) {
                try { $path = $p.MainModule.FileName } catch { }
            }
            if ($path) {
                $pl = $path.ToLowerInvariant()
                $ours = $pl.StartsWith($buildPrefix) -or ($pl -match '\\piano\\')
                if (-not $ours) { continue }
            }
            if (-not $Quiet) {
                Write-Host ("  kill PID {0} (retry)" -f $p.Id) -ForegroundColor Yellow
            }
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            $killed++
        }
        Start-Sleep -Milliseconds 200
        $null = & taskkill.exe /F /IM piano_flow.exe /T 2>&1
    }

    $still = @(Get-Process -Name "piano_flow" -ErrorAction SilentlyContinue)
    if (-not $Quiet) {
        if ($still.Count -gt 0) {
            Write-Host ("WARN: {0} piano_flow still alive" -f $still.Count) -ForegroundColor Red
        } elseif ($killed -gt 0) {
            Write-Host ("Cleaned {0} process(es)." -f $killed) -ForegroundColor Green
        } else {
            Write-Host "No leftover process." -ForegroundColor DarkGray
        }
    }

    return ($still.Count -eq 0)
}
