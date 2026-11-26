-- ============================================================
-- TELA DE TESTE DE ANIMAÇÕES (V7+)
-- Layout replicado do modo multiplayer (duelo 1v1)
-- ============================================================
local animTeste = {}

local ui = require "ui"
local madeira = require "madeira"
local cartas = require "cartas"
local arte = require "arte"
local som = require "som"
local meta = require "meta"

-- Resolucao virtual (igual ao main.lua).
local VW, VH = 1280, 720
local CENTRO = VW / 2

-- Medidas (copiadas do main.lua para ficar idêntico ao duelo).
local CW, CH = ui.E(64), ui.E(88)
local CW_MAO, CH_MAO = ui.E(59), ui.E(88)
local BW, BH = math.floor(ui.E(64) * 0.75), math.floor(ui.E(128) * 0.75)
local DECK_CW, DECK_CH = ui.E(55), ui.E(82.5)
local DECK_DW, DECK_DH = DECK_CW, DECK_CH
local MAO_Y = VH - ui.E(46) - CH
local DECKS_Y = math.floor(VH * 0.40)
local OP_PAINEL_Y = 16
local OP_MAO_Y = OP_PAINEL_Y + ui.E(34) + 8
local PLACA_X, PLACA_Y = 16, 34
local PAINEL_RECT = { x = CENTRO - ui.E(65), y = VH - ui.E(12) - ui.E(34), w = ui.E(130), h = ui.E(34) }
local ALVO_RECT = { x = CENTRO - ui.E(65), y = OP_PAINEL_Y, w = ui.E(130), h = ui.E(34) }
local AREA_L, AREA_A = ui.E(46), ui.E(64)
local AREA_MAX = 3
local MESA_X, MESA_Y = CENTRO, math.floor(VH * 0.40)

-- Botoes do topo.
local VOLTAR = { x = VW - ui.E(16) - ui.E(92), y = ui.E(16), w = ui.E(92), h = ui.E(30) }
local ESCOLHER = { x = VOLTAR.x - ui.E(12) - ui.E(160), y = VOLTAR.y, w = ui.E(160), h = VOLTAR.h }

-- Botoes JOGAR/GUARDAR (canto inferior esquerdo, igual ao multiplayer).
local BTN_W, BTN_H = ui.E(80), ui.E(34)
local BTN_JOGAR = { x = ui.E(12), y = VH - ui.E(20) - ui.E(34), w = BTN_W, h = BTN_H }
local BTN_GUARDAR = { x = ui.E(12) + BTN_W + ui.E(8), y = VH - ui.E(20) - ui.E(34), w = BTN_W, h = BTN_H }

local LINHA_STATUS_Y = 232

local ESCOLHA = {
  painel = { x = 80, y = 35, w = 1120, h = 650 },
  cols = 10, cw = 52, ch = 78, gx = 9, gy = 22,
  x0 = 110, y0 = 105,
  previa = { x = 780, y = 112, w = 163, h = 243 },
}

local COR_OURO = ui.C.OURO
local COR_TEXTO = ui.C.TEXTO
local COR_VERMELHO = ui.C.FALHA
local COR_VERDE = ui.C.SUCESSO
local LIFT_SEL = ui.E(16)

local IDS_MAO = { 1, 3, 5, 6, 8, 21, 22 }
local MAX_MAO = 7
local QTD_MAO_IA = 7
local IDS_DESCARTE = {}

local estado = {
  ativo = false, tempo = 0, mao = {}, maoIA = {}, descarte = {}, rectsMao = {},
  selecionada = nil, saldo = 1000, satisfacao = 100, produtividade = 0,
  bonusSatisfacao = 0, greve = false,
  oponente = { nome = "CONVIDADO", saldo = 1000, satisfacao = 100, produtividade = 0, bonusSatisfacao = 0, greve = false, avatar = "3", mao = QTD_MAO_IA, areaSegura = {} },
  alvoSelecionado = nil, modoAlvo = false,
  animando = false, animacao = nil, mensagens = {}, popups = {},
  particulas = {}, tremores = 0, flash = 0, opFlash = 0,
  nomeJogador = "JOGADOR_1", avatarJogador = "1",
  escolhendo = false, galeria = {}, hoverGaleriaId = nil,
  previewId = nil, rectsGaleria = {}, rectsEscolha = {},
  selUids = {},
  areaSegura = {},
}

local hoverX, hoverY = nil, nil
local hoverTravado = nil
local fundoMesa = nil

local iniciarAtaque, executarAtaque, alternarCartaMao, temNaMao, cartaDaGaleria
local layoutMao, layoutOponente, pontoNaCarta, retAreaSegura, dentro
local addMensagem, addPopup, explodir, posicaoNaAnimacao, montarCartas
local desenharFundo, desenharMesaCentral, desenharDecks, desenharAreaSeguraOponente
local desenharAreaSeguraPropria, desenharPilhas, desenharVisor, desenharOponente
local desenharMaoIA, desenharPlaca, desenharMao, desenharPainelJogador
local desenharAnimacao, desenharParticulas, desenharPopups, desenharStatusLinha
local desenharMira, desenharVoltar, desenharBotaoEscolher, desenharBotoesJogarGuardar
local desenharEscolha

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local uidSeq = 0

function novaCarta(id)
  local base = cartas.porId(id)
  if not base then return nil end
  local c = cartas.copia(base)
  uidSeq = uidSeq + 1
  c.uid = "anim" .. uidSeq
  c.uidNum = uidSeq
  return c
end

