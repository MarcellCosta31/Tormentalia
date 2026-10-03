Add-Type -AssemblyName System.Drawing

$w = 408
$h = 612
$out = Join-Path $PSScriptRoot "..\src\assets\cards\arte_faltando.png"

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "AntiAlias"
$g.TextRenderingHint = "AntiAliasGridFit"

$bg = [System.Drawing.Color]::FromArgb(255, 24, 20, 32)
$g.Clear($bg)

$hatch = [System.Drawing.Color]::FromArgb(255, 38, 32, 50)
$pen = New-Object System.Drawing.Pen($hatch, 6)
for ($x = -$h; $x -lt $w; $x += 28) {
  $g.DrawLine($pen, $x, 0, ($x + $h), $h)
}
$pen.Dispose()

$border = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 120, 100, 160), 4)
$g.DrawRectangle($border, 14, 14, ($w - 28), ($h - 28))
$border.Dispose()

$fontBig = New-Object System.Drawing.Font("Consolas", 44, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fontSmall = New-Object System.Drawing.Font("Consolas", 18, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$yellow = [System.Drawing.Brushes]::Yellow
$gray = [System.Drawing.Brushes]::Gray

$lines = @("ARTE", "FALTANDO")
$y = [int](($h / 2) - 55)
foreach ($line in $lines) {
  $size = $g.MeasureString($line, $fontBig)
  $g.DrawString($line, $fontBig, $yellow, [int](($w - $size.Width) / 2), $y)
  $y += [int]$size.Height + 6
}

$help = "sem ilustracao"
$sizeHelp = $g.MeasureString($help, $fontSmall)
$g.DrawString($help, $fontSmall, $gray, [int](($w - $sizeHelp.Width) / 2), ($h - 90))

$fontBig.Dispose()
$fontSmall.Dispose()
$g.Dispose()

$bmp.Save((Resolve-Path (Split-Path $out)).Path + "\arte_faltando.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output "gerado: src\assets\cards\arte_faltando.png ($w x $h)"
