@echo off
rem Author: ynchris（汉化老兵）
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-HighResFix.ps1" %*
echo.
pause
