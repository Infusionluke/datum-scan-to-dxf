@echo off
title Datum
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Datum.ps1"
if errorlevel 1 (
  echo.
  echo Datum failed to start.
  pause
)