function construirGaleria()
  local lista = {}
  for id = 1, 80 do
    local c = cartas.porId(id)
    if c then lista[#lista + 1] = c end
  end
  return lista
end

function temNaMao(id)
  for _, c in ipairs(estado.mao) do if c.id == id then return true end end
  return false
end

function cartaDaGaleria(id)
  for _, c in ipairs(estado.galeria) do if c.id == id then return c end end
  return nil
end

function alternarCartaMao(id)
  if temNaMao(id) then
    for i = #estado.mao, 1, -1 do if estado.mao[i].id == id then table.remove(estado.mao, i) break end end
  else
    if #estado.mao < MAX_MAO then
      local c = novaCarta(id)
      if c then estado.mao[#estado.mao + 1] = c end
    end
  end
end

function layoutMao(n)
  local rets = {}
  if n <= 0 then return rets end
  local gap = math.max(ui.E(6), math.floor((CW_MAO * n) / (n + 1)))
  local total = CW_MAO * n + gap * (n - 1)
  local x0 = CENTRO - total / 2
  for i = 1, n do
    local rot = math.rad((i - (n + 1) / 2) * 4)
    rets[i] = { x = x0 + (i - 1) * (CW_MAO + gap), y = MAO_Y, w = CW_MAO, h = CH_MAO, rot = rot, idx = i }
  end
  return rets
end

function layoutOponente(n)
  local rets = {}
  if n <= 0 then return rets end
  local gap = math.max(ui.E(6), math.floor((BW * n) / (n + 1)))
  local total = BW * n + gap * (n - 1)
  local x0 = CENTRO - total / 2
  for i = 1, n do
    local rot = math.rad((i - (n + 1) / 2) * 3)
    rets[i] = { x = x0 + (i - 1) * (BW + gap), y = OP_MAO_Y, w = BW, h = BH, rot = rot, idx = i }
  end
  return rets
end

function pontoNaCarta(x, y, r)
  if not r then return false end
  local cx = r.x + r.w / 2
  local cy = r.y + r.h / 2
  local dx = (x - cx) * math.cos(-r.rot) - (y - cy) * math.sin(-r.rot)
  local dy = (x - cx) * math.sin(-r.rot) + (y - cy) * math.cos(-r.rot)
  return math.abs(dx) <= r.w / 2 and math.abs(dy) <= r.h / 2
end

function retAreaSegura(i, topo)
  local passo = AREA_L + ui.E(4)
  local total = AREA_L * AREA_MAX + ui.E(4) * (AREA_MAX - 1)
  return {
    x = VW - ui.E(12) - total + ((i or 1) - 1) * passo,
    y = topo and ui.E(60) or (VH - ui.E(12) - AREA_A),
    w = AREA_L, h = AREA_A,
  }
end

function dentro(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function addMensagem(texto, cor, dur)
  estado.mensagens[#estado.mensagens + 1] = { texto = texto, cor = cor or COR_TEXTO, t = 0, duracao = dur or 2.5 }
end

function addPopup(texto, x, y, cor, dur)
  estado.popups[#estado.popups + 1] = { texto = texto, x = x, y = y, cor = cor or COR_TEXTO, t = 0, duracao = dur or 1.2 }
end

function explodir(x, y, qtd, cores)
  for _ = 1, qtd do
    local ang = love.math.random() * math.pi * 2
    local vel = love.math.random() * 280 + 120
    estado.particulas[#estado.particulas + 1] = {
      x = x, y = y, vx = math.cos(ang) * vel, vy = math.sin(ang) * vel - 60, grav = 400,
      tam = love.math.random() * 4 + 2, cor = cores[love.math.random(1, #cores)],
      vida = 0.6 + love.math.random() * 0.4, vidaMax = 1,
    }
  end
end

function posicaoNaAnimacao(a, p)
  local ox, oy, tx, ty = a.origemX, a.origemY, a.alvoX, a.alvoY
  local cx, cy, rot, escala
  if p < 0.52 then
    local ease = 1 - (1 - p / 0.52) ^ 3
    cx = ox + (tx - ox) * ease
    cy = oy + (ty - oy) * ease - math.sin(ease * math.pi) * ui.E(60)
    rot = ease * math.pi * 2.5
    escala = 1 + ease * 0.15
  else
    local p2 = (p - 0.52) / 0.48
    local ease = p2 < 0.5 and 1 - (1 - p2 * 2) ^ 2 or (1 - (p2 - 0.5) * 2) ^ 2
    cx = tx + (ox - tx) * ease
    cy = ty + (oy - ty) * ease
    rot = math.pi * 2.5 * (1 - ease)
    escala = 1 + (1 - ease) * 0.15
  end
  local alfa = p < 0.12 and p / 0.12 or (p > 0.88 and (1 - p) / 0.12 or 1)
  return cx, cy, rot, escala, alfa
end

function montarCartas()
  estado.mao = {}
  for _, id in ipairs(IDS_MAO) do local c = novaCarta(id); if c then estado.mao[#estado.mao + 1] = c end end
  estado.maoIA = {}; for i = 1, QTD_MAO_IA do estado.maoIA[i] = i end
  estado.descarte = {}; for _, id in ipairs(IDS_DESCARTE) do local c = novaCarta(id); if c then estado.descarte[#estado.descarte + 1] = c end end
  estado.areaSegura = {}
  estado.rectsMao = layoutMao(#estado.mao)
end

-- ------------------------------------------------------------
-- Ataque com seleção de alvo
-- ------------------------------------------------------------
local function primeiraSelecionada()
  if #estado.selUids == 0 then return nil end
  local uid = estado.selUids[1]
  for _, c in ipairs(estado.mao) do if c.uid == uid then return c end end
  return nil
end

function iniciarAtaque(carta)
  carta = carta or primeiraSelecionada()
  if estado.animando or estado.escolhendo or not carta then return end
  local precisaAlvo = carta.precisaAlvo == true
  -- No modo teste com 1 oponente, sempre ataca direto.
  executarAtaque(carta, 1)
end

function executarAtaque(carta, alvoIdx)
  if estado.animando or estado.escolhendo or not carta then return end
  alvoIdx = alvoIdx or 1

  local idx = nil
  for i, c in ipairs(estado.mao) do if c == carta then idx = i break end end
  local r = idx and (estado.rectsMao[idx] or layoutMao(#estado.mao)[idx]) or nil
  local ox = r and (r.x + r.w / 2) or CENTRO
  local oy = r and (r.y + r.h / 2) or (MAO_Y + CH / 2)

  -- Posição do alvo (painel do oponente no topo).
  local alvoX = CENTRO
  local alvoY = OP_PAINEL_Y + ui.E(17)
  local dano = 100 + (carta.id % 5) * 50

  estado.selecionada = carta
  estado.animando = true
  estado.modoAlvo = false
  estado.opFlash = 1
  estado.animacao = { t = 0, duracao = 1.4, carta = carta, origemX = ox, origemY = oy, alvoX = alvoX, alvoY = alvoY, alvoIdx = alvoIdx, impacto = false, rastro = {}, dano = dano }
  addMensagem("ATAQUE: " .. carta.nome .. " -> " .. estado.oponente.nome, COR_OURO)
end

-- ------------------------------------------------------------
-- Update
-- ------------------------------------------------------------
function animTeste.atualizar(dt)
  if not estado.ativo then return end
  estado.tempo = estado.tempo + dt

  for i = #estado.mensagens, 1, -1 do local m = estado.mensagens[i]; m.t = m.t + dt; if m.t >= m.duracao then table.remove(estado.mensagens, i) end end
  for i = #estado.popups, 1, -1 do local p = estado.popups[i]; p.t = p.t + dt; p.y = p.y - dt * ui.E(34); if p.t >= p.duracao then table.remove(estado.popups, i) end end
  for i = #estado.particulas, 1, -1 do local p = estado.particulas[i]; p.x = p.x + p.vx * dt; p.y = p.y + p.vy * dt; p.vy = p.vy + p.grav * dt; p.vida = p.vida - dt; if p.vida <= 0 then table.remove(estado.particulas, i) end end

  estado.tremores = math.max(0, estado.tremores - dt * 28)
  estado.flash = math.max(0, estado.flash - dt * 4.5)
  estado.opFlash = math.max(0, estado.opFlash - dt * 3.5)

  local a = estado.animacao
  if estado.animando and a then
    a.t = a.t + dt
    local p = math.min(a.t / a.duracao, 1)
    if p >= 0.12 and p < 0.52 then
      local cx, cy = posicaoNaAnimacao(a, p)
      a.rastro[#a.rastro + 1] = { x = cx, y = cy, vida = 0.22 }
    end
    for i = #a.rastro, 1, -1 do local r = a.rastro[i]; r.vida = r.vida - dt; if r.vida <= 0 then table.remove(a.rastro, i) end end

    if p >= 0.52 and not a.impacto then
      a.impacto = true
      estado.tremores = ui.E(11)
      estado.flash = 0.5
      estado.opFlash = 1
      local alvo = estado.oponente
      if alvo then alvo.saldo = math.max(0, alvo.saldo - a.dano); addPopup("- R$ " .. tostring(a.dano), CENTRO, OP_PAINEL_Y + ui.E(18), COR_VERMELHO) end
      addMensagem("ALVO ATINGIDO!  -R$ " .. tostring(a.dano), COR_VERDE)
      som.tocar("psicar", 0.8)
    end
    if p >= 1 then estado.animando = false; estado.animacao = nil end
  end
end

-- ------------------------------------------------------------
-- Desenho
-- ------------------------------------------------------------
function desenharFundo()
  love.graphics.setColor(1, 1, 1, 1)
  if fundoMesa then ui.imagemCover(fundoMesa, 0, 0, VW, VH) else love.graphics.setColor(ui.C.FUNDO); love.graphics.rectangle("fill", 0, 0, VW, VH) end
end

-- Mesa central: circulo tracejado girando + espadas + compra/descarte mini.
function desenharMesaCentral()
  local re, ri = ui.E(140) / 2, ui.E(120) / 2
  local rot = love.timer.getTime() * (2 * math.pi / 30)
  -- Circulo externo tracejado.
  local seg, gap = 10, 8
  local cor = ui.hex "#FFD54F"
  for i = 0, seg - 1 do
    local a0 = rot + (i / seg) * 2 * math.pi
    local a1 = rot + ((i + 0.5) / seg) * 2 * math.pi
    love.graphics.setColor(cor[1], cor[2], cor[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", MESA_X, MESA_Y, re, a0, a1)
  end
  love.graphics.setLineWidth(1)
  -- Circulo interno.
  ui.caixa(MESA_X - ri, MESA_Y - ri, ri * 2, ri * 2, ri, ui.hex "#0F1322", ui.hex "#7A5C29", 2, 0.92)
  -- Espadas.
  ui.iconeEspadas(MESA_X, MESA_Y - ri + ui.E(24), ui.E(30))
end

-- Circulo tracejado simples (fallback se love.graphics.arc nao suportar).
-- (mantido acima com arc; se der problema, substitui por linha a linha)

function desenharDecks()
  local gap = ui.E(21)
  local total = DECK_CW + gap + DECK_DW
  local x = CENTRO - total / 2
  local cyCompra = DECKS_Y + (DECK_DH - DECK_CH) / 2
  ui.verso(x, cyCompra, DECK_CW, DECK_CH)
  ui.txtCabe("COMPRA", x - ui.E(6), DECKS_Y + DECK_DH + ui.E(10), 13, DECK_CW + ui.E(12), COR_OURO, "center", 10)
  local dx = x + DECK_CW + gap
  local topo = estado.descarte[#estado.descarte]
  if not topo then
    ui.caixaTracejada(dx, DECKS_Y, DECK_DW, DECK_DH, ui.E(6), ui.hex "#1E1E32", 0.4, ui.hex "#777777", 1, ui.E(2), ui.E(5), ui.E(4))
  else
    local hDesc = ui.alturaCarta(topo, DECK_DW); local wDesc = DECK_DW
    if hDesc > DECK_DH then hDesc = DECK_DH; wDesc = ui.larguraCarta(topo, hDesc) end
    ui.carta(topo, dx + (DECK_DW - wDesc) / 2, DECKS_Y + (DECK_DH - hDesc) / 2, wDesc, hDesc, {})
  end
  ui.txtCabe("DESCARTE", dx - ui.E(6), DECKS_Y + DECK_DH + ui.E(10), 13, DECK_DW + ui.E(12), COR_OURO, "center", 10)
end

-- Area segura do OPPONENTE (topo direito, versos).
function desenharAreaSeguraOponente()
  local op = estado.oponente
  local opVazia = #op.areaSegura == 0
  for i = 1, AREA_MAX do
    local s = retAreaSegura(i, true)
    if op.areaSegura[i] then
      ui.verso(s.x, s.y, s.w, s.h, { dobra = 1, alfa = 0.7 })
    else
      ui.caixaTracejada(s.x, s.y, s.w, s.h, ui.E(6), ui.hex "#808080", 0.105, COR_OURO, 0.21, ui.E(1.5), ui.E(4), ui.E(3))
      if opVazia then
        ui.txt("VAZIA", s.x, s.y + s.h / 2 - ui.E(5), 10, COR_OURO, "center", s.w, 0.28)
      end
    end
  end
end

-- Area segura propria (baixo direito, face visível).
function desenharAreaSeguraPropria()
  local areaVazia = #estado.areaSegura == 0
  for i = 1, AREA_MAX do
    local s = retAreaSegura(i, false)
    local cartaP = estado.areaSegura[i]
    if cartaP then
      local selP = false -- pode ser estendido com selAreaUid
      ui.carta(cartaP, s.x, s.y, s.w, s.h, { dobra = 1, destaque = selP and COR_OURO or nil })
    else
      ui.caixaTracejada(s.x, s.y, s.w, s.h, ui.E(6), ui.hex "#808080", 0.15, COR_OURO, 0.3, ui.E(1.5), ui.E(4), ui.E(3))
      if areaVazia then
        ui.txt("VAZIA", s.x, s.y + s.h / 2 - ui.E(5), 10, COR_OURO, "center", s.w, 0.4)
      end
    end
  end
end

-- Pilhas da mesa (simplificado, sem depender de partida real).
function desenharPilhas()
  local w, h = ui.E(46), ui.E(64)
  local gap = ui.E(4)
  local x0 = ui.E(10)
  local y0 = DECKS_Y

  local function slot(carta, x, rotulo)
    ui.txt(rotulo, x - ui.E(2), y0 - ui.E(14), 10, COR_OURO, "center", w + ui.E(4), 0.85)
    if carta then
      ui.carta(carta, x, y0, w, h, { preencherArte = true })
    else
      ui.caixaTracejada(x, y0, w, h, ui.E(6), ui.hex "#1E1E32", 0.35, ui.hex "#777777", 0.65, ui.E(1.5), ui.E(4), ui.E(3))
    end
  end

  slot(nil, x0, "DEFESA")
  slot(nil, x0 + w + gap, "JOGADAS")
  slot(nil, x0 + (w + gap) * 2, "CURINGA")
end

-- Visor de curingas (simplificado).
function desenharVisor()
  local w, h = ui.E(228), ui.E(86)
  local x = VW - ui.E(12) - w
  local y = DECKS_Y
  ui.caixa(x, y, w, h, ui.E(8), ui.hex "#120B20", COR_OURO, ui.E(1.5), 0.9)
  ui.txt("VISOR DE CURINGAS", x + ui.E(8), y + ui.E(5), ui.E(9), COR_OURO, "left", w - ui.E(16))
  ui.txt("SEM CURINGA ATIVO", x + ui.E(8), y + ui.E(20), ui.E(8), ui.C.TEXTO2, "left", w - ui.E(16))
end

-- Oponente (topo, centralizado): painel + barras SAT/PROD + mão.
function desenharOponente()
  local op = estado.oponente
  local x, y = CENTRO - ui.E(65), OP_PAINEL_Y

  -- Halo de seleção de alvo no painel do oponente.
  if estado.modoAlvo and not estado.animando then
    local pulso = 0.5 + 0.5 * math.sin(estado.tempo * 8)
    local painelW, painelH = ALVO_RECT.w, ALVO_RECT.h
    love.graphics.setColor(1, 0.84, 0.2, 0.15 + 0.25 * pulso)
    love.graphics.rectangle("fill", x - ui.E(10), y - ui.E(10), painelW + ui.E(20), painelH + ui.E(20), ui.E(12))
    love.graphics.setColor(1, 0.84, 0.2, 0.6 + 0.4 * pulso)
    love.graphics.setLineWidth(ui.E(3))
    love.graphics.rectangle("line", x - ui.E(10), y - ui.E(10), painelW + ui.E(20), painelH + ui.E(20), ui.E(12))
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 0.84, 0.2, 1)
    ui.txt("1", x + painelW - ui.E(22), y + ui.E(4), 18, COR_OURO, "center", ui.E(20))
  end

  -- Painel do oponente.
  ui.painelStatus({ nome = op.nome, saldo = op.saldo, quem = op.avatar, x = x, y = y, largura = ALVO_RECT.w, corDestaque = COR_OURO, ocultarSaldo = false })

  -- Barras verticais de Satisfacao/Produtividade a ESQUERDA do painel.
  ui.barrasStatus(CENTRO - ui.E(65) - ui.larguraBarrasStatus() - ui.E(6),
    OP_PAINEL_Y, ui.E(34), op)

  -- Flash de dano.
  if estado.opFlash > 0 then
    love.graphics.setColor(1, 0.15, 0.15, estado.opFlash * 0.45)
    love.graphics.rectangle("fill", x, y, ALVO_RECT.w, ALVO_RECT.h, ui.E(5))
  end

  -- Mão do oponente (versos).
  local rets = layoutOponente(op.mao or QTD_MAO_IA)
  for _, r in ipairs(rets) do
    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
    love.graphics.rotate(r.rot)
    ui.verso(-r.w / 2, -r.h / 2, r.w, r.h)
    love.graphics.pop()
  end
end

function desenharMaoIA() end -- nao usado (desenharOponente ja desenha)

function desenharPlaca()
  ui.placaTurno({ x = PLACA_X, y = PLACA_Y, turno = 1, max = 10, nome = estado.nomeJogador, isHumano = true, fluxo = "PARA A ESQUERDA" })
end

function desenharMao()
  estado.rectsMao = layoutMao(#estado.mao)
  local mao = estado.mao

  local function estaSel(uid)
    for _, u in ipairs(estado.selUids) do if u == uid then return true end end
    return false
  end

  local animando = estado.animando and estado.animacao
  local function voando(c) return animando and estado.animacao.carta == c end

  local hoverIdx = nil
  if not estado.escolhendo and hoverX and hoverY then
    for i = #estado.rectsMao, 1, -1 do
      local c = mao[i]
      if c and not voando(c) and pontoNaCarta(hoverX, hoverY, estado.rectsMao[i]) then hoverIdx = i; break end
    end
  end

  local selecionadas = {}; local hoverRect = nil
  for i, r in ipairs(estado.rectsMao) do
    local c = mao[i]
    if c and not voando(c) then
      if estaSel(c.uid) then
        selecionadas[#selecionadas + 1] = r
      elseif i == hoverIdx then
        hoverRect = r
      else
        love.graphics.push()
        love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
        love.graphics.rotate(r.rot)
        ui.carta(c, -r.w / 2, -r.h / 2, r.w, r.h, { preencherArte = true })
        love.graphics.pop()
      end
    end
  end

  -- HOVER: carta sobe, escala 1.06, brilho creme.
  if hoverRect then
    hoverRect.y = hoverRect.y - ui.E(10)
    local areaX = retAreaSegura(1, false).x
    local bordaDir = hoverRect.x + hoverRect.w / 2 + hoverRect.w * 1.35 / 2
    local excesso = bordaDir - (areaX - ui.E(4))
    if excesso > 0 then hoverRect.x = hoverRect.x - excesso end
    love.graphics.push()
    love.graphics.translate(hoverRect.x + hoverRect.w / 2, hoverRect.y + hoverRect.h / 2)
    love.graphics.rotate(hoverRect.rot)
    ui.carta(mao[hoverIdx], -hoverRect.w / 2, -hoverRect.h / 2, hoverRect.w, hoverRect.h,
      { escala = 1.06, preencherArte = true, destaque = ui.C.CREME, destaqueAlfa = 0.14 })
    love.graphics.pop()
  end

  -- Selecionadas por cima, com lift.
  for _, r in ipairs(selecionadas) do
    local c = mao[r.idx]
    local destaque = nil
    if hoverX and hoverY and (pontoNaCarta(hoverX, hoverY, r) or dentro(hoverX, hoverY, ESCOLHER)) then
      destaque = COR_OURO
    end
    r.y = r.y - LIFT_SEL
    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
    love.graphics.rotate(r.rot)
    ui.carta(c, -r.w / 2, -r.h / 2, r.w, r.h,
      { escala = 1.05, preencherArte = true, destaque = destaque })
    love.graphics.pop()

    -- Tooltip do efeito ACIMA da carta levantada.
    if c and c.descricao then
      local tx = r.x + r.w / 2
      local ty = r.y - ui.E(6)
      local tw = ui.E(260)
      local th = ui.E(72)
      local tipX = tx - tw / 2
      local tipY = ty - th
      if tipX < ui.E(8) then tipX = ui.E(8) end
      if tipX + tw > VW - ui.E(8) then tipX = VW - ui.E(8) - tw end
      ui.caixa(tipX, tipY, tw, th, ui.E(8), ui.hex "#0D101C", COR_OURO, ui.E(2.5), 0.98)
      ui.txtCabe("EFEITO:", tipX + ui.E(10), tipY + ui.E(6), ui.E(10), tw - ui.E(20), COR_OURO, "left", ui.E(9))
      ui.textoQuebrado(c.descricao, tipX + ui.E(10), tipY + ui.E(24), tw - ui.E(20), ui.E(10), ui.C.TEXTO, "left", ui.E(9))
      love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 0.98)
      love.graphics.polygon("fill", tx, ty, tx - ui.E(6), ty - ui.E(8), tx + ui.E(6), ty - ui.E(8))
    end
  end

  -- PREVIA INSTANTÂNEA (arte grande à esquerda da mão).
  if hoverIdx and mao[hoverIdx] and not estado.escolhendo then
    local pvH = ui.E(150)
    local pvW = math.floor(pvH * CW_MAO / CH_MAO + 0.5)
    local vao = ui.E(14)
    local maoEsq = estado.rectsMao[1] and estado.rectsMao[1].x or (CENTRO - CW_MAO / 2)
    local deckEsq = CENTRO - (DECK_CW + ui.E(21) + DECK_DW) / 2
    local px = maoEsq - pvW - vao
    local maxPx = deckEsq - pvW - vao
    if px > maxPx then px = maxPx end
    px = math.max(ui.E(8), px)
    local py = PAINEL_RECT.y - pvH - ui.E(8)
    local carta = mao[hoverIdx]
    local img = carta and arte.arte(carta)
    if img and arte.temArte(carta) then
      ui.imagemContain(img, px, py, pvW, pvH)
    else
      ui.caixa(px, py, pvW, pvH, ui.E(8), ui.C.CORPO_CARTA, ui.corBorda(carta), ui.E(3))
      ui.faceCompleta(carta, px + ui.E(3), py + ui.E(3), pvW - ui.E(6), pvH - ui.E(6))
      ui.caixa(px, py, pvW, pvH, ui.E(8), nil, { 1, 1, 1 }, ui.E(2))
    end
  end
end

-- Painel do jogador (baixo, centralizado) + barras SAT/PROD.
function desenharPainelJogador()
  local hab = estado.avatarJogador
  if hab ~= "taylor" and hab ~= "marx" and hab ~= "mayo" then hab = nil end
  local x, y, larg = PAINEL_RECT.x, PAINEL_RECT.y, PAINEL_RECT.w
  ui.painelStatus({ nome = estado.nomeJogador or "VOCE", saldo = estado.saldo, quem = "voce", habilidade = hab, x = x, y = y, largura = larg, corDestaque = COR_OURO, ocultarSaldo = false })
  -- StatusJogador (SAT/PROD) ao lado do painel do jogador.
  local j = { nome = estado.nomeJogador, satisfacao = estado.satisfacao, produtividade = estado.produtividade, bonusSatisfacao = estado.bonusSatisfacao, greve = estado.greve }
  ui.barrasStatus(PAINEL_RECT.x - ui.larguraBarrasStatus() - ui.E(6),
    PAINEL_RECT.y, ui.E(34), j)
end

function desenharAnimacao()
  local a = estado.animacao; if not a then return end
  local p = math.min(a.t / a.duracao, 1)
  for _, r in ipairs(a.rastro) do local alfa = math.max(0, r.vida / 0.22) * 0.45; love.graphics.setColor(1, 0.55, 0.1, alfa); love.graphics.rectangle("fill", r.x - CW_MAO * 0.28, r.y - CH_MAO * 0.30, CW_MAO * 0.56, CH_MAO * 0.60, ui.E(8)) end
  local cx, cy, rot, escala, alfa = posicaoNaAnimacao(a, p)
  love.graphics.push(); love.graphics.translate(cx, cy); love.graphics.rotate(rot)
  ui.carta(a.carta, -CW_MAO / 2, -CH_MAO / 2, CW_MAO, CH_MAO, { escala = escala, destaque = COR_OURO, destaqueAlfa = math.max(0, alfa) * 0.5, preencherArte = true })
  love.graphics.pop()
end

function desenharParticulas()
  for _, p in ipairs(estado.particulas) do local alfa = math.max(0, p.vida / p.vidaMax); love.graphics.setColor(p.cor[1], p.cor[2], p.cor[3], alfa); love.graphics.rectangle("fill", p.x - p.tam / 2, p.y - p.tam / 2, p.tam, p.tam, ui.E(1)) end
end

function desenharPopups()
  for _, p in ipairs(estado.popups) do local alfa = math.max(0, 1 - p.t / p.duracao); ui.txt(p.texto, p.x - ui.E(90), p.y, 22, p.cor, "center", ui.E(180), alfa) end
end

function desenharStatusLinha()
  if #estado.mensagens > 0 then for i, m in ipairs(estado.mensagens) do local alfa = math.max(0, 1 - m.t / m.duracao); local ordem = #estado.mensagens - i; ui.txt(m.texto, 0, LINHA_STATUS_Y + ordem * ui.E(11), 15, m.cor, "center", VW, alfa) end; return end
  if estado.modoAlvo then ui.txt("MODO ALVO: clique no oponente (1)", 0, LINHA_STATUS_Y, 13, COR_OURO, "center", VW)
  elseif estado.selecionada then ui.txt("SELECIONADA: " .. estado.selecionada.nome .. (estado.selecionada.precisaAlvo and " (precisa alvo)" or "") .. "   -   clique no oponente para atacar", 0, LINHA_STATUS_Y, 13, COR_OURO, "center", VW) end
end

function desenharMira()
  if not estado.selecionada or estado.animando or estado.modoAlvo then return end
  local idx; for i, c in ipairs(estado.mao) do if c == estado.selecionada then idx = i break end end
  local r = idx and estado.rectsMao[idx]; if not r then return end
  local ox, oy = r.x + r.w / 2, r.y + r.h / 2
  local tx, ty = CENTRO, OP_PAINEL_Y + ui.E(17)
  love.graphics.setColor(1, 0.84, 0.2, 0.28); love.graphics.setLineWidth(ui.E(1.5))
  for i = 0, 17, 2 do local t0 = i / 18; local t1 = (i + 1) / 18; love.graphics.line(ox + (tx - ox) * t0, oy + (ty - oy) * t0, ox + (tx - ox) * t1, oy + (ty - oy) * t1) end
  love.graphics.setLineWidth(1)
end

function desenharVoltar()
  local hov = hoverX and hoverY and dentro(hoverX, hoverY, VOLTAR)
  ui.caixa(VOLTAR.x, VOLTAR.y, VOLTAR.w, VOLTAR.h, ui.E(6), ui.C.PAINEL, COR_OURO, ui.E(1.5), hov and 1 or 0.9)
  ui.txt("VOLTAR", VOLTAR.x, VOLTAR.y + ui.E(6), 13, COR_OURO, "center", VOLTAR.w)
end

function desenharBotaoEscolher()
  local hov = hoverX and hoverY and dentro(hoverX, hoverY, ESCOLHER)
  ui.caixa(ESCOLHER.x, ESCOLHER.y, ESCOLHER.w, ESCOLHER.h, ui.E(6), ui.C.PAINEL, COR_OURO, ui.E(1.5), hov and 1 or 0.9)
  ui.txt("ESCOLHER MAO", ESCOLHER.x, ESCOLHER.y + ui.E(6), 13, COR_OURO, "center", ESCOLHER.w)
end

function desenharBotoesJogarGuardar()
  local temSel = #estado.selUids > 0
  if not temSel then return end

  -- JOGAR.
  local hovJ = hoverX and hoverY and dentro(hoverX, hoverY, BTN_JOGAR)
  ui.caixa(BTN_JOGAR.x, BTN_JOGAR.y, BTN_JOGAR.w, BTN_JOGAR.h, ui.E(8), ui.C.VERDE, ui.C.VERDE_CLARO, ui.E(2), hovJ and 1 or 0.95)
  ui.txt("JOGAR", BTN_JOGAR.x, BTN_JOGAR.y + ui.E(8), 14, ui.hex "#10121F", "center", BTN_JOGAR.w)
  ui.txtCabe("#" .. #estado.selUids, BTN_JOGAR.x, BTN_JOGAR.y + ui.E(24), 10, ui.hex "#10121F", "center", BTN_JOGAR.w)

  -- GUARDAR.
  local hovG = hoverX and hoverY and dentro(hoverX, hoverY, BTN_GUARDAR)
  ui.caixa(BTN_GUARDAR.x, BTN_GUARDAR.y, BTN_GUARDAR.w, BTN_GUARDAR.h, ui.E(8), ui.hex "#1565C0", ui.hex "#42A5F5", ui.E(2), hovG and 1 or 0.95)
  ui.txt("GUARDAR", BTN_GUARDAR.x, BTN_GUARDAR.y + ui.E(8), 14, ui.hex "#10121F", "center", BTN_GUARDAR.w)
end

function desenharEscolha()
  local fx, fy, fw, fh = ui.retTelaCheia(VW, VH)
  love.graphics.setColor(0, 0, 0, 0.76); love.graphics.rectangle("fill", fx, fy, fw, fh)
  local p = ESCOLHA.painel
  ui.caixa(p.x, p.y, p.w, p.h, ui.E(14), ui.hex "#0F1322", COR_OURO, ui.E(2))
  ui.txt("ESCOLHER CARTAS DA MAO", p.x, p.y + ui.E(14), 20, COR_OURO, "center", p.w)
  ui.txt("Clique para adicionar/remover (maximo 7). Feche para ver na mao.", p.x, p.y + ui.E(30), 11, ui.C.TEXTO2, "center", p.w)

  estado.hoverGaleriaId = nil
  if hoverX and hoverY then for i = #estado.rectsGaleria, 1, -1 do local it = estado.rectsGaleria[i]; if dentro(hoverX, hoverY, it) then estado.hoverGaleriaId = it.id; estado.previewId = it.id; break end end end

  estado.rectsGaleria = {}
  local cw, ch = ESCOLHA.cw, ESCOLHA.ch
  for index, c in ipairs(estado.galeria) do
    local col = (index - 1) % ESCOLHA.cols; local row = math.floor((index - 1) / ESCOLHA.cols)
    local rx = ESCOLHA.x0 + col * (cw + ESCOLHA.gx); local ry = ESCOLHA.y0 + row * (ch + ESCOLHA.gy)
    local sel = temNaMao(c.id); local hov = estado.hoverGaleriaId == c.id
    ui.carta(c, rx, ry, cw, ch, { preencherArte = true, destaque = sel and COR_OURO or (hov and ui.C.CREME or nil), destaqueAlfa = sel and 0.5 or (hov and 0.22 or nil) })
    if sel then love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 1); love.graphics.circle("fill", rx + cw - ui.E(5), ry + ui.E(5), ui.E(4)); love.graphics.setColor(0.1, 0.1, 0.15, 1); love.graphics.circle("fill", rx + cw - ui.E(5), ry + ui.E(5), ui.E(2)) end
    ui.txtCabe(c.nome, rx - ui.E(2), ry + ch + ui.E(2), 7, cw + ui.E(4), sel and COR_OURO or ui.C.TEXTO2, "center", 6)
    estado.rectsGaleria[#estado.rectsGaleria + 1] = { x = rx, y = ry, w = cw, h = ch, id = c.id }
  end

  local pv = estado.previewId and cartaDaGaleria(estado.previewId) or estado.galeria[1]
  if pv then
    local pr = ESCOLHA.previa
    ui.txt("PREVIA NA MAO", pr.x - ui.E(20), pr.y - ui.E(24), 12, COR_OURO, "center", pr.w + ui.E(40))
    ui.carta(pv, pr.x, pr.y, pr.w, pr.h, { preencherArte = true })
    ui.txtCabe(pv.nome, pr.x - ui.E(20), pr.y + pr.h + ui.E(8), 15, pr.w + ui.E(40), COR_OURO, "center", 9)
    local tipo = tostring(pv.tipo or "-"); local pct = math.floor(((pv.chance or 1) * 100) + 0.5)
    ui.txt("ID " .. pv.id .. "  |  " .. tipo .. "  |  CHANCE " .. pct .. "%", pr.x - ui.E(20), pr.y + pr.h + ui.E(30), 10, ui.C.TEXTO2, "center", pr.w + ui.E(40))
    ui.textoQuebrado(pv.descricao or "", pr.x - ui.E(20), pr.y + pr.h + ui.E(50), pr.w + ui.E(40), 10, ui.C.DESCRICAO, "left", 7)
  end

  local cheia = #estado.mao >= MAX_MAO
  ui.txt("NA MAO: " .. #estado.mao .. "/" .. MAX_MAO, p.x, p.y + ui.E(16), 12, cheia and COR_VERMELHO or COR_OURO, "right", p.w - ui.E(30))

  local by = p.y + p.h - ui.E(58); local bh = ui.E(40)
  local bLimpar = { x = p.x + ui.E(150), y = by, w = ui.E(130), h = bh }
  local bPadrao = { x = bLimpar.x + bLimpar.w + ui.E(12), y = by, w = ui.E(130), h = bh }
  local bFechar = { x = p.x + p.w - ui.E(30) - ui.E(160), y = by, w = ui.E(160), h = bh }
  estado.rectsEscolha = { limpar = bLimpar, padrao = bPadrao, fechar = bFechar }

  local hovL = hoverX and hoverY and dentro(hoverX, hoverY, bLimpar); local hovP = hoverX and hoverY and dentro(hoverX, hoverY, bPadrao)
  ui.caixa(bLimpar.x, bLimpar.y, bLimpar.w, bLimpar.h, ui.E(6), ui.C.PAINEL, hovL and ui.C.CREME or COR_OURO, ui.E(1.5)); ui.txt("LIMPAR", bLimpar.x, bLimpar.y + ui.E(12), 13, hovL and ui.C.CREME or COR_OURO, "center", bLimpar.w)
  ui.caixa(bPadrao.x, bPadrao.y, bPadrao.w, bPadrao.h, ui.E(6), ui.C.PAINEL, hovP and ui.C.CREME or COR_OURO, ui.E(1.5)); ui.txt("PADRAO", bPadrao.x, bPadrao.y + ui.E(12), 13, hovP and ui.C.CREME or COR_OURO, "center", bPadrao.w)
  ui.botao("FECHAR", bFechar.x, bFechar.y, bFechar.w, bFechar.h, ui.C.VERDE, ui.C.VERDE_CLARO, 16)
end

function animTeste.desenhar()
  if not estado.ativo then return end
  desenharFundo()

  local mx, my = 0, 0
  if estado.tremores > 0 then mx = (love.math.random() - 0.5) * estado.tremores; my = (love.math.random() - 0.5) * estado.tremores end
  love.graphics.push(); love.graphics.translate(mx, my)

  -- Ordem de desenho (igual ao multiplayer).
  desenharMesaCentral()      -- circulo tracejado + espadas (centro)
  desenharPlaca()            -- placa de turno (topo esquerda)
  desenharOponente()         -- painel + barras SAT/PROD + mao (topo)
  desenharDecks()            -- compra/descarte (centro)
  desenharPilhas()           -- pilhas DEFESA/JOGADAS/CURINGA (centro)
  desenharVisor()            -- visor de curingas (centro direita)
  desenharMao()              -- mao do jogador (baixo centro)
  desenharPainelJogador()    -- painel + barras SAT/PROD do jogador (baixo centro)
  desenharAreaSeguraOponente() -- area segura oponente (topo direita)
  desenharAreaSeguraPropria()  -- area segura propria (baixo direita)
  desenharMira()             -- mira de ataque
  desenharAnimacao()         -- carta voando
  desenharParticulas()       -- particulas de impacto
  love.graphics.pop()

  desenharPopups()
  desenharStatusLinha()
  if estado.flash > 0 then love.graphics.setColor(1, 1, 1, estado.flash * 0.35); love.graphics.rectangle("fill", 0, 0, VW, VH) end
  desenharBotoesJogarGuardar()

  if estado.escolhendo then desenharEscolha() else desenharVoltar(); desenharBotaoEscolher() end
end

-- ------------------------------------------------------------
-- Entrada
-- ------------------------------------------------------------
function animTeste.apontar(x, y) if hoverTravado then return end; hoverX, hoverY = x, y end
function animTeste.hoverNaCarta(n) local r = layoutMao(#estado.mao)[n]; if not r then return false end; hoverTravado = { x = r.x + r.w / 2, y = r.y + r.h / 2 }; hoverX, hoverY = hoverTravado.x, hoverTravado.y; return true end
function animTeste.soltarHover() hoverTravado = nil end

function animTeste.clicado(vx, vy)
  if not estado.ativo then return nil end
  if estado.escolhendo then
    local b = estado.rectsEscolha or {}
    if b.fechar and dentro(vx, vy, b.fechar) then animTeste.fecharEscolha(); return "escolha" end
    if b.limpar and dentro(vx, vy, b.limpar) then animTeste.definirMao({}); estado.previewId = estado.galeria[1] and estado.galeria[1].id; return "escolha" end
    if b.padrao and dentro(vx, vy, b.padrao) then animTeste.definirMao(IDS_MAO); estado.previewId = estado.mao[1] and estado.mao[1].id; return "escolha" end
    for _, it in ipairs(estado.rectsGaleria or {}) do if dentro(vx, vy, it) then alternarCartaMao(it.id); estado.previewId = it.id; return "escolha" end end
    return "escolha"
  end
  if dentro(vx, vy, ESCOLHER) then animTeste.abrirEscolha(); return "escolha" end
  if dentro(vx, vy, VOLTAR) then return "voltar" end

  -- Botoes JOGAR/GUARDAR.
  if dentro(vx, vy, BTN_JOGAR) then
    if #estado.selUids > 0 then iniciarAtaque(primeiraSelecionada()) end
    return "jogar"
  end
  if dentro(vx, vy, BTN_GUARDAR) then
    if #estado.selUids > 0 then
      -- Guardar na area segura propria (primeiro slot vazio).
      local c = primeiraSelecionada()
      if c then
        for i = 1, AREA_MAX do
          if not estado.areaSegura[i] then
            estado.areaSegura[i] = c
            -- remove da mao
            for j = #estado.mao, 1, -1 do if estado.mao[j].uid == c.uid then table.remove(estado.mao, j) break end end
            estado.selUids = {}
            estado.selecionada = nil
            estado.rectsMao = layoutMao(#estado.mao)
            addMensagem("Carta guardada na area segura", COR_OURO)
            break
          end
        end
      end
    end
    return "guardar"
  end

  -- Cartas da mao.
  for i = #estado.rectsMao, 1, -1 do
    local c = estado.mao[i]; local r = estado.rectsMao[i]
    if c and r then
      local lift = 0
      for _, uid in ipairs(estado.selUids) do if uid == c.uid then lift = LIFT_SEL; break end end
      local rr = { x = r.x, y = r.y - lift, w = r.w, h = r.h, rot = r.rot }
      if pontoNaCarta(vx, vy, rr) then
        local found = false
        for idx, uid in ipairs(estado.selUids) do
          if uid == c.uid then table.remove(estado.selUids, idx); found = true; break end
        end
        if not found then estado.selUids[#estado.selUids + 1] = c.uid end
        estado.selecionada = c
        estado.modoAlvo = false
        estado.alvoSelecionado = nil
        addMensagem("Carta: " .. c.nome .. (c.precisaAlvo and " (precisa alvo)" or ""), COR_OURO)
        return "carta"
      end
    end
  end

  -- Clique no oponente (alvo).
  local ox, oy = CENTRO - ui.E(65), OP_PAINEL_Y
  local area = { x = ox - ui.E(10), y = oy - ui.E(10), w = ALVO_RECT.w + ui.E(20), h = ALVO_RECT.h + ui.E(20) }
  if dentro(vx, vy, area) then
    if estado.modoAlvo then executarAtaque(primeiraSelecionada(), 1); return "ataque"
    elseif primeiraSelecionada() and not estado.animando then iniciarAtaque(primeiraSelecionada()); return "ataque"
    elseif not primeiraSelecionada() then addMensagem("Escolha uma carta primeiro", COR_VERMELHO) end
    return "alvo"
  end
  return nil
end

function animTeste.teclaPressionada(key)
  if not estado.ativo then return false end
  if estado.escolhendo then if key == "escape" or key == "m" then animTeste.fecharEscolha(); return true end; return false end
  if key == "escape" then return false end
  if key == "m" then animTeste.abrirEscolha(); return true end
  local n = tonumber(key)
  if n and n >= 1 and n <= #estado.mao then
    local c = estado.mao[n]
    local found = false
    for idx, uid in ipairs(estado.selUids) do if uid == c.uid then table.remove(estado.selUids, idx); found = true; break end end
    if not found then estado.selUids[#estado.selUids + 1] = c.uid end
    estado.selecionada = c
    estado.modoAlvo = false
    estado.alvoSelecionado = nil
    addMensagem("Carta: " .. c.nome .. (c.precisaAlvo and " (precisa alvo)" or ""), COR_OURO)
    return true
  end
  if (key == "space" or key == "return") and primeiraSelecionada() then iniciarAtaque(primeiraSelecionada()); return true end
  return false
end

-- ------------------------------------------------------------
-- API
-- ------------------------------------------------------------
function animTeste.iniciar(perfil)
  estado.ativo = true; estado.tempo = 0; estado.selecionada = nil; estado.alvoSelecionado = nil; estado.modoAlvo = false; estado.animando = false; estado.animacao = nil; estado.mensagens = {}; estado.popups = {}; estado.particulas = {}; estado.tremores = 0; estado.flash = 0; estado.opFlash = 0; estado.saldo = 1000; estado.satisfacao = 100; estado.produtividade = 0; estado.bonusSatisfacao = 0; estado.greve = false; estado.nomeJogador = (perfil and perfil.nick) or "JOGADOR_1"; estado.avatarJogador = (perfil and perfil.avatar) or "1"; estado.galeria = construirGaleria(); estado.escolhendo = false; estado.hoverGaleriaId = nil; estado.previewId = estado.galeria[1] and estado.galeria[1].id or nil; estado.rectsGaleria = {}; estado.rectsEscolha = {}; estado.selUids = {}; estado.areaSegura = {}; montarCartas(); if not fundoMesa then fundoMesa = madeira.gerar(VW, VH) end
end

function animTeste.encerrar() estado.ativo = false; estado.animando = false; estado.animacao = nil; estado.escolhendo = false end
function animTeste.selecionar(n) local c = estado.mao[n]; if c then estado.selecionada = c end; return c ~= nil end
function animTeste.atacar() if estado.selecionada then iniciarAtaque(estado.selecionada) end end
function animTeste.definirMao(ids) estado.mao = {}; for _, id in ipairs(ids) do local c = novaCarta(id); if c then estado.mao[#estado.mao + 1] = c end end; estado.rectsMao = layoutMao(#estado.mao) end
function animTeste.abrirEscolha() if not estado.escolhendo then estado.escolhendo = true; estado.previewId = estado.mao[1] and estado.mao[1].id or estado.galeria[1].id end end
function animTeste.fecharEscolha() estado.escolhendo = false; estado.hoverGaleriaId = nil end

return animTeste