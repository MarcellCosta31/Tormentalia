-- Tela PERFIL DO JOGADOR: agora em 4 abas dentro do mesmo painel, com uma
-- nav bar vertical a esquerda (RESUMO / AVATARES / EMOTES / CARTAS), no
-- lugar do layout antigo de duas colunas fixas. Inspirado nos 4 prints de
-- referencia do usuario. Os botoes da nav sao ARTE PRONTA
-- (arte/perfil/botoes_perfil: botao_<aba>.png e botao_<aba>_selecionado.png,
-- a verde da aba ativa); so caem no desenho vetorial se a arte faltar.
--
--   RESUMO   -> avatar + nick, "EMOTES SELECIONADOS" e "CARTAS SELECIONADAS"
--   AVATARES -> preview + nick a esquerda, grade com TODOS os avatares do
--               jogador a direita (clique troca o avatar) e, na base, a FICHA
--               do avatar selecionado: nome + habilidade + resumo do teorico
--               (os padroes nao tem habilidade nem descricao)
--   EMOTES   -> preview grande do emote focado + nome/descricao a esquerda,
--               grade com TODOS os emotes do jogador a direita (clique
--               equipa/desequipa, maximo 4; tambem atualiza o foco e, nos
--               emojis de sprite da loja, faz a animacao tocar em loop no
--               preview enquanto ele fica selecionado)
--   CARTAS   -> apenas o DESIGNER por enquanto (sem dados/inventario de
--               cartas ainda): preview vazio, grade "CARTAS EM BREVE" e
--               rotulo "DECK ATUAL 0/7" vazio
--
-- Aberta clicando no avatar do canto superior direito do menu (TelaInicial).
local ui = require "ui"
local arte = require "arte"
local inv = require "inventario"

local P = {}

local VW, VH = 1280, 720
local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local ARQ = "perfil.txt"
local BASE_AVATARES = 8
local NICK_MAX = 20
-- Emotes iniciais de graca (vetoriais 1..4 do ui.emoji); os comprados na
-- loja (codigos 5+ = sprites) entram na grade junto. Maximo equipados: 4.
local EMOJIS_BASE = { 1, 2, 3, 4 }
local EMOJI_MAX = 4
-- Cartas: ainda sem sistema/inventario propria; so o numero maximo do
-- deck ja fica reservado no designer (aba CARTAS fica vazia por enquanto).
local DECK_MAX = 7
-- Colunas da grade de avatares (a de emotes tambem usa 6): com os 11
-- avatares possiveis sao 2 linhas, que cabem acima da FICHA do selecionado.
local AV_COLS = 6

-- Paleta (mesma linha visual do resto do jogo)
local GOLD = ui.hex "#c8963c"
local GOLD_LIGHT = ui.hex "#f0b429"
local BG_PAINEL = { 10 / 255, 18 / 255, 34 / 255, 0.97 }
local BG_FUNDO = ui.hex "#0A0714"
local VERDE = ui.hex "#3df064"
local VERDE_ESCURO = ui.hex "#0e5a26"
local COR_INPUT = ui.hex "#0c1424"
local COR_SPOT = ui.hex "#182740"
local COR_ITEM = ui.hex "#131e36"
local COR_ITEM_BORDA = ui.hex "#3d5a8c"
local COR_NAV = ui.hex "#0e1a30"
local COR_NAV_BORDA = ui.hex "#2c4468"
local CINZA = ui.hex "#93a4bd"
local BRANCO = { 1, 1, 1 }

-- Nome/descricao dos 4 emotes vetoriais base (os comprados usam os campos
-- do catalogo em inv.emojisProdutos quando existirem, com fallback seguro).
local EMOTE_INFO_BASE = {
  [1] = { nome = "SORRISO", desc = "Um sorriso simples e sincero." },
  [2] = { nome = "RISADA", desc = "Quando a partida esta boa demais!" },
  [3] = { nome = "TRISTEZA", desc = "Nem tudo sao flores no mercado." },
  [4] = { nome = "RAIVA", desc = "Paciencia tem limite." },
}

local ABAS = { "resumo", "avatares", "emotes", "cartas" }
local ABA_LABEL = { resumo = "RESUMO", avatares = "AVATARES", emotes = "EMOTES", cartas = "CARTAS" }
-- Botoes da nav: ARTE PRONTA (385x190, com moldura + icone + rotulo ja
-- embutidos; a versao "_sel" tem a moldura verde da aba ativa). A largura do
-- botao sai da altura por essa proporcao (largura/altura) para a arte nao
-- esticar.
local ASP_BOTAO = 385 / 190

-- { nick, avatarId, emojis, emoteFoco, emoteInicio, aba, t, editou } — o
-- emoteInicio e a ancora de st.t em que o emote em foco (re)comecou, para a
-- animacao da demonstracao tocar do primeiro quadro a cada clique.
local st = nil
local R = {}    -- retangulos de clique (dependem da aba atual)
local L = {}    -- medidas do layout (dependem da aba atual)

-- utf8 manual (LuaJIT nao tem lib utf8): conta/remove ultima sequencia.
local function contarAte(s, max)
  local n, i = 0, 1
  while i <= #s do
    local b = s:byte(i)
    local len = b < 0x80 and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4))
    n = n + 1
    if n > max then return s:sub(1, i - 1) end
    i = i + len
  end
  return s
end

local function apagarUtf8(s)
  if #s == 0 then return s end
  local i = #s
  while i > 1 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
  return s:sub(1, i - 1)
end

local function dentro(x, y, r)
  return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Retangulo com borda por DENTRO (RN desenha border dentro do box).
local function retInterno(x, y, w, h, raio, lw, fundo, borda, overlay)
  if fundo then
    love.graphics.setColor(fundo[1], fundo[2], fundo[3], fundo[4] or 1)
    love.graphics.rectangle("fill", x, y, w, h, raio, raio, 8)
  end
  if overlay then
    love.graphics.setColor(overlay[1], overlay[2], overlay[3], overlay[4] or 1)
    love.graphics.rectangle("fill", x, y, w, h, raio, raio, 8)
  end
  if borda then
    love.graphics.setLineWidth(lw)
    ui.pintar(borda)
    love.graphics.rectangle("line", x + lw / 2, y + lw / 2, w - lw, h - lw,
      math.max(1, raio - lw / 2), math.max(1, raio - lw / 2), 8)
    love.graphics.setLineWidth(1)
  end
end

