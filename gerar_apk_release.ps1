$ErrorActionPreference = 'Stop'

$proj    = $PSScriptRoot
$android = 'C:\Users\Marcell\AppData\Local\Temp\opencode\love-android'
$sdk     = 'C:\Android\sdk'
$java    = 'C:\Program Files\Microsoft\jdk-17.0.21.102-hotspot'
$store   = Join-Path $env:TEMP 'tormentalia.keystore'
$pass    = 'tormentalia2026'
$alias   = 'tormentalia'
$appId   = 'com.marcellcosta.tormentalia'

$env:JAVA_HOME = $java
$env:PATH = "$java\bin;$env:PATH"
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

Write-Host 'Configurando o projeto...'
$gp = @"
app.name=Tormentalia
app.application_id=$appId
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

if (-not (Test-Path $store)) {
  Write-Host 'Gerando keystore...'
  & "$java\bin\keytool.exe" -genkeypair -v -keystore $store `
    -alias $alias -keyalg RSA -keysize 2048 -validity 10000 `
    -storepass $pass -keypass $pass `
    -dname "CN=Tormentalia, OU=Jogo, O=Marcell Costa, L=SP, ST=SP, C=BR"
}

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

Write-Host 'Preparando assets do jogo...'
$assets = "$android\app\src\embed\assets"
New-Item -ItemType Directory -Force -Path $assets | Out-Null
Get-ChildItem -LiteralPath $assets -Force | Remove-Item -Recurse -Force
$zipTmp = Join-Path $env:TEMP 'jogo_para_apk.zip'
Copy-Item -LiteralPath (Join-Path $proj 'game.love') -Destination $zipTmp -Force
Expand-Archive -LiteralPath $zipTmp -DestinationPath $assets -Force

Write-Host 'Compilando release...'
Push-Location $android
try {
  & .\gradlew assembleEmbedNoRecordRelease --no-daemon --no-build-cache
  if ($LASTEXITCODE -ne 0) { throw "gradlew falhou com $LASTEXITCODE" }
} finally { Pop-Location }

$unsigned = Get-ChildItem -Path "$android\app\build\outputs\apk" -Recurse -Filter '*release*unsigned*.apk' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $unsigned) {
  $unsigned = Get-ChildItem -Path "$android\app\build\outputs\apk" -Recurse -Filter '*release*.apk' |
    Where-Object { $_.Name -notmatch 'aligned|signed' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $unsigned) { throw 'APK release nao encontrado' }
Write-Host "APK bruto: $($unsigned.FullName)"

$aligned = Join-Path $env:TEMP 'tormentalia_aligned.apk'
$finalTmp = Join-Path $env:TEMP 'tormentalia_signed.apk'
& "$sdk\build-tools\34.0.0\zipalign.exe" -p -f 4 $unsigned.FullName $aligned
if ($LASTEXITCODE -ne 0) { throw 'zipalign falhou' }

& "$sdk\build-tools\34.0.0\apksigner.bat" sign `
  --ks $store --ks-key-alias $alias `
  --ks-pass "pass:$pass" --key-pass "pass:$pass" `
  --out $finalTmp $aligned
if ($LASTEXITCODE -ne 0) { throw 'apksigner falhou' }

$dest = Join-Path $proj 'build\android\Tormentalia-release.apk'
New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
Copy-Item -LiteralPath $finalTmp -Destination $dest -Force
Get-ChildItem -LiteralPath (Split-Path $dest) -Filter '*CaroDeus*.apk' -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue
& "$sdk\build-tools\34.0.0\apksigner.bat" verify $dest
"APK release assinado: $dest"
"Tamanho: $([math]::Round((Get-Item $dest).Length / 1MB, 1)) MB"
"Keystore: $store (senha: $pass)"
