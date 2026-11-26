-- AnimacaoInicioBatalha (port de src/components/arena/AnimacaoInicioBatalha.js):
-- overlay escuro + raios girando, texto "QUEM COMECA / A BATALHA?", quadro
-- sorteando (16 trancos desacelerando) e parando no jogador ativo, confete e
-- fade final (~6.5s). Sem skip (igual ao React).
local ui = require "ui"
local arte = require "arte"
local anim = require "anim"
local som = require "som"
local fx = require "fx"

local I = {}

local VW, VH = 1280, 720
local NUM_RAIOS = 12
local NUM_CONFETES = 18
local CORES_CONFETE = { "#FFD54F", "#C62828", "#FFF8E7", "#7C8AAC" }
local TOTAL_TRANCOS = 16

local st = nil
-- Geracao da intro: incrementada a cada iniciar(). Callbacks agendados em
-- anim.depois (agora global) sao embrulhados com seguro(): se a intro foi
-- limpa (st = nil) ou reiniciada, o callback antigo vira no-op em vez de
-- mexer numa st orfa ou na nova st.
local geracao = 0

local function seguro(fn)
  local g = geracao
  return function()
    if st and geracao == g then fn() end
  end
end

-- Wrappers de easing para manter o comportamento visual original:
-- saidaExcesso (c=1.1) e saidaExcessoSuave (c=0.55) do Reanimated.
local function saidaExcesso(k) return anim.saidaExcesso(k) end
local function saidaExcessoSuave(k) return anim.saidaExcesso(k, 0.55) end

