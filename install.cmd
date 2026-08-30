@echo off
rem Thin wrapper around install.ps1, kept so existing callers and documented
rem commands that say "install.cmd" keep working. All logic lives in the
rem PowerShell script; nothing here should grow.
setlocal

set "DEVNUL=nul"
set "PSEXE=pwsh"
where pwsh >%DEVNUL% 2>&1 || set "PSEXE=powershell"

"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
exit /b %ERRORLEVEL%
