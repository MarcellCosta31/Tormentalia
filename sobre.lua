-- Tela SOBRE: quem fez o Tormentalia, com as fotos de arte/criadores,
-- o papel de cada um, um botao reservado para o site do jogo e a versao.
-- Exposta em ui._sobre para o main nao ganhar locals (teto de 200 do LuaJIT).
local ui = require "ui"

local C = {}

local VW, VH = 1280, 720
local PX, PY, PW, PH = 48, 28, 1184, 664

local COR_OURO = ui.hex "#FFD54F"
local COR_TXT = ui.hex "#C6CCE8"
local COR_ROLE = ui.hex "#E4C98F"
local COR_FUNDO = ui.hex "#0C1020"
local COR_BORDA = ui.hex "#7A5C29"
local COR_CARTAO = ui.hex "#161C33"
local COR_DESTAQUE = ui.hex "#232B4C"
local COR_BTN = { 0.06, 0.07, 0.12 }
local COR_BTN_HOVER = { 0.18, 0.15, 0.07 }

-- Ordem: Daniel, Davi, MARCELL (meio), Danilo e Kaua.
local CRIADORES = {
  { nome = "DANIEL VITOR", papel = "roteirista, designer",
    arquivo = "arte/criadores/daniel.jpeg" },
  { nome = "DAVI SOUSA", papel = "roteirista, designer",
    arquivo = "arte/criadores/davi.jpeg", fotoAncoraY = 0 },
  { nome = "MARCELL COSTA", papel = "programador, designer, roteirista",
    arquivo = "arte/criadores/marcell_costa.png" },
  { nome = "DANILO NUNES", papel = "marketing",
    arquivo = "arte/criadores/danilo.jpeg" },
  { nome = "KAUA KENNEDY", papel = "roteirista",
    arquivo = "arte/criadores/kennedy.jpeg" },
}

local fotos = {}
local carregado = false

local function carregarFotos()
  if carregado then return end
  carregado = true
  for i, pessoa in ipairs(CRIADORES) do
    local ok, img = pcall(love.graphics.newImage, pessoa.arquivo)
    fotos[i] = ok and img or nil
  end
end

-- Cartoes dos criadores (retangulos virtuais; ficam expostos para testes).
local CARD_W, CARD_H, CARD_GAP = 216, 344, 14
local totalW = #CRIADORES * CARD_W + (#CRIADORES - 1) * CARD_GAP
local CARD_X0 = PX + math.floor((PW - totalW) / 2)
local CARD_Y = PY + 108

local RET_CARDS = {}
for i = 1, #CRIADORES do
  RET_CARDS[i] = {
    x = CARD_X0 + (i - 1) * (CARD_W + CARD_GAP),
    y = CARD_Y, w = CARD_W, h = CARD_H,
  }
end

local RET_SITE = { x = PX + math.floor((PW - 380) / 2), y = PY + 500,
  w = 380, h = 50 }
local RET_VOLTAR = { x = PX + PW - 198, y = PY + 600, w = 150, h = 48 }

C.RET_CARDS = RET_CARDS
C.RET_SITE = RET_SITE
C.RET_VOLTAR = RET_VOLTAR
C.VERSAO = "VERSÃO 1.0"
C.CRIADORES = CRIADORES

local function porCima(r, hover)
  return hover and hover.x >= r.x and hover.x <= r.x + r.w
    and hover.y >= r.y and hover.y <= r.y + r.h
end

local function botao(r, texto, hover, tam)
  local destaque = porCima(r, hover)
  ui.caixa(r.x, r.y, r.w, r.h, 10,
    destaque and COR_BTN_HOVER or COR_BTN,
    destaque and COR_OURO or COR_BORDA, 2)
  ui.txt(texto, r.x, r.y + math.floor((r.h - (tam or 17)) / 2) - 2,
    tam or 17, COR_OURO, "center", r.w)
end

-- Abre a tela: so garante que as fotos estao carregadas.
function C.abrir()
  carregarFotos()
