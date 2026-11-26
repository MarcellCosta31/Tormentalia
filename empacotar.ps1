param()
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $raiz

$zip = Join-Path $raiz "game.zip"
$love = Join-Path $raiz "game.love"
if (Test-Path $zip) { Remove-Item $zip -Force }
if (Test-Path $love) { Remove-Item $love -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$alvos = Get-ChildItem -Recurse -File | Where-Object {
  $_.Extension -notin @(".bat", ".ps1", ".zip", ".love", ".html", ".htm") -and
  # Logs de debug (dbg_shot.txt e cia.) nao sao jogo — sem essa guarda
  # eles entram no pacote e sobem o numero de arquivos do game.love.
  -not $_.Name.StartsWith("dbg_") -and
  # A pasta trailer/ tem clipes e MP4s grandes de captura; ela nunca deve
  # entrar no game.love.
  -not ($_.FullName -like "$raiz\trailer\*") -and
  # build/ guarda os executaveis e APKs (centenas de MB) gerados para
  # distribuicao; .github/ e android-res/ sao so configuracao de build.
  -not ($_.FullName -like "$raiz\build\*") -and
  -not ($_.FullName -like "$raiz\.github\*") -and
  -not ($_.FullName -like "$raiz\android-res\*") -and
  # site/ e shots/ nao sao usados em runtime e trazem capturas antigas.
  -not ($_.FullName -like "$raiz\site\*") -and
  -not ($_.FullName -like "$raiz\shots\*") -and
  -not ($_.FullName -like "$raiz\.vscode\*")
}

$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($arquivo in $alvos) {
    $relativo = $arquivo.FullName.Substring($raiz.Length + 1).Replace("\", "/")
    # FileShare.ReadWrite permite empacotar mesmo quando o Office esta com
    # o manual/planilha aberto (CreateEntryFromFile usa FileShare.Read e
    # falha nesse caso, deixando o game.love apagado no meio do processo).
    $entry = $archive.CreateEntry($relativo)
    $dest = $entry.Open()
    try {
      $origem = [System.IO.FileStream]::new($arquivo.FullName,
        [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite)
      try { $origem.CopyTo($dest) } finally { $origem.Dispose() }
    } finally { $dest.Dispose() }
  }
} finally {
  $archive.Dispose()
}

Move-Item $zip $love -Force
Write-Host ("game.love gerado: {0} ({1} arquivos)" -f $love, $alvos.Count)
