@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0zemi_cli.ps1" %*
exit /b %ERRORLEVEL%
