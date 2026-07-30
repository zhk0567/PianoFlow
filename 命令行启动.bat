@echo off
REM ASCII-only + CRLF required. LF-only makes cmd strip the first char of each line.
cd /d "%~dp0"
title PianoFlow Console
echo PianoFlow console launcher
echo Default: flutter run (Dart logs including [PianoFlow/Verovio]). Modes: run ^| auto ^| exe ^| build
echo.
REM Default MODE=run so Verovio/Dart logs always show.
set MODE=%~1
if "%MODE%"=="" set MODE=run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-console.ps1" %MODE%
set ERR=%ERRORLEVEL%
echo.
if not "%ERR%"=="0" (
  echo Finished with exit code %ERR% - see log above
) else (
  echo Finished OK
)
pause
exit /b %ERR%