-- CantosDecorativos.js: 4 "L" dourados 12dp offset -3dp borda 3dp.
local function cantos(x, y, w, h, cor)
  local s = 12 * L.G
  local o = 3 * L.G
  love.graphics.setLineWidth(3 * L.G)
  ui.pintar(cor)
  local function l(px, py, sx, sy)
    love.graphics.line(px, py, px + sx * s, py)
    love.graphics.line(px, py, px, py + sy * s)
  end
  l(x - o, y - o, 1, 1)
  l(x + w + o, y - o, -1, 1)
  l(x - o, y + h + o, 1, -1)
  l(x + w + o, y + h + o, -1, -1)
  love.graphics.setLineWidth(1)
end

local function diamante(cx, cy, d)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(math.rad(45))
  love.graphics.rectangle("fill", -d / 2, -d / 2, d, d)
  love.graphics.pop()
end

-- Check desenhado (o glyph "✓" nao esta garantido na fonte do jogo).
local function check(cx, cy, s, cor)
  ui.pintar(cor)
  love.graphics.setLineWidth(s * 0.17)
  love.graphics.line(
    cx - s * 0.42, cy + s * 0.03,
    cx - s * 0.10, cy + s * 0.34,
    cx + s * 0.46, cy - s * 0.32)
  love.graphics.setLineWidth(1)
end

-- Icones vetoriais da nav bar (sem depender de sprites proprios).
local function iconeResumo(cx, cy, s, cor)
  ui.pintar(cor)
  love.graphics.circle("fill", cx, cy - s * 0.18, s * 0.32)
  love.graphics.rectangle("fill", cx - s * 0.42, cy + s * 0.08, s * 0.84, s * 0.42, s * 0.16, s * 0.16)
end

local function iconeAvatares(cx, cy, s, cor)
  ui.pintar(cor)
  love.graphics.setLineWidth(math.max(1, s * 0.12))
  love.graphics.rectangle("line", cx - s * 0.42, cy - s * 0.42, s * 0.84, s * 0.84, s * 0.12, s * 0.12)
  love.graphics.circle("fill", cx, cy - s * 0.1, s * 0.2)
  love.graphics.rectangle("fill", cx - s * 0.28, cy + s * 0.14, s * 0.56, s * 0.26, s * 0.1, s * 0.1)
  love.graphics.setLineWidth(1)
end

local function iconeEmotes(cx, cy, s, cor)
  ui.pintar(cor)
  love.graphics.setLineWidth(math.max(1, s * 0.11))
  love.graphics.circle("line", cx, cy, s * 0.46)
  love.graphics.circle("fill", cx - s * 0.16, cy - s * 0.08, s * 0.06)
  love.graphics.circle("fill", cx + s * 0.16, cy - s * 0.08, s * 0.06)
  love.graphics.arc("line", "open", cx, cy, s * 0.24, math.rad(20), math.rad(160))
  love.graphics.setLineWidth(1)
end

local function iconeCartas(cx, cy, s, cor)
  ui.pintar(cor)
  love.graphics.push()
  love.graphics.translate(cx - s * 0.12, cy + s * 0.06)
  love.graphics.rotate(math.rad(-12))
  love.graphics.rectangle("fill", -s * 0.26, -s * 0.36, s * 0.52, s * 0.72, s * 0.08, s * 0.08)
  love.graphics.pop()
  love.graphics.push()
  love.graphics.translate(cx + s * 0.12, cy - s * 0.02)
  love.graphics.rotate(math.rad(10))
  love.graphics.rectangle("fill", -s * 0.26, -s * 0.36, s * 0.52, s * 0.72, s * 0.08, s * 0.08)
  love.graphics.pop()
end

local ICONES_ABA = { resumo = iconeResumo, avatares = iconeAvatares, emotes = iconeEmotes, cartas = iconeCartas }

