@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0watchdog.ps1" -Action Pause
pause
