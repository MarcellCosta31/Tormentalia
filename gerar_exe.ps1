# Gera um executavel Windows unico (engine LÖVE + game.love fundidos).
# O icone padrao do love.exe e substituido pela arte de Tormentalia.
# Uso: powershell -ExecutionPolicy Bypass -File gerar_exe.ps1
$ErrorActionPreference = 'Stop'

$raiz   = Split-Path -Parent $MyInvocation.MyCommand.Path
$love   = 'C:\Program Files\LOVE'
$out    = Join-Path $raiz 'build\windows'
$jogo   = Join-Path $raiz 'game.love'
$ico    = Join-Path $raiz 'build\icons\tormentalia.ico'
$patch  = Join-Path $raiz 'scripts\patch_exe_icon.py'

if (-not (Test-Path $jogo)) {
  throw "game.love nao encontrado. Rode empacotar.bat primeiro."
}
if (-not (Test-Path (Join-Path $love 'love.exe'))) {
  throw "love.exe nao encontrado em $love"
}
if (-not (Test-Path $ico)) {
  throw "ICO nao encontrado. Rode: python scripts/gerar_icons.py"
}

New-Item -ItemType Directory -Force -Path $out | Out-Null

# DLLs e arquivos de apoio precisam acompanhar o executavel.
Get-ChildItem -LiteralPath $love -File | Where-Object {
  $_.Extension -eq '.dll' -or $_.Name -in @('license.txt', 'changes.txt')
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $out -Force }

# Patcha uma copia do love.exe ANTES de fundir: o UpdateResource reescreve
# recursos e nao pode mexer no ZIP (game.love) que sera anexado depois.
$loveBase = Join-Path $env:TEMP 'tormentalia_love_base.exe'
Copy-Item -LiteralPath (Join-Path $love 'love.exe') -Destination $loveBase -Force
& python $patch $loveBase $ico
if ($LASTEXITCODE -ne 0) { throw "Falha ao aplicar o icone no executavel" }

# Fusiona: love.exe (com icone novo) + game.love -> Tormentalia.exe
$dest = Join-Path $out 'Tormentalia.exe'
$stream = [System.IO.File]::Create($dest)
try {
  foreach ($src in @($loveBase, $jogo)) {
    $in = [System.IO.File]::OpenRead($src)
    try { $in.CopyTo($stream) } finally { $in.Dispose() }
  }
} finally { $stream.Dispose() }

# Remove executaveis com o nome antigo, se ainda existirem.
Get-ChildItem -LiteralPath $out -Filter '*CaroDeus*.exe' -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue

"Executavel gerado: $dest"
"Tamanho: $([math]::Round((Get-Item $dest).Length / 1MB, 1)) MB"
