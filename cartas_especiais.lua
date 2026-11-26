-- cartas_especiais.lua
-- Animacoes especiais das cartas Curinga.
--
-- Cartas "de impacto" (Monstro Inflacao, Efeito Hawthorne, Flutuacao do
-- Mercado, Rotatividade de Mercado e Seletividade de Taylor): a arte da carta
-- salta para a frente, no centro da tela, por 3 segundos, cada uma com o seu
-- som.
--
-- Probabilidade Mortal: a carta anda loucamente pela tela por 4 segundos com
-- som de tensao e, no fim, avanca sobre o jogador sorteado (som de susto).
--
-- O modulo so cuida da parte visual/sonora: quem chama e o main, no funil do
-- zoom de resultado (novoResultadoLote), entao a animacao vale para o jogador
-- local, para a IA e para as partidas em rede. As regras continuam intactas.

local ui = require "ui"
local som = require "som"
local arte = require "arte"

local M = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"

M.DURACAO_IMPACTO = 3.0
-- Probabilidade Mortal: 4s andando + 0.45s de avanco + 0.45s de impacto.
M.DURACAO_CAOS = 4.0
M.DURACAO_CAOS_TOTAL = 4.9

-- id -> definicao.
--   arte = PNG SEM o template da carta (arte/cards/curinga/anim), otimizado
--   para 768x768 a partir das artes originais em arte/cards/curinga.
--   cor  = cor do halo/raios de cada animacao.
M.DEFS = {
  [6]  = { tipo = "impacto", som = "uau",       somFinal = nil,
           arte = "arte/cards/curinga/anim/monstro_inflacao.png",
           cor = { 1.00, 0.55, 0.15 } },
  [26] = { tipo = "impacto", som = "terror",    somFinal = nil,
           arte = "arte/cards/curinga/anim/efeito_hawthorne.png",
           cor = { 0.72, 0.38, 0.98 } },
  [19] = { tipo = "impacto", som = "engracado", somFinal = nil,
           arte = "arte/cards/curinga/anim/flutuacao_mercado.png",
           cor = { 0.28, 0.78, 1.00 } },
  [50] = { tipo = "impacto", som = "engracado", somFinal = nil,
           arte = "arte/cards/curinga/anim/rotatividade_mercado.png",
           cor = { 1.00, 0.82, 0.30 } },
  [18] = { tipo = "impacto", som = "risada",    somFinal = nil,
           arte = "arte/cards/curinga/anim/seletividade_taylor.png",
           cor = { 0.82, 0.48, 1.00 } },
  [51] = { tipo = "caos",    som = "tensao",    somFinal = "susto",
           arte = "arte/cards/curinga/anim/probabilidade_mortal.png",
           cor = { 1.00, 0.22, 0.20 } },
}

-- Nomes usados apenas pelo gatilho de captura (JOGO_CURINGA) e por depuracao.
M.NOMES = {
  [6] = "O Monstro Inflacao",
  [18] = "Seletividade de Taylor",
  [19] = "Flutuacao do Mercado",
  [26] = "Efeito Hawthorne",
  [50] = "Rotatividade de Mercado",
  [51] = "Probabilidade Mortal",
}

local ativo = nil
local cache = {}

-- Carrega a arte sem template sob demanda. O cache mantem no maximo as 6
-- artes quadradas (768x768, ~2 MB cada na VRAM), o que e barato no celular.
local function imagem(caminho)
  if not caminho then return nil end
  if cache[caminho] then return cache[caminho] end
  if MODO_TESTE then return nil end
  local ok, img = pcall(love.graphics.newImage, caminho)
  if not ok or not img then return nil end
  img:setFilter("linear", "linear")
  cache[caminho] = img
  return img
end

local function clamp01(k)
  if k < 0 then return 0 end
  if k > 1 then return 1 end
  return k
end

local function easeOut(k)
  k = clamp01(k)
  return 1 - (1 - k) ^ 3
end

function M.def(carta)
  return carta and M.DEFS[carta.id] or nil
end

function M.nomeDoId(id)
  return M.NOMES[tonumber(id) or 0]
end

function M.ativo()
  return ativo ~= nil
end

function M.limpar()
  ativo = nil
end

