param()
# Gera os efeitos sonoros das animacoes especiais das cartas Curinga.
# Mesmo formato do gerar_sons.ps1: 16-bit PCM 44100Hz mono, sintetico e
# deterministico (seed fixa). Pode substituir qualquer .wav por um real de
# MESMO nome em sons/ sem mudar o codigo.
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$saida = Join-Path $raiz "sons"
if (-not (Test-Path $saida)) { New-Item -ItemType Directory -Path $saida | Out-Null }
$SR = 44100

function Add-Sine($l, [double]$freq, [double]$dur, [double]$vol,
                  [double]$decay, [double]$delay) {
  $off = [int]($delay * $SR)
  $n = [int]($dur * $SR)
  for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $SR
    $v = $vol * [Math]::Exp(-$decay * $t) * [Math]::Sin(2 * [Math]::PI * $freq * $t)
    $idx = $off + $i
    while ($l.Count -le $idx) { $l.Add(0.0) | Out-Null }
    $l[$idx] = $l[$idx] + $v
  }
}

function Add-Chirp($l, [double]$f0, [double]$f1, [double]$dur,
                   [double]$vol, [double]$decay, [double]$delay) {
  $off = [int]($delay * $SR)
  $n = [int]($dur * $SR)
  $ph = 0.0
  for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $SR
    $f = $f0 + ($f1 - $f0) * ($t / $dur)
    $ph += 2 * [Math]::PI * $f / $SR
    $v = $vol * [Math]::Exp(-$decay * $t) * [Math]::Sin($ph)
    $idx = $off + $i
    while ($l.Count -le $idx) { $l.Add(0.0) | Out-Null }
    $l[$idx] = $l[$idx] + $v
  }
}

function Add-Noise($l, [double]$dur, [double]$vol, [double]$decay,
                   [double]$lp, [double]$delay) {
  $off = [int]($delay * $SR)
  $n = [int]($dur * $SR)
  $rand = New-Object System.Random(7)
  $prev = 0.0
  for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $SR
    $w = $rand.NextDouble() * 2 - 1
    $prev = $prev + $lp * ($w - $prev)
    $v = $vol * [Math]::Exp(-$decay * $t) * $prev
    $idx = $off + $i
    while ($l.Count -le $idx) { $l.Add(0.0) | Out-Null }
    $l[$idx] = $l[$idx] + $v
  }
}

# Tom com vibrato (voz/instrumento "vivo"): usado no "uau" e no terror.
function Add-Vib($l, [double]$freq, [double]$dur, [double]$vol,
                 [double]$decay, [double]$delay, [double]$rate,
                 [double]$depth) {
  $off = [int]($delay * $SR)
  $n = [int]($dur * $SR)
  $ph = 0.0
  for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $SR
    $f = $freq * (1 + $depth * [Math]::Sin(2 * [Math]::PI * $rate * $t))
    $ph += 2 * [Math]::PI * $f / $SR
    $v = $vol * [Math]::Exp(-$decay * $t) * [Math]::Sin($ph)
    $idx = $off + $i
    while ($l.Count -le $idx) { $l.Add(0.0) | Out-Null }
    $l[$idx] = $l[$idx] + $v
  }
}

# "Ha" de risada: fundamental com harmonicos + envelope de vogal.
function Add-Ha($l, [double]$f0, [double]$dur, [double]$vol, [double]$delay) {
  $off = [int]($delay * $SR)
  $n = [int]($dur * $SR)
  $ph = 0.0
  for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $SR
    $amp = [Math]::Sin([Math]::PI * ($t / $dur))
    $f = $f0 * (1 + 0.10 * [Math]::Sin(2 * [Math]::PI * 8 * $t))
    $ph += 2 * [Math]::PI * $f / $SR
    $h1 = [Math]::Sin($ph)
    $h2 = [Math]::Sin(2 * $ph)
    $h3 = [Math]::Sin(3 * $ph)
    $v = $vol * $amp * ($h1 + 0.55 * $h2 + 0.30 * $h3)
    $idx = $off + $i
    while ($l.Count -le $idx) { $l.Add(0.0) | Out-Null }
    $l[$idx] = $l[$idx] + $v
  }
}

function Add-Heart($l, [double]$delay, [double]$vol) {
  Add-Sine $l 58 0.16 $vol 22 $delay
  Add-Sine $l 42 0.20 ($vol * 0.75) 18 ($delay + 0.02)
  Add-Noise $l 0.05 ($vol * 0.45) 60 0.25 $delay
}

function Write-Wav([string]$caminho, $l) {
  $n = $l.Count
  $bytes = New-Object byte[] ($n * 2)
  for ($i = 0; $i -lt $n; $i++) {
    $v = [Math]::Max(-1.0, [Math]::Min(1.0, $l[$i]))
    $nb = [BitConverter]::GetBytes([int16][Math]::Round($v * 32000))
    $bytes[$i * 2] = $nb[0]
    $bytes[$i * 2 + 1] = $nb[1]
  }
  $fs = [System.IO.File]::Open($caminho, "Create")
  $w = New-Object System.IO.BinaryWriter($fs)
  $w.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
  $w.Write([int32](36 + $bytes.Length))
  $w.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
  $w.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
  $w.Write([int32]16)
  $w.Write([int16]1)
  $w.Write([int16]1)
  $w.Write([int32]$SR)
  $w.Write([int32]($SR * 2))
  $w.Write([int16]2)
  $w.Write([int16]16)
  $w.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
  $w.Write([int32]$bytes.Length)
  $w.Write($bytes)
  $w.Close()
}

