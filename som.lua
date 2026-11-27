-- Efeitos sonoros curtos: sons/*.wav carregados por NOME. Os arquivos
-- sao sinteticos gerados por gerar_sons.ps1 e podem ser substituidos por
-- qualquer .wav real de mesmo nome sem mudar codigo (o gerado usa
-- 16-bit/44100Hz/mono). Em MODO_TESTE nada toca: a suite roda muda e nao
-- depende de dispositivo de audio.
local M = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local fontes = {}
local mudo = false

-- Volume dos efeitos (0..1): afeta so os sons curtos de M.tocar e persiste
-- em "config_som" (a tela de CONFIGURACOES sobe/desce em passos de 10%).
local volumeEfeitos = 1
local ARQ_EFEITOS = "config_som"
-- Volume da trilha (0..1): separado do dos efeitos, para o jogador ajustar
-- cada um. Persiste em "config_musica"; quem ainda so tem o "config_som"
-- antigo (volume mestre unico) herda o valor dele nos dois na primeira vez.
local volumeMusica = 1
local ARQ_MUSICA = "config_musica"

local NOMES = { "clique", "jogar", "guardar", "passar", "turno",
  "vitoria", "derrota", "emoji", "saida", "tempo", "roleta", "festa",
  "passo", "psicar", "uau", "terror", "engracado", "risada", "tensao",
  "susto", "caixa", "escudo", "impacto", "versus" }

-- Ultimo nome pedido (mesmo em MODO_TESTE/mudo: a suite usa para conferir
-- que um codigo dispara o efeito certo sem depender de audio).
M.ultimo = nil

-- Ultima trilha pedida a musica() (tambem em MODO_TESTE: o smoke confere
-- que cada tela roda a trilha certa — menu, batalha ou vento).
M.musicaUltima = nil

-- Carrega as fontes uma vez (chamado no love.load; no-op no teste).
function M.carregar()
  -- Volume dos efeitos persistido (lido tambem em MODO_TESTE: a suite confere).
  local okV, txtV = pcall(love.filesystem.read, ARQ_EFEITOS)
  if okV and txtV then
    local n = tonumber(txtV)
    if n then volumeEfeitos = math.max(0, math.min(1, n)) end
  end
  -- Volume da trilha. Sem "config_musica" (quem vem do volume mestre unico)
  -- a trilha herda o valor dos efeitos, para o ajuste antigo valer para os
  -- dois ate o jogador mexer em cada um.
  local okM, txtM = pcall(love.filesystem.read, ARQ_MUSICA)
  if okM and txtM then
    local n = tonumber(txtM)
    if n then volumeMusica = math.max(0, math.min(1, n)) end
  else
    volumeMusica = volumeEfeitos
  end
  if MODO_TESTE or not love.audio then return end
  for _, nome in ipairs(NOMES) do
    local ok, src = pcall(love.audio.newSource,
      "sons/" .. nome .. ".wav", "static")
    if ok and src then fontes[nome] = src end
  end
end

-- Toca o som (reinicia se ja estiver tocando, certo para efeitos curtos).
-- Volume opcional 0..1; falha silenciosa se o arquivo nao existir.
function M.tocar(nome, vol)
  M.ultimo = nome
  if MODO_TESTE or mudo or not love.audio then return end
  local s = fontes[nome]
  if not s then return end
  pcall(function()
    s:setPitch(1)
    s:setVolume((vol or 1) * volumeEfeitos)
    s:stop()
    s:play()
  end)
end

-- Toca com pitch escalado (chain: cada link sobe um pouco o tom).
function M.tocarPitch(nome, pitch, vol)
  M.ultimo = nome
  if MODO_TESTE or mudo or not love.audio then return end
  local s = fontes[nome]
  if not s then return end
  pcall(function()
    s:setPitch(math.max(0.5, math.min(2.5, pitch or 1)))
    s:setVolume((vol or 1) * volumeEfeitos)
    s:stop()
    s:play()
  end)
end

function M.definirMudo(v)
  mudo = v and true or false
end

function M.estaMudo()
  return mudo
end

-- Musica de fundo (stream em loop infinito; gerada por
-- gerar_musica_menu.ps1 como sons/menu.wav). Chamada repetida e no-op
-- enquanto a mesma musica ja estiver tocando; em MODO_TESTE/mudo nada toca.
local musicaSrc = nil
local musicaNome = nil

function M.musica(nome)
  M.musicaUltima = nome -- registra tambem em MODO_TESTE (smoke da tela)
  if MODO_TESTE or not love.audio then return end
  if mudo then
    M.pararMusica()
    return
  end
  if musicaNome == nome and musicaSrc and musicaSrc:isPlaying() then return end
  M.pararMusica()
  local ok, s = pcall(love.audio.newSource, "sons/" .. nome .. ".wav", "stream")
  if not ok or not s then return end
  s:setLooping(true)
  s:setPitch(1)
  s:setVolume(0.6 * volumeMusica)
  pcall(function() s:play() end)
  musicaSrc, musicaNome = s, nome
  -- Diagnóstico opcional (JOGO_MUSICA_DBG=1): confirma que a fonte da
  -- música nasceu e já está em reprodução no frame corrente.
  if os.getenv("JOGO_MUSICA_DBG") then
    io.write("[musica] '" .. nome .. "' tocando=" .. tostring(s:isPlaying()) .. "\n")
  end
end

-- Ajusta o pitch da trilha corrente (musica adaptativa: 1.0 calma,
-- ~1.08 media, ~1.16 finals). Nao muda o nome nem reinicia a musica.
function M.musicaIntensidade(fator)
  if MODO_TESTE or not musicaSrc then return end
  pcall(function()
    musicaSrc:setPitch(math.max(0.5, math.min(2, fator or 1)))
  end)
end

function M.pararMusica()
  if musicaSrc then pcall(function() musicaSrc:stop() end) end
  musicaSrc, musicaNome = nil, nil
end

-- Volume dos efeitos (0..1): a tela de CONFIGURACOES usa para subir/descer.
-- Passos de 10% arredondados aqui (0.5 + 0.1 vira 0.6 de verdade) e
-- MODO_TESTE so muda a memoria (mesmo trato do salvarProg do selecao).
-- Aplica na hora: os efeitos leem volumeEfeitos a cada tocar().
function M.definirVolumeEfeitos(v)
  v = math.max(0, math.min(1, v or 1))
  volumeEfeitos = math.floor(v * 10 + 0.5) / 10
  if MODO_TESTE then return end
  pcall(love.filesystem.write, ARQ_EFEITOS, string.format("%.1f", volumeEfeitos))
  return volumeEfeitos
end

-- Volume da trilha (0..1): mesmos passos de 10%, aplicado na hora na
-- musica que ja esta tocando e persistido em "config_musica".
function M.definirVolumeMusica(v)
  v = math.max(0, math.min(1, v or 1))
  volumeMusica = math.floor(v * 10 + 0.5) / 10
  if musicaSrc then
    pcall(function() musicaSrc:setVolume(0.6 * volumeMusica) end)
  end
  if MODO_TESTE then return end
  pcall(love.filesystem.write, ARQ_MUSICA, string.format("%.1f", volumeMusica))
  return volumeMusica
end

function M.volumeEfeitos()
  return volumeEfeitos
end

function M.volumeMusica()
  return volumeMusica
end

return M