-- Inicia a animacao da carta (se ela tiver uma). Devolve a duracao em
-- segundos (0 quando a carta nao tem animacao ou ja existe uma tocando).
-- opts.alvoX/alvoY: centro do assento da vitima (Probabilidade Mortal).
function M.iniciar(carta, opts)
  if not carta then return 0 end
  local def = M.DEFS[carta.id]
  if not def then return 0 end
  -- Uma animacao por vez: o resultado de uma leva nunca empilha dois zooms.
  if ativo then return 0 end

  opts = opts or {}
  local img = def.arte and imagem(def.arte) or arte.arte(carta)
  local dur = (def.tipo == "caos") and M.DURACAO_CAOS_TOTAL or M.DURACAO_IMPACTO

  -- Faiscas deterministicas por carta (mesmo visual a cada partida).
  local particulas = {}
  if def.tipo == "impacto" then
    local rnd = love.math.newRandomGenerator((tonumber(carta.id) or 1) * 7919 + 13)
    for i = 1, 26 do
      particulas[i] = {
        ang = rnd:random() * math.pi * 2,
        dist = 0.16 + rnd:random() * 0.58,
        vel = 0.10 + rnd:random() * 0.34,
        tam = 2 + rnd:random() * 4,
        fase = rnd:random() * math.pi * 2,
      }
    end
  end

  ativo = {
    def = def,
    carta = carta,
    img = img,
    tipo = def.tipo,
    t = 0,
    dur = dur,
    fase = (tonumber(carta.uidNum) or tonumber(carta.id) or 1) * 1.37,
    alvoX = opts.alvoX,
    alvoY = opts.alvoY,
    particulas = particulas,
    rastro = {},
    ultimoRastro = 0,
    somFinalTocado = false,
  }
  som.tocar(def.som)
  return dur
end

