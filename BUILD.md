# Como gerar os pacotes para distribuição

O jogo roda em LÖVE 11.5. O ponto de partida é sempre o `game.love`:

```bat
cmd /c empacotar.bat
```

Ele gera um ZIP com `main.lua` na raiz (obrigatório).

## Pacotes já gerados

| Arquivo | O que é |
|---|---|
| `build\windows\Tormentalia.exe` | Executável Windows (pasta inteira `build\windows` é a distribuição) |
| `build\android\Tormentalia.apk` | APK debug, instalável por sideload |
| `build\android\Tormentalia-release.apk` | APK release assinado (recomendado para distribuir) |

## Windows — executável `.exe`

```bat
powershell -ExecutionPolicy Bypass -File gerar_exe.ps1
```

O script copia as DLLs do LÖVE, aplica o ícone `build\icons\tormentalia.ico` em uma
cópia do `love.exe` e funde o resultado com `game.love` em:

```
build\windows\Tormentalia.exe
```

Para gerar/regenerar os ícones a partir de `arte\deus_mercado\logo.png`:

```bat
python scripts\gerar_icons.py
```

Para distribuir, compacte **toda** a pasta `build\windows` (o `.exe` sozinho não funciona sem as DLLs). Teste local: rodar o exe com `JOGO_TESTE=1` imprime a suíte e termina com código 0.

## Android — APK / AAB

Não é preciso ter Lua nem LÖVE instalado no celular: o APK já embute o engine.

### Opção 1 — GitHub Actions (sem SDK na máquina)

O workflow `.github/workflows/build-android.yml` monta o `game.love` a partir dos fontes (para não versionar um arquivo de ~400 MB), compila e anexa o APK como artefato. O ícone vem de `android-res/drawable-*/tormentalia_icon.png` (`icon-specifier: '@drawable/tormentalia_icon'`).

1. Crie um keystore uma vez:

   ```bat
   keytool -genkeypair -v -keystore android.keystore -alias tormentalia -keyalg RSA -keysize 2048 -validity 10000
   ```

2. No GitHub, em **Settings → Secrets and variables → Actions**, cadastre:

   | Secret | Valor |
   |---|---|
   | `ANDROID_KEYSTORE_ALIAS` | `tormentalia` |
   | `ANDROID_KEYSTORE_BASE64` | `powershell -Command "[Convert]::ToBase64String([IO.File]::ReadAllBytes('android.keystore'))"` |
   | `ANDROID_KEYSTORE_KEYPASSWORD` | senha da chave |
   | `ANDROID_KEYSTORE_STOREPASSWORD` | senha do keystore |

3. Gatilho: **Actions → Build Android APK → Run workflow**, ou:

   ```bat
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. Baixe o APK em **Artifacts → android**. Sem os secrets, o workflow ainda gera o APK **debug** (instalável); com eles, gera o **release assinado**.

### Opção 2 — build local (já configurado nesta máquina)

Foram instalados: **JDK 17** em `C:\Program Files\Microsoft\jdk-17.0.21.102-hotspot`, **Android SDK** em `C:\Android\sdk` (API 34, build-tools 34, NDK **25.2.9519653** — exigido pelo branch `11.5a` — e CMake 3.22), e o repositório `love-android` clonado em `%TEMP%\opencode\love-android`.

Regenerar depois de alterar o jogo (rode `empacotar.bat` antes):

```bat
powershell -ExecutionPolicy Bypass -File gerar_apk_debug.ps1
powershell -ExecutionPolicy Bypass -File gerar_apk_release.ps1
```

O script release gera/usa o keystore em `%TEMP%\tormentalia.keystore` (alias `tormentalia`, senha `tormentalia2026`), alinha e assina o APK com `zipalign` + `apksigner`. **Guarde esse keystore**: se ele for perdido, as futuras atualizações não poderão substituir o app instalado. Para Play Store, use um AAB (`gradlew bundleEmbedNoRecordRelease`).

Em uma máquina nova, o passo a passo equivalente é: instalar JDK 17 + command-line tools do Android, aceitar licenças, instalar `platforms;android-34`, `build-tools;34.0.0`, `ndk;25.2.9519653`, `cmake;3.22.1`, clonar `love-android` com `--recurse-submodules --branch 11.5a`, extrair o `game.love` em `app/src/embed/assets` e rodar o Gradle.

### Teste rápido sem gerar APK

Instale o APK oficial do LÖVE 11.5 (love2d.org/releases) e abra o `game.love` pelo gerenciador de arquivos.

## Atenção ao tamanho

O `game.love` tem ~400 MB por causa das artes em `arte/`. O APK ficará proporcionalmente grande. Antes de publicar, vale reduzir as PNGs (resolução ou WebP) — o projeto já trata WebP renomeado como `.png` em `arte.lua`.
