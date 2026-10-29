@echo off
title Ping-Server-OPS
rem %~dp0
cd /d "%~dp0"

rem
powershell -NoProfile -ExecutionPolicy Bypass -File "ping_servers.ps1"

pause