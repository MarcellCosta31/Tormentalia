param()
# Gera os efeitos sonoros do jogo (16-bit PCM 44100Hz mono) em sons/.
# Sao sinteticos basicos de proposito: pode substituir qualquer .wav por
# um arquivo real de MESMO nome (idealmente 44.1kHz/16-bit/mono) sem mudar
# codigo — o som.lua so carrega por nome. Seed fixa: o resultado e
# identico a cada execucao.
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

# clique: tick curto de botao (tudo que e toque na UI).
$l = Novo
Add-Sine $l 1900 0.045 0.55 60 0
Add-Noise $l 0.02 0.25 120 0.6 0
Write-Wav (Join-Path $saida "clique.wav") $l

# jogar: swoosh da leva (ruido com graves filtrados + subida suave).
$l = Novo
Add-Noise $l 0.16 0.50 25 0.25 0
Add-Chirp $l 350 850 0.14 0.25 30 0
Write-Wav (Join-Path $saida "jogar.wav") $l

# guardar: thud macio da area segura.
$l = Novo
Add-Sine $l 240 0.10 0.55 45 0
Add-Sine $l 480 0.05 0.20 60 0
Write-Wav (Join-Path $saida "guardar.wav") $l

# passar: blip curto de desistencia.
$l = Novo
Add-Sine $l 620 0.09 0.45 50 0
Write-Wav (Join-Path $saida "passar.wav") $l

# turno: sino de 2 notas quando a vez chega para voce.
$l = Novo
Add-Sine $l 880 0.28 0.45 12 0
Add-Sine $l 1318.51 0.50 0.40 10 0.16
Write-Wav (Join-Path $saida "turno.wav") $l

# vitoria: arpejo maior C5 E5 G5 C6.
$l = Novo
Add-Sine $l 523.25 0.35 0.40 11 0
Add-Sine $l 659.26 0.35 0.40 11 0.13
Add-Sine $l 783.99 0.35 0.40 11 0.26
Add-Sine $l 1046.50 0.55 0.40 9 0.39
Write-Wav (Join-Path $saida "vitoria.wav") $l

# derrota: arpejo descendente A4 F4 D4 A3.
$l = Novo
Add-Sine $l 440 0.35 0.40 10 0
Add-Sine $l 349.23 0.35 0.40 10 0.15
Add-Sine $l 293.66 0.35 0.40 10 0.30
Add-Sine $l 220 0.55 0.40 8 0.45
Write-Wav (Join-Path $saida "derrota.wav") $l

# emoji: pop que sobe.
$l = Novo
Add-Chirp $l 480 1500 0.09 0.55 40 0
Write-Wav (Join-Path $saida "emoji.wav") $l

# saida: blip grave duplo do jogador que desconectou.
$l = Novo
Add-Sine $l 430 0.10 0.45 30 0
Add-Sine $l 330 0.14 0.40 25 0.09
Write-Wav (Join-Path $saida "saida.wav") $l

# tempo: bipe duplo do relogio esgotando na sua vez.
$l = Novo
Add-Sine $l 1200 0.09 0.50 40 0
Add-Sine $l 1200 0.09 0.50 40 0.16
Write-Wav (Join-Path $saida "tempo.wav") $l

# roleta: sorteio de quem comeca (ruido grave girando + 16 trancos na
# MESMA escada de desaceleracao da animacao: atraso 0.04+(i/16)^2*0.3 a
# partir de 0.15s — o som casa tranco por tranco com o quadro) e parada.
$l = Novo
Add-Noise $l 2.45 0.30 0.55 0.12 0
$t = 0.15
for ($i = 1; $i -le 15; $i++) {
  Add-Sine $l 2600 0.018 0.50 260 $t
  $t += 0.04 + [Math]::Pow($i / 16.0, 2) * 0.3
}
# Parada: o ultimo tranco e maior (a bola encosta) + grave da parada.
Add-Sine $l 2600 0.025 0.65 200 $t
Add-Sine $l 160 0.18 0.60 28 ($t + 0.02)
Add-Noise $l 0.06 0.40 110 0.5 ($t + 0.02)
Write-Wav (Join-Path $saida "roleta.wav") $l

# festa: revelacao de quem comeca — serpentinha subindo, estouros de
# festa, brilhos e ding final; toca no mesmo instante do confete.
$l = Novo
Add-Chirp $l 420 1050 0.38 0.45 8 0
Add-Chirp $l 840 2100 0.38 0.18 8 0
Add-Sine $l 700 0.05 0.55 90 0
Add-Noise $l 0.04 0.45 140 0.4 0
Add-Sine $l 560 0.05 0.50 95 0.14
Add-Noise $l 0.04 0.40 150 0.4 0.14
Add-Sine $l 820 0.05 0.50 90 0.30
Add-Noise $l 0.04 0.40 150 0.4 0.30
Add-Sine $l 3200 0.05 0.30 120 0.48
Add-Sine $l 2600 0.05 0.30 120 0.58
Add-Sine $l 2200 0.05 0.30 120 0.68
Add-Sine $l 1046.50 0.50 0.35 10 0.78
Write-Wav (Join-Path $saida "festa.wav") $l

# passo: batidinha leve de sapato na caminhada da intro (thud grave curto
# + contato de ruido) — toca 2x por ciclo de 8 quadros (a cada 0.5s).
$l = Novo
Add-Sine $l 150 0.07 0.50 70 0
Add-Noise $l 0.045 0.30 90 0.35 0
Write-Wav (Join-Path $saida "passo.wav") $l

# psicar: duas batidas leves do piscar de olhos do emoji do Karl Marx
# (o balao anima nos 6 quadros; o som dispara no primeiro, com um retoque
# curto em seguida — cascatinha tipo "pisc-pisc").
$l = Novo
Add-Sine $l 980 0.05 0.35 70 0
Add-Noise $l 0.03 0.18 140 0.5 0
Add-Sine $l 820 0.05 0.35 70 0.10
Add-Noise $l 0.03 0.18 140 0.5 0.10
Write-Wav (Join-Path $saida "psicar.wav") $l

Get-ChildItem $saida -Filter *.wav | ForEach-Object {
  Write-Host ("{0} ({1} bytes)" -f $_.Name, $_.Length)
}
