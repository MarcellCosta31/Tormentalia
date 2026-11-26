@echo off
cd /d "%~dp0"
set JOGO_TESTE=1
"C:\Program Files\LOVE\love.exe" "%~dp0."
echo Codigo de saida: %ERRORLEVEL%