function M.atualizar(dt)
  local a = ativo
  if not a then return end
  a.t = a.t + dt

  if a.tipo == "caos" then
    if a.t < M.DURACAO_CAOS then
      a.ultimoRastro = a.ultimoRastro + dt
      if a.ultimoRastro >= 0.05 then
        a.ultimoRastro = 0
        a.rastro[#a.rastro + 1] = a.t
        if #a.rastro > 8 then table.remove(a.rastro, 1) end
      end
    elseif not a.somFinalTocado then
      a.somFinalTocado = true
      som.tocar(a.def.somFinal or "susto")
      if ui._fx then
        ui._fx.flash({ 0.85, 0.02, 0.02 }, 0.45, 0.72)
        ui._fx.bater(1)
        ui._fx.hitstop(0.06)
      end
    end
  end

  if a.t >= a.dur then ativo = nil end
end

-- ---------------------------------------------------------------------------
-- DESENHO
-- ---------------------------------------------------------------------------

-- Desenha a arte recortada em retangulo arredondado (stencil), para as artes
-- quadradas sem template nao aparecerem com cantos duros.
local function arteRedonda(img, x, y, w, h, raio, alfa)
  love.graphics.stencil(function()
    love.graphics.rectangle("fill", x, y, w, h, raio, raio, 12)
  end, "replace", 1)
  love.graphics.setStencilTest("equal", 1)
  love.graphics.setColor(1, 1, 1, alfa)
  love.graphics.draw(img, x, y, 0, w / img:getWidth(), h / img:getHeight())
  love.graphics.setStencilTest()
end

-- Faixa escura atras do titulo: o texto fica legivel mesmo por cima do HUD.
local function faixaTexto(y, vw, alfa)
  love.graphics.setColor(0, 0, 0, 0.62 * alfa)
  love.graphics.rectangle("fill", -4, y - ui.E(5), vw + 8, ui.E(34))
end

local function desenharImpacto(a, vw, vh)
  local dur = a.dur
  local ent = clamp01(a.t / 0.28)
  local sai = clamp01((a.t - (dur - 0.5)) / 0.5)
  local alfa = math.min(ent, 1 - sai)
  if alfa <= 0 then return end

  local cor = a.def.cor or { 1, 0.85, 0.4 }
  local cx, cy = vw / 2, vh * 0.47

  -- Fundo escurecido: a arte e o unico foco.
  love.graphics.setColor(0, 0, 0, 0.80 * alfa)
  love.graphics.rectangle("fill", -4, -4, vw + 8, vh + 8)

  -- Raios girando atras da arte.
  local raios = 14
  for i = 1, raios do
    local ang = a.t * 0.28 + i * (math.pi * 2 / raios)
    local r1, r2 = ui.E(70), ui.E(520)
    love.graphics.setColor(cor[1], cor[2], cor[3], 0.055 * alfa)
    love.graphics.polygon("fill",
      cx + math.cos(ang) * r1, cy + math.sin(ang) * r1,
      cx + math.cos(ang + 0.10) * r2, cy + math.sin(ang + 0.10) * r2,
      cx + math.cos(ang - 0.10) * r2, cy + math.sin(ang - 0.10) * r2)
  end

  -- Halo suave.
  for i = 7, 1, -1 do
    love.graphics.setColor(cor[1], cor[2], cor[3], 0.028 * alfa)
    love.graphics.circle("fill", cx, cy, ui.E(120) + i * ui.E(34))
  end

  local img = a.img
  local maxW, maxH = vw * 0.62, vh * 0.64
  local dw, dh
  if img then
    local iw, ih = img:getDimensions()
    local esc = math.min(maxW / iw, maxH / ih)
    dw, dh = iw * esc, ih * esc
  else
    -- Fallback sem imagem (teste/sem arquivo): bloco dourado.
    dw, dh = maxH * 0.56, maxH
  end

  -- Entrada com overshoot: a arte "salta" para a frente.
  local k = easeOut(a.t / 0.42)
  local overshoot = 1 + 0.09 * math.sin(math.pi * clamp01((a.t - 0.18) / 0.5))
  local escala = (0.45 + 0.55 * k) * overshoot
    * (1 + 0.012 * math.sin(a.t * 3.4))
  local rot = math.sin(a.t * 1.6 + a.fase) * 0.028 * (1 - k * 0.5)
  dw, dh = dw * escala, dh * escala

  -- Sombra/glow atras.
  love.graphics.setColor(0, 0, 0, 0.55 * alfa)
  love.graphics.rectangle("fill", cx - dw / 2 + ui.E(7),
    cy - dh / 2 + ui.E(12), dw, dh, ui.E(16), ui.E(16))

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(rot)
  if img then
    arteRedonda(img, -dw / 2, -dh / 2, dw, dh, ui.E(16), alfa)
    love.graphics.setColor(1, 0.86, 0.42, 0.85 * alfa)
    love.graphics.setLineWidth(math.max(2, ui.E(2)))
    love.graphics.rectangle("line", -dw / 2, -dh / 2, dw, dh,
      ui.E(16), ui.E(16))
    love.graphics.setLineWidth(1)
  else
    love.graphics.setColor(cor[1], cor[2], cor[3], 0.8 * alfa)
    love.graphics.rectangle("fill", -dw / 2, -dh / 2, dw, dh,
      ui.E(16), ui.E(16))
  end
  love.graphics.pop()

  -- Faiscas ao redor.
  for _, p in ipairs(a.particulas or {}) do
    local raio = (p.dist + a.t * p.vel) % 0.86
    local px = cx + math.cos(p.ang + a.t * 0.35) * raio * vw * 0.42
    local py = cy + math.sin(p.ang + a.t * 0.35) * raio * vh * 0.46
    local tw = 0.35 + 0.65 * math.abs(math.sin(a.t * 3 + p.fase))
    love.graphics.setColor(1, 0.92, 0.6, tw * alfa * 0.9)
    love.graphics.circle("fill", px, py, ui.E(p.tam) * (0.5 + tw))
  end

  -- Nome da carta no topo (faixa escura para nao brigar com o HUD).
  local nome = string.upper((a.carta and a.carta.nome) or "CARTA")
  local yTit = vh * 0.045
  faixaTexto(yTit, vw, alfa)
  ui.txtEspacado(nome, 0, yTit, ui.E(18), { 1, 0.9, 0.6, alfa },
    ui.E(3), vw)
end

-- Caminho caotico da Probabilidade Mortal (deterministico pelo tempo).
local function posCaos(a, t, vw, vh)
  local cx, cy = vw / 2, vh * 0.46
  local x = cx + math.sin(t * 2.15 + a.fase) * vw * 0.30
    + math.sin(t * 5.40 + 1.7) * vw * 0.10
  local y = cy + math.cos(t * 1.75 + 0.6) * vh * 0.27
    + math.sin(t * 4.20 + 0.4) * vh * 0.08
  return x, y
end

local function desenharCaos(a, vw, vh)
  local cor = a.def.cor or { 1, 0.2, 0.2 }
  local t = a.t
  local alfa = 1
  if t > a.dur - 0.4 then alfa = clamp01((a.dur - t) / 0.4) end

  -- Fundo levemente escurecido (a mesa continua visivel).
  love.graphics.setColor(0, 0, 0, 0.55 * alfa)
  love.graphics.rectangle("fill", -4, -4, vw + 8, vh + 8)

  local tx = a.alvoX or (vw / 2)
  local ty = a.alvoY or (vh * 0.28)



  local img = a.img
  local iw, ih = 1, 1
  if img then iw, ih = img:getDimensions() end
  local baseH = math.min(vh * 0.44, vw * 0.44)
  local dw, dh = baseH * iw / ih, baseH

  local x, y, rot, esc
  if t < M.DURACAO_CAOS then
    x, y = posCaos(a, t, vw, vh)
    rot = math.sin(t * 7 + a.fase) * 0.45
    esc = 0.72 + 0.06 * math.sin(t * 9)

    -- Rastro de posicoes anteriores.
    local n = #a.rastro
    for i, rt in ipairs(a.rastro) do
      local rx, ry = posCaos(a, rt, vw, vh)
      local k = i / math.max(1, n)
      love.graphics.setColor(cor[1], cor[2], cor[3], 0.10 * k * alfa)
      love.graphics.circle("fill", rx, ry, ui.E(24) * k + ui.E(10))
    end
  elseif t < M.DURACAO_CAOS + 0.45 then
    -- Avanco: acelera em direcao ao assento da vitima.
    local k = clamp01((t - M.DURACAO_CAOS) / 0.45)
    local x0, y0 = posCaos(a, M.DURACAO_CAOS, vw, vh)
    local e = k * k * k
    x = x0 + (tx - x0) * e
    y = y0 + (ty - y0) * e - math.sin(k * math.pi) * vh * 0.10
    rot = (1 - k) * math.sin(t * 10) * 0.5
    esc = 0.78 + 0.9 * e
    love.graphics.setColor(1, 0.1, 0.1, 0.35 * alfa)
    love.graphics.setLineWidth(math.max(2, ui.E(5)))
    love.graphics.line(x0, y0, x, y)
    love.graphics.setLineWidth(1)
  else
    -- Impacto: explosao vermelha no assento e a carta por cima.
    local k = clamp01((t - (M.DURACAO_CAOS + 0.45)) / 0.45)
    x, y = tx, ty
    rot = 0
    esc = 1.7 - 0.3 * k
    love.graphics.setColor(1, 0.1, 0.05, 0.55 * (1 - k) * alfa)
    love.graphics.circle("fill", tx, ty, ui.E(60) + ui.E(220) * k)
  end

  if img then
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rot)
    local w2, h2 = dw * esc, dh * esc
    love.graphics.setColor(0, 0, 0, 0.6 * alfa)
    love.graphics.rectangle("fill", -w2 / 2 + ui.E(6), -h2 / 2 + ui.E(10),
      w2, h2, ui.E(12), ui.E(12))
    -- Arte quadrada sem template: cantos arredondados + moldura na cor da
    -- carta, para ler como uma "carta" flutuando e nao como um recorte duro.
    arteRedonda(img, -w2 / 2, -h2 / 2, w2, h2, ui.E(12), alfa)
    love.graphics.setColor(cor[1], cor[2], cor[3], 0.85 * alfa)
    love.graphics.setLineWidth(math.max(2, ui.E(2)))
    love.graphics.rectangle("line", -w2 / 2, -h2 / 2, w2, h2,
      ui.E(12), ui.E(12))
    love.graphics.setLineWidth(1)
    love.graphics.pop()
  end

  local nome = string.upper((a.carta and a.carta.nome) or "PROBABILIDADE MORTAL")
  if t < M.DURACAO_CAOS + 0.45 then
    local pulso = 0.7 + 0.3 * math.sin(t * 7)
    local yTit = vh * 0.06
    faixaTexto(yTit, vw, alfa)
    ui.txtEspacado(nome, 0, yTit, ui.E(19),
      { 1, 0.35, 0.3, pulso * alfa }, ui.E(3), vw)
  else
    local yElim = vh * 0.60
    faixaTexto(yElim, vw, alfa)
    ui.txtEspacado(ui.tr("ELIMINADO!"), 0, yElim, ui.E(26),
      { 1, 0.2, 0.15, alfa }, ui.E(5), vw)
  end
end

function M.desenhar(vw, vh)
  local a = ativo
  if not a then return end
  vw = vw or love.graphics.getWidth()
  vh = vh or love.graphics.getHeight()
  love.graphics.push("all")
  if a.tipo == "caos" then
    desenharCaos(a, vw, vh)
  else
    desenharImpacto(a, vw, vh)
  end
  love.graphics.pop()
end

return M