local function novoConfete()
  return {
    x = (love.math.random() - 0.5) * VW * 0.9,
    atraso = love.math.random() * 0.25,
    duracao = 0.9 + love.math.random() * 0.5,
    rotFinal = (love.math.random() > 0.5 and 1 or -1)
      * (40 + love.math.random() * 80),
    cor = ui.hex(CORES_CONFETE[love.math.random(#CORES_CONFETE)]),
    tam = 6 + love.math.random() * 5,
  }
end

-- Brasas ambientes da intro (paleta Tormentalia: ouro, vinho, branco,
-- cinza azulado). Sobem devagar e renascem por baixo.
local function novasBrasasIntro()
  local cores = {
    { 1.00, 0.84, 0.31 },   -- ouro
    { 0.68, 0.16, 0.18 },   -- vinho/vermelho
    { 0.95, 0.93, 0.88 },   -- branco luminoso
    { 0.49, 0.54, 0.67 },   -- cinza azulado
  }
  local bs = {}
  for i = 1, 24 do
    bs[i] = {
      x = love.math.random() * VW,
      y = love.math.random() * VH,
      vy = 8 + love.math.random() * 22,
      tam = math.max(1, math.floor(ui.E(1))),
      cor = cores[love.math.random(#cores)],
      alfa = 0.15 + love.math.random() * 0.35,
      fase = love.math.random() * math.pi * 2,
      velPisca = 1.3 + love.math.random() * 2.2,
    }
  end
  return bs
end

-- opcoes: { ativo = idx 0-based que comeca, jogadores = { {nome=, avatar=}, ... } }
function I.iniciar(opcoes)
  opcoes = opcoes or {}
  local lista = opcoes.jogadores or {}
  if #lista == 0 then
    lista = {
      { nome = "JOGADOR", avatar = arte.avatar("voce") },
      { nome = "OPONENTE", avatar = arte.avatar("ia") },
    }
  end
  local escolhido = math.min(math.max(opcoes.ativo or 0, 0), #lista - 1)

  geracao = geracao + 1
  st = {
    t = 0,
    fase = "intro",
    lista = lista,
    escolhido = escolhido,
    idxExibido = 0,
    corTema = escolhido == 0 and ui.hex "#FFD54F" or ui.hex "#C62828",
    tw = {
      overlay = { v = 0 },
      perguntaOp = { v = 0 },
      perguntaEsc = { v = 0.5 },
      quadroEsc = { v = 0 },
      quadroRot = { v = 0 },
      flip = { v = 1 },
      revel = { v = 0 },
      flash = { v = 0 },
    },
    brasas = novasBrasasIntro(),
    trancos = 0,
    proxTranco = nil,
    confetes = nil,
    confT = nil,
    pulso = 0.3,
    raiosRot = 0,
    completo = false,
  }

  anim.tween(st.tw.overlay, { v = 1 }, 0.4, anim.linear)
  anim.tween(st.tw.perguntaOp, { v = 1 }, 0.5, anim.linear)
  anim.tween(st.tw.perguntaEsc, { v = 1 }, 0.7, anim.saidaExcesso)
  anim.depois(1.1, seguro(function()
    if st.fase ~= "intro" then return end
    st.fase = "rolling"
    -- Roleta: toca na virada para o quadro girar; o wav tem os 16 trancos
    -- na mesma escada de desaceleracao destes timers (case tranco a tranco).
    som.tocar("roleta")
    anim.tween(st.tw.perguntaOp, { v = 0 }, 0.2, anim.linear)
    anim.tween(st.tw.quadroEsc, { v = 1 }, 0.45, saidaExcessoSuave)
    st.proxTranco = 0.15
  end))
end

local function proximoTranco()
  st.trancos = st.trancos + 1
  local progresso = st.trancos / TOTAL_TRANCOS

  if #st.lista > 1 then
    local novo = love.math.random(#st.lista)
    if novo - 1 == st.idxExibido then
      novo = (st.idxExibido + 1) % #st.lista + 1
    end
    st.idxExibido = novo - 1
  end

  -- tranco visual: chacoalha e volta
  anim.tween(st.tw.quadroRot, { v = (love.math.random() - 0.5) * 14 }, 0.055, anim.linear)
  anim.tween(st.tw.quadroEsc, { v = 1.05 }, 0.055, anim.linear)
  anim.depois(0.055, seguro(function()
    anim.tween(st.tw.quadroRot, { v = 0 }, 0.22, anim.saidaCubica)
    anim.tween(st.tw.quadroEsc, { v = 1 }, 0.3, saidaExcessoSuave)
  end))

  if st.trancos < TOTAL_TRANCOS then
    local atraso = 0.04 + progresso * progresso * 0.3
    anim.depois(atraso, seguro(proximoTranco))
  else
    -- Parada no escolhido: pequeno tranco e "virada de carta" (fecha,
    -- troca o avatar no meio, abre). Assim a troca nao aparece seca.
    anim.tween(st.tw.quadroEsc, { v = 1.14 }, 0.09, anim.linear)
    anim.depois(0.09, seguro(function() anim.tween(st.tw.quadroEsc, { v = 1 }, 0.4, saidaExcesso) end))
    anim.tween(st.tw.flip, { v = 0.02 }, 0.12, anim.entradaCubica)
    anim.depois(0.12, seguro(function()
      st.idxExibido = st.escolhido
      anim.tween(st.tw.flip, { v = 1 }, 0.20, saidaExcesso)
    end))
    anim.depois(0.48, seguro(function()
      if st.fase ~= "rolling" then return end
      st.fase = "resultado"
      -- Festa: revela o jogador escolhido (mesmo instante do flash,
      -- shake e confete; a roleta ja parou 0.48s antes).
      som.tocar("festa")
      fx.bater(0.8)
      anim.tween(st.tw.revel, { v = 1 }, 0.3, anim.linear)
      anim.tween(st.tw.flash, { v = 0.85 }, 0.09, anim.linear)
      anim.depois(0.09, seguro(function() anim.tween(st.tw.flash, { v = 0 }, 0.25, anim.linear) end))
      st.confetes = {}
      for _ = 1, NUM_CONFETES do
        st.confetes[#st.confetes + 1] = novoConfete()
      end
      st.confT = 0
      anim.depois(2.2, seguro(function()
        anim.tween(st.tw.overlay, { v = 0 }, 0.5, anim.linear)
        anim.depois(0.5, seguro(function() st.completo = true end))
      end))
    end))
  end
end

-- Devolve true quando a animacao terminou (chamar onCompleto).
function I.atualizar(dt)
  if not st or st.completo then return st ~= nil end
  st.t = st.t + dt
  st.raiosRot = (st.raiosRot + dt / 8) % 1

  -- glow: sobe 0.9s e desce 0.9s (0.3 -> 1 -> 0.3)
  st.pulso = st.pulso + (st.pulso < 0.65 and dt / 0.9 or -dt / 0.9)
  if st.pulso > 1 then st.pulso = 1 - (st.pulso - 1) end
  if st.pulso < 0.3 then st.pulso = 0.3 + (0.3 - st.pulso) end

  if st.proxTranco and st.fase == "rolling" then
    st.proxTranco = st.proxTranco - dt
    if st.proxTranco <= 0 then
      st.proxTranco = nil
      proximoTranco()
    end
  end
  -- os tweens da intro sao avançados pelo anim.update(dt) global em
  -- main.lua (nao chame aqui para evitar rodar duas vezes por frame).
  if st.brasas then
    for _, b in ipairs(st.brasas) do
      b.y = b.y - b.vy * dt
      if b.y < -ui.E(10) then
        b.y = VH + ui.E(10)
        b.x = love.math.random() * VW
      end
    end
  end
  if st.confT then
    st.confT = st.confT + dt
  end
  return st.completo
end

local function desenharRaios(oA)
  oA = oA or 1
  -- Brilho central suave (atmosfera) antes dos raios.
  love.graphics.setColor(1, 213 / 255, 79 / 255, 0.05 * oA)
  love.graphics.circle("fill", VW / 2, VH / 2, ui.E(260))

  local h = VH * 0.9
  love.graphics.push()
  love.graphics.translate(VW / 2, VH / 2)
  love.graphics.rotate(st.raiosRot * 2 * math.pi)
  for i = 0, NUM_RAIOS - 1 do
    love.graphics.push()
    love.graphics.rotate((360 / NUM_RAIOS) * i * math.pi / 180)
    if i % 4 == 0 then
      -- Feixes de azul profundo pontuam a roda.
      love.graphics.setColor(21 / 255, 101 / 255, 192 / 255, 0.07 * oA)
    else
      love.graphics.setColor(255 / 255, 213 / 255, 79 / 255, 0.06 * oA)
    end
    local w = ui.E(3)
    love.graphics.rectangle("fill", -w / 2, -h / 2, w, h)
    love.graphics.pop()
  end
  love.graphics.pop()
end

-- Vinheta: escurece as bordas em camadas (sem shader), mantendo o
-- centro limpo para o quadro/texto.
local function desenharVinheta(oA)
  local passo = math.max(1, ui.E(8))
  local camadas = 12
  for i = 1, camadas do
    local t = i / camadas
    local a = 0.42 * (t * t) * oA
    local d = (i - 1) * passo
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.rectangle("fill", 0, d, VW, passo)
    love.graphics.rectangle("fill", 0, VH - d - passo, VW, passo)
    love.graphics.rectangle("fill", d, 0, passo, VH)
    love.graphics.rectangle("fill", VW - d - passo, 0, passo, VH)
  end
end

-- Brasas ambientes subindo atras de tudo (paleta Tormentalia).
local function desenharBrasas(oA)
  if not st.brasas then return end
  for _, b in ipairs(st.brasas) do
    local pisca = 0.5 + 0.5 * math.sin(st.t * b.velPisca + b.fase)
    local alfa = b.alfa * pisca * oA
    if alfa > 0.01 then
      love.graphics.setColor(b.cor[1], b.cor[2], b.cor[3], alfa)
      love.graphics.rectangle("fill", math.floor(b.x), math.floor(b.y),
        b.tam, b.tam)
    end
  end
end

local function desenharPergunta(oA)
  local esc = st.tw.perguntaEsc.v
  local op = st.tw.perguntaOp.v * oA
  if op <= 0.01 then return end
  local t1, t2 = "QUEM COMECA", "A BATALHA?"
  local tam1, tam2 = ui.E(28), ui.E(36)
  local ls1, ls2 = ui.E(4), ui.E(6)
  local alt1 = ui.alturaTexto(tam1)
  local alt2 = ui.alturaTexto(tam2)
  local gap = ui.E(8)
  local hTotal = alt1 + gap + alt2

  love.graphics.push()
  love.graphics.translate(VW / 2, VH / 2)
  love.graphics.scale(esc, esc)
  local y = -hTotal / 2
  ui.txtEspacado(t1, 3, y + 3, tam1, { 0, 0, 0, 0.9 * op }, ls1)
  ui.txtEspacado(t1, 0, y, tam1,
    { 170 / 255, 170 / 255, 170 / 255, op }, ls1)
  y = y + alt1 + gap
  ui.txtEspacado(t2, 3, y + 3, tam2, { 0, 0, 0, 0.9 * op }, ls2)
  ui.txtEspacado(t2, 0, y, tam2,
    { 255 / 255, 213 / 255, 79 / 255, op }, ls2)
  love.graphics.pop()
end

local function desenharQuadro(oA)
  local esc = st.tw.quadroEsc.v
  local rot = st.tw.quadroRot.v
  if esc <= 0.01 then return end

  local Q = ui.E(140)          -- quadro 140x140
  local raioEx = ui.E(20)
  local borda = ui.E(4)
  local pad = ui.E(6)
  local cx, cy = VW / 2, VH / 2

  -- glow pulsante atras do quadro (190x190)
  local baseA = (st.fase == "resultado") and (85 / 255) or 0.3
  local pulsoOp = 0.25 + 0.3 * ((st.pulso - 0.3) / 0.7)
  local corGlow = st.fase == "resultado" and st.corTema
    or { 255 / 255, 213 / 255, 79 / 255 }
  love.graphics.setColor(corGlow[1], corGlow[2], corGlow[3],
    baseA * pulsoOp * oA)
  love.graphics.circle("fill", cx, cy, ui.E(95))

  -- sombra dourada do quadro (shadowRadius 14)
  love.graphics.setColor(1, 213 / 255, 79 / 255, 0.30 * oA)
  love.graphics.rectangle("fill", cx - Q / 2 - 14, cy - Q / 2 - 14,
    Q + 28, Q + 28, raioEx + 14, raioEx + 14, 8)
  love.graphics.setColor(1, 213 / 255, 79 / 255, 0.16 * oA)
  love.graphics.rectangle("fill", cx - Q / 2 - 26, cy - Q / 2 - 26,
    Q + 52, Q + 52, raioEx + 26, raioEx + 26, 8)

  local flip = math.max(st.tw.flip.v, 0.02)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(rot * math.pi / 180)
  love.graphics.scale(esc * flip, esc)

  -- borda externa (#E8B923 / #FFF3C4)
  local bx, by = -Q / 2, -Q / 2
  love.graphics.setColor(232 / 255, 185 / 255, 35 / 255, 1)
  love.graphics.rectangle("fill", bx, by, Q, Q, raioEx, raioEx, 8)
  love.graphics.setColor(1, 243 / 255, 196 / 255, 1)
  love.graphics.setLineWidth(borda)
  love.graphics.rectangle("line", bx + borda / 2, by + borda / 2,
    Q - borda, Q - borda, raioEx, raioEx, 8)
  love.graphics.setLineWidth(1)

  -- miolo (#1C2238)
  local mx, my = bx + pad, by + pad
  local mw, mh = Q - pad * 2, Q - pad * 2
  local raioMiolo = ui.E(14)
  love.graphics.setColor(28 / 255, 34 / 255, 56 / 255, 1)
  love.graphics.rectangle("fill", mx, my, mw, mh, raioMiolo, raioMiolo, 8)
  love.graphics.setColor(1, 243 / 255, 196 / 255, 1)
  love.graphics.setLineWidth(ui.E(2))
  love.graphics.rectangle("line", mx + ui.E(1), my + ui.E(1),
    mw - ui.E(2), mh - ui.E(2), raioMiolo, raioMiolo, 8)
  love.graphics.setLineWidth(1)

  -- avatar (cover, com overflow hidden). O scissor do LÖVE esta em
  -- coordenadas de tela (nao sofre a transformacao atual), entao converte
  -- os cantos do miolo e usa o bounding box (inclui rotacao do tranco).
  local atual = st.lista[st.idxExibido + 1] or st.lista[st.escolhido + 1]
  if atual and atual.avatar then
    local x1, y1 = love.graphics.transformPoint(mx, my)
    local x2, y2 = love.graphics.transformPoint(mx + mw, my)
    local x3, y3 = love.graphics.transformPoint(mx, my + mh)
    local x4, y4 = love.graphics.transformPoint(mx + mw, my + mh)
    local sx = math.min(x1, x2, x3, x4)
    local sy = math.min(y1, y2, y3, y4)
    love.graphics.setScissor(sx, sy,
      math.max(x1, x2, x3, x4) - sx,
      math.max(y1, y2, y3, y4) - sy)
    ui.imagemCover(atual.avatar, mx, my, mw, mh)
    love.graphics.setScissor()
  end

  -- faixa de nome
  local tamNome = ui.E(12)
  local altNome = ui.alturaTexto(tamNome) + ui.E(5) * 2
  love.graphics.setColor(0, 0, 0, 0.62)
  love.graphics.rectangle("fill", mx, my + mh - altNome, mw, altNome)
  local nome = (atual and atual.nome) or ""
  ui.txtEspacado(nome, mx, my + mh - altNome + ui.E(5), tamNome,
    { 1, 213 / 255, 79 / 255, 1 }, ui.E(1), mw)

  love.graphics.pop()
end

local function desenharConfetes(oA)
  if not st.confetes then return end
  for _, c in ipairs(st.confetes) do
    local p = (st.confT - c.atraso) / c.duracao
    if p >= 0 then
      if p > 1 then p = 1 end
      local y = -ui.E(40) + (VH * 0.7 + ui.E(40)) * p
      local rot = c.rotFinal * p * math.pi / 180
      local alfa = (p <= 0.85 and 1 or (1 - (p - 0.85) / 0.15)) * oA
      local w = ui.E(c.tam)
      love.graphics.push()
      love.graphics.translate(VW / 2 + c.x, y)
      love.graphics.rotate(rot)
      love.graphics.setColor(c.cor[1], c.cor[2], c.cor[3], alfa)
      love.graphics.rectangle("fill", -w / 2, -w / 2, w, w, 1, 1, 2)
      love.graphics.pop()
    end
  end
end

local FRASE_RESULTADO = "A BATALHA COMECA"

-- Texto do resultado aparecendo letra a letra (typewriter), com cursor
-- dourado piscando enquanto ainda ha o que escrever.
local function desenharTypewriter(oA)
  local confT = st.confT or 0
  local n = math.floor(math.max(0, confT - 0.15) / 0.05)
  if n > #FRASE_RESULTADO then n = #FRASE_RESULTADO end
  if n <= 0 then return end
  local typed = FRASE_RESULTADO:sub(1, n)
  local tam = ui.E(16)
  local larg = ui.larguraTexto(typed, tam)
  local x = math.floor(VW / 2 - larg / 2)
  local y = math.floor(VH / 2 + ui.E(120))
  ui.txt(typed, x, y, tam, ui.C.CREME, nil, nil, oA)
  local pisca = (math.floor(confT * 6) % 2 == 0)
  if n < #FRASE_RESULTADO and pisca then
    love.graphics.setColor(1, 213 / 255, 79 / 255, oA)
    love.graphics.rectangle("fill", x + larg + ui.E(3), y, ui.E(7), ui.E(15))
  end
end

function I.desenhar()
  if not st then return end
  local oA = st.tw.overlay.v
  local sx, sy = fx.offset()

  love.graphics.push()
  love.graphics.translate(sx, sy)

  -- overlay
  love.graphics.setColor(5 / 255, 5 / 255, 20 / 255, 0.95 * oA)
  ui.preencherTela(VW, VH)

  -- flash dourado
  local fa = st.tw.flash.v * oA
  if fa > 0.01 then
    love.graphics.setColor(1, 213 / 255, 79 / 255, fa)
    ui.preencherTela(VW, VH)
  end

  -- Atmosfera: brasas subindo, raios e vinheta nas bordas.
  desenharBrasas(oA)
  desenharRaios(oA)
  desenharVinheta(oA)

  if st.fase == "intro" then
    desenharPergunta(oA)
  else
    desenharQuadro(oA)
  end

  if st.fase == "resultado" then
    -- revelacaoGlow (18%..82% x, topo 30%, altura 200)
    local ra = 0.10 * st.tw.revel.v * oA
    if ra > 0.01 then
      love.graphics.setColor(1, 213 / 255, 79 / 255, ra)
      local gy = VH * 0.3
      love.graphics.rectangle("fill", VW * 0.18, gy, VW * 0.64, ui.E(200),
        ui.E(100), ui.E(100), 8)
    end
    -- Anel de resultado pulsante ao redor do quadro (cor do tema).
    local rv = st.tw.revel.v
    if rv > 0.01 then
      local confT = st.confT or 0
      local onda = math.sin(confT * 4.5) * 0.5 + 0.5
      local r = ui.E(96) + math.floor(onda * ui.E(10))
      love.graphics.setColor(st.corTema[1], st.corTema[2], st.corTema[3],
        0.55 * rv * oA)
      love.graphics.setLineWidth(ui.E(3))
      love.graphics.circle("line", VW / 2, VH / 2, r)
      love.graphics.setColor(1, 213 / 255, 79 / 255, 0.35 * rv * oA)
      love.graphics.setLineWidth(ui.E(1))
      love.graphics.circle("line", VW / 2, VH / 2, r + ui.E(10))
      love.graphics.setLineWidth(1)
    end
    desenharConfetes(oA)
    desenharTypewriter(oA)
  end

  love.graphics.pop()
end

function I.ativo()
  return st ~= nil
end

function I.limpar()
  st = nil
end

return I
