# NuGet CLI (Windows)

`webview_windows` needs `nuget.exe` to restore WebView2 / WIL.  
`Initialize-PianoFlowEnv` downloads v5.10.0 into this folder and puts it on `PATH`, so Flutter/CMake builds stop printing `Nuget is not installed.` every time.
