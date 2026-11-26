-- impacto.lua — Feedback visual das jogadas (Etapa 5): estouro de impacto da
-- carta, numeros flutuantes de Satisfacao/Produtividade, estilhaco de falha,
-- escudo de protecao, aviso de falencia (slow-motion) e a entrada da mao do
-- Deus Mercado. Modulo puramente visual: o main alimenta os eventos e chama
-- atualizar/desehar uma vez por frame. Nenhuma regra de jogo mora aqui.
--
-- Paleta Tormentalia: ouro, azul profundo, vinho, branco luminoso e cinza.
-- Deslocamentos e tamanhos sao inteiros (pixel art sem borrar).
local ui = require "ui"
local fx = require "fx"
local som = require "som"
local arte = require "arte"

local M = {}

local VW, VH = 1280, 720
local OURO = ui.C.OURO
local VINHO = ui.C.VERMELHO
local ACO = ui.hex "#42A5F5"     -- azul claro de apoio (escudo)
local CINZA = { 0.55, 0.58, 0.66 }

-- Estilo do estouro por tipo de carta, preso a paleta Tormentalia: ACAO
-- estoura vinho (agressao), EFEITO azul (mercado) e PROTECAO/CURINGA ouro.
-- A `forca` entra no raio, no numero de faiscas e no trauma.
local TIPO_FX = {
  ACAO = { cor = VINHO, forca = 1.0 },
  EFEITO = { cor = ACO, forca = 0.85 },
  PROTECAO = { cor = OURO, forca = 0.8 },
  CORINGA = { cor = OURO, forca = 1.15 },
  MEDIDA = { cor = OURO, forca = 0.8 },
  BONUS = { cor = OURO, forca = 0.8 },
}

-- Lista unica de efeitos ativos. Cada item tem `tipo`, `t`, `dur`.
local itens = {}
local t = 0

local function limpar()
  itens = {}
  t = 0
end
M.limpar = limpar

function M.ativo()
  return #itens > 0
end

-- Formatadores curtos (ASCII): "+10 SAT", "-25% PROD".
local function fmtInt(v, sufixo)
  local n = math.floor(math.abs(v) + 0.5)
  return (v > 0 and "+" or "-") .. n .. (sufixo or "")
end

local function fmtPct(v, sufixo)
  local n = math.floor(math.abs(v) * 100 + 0.5)
  return (v > 0 and "+" or "-") .. n .. "%" .. (sufixo or "")
end

-- Snapshot das barras e da falencia por seat, para o main comparar depois de
-- aplicar a leva. `partida` fica solta (o chamador cuida do nil).
function M.snapshot(partida)
  local s = { bar = {}, falido = {} }
  if not partida or not partida.jogadores then return s end
  for i, j in ipairs(partida.jogadores) do
    s.bar[i] = { sat = j.satisfacao or 0, prod = j.produtividade or 0 }
    s.falido[i] = j.falido and true or false
  end
  return s
end

-- Estouro de impacto no ponto de pouso da carta: anel, "squash" da mesa e
-- faiscas na paleta. Aplica hit-stop e trauma curtos (fx respeita o flag).
function M.impacto(x, y, cor, forca)
  if not x or not y then return end
  cor = cor or OURO
  forca = forca or 1

  itens[#itens + 1] = {
    tipo = "onda", x = x, y = y, t = 0,
    dur = 0.34 + 0.10 * forca, cor = cor, forca = forca,
  }
  -- O "squash" e a mesa reagindo: elipse achatada abrindo no ponto de pouso.
  itens[#itens + 1] = {
    tipo = "squash", x = x, y = y, t = 0, dur = 0.26, cor = cor,
  }

  local n = math.floor(8 + 10 * forca)
  for i = 1, n do
    local a = (i / n) * math.pi * 2 + love.math.random() * 0.6
    local v = (70 + love.math.random() * 190) * forca
    itens[#itens + 1] = {
      tipo = "faisca", x = x, y = y,
      vx = math.cos(a) * v, vy = math.sin(a) * v - 70,
      t = 0, dur = 0.30 + love.math.random() * 0.34,
      cor = cor, tam = math.max(2, ui.E(1 + love.math.random() * 2)),
      rot = love.math.random() * 6.28,
      vr = (love.math.random() * 2 - 1) * 8,
    }
  end

  fx.hitstop(0.04)
  fx.bater(0.28 * forca)