-- Ids da grade: os 8 base + os comprados na loja (na ordem do catalogo).
local function listaIds()
  local ids = {}
  for i = 1, BASE_AVATARES do ids[#ids + 1] = tostring(i) end
  for _, id in ipairs(inv.avataresComprados()) do ids[#ids + 1] = id end
  return ids
end

-- Codigos dos emotes NA GRADE: os 4 iniciais (sempre) + os comprados na
-- loja, na ordem do catalogo (comprados 5+ entram depois dos vetoriais).
local function listaEmojis()
  local codigos = {}
  for _, c in ipairs(EMOJIS_BASE) do codigos[#codigos + 1] = c end
  for _, id in ipairs(inv.emojisComprados()) do
    for _, p in ipairs(inv.emojisProdutos()) do
      if p.id == id then codigos[#codigos + 1] = p.codigo end
    end
  end
  return codigos
end

-- Lista equipada saneada: so codigos possuidos, sem repetir, no maximo 4.
local function sanearEmojis(lista)
  if type(lista) ~= "table" then
    return { EMOJIS_BASE[1], EMOJIS_BASE[2], EMOJIS_BASE[3], EMOJIS_BASE[4] }
  end
  local possiveis, visto, saida = {}, {}, {}
  for _, c in ipairs(listaEmojis()) do possiveis[c] = true end
  for _, c in ipairs(lista) do
    c = tonumber(c)
    if c and possiveis[c] and not visto[c] and #saida < EMOJI_MAX then
      visto[c] = true
      saida[#saida + 1] = c
    end
  end
  return saida
end

local function sanearAvatar(id)
  id = tostring(id or "1")
  if not arte.img("avatar_" .. id) then return "1" end
  for _, g in ipairs(listaIds()) do
    if g == id then return id end
  end
  return "1"
end

-- LAYOUT --------------------------------------------------------------------

local function calcularLayout()
  local PW = VW * 0.82
  local PH = VH * 0.86
  local G = PW / 900
  local x0 = (VW - PW) / 2
  local y0 = (VH - PH) / 2
  local padX, padY = PW * 0.03, PW * 0.03
  local inner = PW - padX * 2

  -- titulo (caixa centralizada com diamantes dos dois lados)
  local tamTit, lsTit = PW * 0.034, 2 * G
  local titulo = "PERFIL DO JOGADOR"
  local titleW = ui.larguraTexto(ui.tr(titulo), tamTit, lsTit)
  local tituloBoxW = math.min(inner * 0.5, titleW + PW * 0.22)
  local tituloBoxH = ui.alturaTexto(tamTit) + PW * 0.024
  local tituloBoxX = x0 + (PW - tituloBoxW) / 2
  local tituloBoxY = y0 + padY

  local mtDiv = PW * 0.022
  local divY = tituloBoxY + tituloBoxH + mtDiv
  local divH = 1.5 * G

  -- rodape (botao confirmar), reservado antes do corpo pra sobrar altura certa
  local mtRodape = PW * 0.03
  local tamBtnTxt = PW * 0.026
  local btnPy = PW * 0.02
  local btnH = ui.alturaTexto(tamBtnTxt) + btnPy * 2
  local btnW = inner * 0.24
  local btnX = x0 + (PW - btnW) / 2

  local corpoY = divY + divH + PW * 0.03
  local corpoH = (y0 + PH) - padY - btnH - mtRodape - corpoY
  local btnY = corpoY + corpoH + mtRodape

  -- nav vertical a esquerda: os botoes sao arte pronta (385x190), entao a
  -- LARGURA sai da altura pela proporcao do PNG e os 4 com os vaos fecham
  -- exatamente a altura do corpo (sem esticar/distorcer a arte).
  local navX = x0 + padX
  local navGap = PW * 0.012
  local navItemH = (corpoH - (#ABAS - 1) * navGap) / #ABAS
  local navW = navItemH * ASP_BOTAO
  local navY = corpoY

  -- area de conteudo (direita da nav)
  local gapNav = PW * 0.025
  local contentX = navX + navW + gapNav
  local contentW = (x0 + PW - padX) - contentX
  local contentY = corpoY
  local contentH = corpoH

  -- seta de "voltar para o resumo" (so aparece fora da aba resumo)
  local setaD = btnH
  local setaX = contentX
  local setaY = btnY

  -- tipografia do input de nick (comum as abas RESUMO/AVATARES)
  local tamInput, lsInput, padInput = PW * 0.024, 1 * G, 8 * G

  L = {
    G = G, PW = PW, PH = PH, x0 = x0, y0 = y0, padX = padX, padY = padY, inner = inner,
    titulo = titulo, tamTit = tamTit, lsTit = lsTit, titleW = titleW,
    tituloBoxX = tituloBoxX, tituloBoxY = tituloBoxY, tituloBoxW = tituloBoxW, tituloBoxH = tituloBoxH,
    divY = divY, divH = divH,
    contentX = contentX, contentY = contentY, contentW = contentW, contentH = contentH,
    btnX = btnX, btnY = btnY, btnW = btnW, btnH = btnH, tamBtnTxt = tamBtnTxt,
    setaX = setaX, setaY = setaY, setaD = setaD,
    tamInput = tamInput, lsInput = lsInput, padInput = padInput,
  }

  R = {
    voltar = { x = VW * 0.02, y = VH * 0.035, w = VW * 0.09, h = VW * 0.09 },
    painel = { x = x0, y = y0, w = PW, h = PH },
    confirmar = { x = btnX, y = btnY, w = btnW, h = btnH },
    voltarAba = (st.aba ~= "resumo") and { x = setaX, y = setaY, w = setaD, h = setaD } or nil,
    nav = {},
    itens = {},
    emotesGrid = {},
  }

  for i, aba in ipairs(ABAS) do
    R.nav[i] = {
      aba = aba,
      x = navX, y = navY + (i - 1) * (navItemH + navGap),
      w = navW, h = navItemH,
    }
  end

  if st.aba == "avatares" then
    local colW = contentW * 0.34
    local gapCorpo = contentW * 0.04
    local gx = contentX + colW + gapCorpo
    local gridW = contentW - colW - gapCorpo
    local secLblTam = PW * 0.024
    local secY = contentY
    local gridY = secY + ui.alturaTexto(secLblTam) + PW * 0.03

    -- FICHA do avatar selecionado: faixa na base do conteudo com o nome, a
    -- habilidade e o resumo do teorico (os padroes nao tem habilidade nem
    -- descricao). Reservada ANTES da grade, que sobe para caber em cima.
    local fichaH = PW * 0.125
    local fichaY = contentY + contentH - fichaH
    local mtFicha = PW * 0.012

    -- Grade em AV_COLS colunas; se as linhas nao couberem acima da ficha, o
    -- item encolhe (o vao entre linhas acompanha, 22% do item).
    local ids = listaIds()
    local totalIds = #ids
    local linhas = math.ceil(totalIds / AV_COLS)
    local altGrid = fichaY - mtFicha - gridY
    local itemW = math.min(gridW * 0.145,
      altGrid / (linhas + 0.22 * (linhas - 1)))
    local rowGap = itemW * 0.22
    local colGap = (gridW - itemW * AV_COLS) / (AV_COLS - 1)

    for i = 1, totalIds do
      local col = (i - 1) % AV_COLS
      local linha = math.floor((i - 1) / AV_COLS)
      local itensNaLinha = math.min(AV_COLS, totalIds - linha * AV_COLS)
      local offsetLinha = (AV_COLS - itensNaLinha) * (itemW + colGap) / 2
      R.itens[i] = {
        id = ids[i],
        x = gx + offsetLinha + col * (itemW + colGap),
        y = gridY + linha * (itemW + rowGap),
        w = itemW, h = itemW,
      }
    end

    -- Coluna esquerda: preview + campo do nick (a altura do preview cede o
    -- que for preciso para o campo fechar exatamente na base do conteudo).
    local inputH = PW * 0.07
    local spotH = math.min(colW / 0.95, contentH - inputH - PW * 0.025)
    L.av = { gx = gx, gridW = gridW, secLblTam = secLblTam, secY = secY }
    R.spotlight = { x = contentX, y = contentY, w = colW, h = spotH }
    R.input = { x = contentX, y = contentY + spotH + PW * 0.025, w = colW, h = inputH }
    R.ficha = { x = gx, y = fichaY, w = gridW, h = fichaH }

  elseif st.aba == "emotes" then
    local colW = contentW * 0.24
    local gapCorpo = contentW * 0.04
    local gx = contentX + colW + gapCorpo
    local gridW = contentW - colW - gapCorpo
    local secLblTam = PW * 0.024
    local secY = contentY
    local gridY = secY + ui.alturaTexto(secLblTam) + PW * 0.03
    local itemW = gridW * 0.145
    local colGap = (gridW - itemW * 6) / 5
    local rowGap = PW * 0.02

    local codigos = listaEmojis()
    local total = #codigos
    for i = 1, total do
      local col = (i - 1) % 6
      local linha = math.floor((i - 1) / 6)
      local itensNaLinha = math.min(6, total - linha * 6)
      local offsetLinha = (6 - itensNaLinha) * (itemW + colGap) / 2
      R.emotesGrid[i] = {
        codigo = codigos[i],
        x = gx + offsetLinha + col * (itemW + colGap),
        y = gridY + linha * (itemW + rowGap),
        w = itemW, h = itemW,
      }
    end

    L.em = { gx = gx, gridW = gridW, secLblTam = secLblTam, secY = secY, previewD = colW }

  elseif st.aba == "cartas" then
    local colW = contentW * 0.22
    local gapCorpo = contentW * 0.035
    local gx = contentX + colW + gapCorpo
    local gridW = contentW - colW - gapCorpo
    local secLblTam = PW * 0.024
    local secY = contentY
    local filtroW = gridW * 0.16
    local headerH = ui.alturaTexto(secLblTam) + PW * 0.03
    local deckBlockH = ui.alturaTexto(secLblTam) + PW * 0.05
    local gridY = secY + headerH
    local gridH = contentH - headerH - deckBlockH - PW * 0.02

    L.ca = {
      colW = colW, gx = gx, gridW = gridW, secLblTam = secLblTam, secY = secY,
      filtroW = filtroW, gridY = gridY, gridH = gridH,
    }

  else -- resumo
    local colW = contentW * 0.26
    local spotH = colW / 0.95
    L.re = { colW = colW, gap = contentW * 0.045 }
    R.spotlight = { x = contentX, y = contentY, w = colW, h = spotH }
    R.input = { x = contentX, y = contentY + spotH + PW * 0.025, w = colW, h = PW * 0.07 }
  end
end

-- PERFIL SALVO (perfilStorage.js: JSON em storage; aqui 3 linhas em disco:
-- nick, avatar e emojis equipados por virgula — a 3a e opcional p/ save antigo)

function P.carregar()
  local padrao = { nick = "JOGADOR_1", avatar = "1", emojis = sanearEmojis(nil) }
  if MODO_TESTE then return padrao end
  local ok, dados = pcall(love.filesystem.read, ARQ)
  if not ok or not dados then return padrao end
  local l1, l2, l3 = dados:match("([^\n]*)\n([^\n]*)\n?(.*)")
  local nick = (l1 and l1 ~= "") and l1 or "JOGADOR_1"
  local av = (l2 and l2 ~= "") and l2 or "1"
  local emojis
  if l3 and l3 ~= "" then
    emojis = {}
    for n in l3:gmatch("%d+") do emojis[#emojis + 1] = tonumber(n) end
  end
  return { nick = nick, avatar = sanearAvatar(av), emojis = sanearEmojis(emojis) }
end

function P.salvar(perfil)
  if MODO_TESTE then return true end
  local emojis = type(perfil.emojis) == "table" and perfil.emojis or {}
  local codigos = {}
  for _, c in ipairs(emojis) do codigos[#codigos + 1] = tostring(c) end
  local dados = (perfil.nick or "JOGADOR_1") .. "\n"
    .. tostring(perfil.avatar or "1") .. "\n" .. table.concat(codigos, ",")
  local ok = pcall(love.filesystem.write, ARQ, dados)
  return ok
end

-- ESTADO / ACOES -----------------------------------------------------------

function P.iniciar(perfil)
  perfil = perfil or {}
  local nick = perfil.nick or "JOGADOR_1"
  if nick == "" then nick = "JOGADOR_1" end
  local emojis = sanearEmojis(perfil.emojis)
  st = {
    nick = nick,
    avatarId = sanearAvatar(perfil.avatar),
    emojis = emojis,
    emoteFoco = emojis[1] or EMOJIS_BASE[1],
    emoteInicio = 0,
    aba = "resumo",
    t = 0,
    editou = false,
  }
  calcularLayout()
end

function P.estado()
  if not st then P.iniciar() end
  return { nick = st.nick, avatarId = st.avatarId }
end

function P.abaAtual()
  if not st then P.iniciar() end
  return st.aba
end

function P.mudarAba(aba)
  if not st then P.iniciar() end
  if ABA_LABEL[aba] and st.aba ~= aba then
    st.aba = aba
    calcularLayout()
  end
end

-- Copia da lista equipada (imutavel por fora).
function P.emojis()
  if not st then P.iniciar() end
  local saida = {}
  for _, c in ipairs(st.emojis) do saida[#saida + 1] = c end
  return saida
end

function P.equipado(codigo)
  if not st then P.iniciar() end
  codigo = tonumber(codigo)
  if not codigo then return false end
  for _, c in ipairs(st.emojis) do
    if c == codigo then return true end
  end
  return false
end

-- Alterna o emote da grade entre equipado e guardado; no maximo EMOJI_MAX
-- equipados (grade cheia nao faz nada — desequipa um antes de equipar outro).
function P.alternarEmoji(codigo)
  if not st then P.iniciar() end
  codigo = tonumber(codigo)
  if not codigo then return false end
  local tem = false
  for _, c in ipairs(listaEmojis()) do
    if c == codigo then tem = true break end
  end
  if not tem then return false end
  for i, c in ipairs(st.emojis) do
    if c == codigo then
      table.remove(st.emojis, i)
      return true
    end
  end
  if #st.emojis >= EMOJI_MAX then return false end
  st.emojis[#st.emojis + 1] = codigo
  return true
end

-- Foco da demonstracao (aba EMOTES): troca o emote em destaque e reinicia a
-- animacao do primeiro quadro — clicar de novo no mesmo emote tambem
-- reinicia (o toque funciona como "toca outra vez").
function P.focarEmoji(codigo)
  if not st then P.iniciar() end
  codigo = tonumber(codigo)
  if not codigo then return false end
  local tem = false
  for _, c in ipairs(listaEmojis()) do
    if c == codigo then tem = true break end
  end
  if not tem then return false end
  st.emoteFoco = codigo
  st.emoteInicio = st.t
  return true
end

-- Quadro atual da animacao do emote em foco (aba EMOTES). Emoji vetorial
-- (1..4) nao tem animacao: devolve nil e o desenho cai no rosto fixo. Nos
-- sprites da loja a animacao REPETE enquanto o emoji fica selecionado
-- (uma volta a cada arte.emojiSpriteDur, hoje 1,5s).
function P.quadroEmote()
  if not st then P.iniciar() end
  local foco = st.emoteFoco or st.emojis[1] or EMOJIS_BASE[1]
  local prod = foco >= 5 and inv.emojiPorCodigo(foco)
  if not prod then return nil end
  local nq = arte.emojiSpriteTotal(prod.id)
  if nq <= 0 then return nil end
  local dur = arte.emojiSpriteDur()
  local volta = (st.t - (st.emoteInicio or 0)) % dur
  return 1 + math.floor(volta / dur * nq)
end

function P.selecionado()
  if not st then P.iniciar() end
  return st.avatarId
end

function P.selecionar(id)
  if not st then P.iniciar() end
  st.avatarId = sanearAvatar(id)
end

function P.definirNick(txt)
  if not st then P.iniciar() end
  st.nick = contarAte(tostring(txt or ""), NICK_MAX)
end

-- Preserva maiusculas/minusculas (pedido do usuario; maxLength=20).
function P.digitar(txt)
  if not st or not txt or txt == "" then return end
  st.nick = contarAte(st.nick .. txt, NICK_MAX)
  st.editou = true
end

function P.apagar()
  if not st then return end
  local antes = st.nick
  st.nick = apagarUtf8(st.nick)
  if st.nick ~= antes then st.editou = true end
end

function P.confirmar()
  if not st then P.iniciar() end
  local nick = st.nick
  if nick == "" then nick = "JOGADOR_1" end
  local emojis = {}
  for _, c in ipairs(st.emojis) do emojis[#emojis + 1] = c end
  return { nick = nick, avatar = st.avatarId, emojis = emojis }
end

function P.clicado(vx, vy)
  if not st then P.iniciar() end
  if dentro(vx, vy, R.voltar) then return "voltar" end

  for _, item in ipairs(R.nav) do
    if dentro(vx, vy, item) then
      P.mudarAba(item.aba)
      return nil
    end
  end

  if R.voltarAba and dentro(vx, vy, R.voltarAba) then
    P.mudarAba("resumo")
    return nil
  end

  if st.aba == "avatares" then
    for i = 1, #R.itens do
      if dentro(vx, vy, R.itens[i]) then
        P.selecionar(R.itens[i].id)
        return nil
      end
    end
  elseif st.aba == "emotes" then
    for i = 1, #R.emotesGrid do
      if dentro(vx, vy, R.emotesGrid[i]) then
        P.focarEmoji(R.emotesGrid[i].codigo)
        P.alternarEmoji(R.emotesGrid[i].codigo)
        return nil
      end
    end
  end

  if dentro(vx, vy, R.confirmar) then return "confirmar" end
end

function P.rectVoltar() return R.voltar end
function P.rectConfirmar() return R.confirmar end
function P.rectAvatar(i) return R.itens[i] end
function P.rectEmoji(i) return R.emotesGrid[i] end

-- Retangulo do botao da nav de uma aba (pelo nome) e da seta que volta ao
-- resumo (existe nas abas diferentes de RESUMO) — usados pelo smoke/testes.
function P.rectAba(aba)
  for _, item in ipairs(R.nav) do
    if item.aba == aba then return item end
  end
end

function P.rectVoltarAba() return R.voltarAba end
function P.rectFicha() return R.ficha end

-- Texto da FICHA do avatar selecionado (aba AVATARES): nome, habilidade e
-- descricao vem da mesma tabela que a loja usa (ui.infoAvatar). Avatar
-- padrao nao tem habilidade nem descricao — a ficha so mostra o nome.
function P.fichaInfo()
  if not st then P.iniciar() end
  local info = ui.infoAvatar(st.avatarId)
  if not info then return { nome = "AVATAR PADRAO", hab = nil, desc = nil } end
  return { nome = info.nome, hab = info.hab, desc = info.teorico }
end

function P.atualizar(dt)
  if st then st.t = st.t + dt end
end

-- DESENHO ------------------------------------------------------------------

local function desenharInput()
  local r = R.input
  retInterno(r.x, r.y, r.w, r.h, 4 * L.G, 2 * L.G, COR_INPUT, GOLD)
  local tam, ls = L.tamInput, L.lsInput
  local padX = L.padInput
  local avail = r.w - padX * 2
  local largTotal = ui.larguraTexto(st.nick, tam, ls)
  local off = 0
  if st.editou then
    off = math.max(0, largTotal + 4 - (avail - 3))
  end
  local x1, y1 = love.graphics.transformPoint(r.x + padX - 2, r.y + 1)
  local x2, y2 = love.graphics.transformPoint(r.x + r.w - padX + 2, r.y + r.h - 1)
  love.graphics.setScissor(x1, y1, x2 - x1, y2 - y1)
  local altTxt = ui.alturaTexto(tam)
  ui.txtEspacado(st.nick, r.x + padX - off, r.y + (r.h - altTxt) / 2, tam, BRANCO, ls)
  if st.editou and math.floor(st.t * 2) % 2 == 0 then
    local cx = math.min(r.x + padX + largTotal - off + 2, r.x + r.w - padX - 3)
    love.graphics.setColor(BRANCO[1], BRANCO[2], BRANCO[3], 1)
    love.graphics.rectangle("fill", cx, r.y + r.h * 0.16, 3, r.h * 0.68)
  end
  love.graphics.setScissor()
end

-- Quebra manual de texto em linhas (ui nao garante um helper com wrap).
local function textoQuebrado(txt, x, y, maxW, tam, cor)
  local lh = ui.alturaTexto(tam) * 1.3
  local linhas, atual = {}, ""
  for palavra in txt:gmatch("%S+") do
    local teste = atual == "" and palavra or (atual .. " " .. palavra)
    if atual == "" or ui.larguraTexto(teste, tam) <= maxW then
      atual = teste
    else
      linhas[#linhas + 1] = atual
      atual = palavra
    end
  end
  if atual ~= "" then linhas[#linhas + 1] = atual end
  for i, linha in ipairs(linhas) do
    ui.txtEspacado(linha, x, y + (i - 1) * lh, tam, cor)
  end
  return y + #linhas * lh
end

-- Cabecalho de secao reutilizavel: diamante + rotulo + (opcional) texto a
-- direita (ex.: "EQUIPADOS 4/4") + linha divisoria. Devolve o Y onde o
-- conteudo da secao pode comecar.
local function cabecalhoSecao(x, y, w, titulo, tam, extra)
  local G = L.G
  local d = tam * 0.3
  local cy = y + ui.alturaTexto(tam) / 2
  ui.pintar(GOLD_LIGHT)
  diamante(x + d / 2, cy, d)
  ui.txtEspacado(titulo, x + d + 6 * G, y, tam, GOLD_LIGHT)
  if extra then
    local etam = extra.tam or tam * 0.85
    local ew = ui.larguraTexto(ui.tr(extra.texto), etam)
    ui.txtEspacado(extra.texto, x + w - ew, cy - ui.alturaTexto(etam) / 2, etam, extra.cor or GOLD_LIGHT)
  end
  local divY = y + ui.alturaTexto(tam) + 4 * G
  ui.pintar(GOLD)
  love.graphics.rectangle("fill", x, divY, w, 1.5 * G)
  return divY + 5 * G
end

local function desenharCaixaAvatar(r, id, selecionado)
  local lw = (selecionado and 3 or 2) * L.G
  local raio = 4 * L.G
  if selecionado then
    for _, c in ipairs({ { 4 * L.G, 0.5 }, { 9 * L.G, 0.25 } }) do
      love.graphics.setColor(VERDE[1], VERDE[2], VERDE[3], c[2])
      love.graphics.rectangle("fill", r.x - c[1], r.y - c[1],
        r.w + c[1] * 2, r.h + c[1] * 2, raio + c[1], raio + c[1], 8)
    end
  end
  retInterno(r.x, r.y, r.w, r.h, raio, lw,
    COR_ITEM, selecionado and VERDE or COR_ITEM_BORDA,
    selecionado and { VERDE[1], VERDE[2], VERDE[3], 0.12 } or nil)
  local av = arte.img("avatar_" .. id)
  if av then
    local inset = lw + 1
    local ix, iy = r.x + inset, r.y + inset
    local iw, ih = r.w - inset * 2, r.h - inset * 2
    love.graphics.stencil(function()
      ui.pintar({ 1, 1, 1 })
      love.graphics.rectangle("fill", ix, iy, iw, ih,
        math.max(1, raio - inset), math.max(1, raio - inset), 8)
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)
    ui.imagemCover(av, ix, iy, iw, ih)
    love.graphics.setStencilTest()
  end
end

local function desenharCaixaEmote(r, codigo, equipado)
  local lw = (equipado and 3 or 2) * L.G
  local raio = 4 * L.G
  if equipado then
    for _, c in ipairs({ { 3 * L.G, 0.45 }, { 7 * L.G, 0.22 } }) do
      love.graphics.setColor(VERDE[1], VERDE[2], VERDE[3], c[2])
      love.graphics.rectangle("fill", r.x - c[1], r.y - c[1],
        r.w + c[1] * 2, r.h + c[1] * 2, raio + c[1], raio + c[1], 8)
    end
  end
  retInterno(r.x, r.y, r.w, r.h, raio, lw,
    COR_ITEM, equipado and VERDE or COR_ITEM_BORDA,
    equipado and { VERDE[1], VERDE[2], VERDE[3], 0.1 } or nil)
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  ui.emoji(codigo, cx, cy, math.min(r.w, r.h) * 0.36, 1)
end

local function desenharNav()
  for _, item in ipairs(R.nav) do
    local ativo = st.aba == item.aba
    local img = arte.img("btn_perfil_" .. item.aba .. (ativo and "_sel" or ""))
    if img then
      -- Arte pronta do botao: ja traz moldura, icone e rotulo (a versao
      -- verde e a da aba ativa). O retangulo tem a proporcao do PNG, entao
      -- a arte preenche exato, sem sobra nem corte.
      ui.imagemContain(img, item.x, item.y, item.w, item.h)
    else
      -- Reserva: sem a arte, desenha o botao na mao para a tela seguir util.
      local lw = (ativo and 3 or 2) * L.G
      local raio = 3 * L.G
      if ativo then
        for _, c in ipairs({ { 3 * L.G, 0.4 }, { 7 * L.G, 0.2 } }) do
          love.graphics.setColor(VERDE[1], VERDE[2], VERDE[3], c[2])
          love.graphics.rectangle("fill", item.x - c[1], item.y - c[1],
            item.w + c[1] * 2, item.h + c[1] * 2, raio + c[1], raio + c[1], 8)
        end
      end
      retInterno(item.x, item.y, item.w, item.h, raio, lw,
        COR_NAV, ativo and VERDE or COR_NAV_BORDA,
        ativo and { VERDE[1], VERDE[2], VERDE[3], 0.12 } or nil)
      local iconeFn = ICONES_ABA[item.aba]
      iconeFn(item.x + item.h * 0.5, item.y + item.h / 2, item.h * 0.4,
        ativo and VERDE or BRANCO)
      local tamLbl = L.PW * 0.021
      ui.txtEspacado(ABA_LABEL[item.aba], item.x + item.h * 1.05,
        item.y + (item.h - ui.alturaTexto(tamLbl)) / 2, tamLbl,
        ativo and VERDE or BRANCO, 1 * L.G)
    end
  end
end

local function desenharResumo()
  local rs = R.spotlight
  love.graphics.setColor(GOLD_LIGHT[1], GOLD_LIGHT[2], GOLD_LIGHT[3], 0.14)
  love.graphics.rectangle("fill", rs.x - 6 * L.G, rs.y - 6 * L.G,
    rs.w + 12 * L.G, rs.h + 12 * L.G, 4 * L.G, 4 * L.G, 8)
  retInterno(rs.x, rs.y, rs.w, rs.h, 4 * L.G, 3 * L.G, COR_SPOT, GOLD)
  cantos(rs.x, rs.y, rs.w, rs.h, GOLD)
  local av = arte.img("avatar_" .. st.avatarId)
  if av then
    ui.imagemContain(av, rs.x + rs.w * 0.03, rs.y + rs.h * 0.03, rs.w * 0.94, rs.h * 0.94)
  end
  desenharInput()

  local rx = L.contentX + L.re.colW + L.re.gap
  local rw = L.contentW - L.re.colW - L.re.gap
  local pad = L.PW * 0.022
  local boxGap = L.PW * 0.025
  local boxH = (L.contentH - boxGap) * 0.4
  local box1Y = L.contentY
  local box2Y = box1Y + boxH + boxGap
  local box2H = L.contentH - boxH - boxGap

  -- EMOTES SELECIONADOS
  retInterno(rx, box1Y, rw, boxH, 4 * L.G, 2 * L.G, COR_SPOT, GOLD)
  local cy1 = cabecalhoSecao(rx + pad, box1Y + pad, rw - pad * 2, "EMOTES SELECIONADOS", L.PW * 0.025)
  local gap1 = L.PW * 0.015
  local itemD = math.min((rw - pad * 2 - (EMOJI_MAX - 1) * gap1) / EMOJI_MAX, box1Y + boxH - pad - cy1)
  for i, codigo in ipairs(st.emojis) do
    local ix = rx + pad + (i - 1) * (itemD + gap1)
    desenharCaixaEmote({ x = ix, y = cy1, w = itemD, h = itemD }, codigo, true)
  end

  -- CARTAS SELECIONADAS (vazio por enquanto — sem sistema de cartas ainda)
  retInterno(rx, box2Y, rw, box2H, 4 * L.G, 2 * L.G, COR_SPOT, GOLD)
  local cy2 = cabecalhoSecao(rx + pad, box2Y + pad, rw - pad * 2, "CARTAS SELECIONADAS", L.PW * 0.025)
  local gap2 = L.PW * 0.012
  local slotW = (rw - pad * 2 - (DECK_MAX - 1) * gap2) / DECK_MAX
  local slotH = math.min(slotW * 1.4, box2Y + box2H - pad - cy2)
  for i = 1, DECK_MAX do
    local ix = rx + pad + (i - 1) * (slotW + gap2)
    love.graphics.setLineWidth(1.5 * L.G)
    ui.pintar(COR_ITEM_BORDA)
    love.graphics.rectangle("line", ix, cy2, slotW, slotH, 3 * L.G, 3 * L.G, 6)
    love.graphics.setLineWidth(1)
  end
end

-- FICHA do avatar selecionado (aba AVATARES): faixa com o nome, a habilidade
-- e o resumo do teorico. Avatar padrao nao tem habilidade nem descricao: a
-- ficha diz isso (em cinza) em vez de inventar texto.
local function desenharFicha()
  local r = R.ficha
  if not r then return end
  local pad = L.PW * 0.011
  retInterno(r.x, r.y, r.w, r.h, 3 * L.G, 2 * L.G, COR_ITEM, COR_ITEM_BORDA)
  local info = P.fichaInfo()
  local largInt = r.w - pad * 2
  local x, y = r.x + pad, r.y + pad
  local tamNome = L.PW * 0.021
  ui.txtEspacado(info.nome, x, y, tamNome, GOLD_LIGHT, 1 * L.G)
  y = y + ui.alturaTexto(tamNome) + L.PW * 0.004
  if info.hab and info.desc then
    y = textoQuebrado("HABILIDADE: " .. info.hab, x, y, largInt, L.PW * 0.017, VERDE)
    textoQuebrado(info.desc, x, y + L.PW * 0.004, largInt, L.PW * 0.015, BRANCO)
  else
    textoQuebrado("SEM HABILIDADE ESPECIAL", x, y, largInt, L.PW * 0.017, CINZA)
  end
end

local function desenharAvatares()
  local rs = R.spotlight
  love.graphics.setColor(GOLD_LIGHT[1], GOLD_LIGHT[2], GOLD_LIGHT[3], 0.14)
  love.graphics.rectangle("fill", rs.x - 6 * L.G, rs.y - 6 * L.G,
    rs.w + 12 * L.G, rs.h + 12 * L.G, 4 * L.G, 4 * L.G, 8)
  retInterno(rs.x, rs.y, rs.w, rs.h, 4 * L.G, 3 * L.G, COR_SPOT, GOLD)
  cantos(rs.x, rs.y, rs.w, rs.h, GOLD)
  local av = arte.img("avatar_" .. st.avatarId)
  if av then
    ui.imagemContain(av, rs.x + rs.w * 0.03, rs.y + rs.h * 0.03, rs.w * 0.94, rs.h * 0.94)
  end
  desenharInput()

  cabecalhoSecao(L.av.gx, L.av.secY, L.av.gridW, "TODOS OS AVATARES", L.av.secLblTam)
  for i = 1, #R.itens do
    local r = R.itens[i]
    desenharCaixaAvatar(r, r.id, st.avatarId == r.id)
  end
  desenharFicha()
end

local function desenharEmotes()
  local em = L.em
  local px, py, pd = L.contentX, L.contentY, em.previewD
  retInterno(px, py, pd, pd, 4 * L.G, 3 * L.G, COR_SPOT, GOLD)
  cantos(px, py, pd, pd, GOLD)
  local foco = st.emoteFoco or st.emojis[1] or EMOJIS_BASE[1]
  -- Demonstracao: emoji de sprite (5+) toca a animacao quadro a quadro
  -- enquanto fica selecionado (quadro vem do P.quadroEmote); os vetoriais
  -- (1..4) sao desenho fixo. A caixa 0,64*pd e a MESMA do rosto (r = 0,32*pd).
  local quadro = P.quadroEmote()
  local prodSpr = foco >= 5 and inv.emojiPorCodigo(foco)
  local imgSpr = prodSpr and quadro and arte.emojiSprite(prodSpr.id, quadro)
  if imgSpr then
    ui.imagemContain(imgSpr, px + pd * 0.18, py + pd * 0.18, pd * 0.64, pd * 0.64)
  else
    ui.emoji(foco, px + pd / 2, py + pd / 2, pd * 0.32, 1)
  end

  local info = EMOTE_INFO_BASE[foco]
  if not info then
    for _, p in ipairs(inv.emojisProdutos()) do
      if p.codigo == foco then info = { nome = p.nome or "EMOTE", desc = p.descricao or "" } end
    end
  end
  info = info or { nome = "EMOTE", desc = "" }

  local tamNome = L.PW * 0.026
  local nameY = py + pd + L.PW * 0.02
  ui.txtEspacado(info.nome, px, nameY, tamNome, GOLD_LIGHT, 1 * L.G)

  if info.desc ~= "" then
    local descY = nameY + ui.alturaTexto(tamNome) + L.PW * 0.015
    local descH = (L.contentY + L.contentH) - descY
    if descH > L.PW * 0.05 then
      retInterno(px, descY, pd, descH, 3 * L.G, 2 * L.G, COR_ITEM, COR_ITEM_BORDA)
      local padD = L.PW * 0.015
      textoQuebrado(info.desc, px + padD, descY + padD, pd - padD * 2, L.PW * 0.019, BRANCO)
    end
  end

  local numEq = #st.emojis
  cabecalhoSecao(em.gx, em.secY, em.gridW, "TODOS OS EMOTES", em.secLblTam,
    { texto = ui.tr("EQUIPADOS") .. " " .. numEq .. "/" .. EMOJI_MAX, tam = em.secLblTam * 0.85,
      cor = numEq >= EMOJI_MAX and VERDE or GOLD_LIGHT })
  for i = 1, #R.emotesGrid do
    local r = R.emotesGrid[i]
    desenharCaixaEmote(r, r.codigo, P.equipado(r.codigo))
  end
end

local function desenharCartas()
  local ca = L.ca
  local px, py, pd, pdH = L.contentX, L.contentY, ca.colW, L.contentH
  retInterno(px, py, pd, pdH, 4 * L.G, 2 * L.G, COR_ITEM, COR_ITEM_BORDA)
  local tam = L.PW * 0.022
  local lh = ui.alturaTexto(tam) * 1.3
  local blocoY = py + pdH / 2 - lh
  local l1, l2 = ui.tr("SELECIONE"), ui.tr("UMA CARTA")
  local w1 = ui.larguraTexto(l1, tam)
  local w2 = ui.larguraTexto(l2, tam)
  ui.txtEspacado(l1, px + (pd - w1) / 2, blocoY, tam, COR_ITEM_BORDA)
  ui.txtEspacado(l2, px + (pd - w2) / 2, blocoY + lh, tam, COR_ITEM_BORDA)

  cabecalhoSecao(ca.gx, ca.secY, ca.gridW, "TODAS AS CARTAS", ca.secLblTam)
  local filtroH = ui.alturaTexto(ca.secLblTam)
  local fx = ca.gx + ca.gridW - ca.filtroW
  retInterno(fx, ca.secY, ca.filtroW, filtroH, 2 * L.G, 1.5 * L.G, COR_ITEM, COR_ITEM_BORDA)
  ui.txtEspacado("TODAS", fx + L.PW * 0.01, ca.secY, ca.secLblTam * 0.8, GOLD_LIGHT)

  -- grade vazia (designer apenas — sistema de cartas ainda nao existe)
  retInterno(ca.gx, ca.gridY, ca.gridW, ca.gridH, 3 * L.G, 2 * L.G, COR_ITEM, COR_ITEM_BORDA)
  local msg2 = ui.tr("CARTAS EM BREVE")
  local tam2 = L.PW * 0.026
  local mw2 = ui.larguraTexto(msg2, tam2)
  ui.txtEspacado(msg2, ca.gx + (ca.gridW - mw2) / 2,
    ca.gridY + ca.gridH / 2 - ui.alturaTexto(tam2) / 2, tam2, COR_ITEM_BORDA)

  local deckY = ca.gridY + ca.gridH + L.PW * 0.025
  local deckContentY = cabecalhoSecao(ca.gx, deckY, ca.gridW,
    ui.tr("DECK ATUAL") .. " 0/" .. DECK_MAX, ca.secLblTam)
  ui.txtEspacado("Nenhuma carta no deck ainda.", ca.gx, deckContentY, ca.secLblTam * 0.8, COR_ITEM_BORDA)
end

function P.desenhar(hover)
  if not st then P.iniciar() end
  calcularLayout()
  hover = hover or { x = -999, y = -999 }

  local bg = arte.img("perfil_fundo")
  if bg then
    ui.imagemCover(bg, ui.retTelaCheia(VW, VH))
  else
    ui.pintar(BG_FUNDO)
    ui.preencherTela(VW, VH)
  end
  love.graphics.setColor(0, 0, 0, 0.35)
  ui.preencherTela(VW, VH)

  local rv = R.voltar
  local imgVoltar = arte.img("sel_voltar")
  if imgVoltar then
    local iw, ih = rv.w * 0.5, rv.h * 0.5
    ui.imagemContain(imgVoltar, rv.x + (rv.w - iw) / 2, rv.y + (rv.h - ih) / 2, iw, ih)
  end

  local rp = R.painel

  -- sombra do painel
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", rp.x, rp.y + 8 * L.G, rp.w, rp.h, 6 * L.G, 6 * L.G, 8)
  love.graphics.setColor(0, 0, 0, 0.25)
  love.graphics.rectangle("fill", rp.x - 5 * L.G, rp.y - 5 * L.G,
    rp.w + 10 * L.G, rp.h + 18 * L.G, 10 * L.G, 10 * L.G, 8)

  retInterno(rp.x, rp.y, rp.w, rp.h, 6 * L.G, 3 * L.G, BG_PAINEL, GOLD)
  cantos(rp.x, rp.y, rp.w, rp.h, GOLD_LIGHT)

  -- titulo: caixa fina com "◆◆ PERFIL DO JOGADOR ◆◆"
  retInterno(L.tituloBoxX, L.tituloBoxY, L.tituloBoxW, L.tituloBoxH, 3 * L.G, 2 * L.G, nil, GOLD)
  local cyTit = L.tituloBoxY + L.tituloBoxH / 2
  local dTit = L.tamTit * 0.3
  local gapTit = 8 * L.G
  local tx = L.tituloBoxX + (L.tituloBoxW - L.titleW) / 2
  ui.pintar(GOLD_LIGHT)
  diamante(tx - gapTit - dTit * 1.6, cyTit, dTit)
  diamante(tx - gapTit - dTit * 0.3, cyTit, dTit)
  diamante(tx + L.titleW + gapTit + dTit * 0.3, cyTit, dTit)
  diamante(tx + L.titleW + gapTit + dTit * 1.6, cyTit, dTit)
  local sombra = { 0, 0, 0, 0.9 }
  ui.txtEspacado(L.titulo, tx + 2 * L.G, cyTit - ui.alturaTexto(L.tamTit) / 2 + 2 * L.G,
    L.tamTit, sombra, L.lsTit, L.titleW)
  ui.txtEspacado(L.titulo, tx, cyTit - ui.alturaTexto(L.tamTit) / 2, L.tamTit, BRANCO, L.lsTit, L.titleW)

  -- divisor
  ui.pintar(GOLD)
  love.graphics.rectangle("fill", L.x0 + L.padX, L.divY, L.inner, L.divH)

  desenharNav()

  if st.aba == "resumo" then
    desenharResumo()
  elseif st.aba == "avatares" then
    desenharAvatares()
  elseif st.aba == "emotes" then
    desenharEmotes()
  elseif st.aba == "cartas" then
    desenharCartas()
  end

  -- seta "voltar para o resumo" (so fora da aba resumo)
  if R.voltarAba then
    local rv2 = R.voltarAba
    retInterno(rv2.x, rv2.y, rv2.w, rv2.h, 3 * L.G, 2 * L.G, COR_ITEM, COR_ITEM_BORDA)
    love.graphics.setColor(BRANCO[1], BRANCO[2], BRANCO[3], 1)
    love.graphics.setLineWidth(2 * L.G)
    local cx, cy = rv2.x + rv2.w / 2, rv2.y + rv2.h / 2
    love.graphics.line(cx + rv2.w * 0.15, cy - rv2.h * 0.2, cx - rv2.w * 0.15, cy, cx + rv2.w * 0.15, cy + rv2.h * 0.2)
    love.graphics.setLineWidth(1)
  end

  -- botao CONFIRMAR
  local rb = R.confirmar
  love.graphics.setColor(VERDE[1], VERDE[2], VERDE[3], 0.4)
  love.graphics.rectangle("fill", rb.x - 6 * L.G, rb.y - 6 * L.G,
    rb.w + 12 * L.G, rb.h + 12 * L.G, 6 * L.G, 6 * L.G, 8)
  retInterno(rb.x, rb.y, rb.w, rb.h, 6 * L.G, 3 * L.G, VERDE_ESCURO, VERDE)
  local cyBtn = rb.y + rb.h / 2
  local tamCheck = rb.h * 0.5
  check(rb.x + rb.h * 0.3, cyBtn, tamCheck, VERDE)
  local lbl = "CONFIRMAR"
  ui.txtEspacado(lbl, rb.x + rb.h * 0.3 + tamCheck * 0.7,
    cyBtn - ui.alturaTexto(L.tamBtnTxt) / 2, L.tamBtnTxt, BRANCO, 1 * L.G)
end

return P