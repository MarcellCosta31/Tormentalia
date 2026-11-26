$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path

& (Join-Path $raiz "empacotar.ps1")
$love = Join-Path $raiz "game.love"
if (-not (Test-Path $love)) { exit 1 }

$adb = $null
$cmd = Get-Command adb -ErrorAction SilentlyContinue
if ($cmd) {
  $adb = $cmd.Source
} else {
  $encontrado = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter adb.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($encontrado) { $adb = $encontrado.FullName }
}
if (-not $adb) {
  Write-Host "adb nao encontrado. Instale com: winget install Google.PlatformTools"
  exit 1
}

$estado = & $adb get-state 2>&1
if ($LASTEXITCODE -ne 0 -or "$estado" -notmatch "device") {
  Write-Host "Celular nao encontrado via USB."
  Write-Host "Ative Depuracao USB no celular e conecte o cabo."
  exit 1
}

Write-Host "Enviando game.love..."
& $adb push $love /sdcard/Download/game.love

Write-Host "Abrindo no app LOVE..."
& $adb shell am start -a android.intent.action.VIEW -d "file:///sdcard/Download/game.love" -n org.love2d.android/.GameActivity

Write-Host ""
Write-Host "Se nao abrir sozinho: instale o APK do LOVE no celular"
Write-Host "(github.com/love2d/love/releases) e abra Download/game.love"
