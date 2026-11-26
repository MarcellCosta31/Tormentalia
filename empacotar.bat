@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0empacotar.ps1"
if errorlevel 1 (
  echo ERRO: nao foi possivel gerar o pacote.
  exit /b 1
)