end

-- Clique: "voltar" fecha a tela. "site" fica sem acao (sem link ainda).
function C.clicado(x, y)
  if porCima(RET_VOLTAR, { x = x, y = y }) then return "voltar" end
  if porCima(RET_SITE, { x = x, y = y }) then return "site" end
  return nil
end

function C.desenhar(hover)
  carregarFotos()

  love.graphics.setColor(0, 0, 0, 0.86)
  ui.preencherTela(VW, VH)

  -- Painel: moldura bronze com cantos dourados e um fio de ouro no topo.
  ui.caixa(PX, PY, PW, PH, 14, COR_FUNDO, COR_BORDA, 2)
  ui.arestas(PX + 6, PY + 6, PW - 12, PH - 12, 12, COR_OURO, 2)
  ui.caixa(PX + 14, PY + 3, PW - 28, 3, 1, COR_BORDA, nil, 0)
  ui.caixa(PX + PW / 2 - 90, PY + 3, 180, 3, 1, COR_OURO, nil, 0)

  ui.txtEspacado("TORMENTALIA", PX, PY + 20, 30, COR_OURO, 3, PW)
  ui.txt("QUEM FEZ ESTE JOGO", PX, PY + 62, 16, COR_TXT, "center", PW)

  -- Divisor com segmentos mais brilhantes nas pontas.
  love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 0.22)
  love.graphics.rectangle("fill", PX + 28, PY + 92, PW - 56, 1)
  love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 0.7)
  love.graphics.rectangle("fill", PX + 28, PY + 92, 120, 1)
  love.graphics.rectangle("fill", PX + PW - 148, PY + 92, 120, 1)

  for i, pessoa in ipairs(CRIADORES) do
    local r = RET_CARDS[i]
    local porCimaCartao = porCima(r, hover)
    ui.caixa(r.x, r.y, r.w, r.h, 12,
      porCimaCartao and COR_DESTAQUE or COR_CARTAO,
      porCimaCartao and COR_OURO or COR_BORDA, 2)

    -- Retrato: recorte quadrado (o do Davi ancorado no topo).
    local fx, fy = r.x + 18, r.y + 16
    local fw = r.w - 36
    local fh = fw
    ui.caixa(fx - 2, fy - 2, fw + 4, fh + 4, 8, ui.hex "#05070E",
      COR_BORDA, 2)
    if fotos[i] then
      ui.imagemCover(fotos[i], fx, fy, fw, fh, 1, 0.5,
        pessoa.fotoAncoraY or 0.5)
    else
      ui.txt("FOTO", fx, fy + fh / 2 - 8, 14, COR_TXT, "center", fw)
    end

    local nomeY = r.y + 210
    ui.txtCabe(pessoa.nome, r.x + 8, nomeY, 16,
      r.w - 16, COR_OURO, "center", 11)
    -- Filete dourado abaixo do nome.
    love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 0.35)
    love.graphics.rectangle("fill", r.x + r.w / 2 - 28, nomeY + 22, 56, 1)

    local linhas = ui.quebrar(string.upper(pessoa.papel), 13, r.w - 36)
    for j, linha in ipairs(linhas) do
      ui.txtCabe(linha, r.x + 18, r.y + 240 + (j - 1) * 19, 13,
        r.w - 36, COR_ROLE, "center", 10)
    end
  end

  -- Espaco reservado para o site do jogo (sem link ainda).
  love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 0.22)
  love.graphics.rectangle("fill", PX + 120, RET_SITE.y - 18, PW - 240, 1)
  botao(RET_SITE, "SITE DO JOGO", hover, 18)
  ui.txt("EM BREVE", RET_SITE.x, RET_SITE.y + 31, 11, COR_TXT, "center",
    RET_SITE.w)

  botao(RET_VOLTAR, "VOLTAR", hover, 16)
  ui.txt(C.VERSAO, PX + 28, PY + 614, 14, COR_TXT, "left", 240)
end

return C
