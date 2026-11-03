@echo off
rem co_dev collab tool entry (works from cmd, PowerShell and Git Bash). Rules: COLLABORATION.md
rem Usage: scripts\collab.cmd <command> [args]
setlocal
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0collab.ps1" %*
exit /b %ERRORLEVEL%
