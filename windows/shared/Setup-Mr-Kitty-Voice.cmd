@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Mr-Kitty-Voice.ps1"
if errorlevel 1 pause