end

-- Numero/texto flutuante que sobe e some (ganho em ouro, perda em vinho).
function M.flutuante(texto, x, y, cor, tam, dur)
  itens[#itens + 1] = {
    tipo = "flutuante", texto = tostring(texto), x = x, y = y, t = 0,
    dur = dur or 1.25, cor = cor or OURO, tam = tam or ui.E(18),
  }
end

-- Anel/escudo pulsante no alvo protegido.
function M.escudo(x, y, raio, cor)
  itens[#itens + 1] = {
    tipo = "escudo", x = x, y = y, raio = raio or ui.E(34), t = 0,
    dur = 0.85, cor = cor or ACO,
  }
end

-- Estilhaco de carta que falhou: lascas girando e caindo.
function M.estilhaco(x, y, cor, n)
  cor = cor or VINHO
  n = n or 14
  for i = 1, n do
    local a = love.math.random() * math.pi * 2
    local v = 70 + love.math.random() * 210
    itens[#itens + 1] = {
      tipo = "lasca", x = x, y = y,
      vx = math.cos(a) * v, vy = math.sin(a) * v - 100,
      t = 0, dur = 0.45 + love.math.random() * 0.45,
      cor = cor, tam = math.max(2, ui.E(1.5 + love.math.random() * 2.5)),
      rot = love.math.random() * 6.28,
      vr = (love.math.random() * 2 - 1) * 12,
    }
  end
end

-- Carta negada: estilhaco + texto FALHOU + hit-stop + som de erro opcional
-- (o som "erro" pode nao existir: som.tocar falha em silencio).
function M.falha(x, y)
  M.estilhaco(x, y, VINHO, 16)
  M.flutuante("FALHOU", x, y - ui.E(30), VINHO, ui.E(20), 1.1)
  fx.hitstop(0.07)
  fx.bater(0.35)
  som.tocar("erro", 0.55)
end

