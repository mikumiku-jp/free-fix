@echo off
setlocal

powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/mikumiku-jp/free-fix/main/install.ps1 | iex"

endlocal
