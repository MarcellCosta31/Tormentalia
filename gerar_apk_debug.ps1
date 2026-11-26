$ErrorActionPreference = 'Stop'

$proj    = $PSScriptRoot
$android = 'C:\Users\Marcell\AppData\Local\Temp\opencode\love-android'
$sdk     = 'C:\Android\sdk'
$jogo    = Join-Path $proj 'game.love'

$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.21.102-hotspot'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

Write-Host 'Configurando o projeto...'
"sdk.dir=C:/Android/sdk" | Set-Content "$android\local.properties" -Encoding Ascii

$gp = @"
app.name=Tormentalia
app.application_id=com.marcellcosta.tormentalia
app.orientation=landscape
app.version_code=1
app.version_name=1.0.0
android.enableJetifier=false
android.useAndroidX=true
android.defaults.buildfeatures.buildconfig=true
android.nonTransitiveRClass=true
android.nonFinalResIds=true
org.gradle.caching=true
"@
Set-Content "$android\gradle.properties" -Value $gp -Encoding Ascii

#_icone_inicio
Write-Host 'Aplicando icone Tormentalia...'
$resOrigem  = Join-Path $proj 'android-res'
$resDestino = "$android\app\src\main\res"
New-Item -ItemType Directory -Force -Path $resDestino | Out-Null
Get-ChildItem -LiteralPath $resOrigem -Directory | ForEach-Object {
  $alvo = Join-Path $resDestino $_.Name
  New-Item -ItemType Directory -Force -Path $alvo | Out-Null
  Get-ChildItem -LiteralPath $_.FullName -File | Copy-Item -Destination $alvo -Force
}
$manifest = "$android\app\src\main\AndroidManifest.xml"
$xml = Get-Content -LiteralPath $manifest -Raw
$novoXml = $xml -replace 'android:icon="@drawable/love"', 'android:icon="@drawable/tormentalia_icon"'
if ($novoXml -ne $xml) {
  [System.IO.File]::WriteAllText($manifest, $novoXml, [System.Text.UTF8Encoding]::new($false))
}
#_icone_fim

$assets = "$android\app\src\embed\assets"
New-Item -ItemType Directory -Force -Path $assets | Out-Null
Get-ChildItem -LiteralPath $assets -Force | Remove-Item -Recurse -Force
$zipTmp = Join-Path $env:TEMP 'jogo_para_apk.zip'
Copy-Item -LiteralPath $jogo -Destination $zipTmp -Force
Expand-Archive -LiteralPath $zipTmp -DestinationPath $assets -Force
Write-Host "Jogo extraido em $assets"

Write-Host 'Compilando APK debug...'
Push-Location $android
try {
  & .\gradlew assembleEmbedNoRecordDebug --no-daemon
  if ($LASTEXITCODE -ne 0) { throw "gradlew falhou com $LASTEXITCODE" }
} finally { Pop-Location }

$apk = Get-ChildItem -Path "$android\app\build\outputs\apk" -Recurse -Filter '*.apk' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $apk) { throw 'APK nao encontrado' }
$dest = Join-Path $proj 'build\android\Tormentalia.apk'
New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
Copy-Item -LiteralPath $apk.FullName -Destination $dest -Force
Get-ChildItem -LiteralPath (Split-Path $dest) -Filter '*CaroDeus*.apk' -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue
"APK gerado: $dest"
"Tamanho: $([math]::Round((Get-Item $dest).Length / 1MB, 1)) MB"