-- Entrada da mao do Deus Mercado: mao dourada desce do topo, chuva de
-- moedas e titulo batendo em escala. Sem asset novo (tudo vetorial).
function M.deusMercado()
  itens[#itens + 1] = { tipo = "deus", x = VW / 2, t = 0, dur = 2.0 }
  for i = 1, 22 do
    itens[#itens + 1] = {
      tipo = "moeda",
      x = VW / 2 + (love.math.random() * 2 - 1) * ui.E(120),
      y = VH * 0.24 + love.math.random() * ui.E(30),
      vx = (love.math.random() * 2 - 1) * 40,
      vy = -60 - love.math.random() * 90,
      t = 0, dur = 1.0 + love.math.random() * 0.7,
      tam = ui.E(4 + love.math.random() * 3),
      rot = love.math.random() * 6.28,
      vr = (love.math.random() * 2 - 1) * 6,
    }
  end
  fx.flash(OURO, 0.3, 0.25)
  fx.bater(0.3)
  som.tocar("festa", 0.6)
end

-- Consome os eventos de uma leva: diff de SAT/PROD, escudo de protecao,
-- falencia (cinza/lento/aviso) e impacto/estilhaco no ponto de pouso.
-- `listaRes` e uma lista de resultados de jogo.aplicarCarta.
function M.feedback(partida, listaRes, snap, x, y, posFn, posEscudoFn)
  if not partida then return end
  posFn = posFn or function() return VW / 2, VH / 2, ui.E(16) end
  posEscudoFn = posEscudoFn or posFn

  local falhou = false
  local protegidos = {}
  local estilo = nil
  for _, res in ipairs(listaRes or {}) do
    if res then
      if res.sucesso == false then falhou = true end
      if res.protecao then
        for _, i in ipairs(res.protecao) do protegidos[i] = true end
      end
      -- A leva pode ter varias cartas: o estouro usa a mais forte.
      local e = res.carta and TIPO_FX[res.carta.tipo]
      if e and (not estilo or e.forca > estilo.forca) then estilo = e end
    end
  end

  if falhou then
    M.falha(x or VW / 2, y or VH * 0.45)
  elseif x and y and #(listaRes or {}) > 0 then
    M.impacto(x, y, estilo and estilo.cor or OURO,
      estilo and estilo.forca or 0.75)
  end

  local function flutuar(painel, texto, px, py, cor, tam)
    if painel and ui._layout then
      ui._layout.addFlutuante(painel, texto, cor)
    else
      M.flutuante(texto, px, py, cor, tam)
    end
  end

  if snap and snap.bar then
    for i, j in ipairs(partida.jogadores) do
      local a = snap.bar[i]
      if a and not j.saiu then
        local px, py, tam, painel = posFn(i)
        local ds = (j.satisfacao or 0) - a.sat
        local dp = (j.produtividade or 0) - a.prod
        if math.abs(ds) >= 0.5 then
          flutuar(painel, fmtInt(ds, " SAT"), px, py - ui.E(28),
            ds > 0 and ui.C.SUCESSO or VINHO, tam)
        end
        if math.abs(dp) >= 0.005 then
          flutuar(painel, fmtPct(dp, " PROD"), px, py + ui.E(20),
            ui.C.OURO, tam)
        end
      end
    end

    -- Falencia: cinza, slow-motion e aviso grande no seat.
    for i, j in ipairs(partida.jogadores) do
      if j.falido and snap.falido and not snap.falido[i] then
        local px, py = posFn(i)
        M.flutuante("FALENCIA!", px, py - ui.E(60), VINHO, ui.E(22), 2.1)
        M.estilhaco(px, py, VINHO, 20)
        fx.lento(0.35, 0.9)
        fx.flash({ 0.55, 0.55, 0.62 }, 0.4, 0.35)
      end
    end
  end

  for i in pairs(protegidos) do
    local px, py = posEscudoFn(i)
    M.escudo(px, py - ui.E(4), ui.E(34))
  end
end

function M.atualizar(dt)
  if not dt or dt <= 0 then return end
  t = t + dt
  for i = #itens, 1, -1 do
    local e = itens[i]
    e.t = e.t + dt
    if e.tipo == "faisca" or e.tipo == "lasca" then
      e.vy = e.vy + 1000 * dt
      e.x = e.x + e.vx * dt
      e.y = e.y + e.vy * dt
      e.rot = (e.rot or 0) + (e.vr or 0) * dt
    elseif e.tipo == "moeda" then
      e.vy = e.vy + 520 * dt
      e.x = e.x + e.vx * dt
      e.y = e.y + e.vy * dt
      e.rot = (e.rot or 0) + (e.vr or 0) * dt
    elseif e.tipo == "flutuante" then
      e.y = e.y - ui.E(24) * dt
    end
    if e.t >= e.dur then table.remove(itens, i) end
  end
end

-- Desenho ---------------------------------------------------------------

local function desenharMao(cx, cy, alfa)
  local lw = ui.E(2)
  local escuro = { 0.05, 0.04, 0.09 }
  local pw, ph = ui.E(64), ui.E(52)

  -- Palma.
  love.graphics.setColor(escuro[1], escuro[2], escuro[3], 0.55 * alfa)
  love.graphics.rectangle("fill", cx - pw / 2, cy, pw, ph,
    ui.E(10), ui.E(10), 4)
  love.graphics.setLineWidth(lw)
  love.graphics.setColor(OURO[1], OURO[2], OURO[3], 0.9 * alfa)
  love.graphics.rectangle("line", cx - pw / 2, cy, pw, ph,
    ui.E(10), ui.E(10), 4)

  -- Quatro dedos para cima.
  local fw = ui.E(12)
  local esp = pw / 4.6
  for i = -1.5, 1.5, 1 do
    local fx2 = cx + i * esp - fw / 2
    local fh = ph * (0.85 + 0.12 * (1 - math.abs(i) / 1.5))
    love.graphics.setColor(escuro[1], escuro[2], escuro[3], 0.55 * alfa)
    love.graphics.rectangle("fill", fx2, cy - fh + ui.E(6), fw, fh,
      ui.E(6), ui.E(6), 3)
    love.graphics.setColor(OURO[1], OURO[2], OURO[3], 0.9 * alfa)
    love.graphics.rectangle("line", fx2, cy - fh + ui.E(6), fw, fh,
      ui.E(6), ui.E(6), 3)
  end

  -- Polegar rotacionado a esquerda.
  love.graphics.push()
  love.graphics.translate(cx - pw / 2 - ui.E(6), cy + ph * 0.45)
  love.graphics.rotate(-0.6)
  love.graphics.setColor(escuro[1], escuro[2], escuro[3], 0.55 * alfa)
  love.graphics.rectangle("fill", 0, -ui.E(7), ui.E(34), ui.E(14),
    ui.E(7), ui.E(7), 3)
  love.graphics.setColor(OURO[1], OURO[2], OURO[3], 0.9 * alfa)
  love.graphics.rectangle("line", 0, -ui.E(7), ui.E(34), ui.E(14),
    ui.E(7), ui.E(7), 3)
  love.graphics.pop()
  love.graphics.setLineWidth(1)
end

local function desenharDeus(e)
  local entrada = math.min(1, e.t / 0.30)
  local eo = 1 - (1 - entrada) ^ 3
  local yAlvo = VH * 0.24
  local cy = -ui.E(190) + (yAlvo + ui.E(190)) * eo
  local saida = e.t > e.dur - 0.5 and (e.dur - e.t) / 0.5 or 1
  local alfa = math.max(0, math.min(1, saida))

  -- Halo dourado atras da mao.
  love.graphics.setColor(OURO[1], OURO[2], OURO[3], 0.08 * alfa)
  love.graphics.circle("fill", VW / 2, yAlvo + ui.E(40), ui.E(230))

  -- Mao do Deus Mercado: arte dedicada (fundo transparente) desce do topo.
  -- O desenho vetorial antigo fica so como fallback se a imagem faltar.
  local imgInterfere = arte.img("deus_interfere")
  if imgInterfere then
    local iw, ih = imgInterfere:getDimensions()
    local esc = VW / iw
    -- O centro da mao na arte fica em ~47% da altura: alinha esse ponto
    -- ao alvo animado (cy) para a entrada continuar descendo do topo.
    local oy = cy - ih * 0.47 * esc
    love.graphics.setColor(1, 1, 1, alfa)
    love.graphics.draw(imgInterfere, 0, oy, 0, esc, esc)
  else
    desenharMao(VW / 2, cy, alfa)
  end

  -- Titulo bate grande -> normal nos primeiros 0.15s (escala, sem criar
  -- fontes novas a cada frame).
  local k = 1 + math.max(0, 0.15 - e.t) * 4
  local ty = cy + ui.E(84)
  love.graphics.push()
  love.graphics.translate(VW / 2, ty)
  love.graphics.scale(k, k)
  love.graphics.translate(-VW / 2, -ty)
  ui.txt("DEUS MERCADO", 0, math.floor(ty), ui.E(26), OURO,
    "center", VW, alfa)
  love.graphics.pop()
end

function M.desenhar()
  if #itens == 0 then return end
  for _, e in ipairs(itens) do
    local p = math.min(1, e.t / e.dur)
    local a = 1 - p

    if e.tipo == "onda" then
      local r = ui.E(10) + p * ui.E(46) * (0.6 + 0.4 * (e.forca or 1))
      love.graphics.setLineWidth(math.max(1, ui.E(3) * (1 - p)))
      love.graphics.setColor(e.cor[1], e.cor[2], e.cor[3], 0.55 * a)
      love.graphics.circle("line", e.x, e.y, r)
      love.graphics.setLineWidth(1)

    elseif e.tipo == "squash" then
      local rx = ui.E(16) + p * ui.E(30)
      local ry = math.max(1, ui.E(9) * (1 - p))
      love.graphics.setColor(e.cor[1], e.cor[2], e.cor[3], 0.30 * a)
      love.graphics.ellipse("fill", e.x, e.y + ui.E(8), rx, ry)

    elseif e.tipo == "faisca" then
      local s = math.max(2, e.tam * (1 - 0.5 * p))
      love.graphics.push()
      love.graphics.translate(math.floor(e.x), math.floor(e.y))
      love.graphics.rotate(e.rot or 0)
      love.graphics.setColor(e.cor[1], e.cor[2], e.cor[3], a)
      love.graphics.rectangle("fill", -s / 2, -s / 2, s, s, 1, 1, 2)
      love.graphics.pop()

    elseif e.tipo == "lasca" then
      local w = math.max(2, e.tam)
      local h = math.max(2, e.tam * 2)
      love.graphics.push()
      love.graphics.translate(math.floor(e.x), math.floor(e.y))
      love.graphics.rotate(e.rot or 0)
      love.graphics.setColor(e.cor[1], e.cor[2], e.cor[3], a)
      love.graphics.rectangle("fill", -w / 2, -h / 2, w, h, 1, 1, 2)
      love.graphics.pop()

    elseif e.tipo == "moeda" then
      local rx = math.abs(math.cos(e.rot or 0)) * e.tam + 1
      love.graphics.setColor(OURO[1], OURO[2], OURO[3], a)
      love.graphics.ellipse("fill", e.x, e.y, rx, e.tam)

    elseif e.tipo == "flutuante" then
      local tam = e.tam
      local larg = ui.larguraTexto(e.texto, tam)
      local px = math.floor(e.x - larg / 2)
      local py = math.floor(e.y - tam)
      local off = math.max(1, ui.E(1))
      -- Contorno escuro em 4 direcoes (legibilidade sobre a mesa).
      ui.txt(e.texto, px - off, py, tam, { 0, 0, 0, 1 }, nil, nil, 0.8 * a)
      ui.txt(e.texto, px + off, py, tam, { 0, 0, 0, 1 }, nil, nil, 0.8 * a)
      ui.txt(e.texto, px, py - off, tam, { 0, 0, 0, 1 }, nil, nil, 0.8 * a)
      ui.txt(e.texto, px, py + off, tam, { 0, 0, 0, 1 }, nil, nil, 0.8 * a)
      ui.txt(e.texto, px, py, tam, e.cor, nil, nil, a)

    elseif e.tipo == "escudo" then
      local onda = 0.85 + 0.15 * math.sin(p * math.pi * 3)
      local r = e.raio * onda + p * ui.E(6)
      local a2 = 0.9 * a
      love.graphics.setColor(e.cor[1], e.cor[2], e.cor[3], 0.16 * a2)
      love.graphics.circle("fill", e.x, e.y, r)
      love.graphics.setLineWidth(ui.E(3))
      love.graphics.setColor(e.cor[1], e.cor[2], e.cor[3], 0.85 * a2)
      love.graphics.circle("line", e.x, e.y, r)
      love.graphics.setLineWidth(1)
      love.graphics.setColor(OURO[1], OURO[2], OURO[3], 0.45 * a2)
      love.graphics.circle("line", e.x, e.y, r + ui.E(5))
      -- Ticks cardinais (leitura de "escudo", sem asset).
      love.graphics.setColor(CINZA[1], CINZA[2], CINZA[3], 0.7 * a2)
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        love.graphics.line(e.x + d[1] * (r + ui.E(2)), e.y + d[2] * (r + ui.E(2)),
          e.x + d[1] * (r + ui.E(8)), e.y + d[2] * (r + ui.E(8)))
      end

    elseif e.tipo == "deus" then
      desenharDeus(e)
    end
  end
end

return M
