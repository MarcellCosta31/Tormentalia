-- Painel "Quantos jogadores?" (ModalSelecionarJogadores.js) da tela ARENA.
-- Layout compacto em paisagem: container 640px, 7 linhas (2..8), CANCELAR.
-- Sem hover (o React usa activeOpacity=1); clique fora do painel fecha.
local ui = require "ui"

local A = {}

local VW, VH = 1280, 720

-- PLAYER_COLORS do RN (emoji substituido por numeros: a fonte VCR nao tem emoji).
local CORES = {
  "#FFD54F", "#EF5350", "#42A5F5", "#66BB6A",
  "#AB47BC", "#FF7043", "#26C6DA", "#EC407A",
}
local ROTULOS = {
  [2] = "DUELO", [3] = "BATALHA", [4] = "BATALHA",
  [5] = "GUERRA", [6] = "GUERRA", [7] = "CAOS TOTAL", [8] = "CAOS TOTAL",
}

local PAD = 22
local ALT_LINHA = 56
local GAP_LINHA = 9
local LISTA_Y = PAD + 82
local N_LINHAS = 7
local ALT_CANCEL = 48

local function dentro(x, y, r)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function geom()
  local w = 640
  local x = (VW - w) / 2
  local altLista = N_LINHAS * ALT_LINHA + (N_LINHAS - 1) * GAP_LINHA
  local cancelY = LISTA_Y + altLista + 16
  local h = cancelY + ALT_CANCEL + PAD
  local y = math.floor((VH - h) / 2)
  return {
    x = x, y = y, w = w, h = h,
    listaY = y + LISTA_Y,
    cancelar = { x = x + PAD, y = y + cancelY, w = w - PAD * 2, h = ALT_CANCEL },
  }
end

function A.iniciar(titulo)
  A.titulo = titulo or "ARENA"
end

function A.rectLinha(n)
  local g = geom()
  local k = (n or 2) - 2
  if k < 0 or k >= N_LINHAS then return nil end
  return {
    x = g.x + PAD, y = g.listaY + k * (ALT_LINHA + GAP_LINHA),
    w = g.w - PAD * 2, h = ALT_LINHA,
  }
end

function A.rectCancelar()
  return geom().cancelar
end

function A.desenhar()
  local g = geom()

  love.graphics.setColor(0, 0, 0, 0.82)
  ui.preencherTela(VW, VH)

  ui.caixa(g.x, g.y, g.w, g.h, 14, ui.hex "#0F1322", ui.hex "#7A5C29", 2)
  ui.arestas(g.x + 6, g.y + 6, g.w - 12, g.h - 12, 12, ui.hex "#FFD54F", 2)

  -- Header: espadas + titulo (letterSpacing 3) + subtitulo. O titulo padrao
  -- e ARENA; a simulacao usa "SIMULAR PARTIDA" (fonte menor para caber).
  local titulo = A.titulo or "ARENA"
  local tamTit = #titulo > 9 and 24 or 30
  local largTit = ui.larguraTexto(ui.tr(titulo), tamTit, 3)
  ui.iconeEspadas(g.x + g.w / 2 - largTit / 2 - 26, g.y + PAD + tamTit / 2, 30)
  ui.txtEspacado(titulo, g.x, g.y + PAD, tamTit, ui.hex "#FFD54F", 3, g.w)
  ui.txt("Quantos jogadores?", g.x, g.y + PAD + 40, 15,
    ui.hex "#AAB0D0", "center", g.w)

  -- Divisor (opacity 0.25).
  local corDiv = ui.hex "#FFD54F"
  love.graphics.setColor(corDiv[1], corDiv[2], corDiv[3], 0.25)
  love.graphics.rectangle("fill", g.x + PAD, g.y + PAD + 66, g.w - PAD * 2, 1)

  -- Linhas 2..8.
  for n = 2, 8 do
    local r = A.rectLinha(n)
    ui.caixa(r.x, r.y, r.w, r.h, 10, { 1, 1, 1, 0.05 }, ui.hex "#3A3A5C", 1)

    -- Bolinhas coloridas numeradas (avatarRow do RN).
    local q = n
    local dot = math.min(31, math.floor(88 / q))
    local passo = dot + 4
    local dx = r.x + 22
    local dy = r.y + (r.h - dot) / 2
    for i = 1, q do
      local cor = ui.hex(CORES[i])
      local px = dx + (i - 1) * passo
      ui.caixa(px, dy, dot, dot, dot / 2, { cor[1], cor[2], cor[3], 0.133 }, cor, 1.5)
      ui.txt(tostring(i), px, dy + (dot - math.max(7, dot - 7)) / 2 - 1,
        math.max(7, dot - 7), cor, "center", dot)
    end

    -- Numero + rotulo (botaoInfo do RN).
    local infoX = r.x + 22 + passo * q + 14
    ui.txt(tostring(n), infoX, r.y + 7, 24, ui.hex "#FFD54F")
    ui.txt(ROTULOS[n], infoX, r.y + 36, 13, ui.hex "#AAB0D0")

    -- Seta (seta do RN, vetor: a fonte nao tem U+25B6).
    local sx, sy = r.x + r.w - 30, r.y + r.h / 2
    local corSeta = ui.hex "#FFD54F"
    love.graphics.setColor(corSeta[1], corSeta[2], corSeta[3], 0.6)
    love.graphics.polygon("fill", sx - 5, sy - 9, sx + 9, sy, sx - 5, sy + 9)
  end

  -- CANCELAR.
  local rc = g.cancelar
  ui.caixa(rc.x, rc.y, rc.w, rc.h, 8, { 198 / 255, 40 / 255, 40 / 255, 0.2 },
    ui.hex "#C62828", 1)
  ui.txt("CANCELAR", rc.x, rc.y + rc.h / 2 - 9, 16, ui.hex "#EF5350",
    "center", rc.w)
end

-- Devolve n (2..8), "fechar" (CANCELAR/clique fora) ou nil (clique inerte).
function A.clicado(vx, vy)
  for n = 2, 8 do
    local r = A.rectLinha(n)
    if r and dentro(vx, vy, r) then return n end
  end
  local g = geom()
  if dentro(vx, vy, g.cancelar) then return "fechar" end
  if not dentro(vx, vy, g) then return "fechar" end
  return nil
end

return A
