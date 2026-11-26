@echo off
cd /d "%~dp0"
set JOGO_TELA=anim
"C:\Program Files\LOVE\love.exe" "%~dp0." > "%~dp0anim_test.txt" 2>&1
echo EXIT %ERRORLEVEL% >> "%~dp0anim_test.txt"