function Novo { New-Object 'System.Collections.Generic.List[double]' }

# uau: acorde ascendente com vibrato + brilho. Toca no Monstro Inflacao.
$l = Novo
Add-Vib $l 196 0.9 0.34 1.1 0 5.5 0.035
Add-Vib $l 294 0.9 0.26 1.1 0.02 5.5 0.035
Add-Vib $l 392 0.9 0.20 1.2 0.04 5.5 0.035
Add-Chirp $l 392 784 0.75 0.12 1.4 0.05
Add-Sine $l 1568 0.18 0.10 30 0.42
Add-Sine $l 2093 0.16 0.08 34 0.52
Add-Sine $l 2637 0.14 0.06 38 0.60
Write-Wav (Join-Path $saida "uau.wav") $l

# terror: drone grave batendo, cluster dissonante, coracao e um apito agudo
# (sensacao de estar sendo observado). Toca no Efeito Hawthorne.
$l = Novo
Add-Sine $l 43 2.3 0.30 0.55 0
Add-Sine $l 46 2.3 0.24 0.55 0
Add-Sine $l 660 1.9 0.07 0.55 0.10
Add-Sine $l 693 1.9 0.06 0.55 0.10
Add-Chirp $l 2300 2850 1.6 0.05 0.9 0.25
Add-Heart $l 0.05 0.42
Add-Heart $l 0.80 0.34
Add-Heart $l 1.55 0.28
Add-Noise $l 2.2 0.12 0.7 0.05 0
Write-Wav (Join-Path $saida "terror.wav") $l

# engracado: assovio escorregando pra cima e pra baixo + boing. Toca na
# Flutuacao do Mercado e na Rotatividade de Mercado.
$l = Novo
Add-Chirp $l 420 1350 0.34 0.34 2.2 0
Add-Chirp $l 1350 330 0.36 0.32 2.0 0.34
Add-Vib $l 180 0.55 0.30 2.0 0.62 11 0.20
Add-Sine $l 1200 0.05 0.16 90 0.10
Add-Sine $l 1600 0.05 0.12 90 0.20
Write-Wav (Join-Path $saida "engracado.wav") $l

# risada: tres grupos de "ha ha ha" descendo. Toca na Seletividade de Taylor.
$l = Novo
$grupos = @(0.0, 0.52, 1.04)
$base = @(250.0, 226.0, 204.0)
for ($g = 0; $g -lt 3; $g++) {
  for ($j = 0; $j -lt 3; $j++) {
    $t = $grupos[$g] + $j * 0.115
    $f = $base[$g] * (1 - 0.06 * $j)
    Add-Ha $l $f 0.11 0.34 $t
    Add-Noise $l 0.035 0.10 55 0.45 ($t + 0.01)
  }
}
Write-Wav (Join-Path $saida "risada.wav") $l

# tensao: 4 segundos de drone subindo, batimentos acelerando e tique-taques.
# Toca enquanto a Probabilidade Mortal anda pela tela.
$l = Novo
Add-Chirp $l 38 92 3.9 0.30 0.0 0
Add-Chirp $l 76 184 3.9 0.14 0.0 0
Add-Noise $l 3.9 0.10 0.0 0.03 0
$t = 0.0
$passo = 0.82
while ($t -lt 3.85) {
  Add-Heart $l $t (0.30 + 0.16 * ($t / 3.9))
  Add-Sine $l 2400 0.018 0.14 220 $t
  $t += $passo
  if ($passo -gt 0.34) { $passo -= 0.055 }
}
Add-Chirp $l 900 2600 0.7 0.12 2.0 3.1
Write-Wav (Join-Path $saida "tensao.wav") $l

# susto: estouro de ruido + acorde dissonante + boom grave + grito agudo.
# Toca no avanco final da Probabilidade Mortal.
$l = Novo
Add-Noise $l 0.30 0.85 9 0.55 0
Add-Sine $l 55 0.55 0.65 7 0
Add-Sine $l 110 0.35 0.35 8 0
Add-Sine $l 233 0.75 0.28 5 0
Add-Sine $l 247 0.75 0.26 5 0
Add-Sine $l 466 0.55 0.20 7 0.02
Add-Chirp $l 2200 700 0.55 0.30 6 0
Add-Noise $l 0.18 0.35 20 0.30 0.05
Write-Wav (Join-Path $saida "susto.wav") $l

Get-ChildItem $saida -Filter *.wav | ForEach-Object {
  Write-Host ("{0} ({1} bytes)" -f $_.Name, $_.Length)
}
