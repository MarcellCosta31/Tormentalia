-- Tela de CONFIGURACOES: volume da MUSICA e volume dos EFEITOS sonoros
-- separados (passos de 10%, persistidos em "config_musica" e "config_som"),
-- idioma do TEXTO do jogo (pt padrao / en, em "config_idioma" - as artes
-- continuam em portugues) e resetar o progresso dos ciclos (DERROTADOS +
-- soberanos de todos, com confirmacao para nao apagar sem querer). Painel
-- por cima do menu (mesma postura do painel do multiplayer) e botoes em
-- codigo, na linguagem visual do jogo - a arte dos botoes fica para quando
-- houver mockup. Exposta em ui._config para o main nao ganhar locals (esta
-- no teto de 200 do LuaJIT).
local ui = require "ui"
local som = require "som"
local selecao = require "selecao"
local idioma = require "idioma"

local C = {}

local VW, VH = 1280, 720
local PAD = 26

-- Painel central (cores do painel do multiplayer: fundo escuro, moldura
-- bronze e arestas douradas). Mais alto que o antigo: cabem duas linhas de
-- volume, o seletor de idioma e o reset.
local PW, PH = 600, 500
local PX = math.floor((VW - PW) / 2)
local PY = math.floor((VH - PH) / 2)

local COR_OURO = ui.hex "#FFD54F"
local COR_TXT = ui.hex "#AAB0D0"
local COR_FUNDO = ui.hex "#0F1322"
local COR_BORDA = ui.hex "#7A5C29"
local COR_BTN = { 0.06, 0.07, 0.12 }
local COR_BTN_HOVER = { 0.18, 0.15, 0.07 }

-- Passo do volume: 10% (0%..100% em 11 posicoes), igual para os dois.
local PASSO = 0.1

-- Confirmacao do reset: false mostra o botao RESETAR; true mostra
-- SIM/NAO para confirmar a apagada do progresso.
local confirmando = false

-- Botoes (retangulos virtuais; a suite clica pelo centro deles).
-- Linha da musica e linha dos efeitos: mesma forma, valor em % na barra.
local RET_MUS_MENOS = { x = PX + PAD, y = PY + 100, w = 46, h = 44 }
local RET_MUS_MAIS = { x = PX + PW - PAD - 46, y = PY + 100, w = 46, h = 44 }
local RET_EFE_MENOS = { x = PX + PAD, y = PY + 178, w = 46, h = 44 }
local RET_EFE_MAIS = { x = PX + PW - PAD - 46, y = PY + 178, w = 46, h = 44 }
-- Idioma: dois botoes lado a lado; o ativo fica com a borda dourada.
local LARG_IDIOMA = math.floor((PW - PAD * 2 - 14) / 2)
local RET_IDIOMA_PT = { x = PX + PAD, y = PY + 258, w = LARG_IDIOMA, h = 44 }
local RET_IDIOMA_EN = { x = PX + PAD + LARG_IDIOMA + 14, y = PY + 258,
  w = LARG_IDIOMA, h = 44 }

local RET_RESET = { x = PX + 70, y = PY + 356, w = PW - 140, h = 56 }
local RET_SIM = { x = PX + 70, y = PY + 356, w = 130, h = 56 }
local RET_NAO = { x = PX + PW - 70 - 130, y = PY + 356, w = 130, h = 56 }
local RET_VOLTAR = { x = PX + 70, y = PY + PH - 72, w = PW - 140, h = 52 }

C.RET_MUS_MENOS = RET_MUS_MENOS
C.RET_MUS_MAIS = RET_MUS_MAIS
C.RET_EFE_MENOS = RET_EFE_MENOS
C.RET_EFE_MAIS = RET_EFE_MAIS
C.RET_IDIOMA_PT = RET_IDIOMA_PT
C.RET_IDIOMA_EN = RET_IDIOMA_EN
C.RET_RESET = RET_RESET
C.RET_SIM = RET_SIM
C.RET_NAO = RET_NAO
C.RET_VOLTAR = RET_VOLTAR

-- Abre a tela em estado limpo (sem confirmacao pendente).
function C.abrir()
  confirmando = false
end

-- Botao em codigo (mesma linguagem do painel): moldura bronze, texto
-- dourado e destaque quando o mouse passa por cima ou quando ele e o
-- item ativo (usado no seletor de idioma).
function C.botao(r, texto, hover, ativo)
  local porCima = hover and hover.x >= r.x and hover.x <= r.x + r.w
    and hover.y >= r.y and hover.y <= r.y + r.h
  local destaque = porCima or ativo
  ui.caixa(r.x, r.y, r.w, r.h, 10,
    destaque and COR_BTN_HOVER or COR_BTN,
    destaque and COR_OURO or COR_BORDA, 2)
  local tam = 16
  ui.txt(texto, r.x, r.y + math.floor((r.h - tam) / 2) - 2, tam,
    COR_OURO, "center", r.w)
end

-- Linha de volume: rotulo em cima, barra com o % no meio e - / + nas
-- pontas. Mesma forma para a musica e para os efeitos.
local function linhaVolume(rotulo, valor, rMenos, rMais, hover)
  ui.txt(rotulo, PX, PY + (rMenos.y - PY) - 24, 16, COR_TXT, "center", PW)
  C.botao(rMenos, "-", hover)
  C.botao(rMais, "+", hover)
  local barraX = rMenos.x + rMenos.w + 14
  local barraW = rMais.x - 14 - barraX
  local barraY = rMenos.y + 12
  ui.caixa(barraX, barraY, barraW, 20, 10, { 0.10, 0.10, 0.16 },
    COR_BORDA, 1.5)
  local larg = math.floor((barraW - 6) * valor + 0.5)
  if larg > 3 then
    ui.caixa(barraX + 3, barraY + 3, larg, 14, 7, COR_OURO, COR_OURO, 1)
  end
  local pct = math.floor(valor * 100 + 0.5) .. "%"
  ui.txt(pct, barraX + 1, barraY + 3, 15, { 0, 0, 0, 0.8 }, "center", barraW)
  ui.txt(pct, barraX, barraY + 2, 15, { 1, 1, 1 }, "center", barraW)
end

-- Desenha o painel por cima do menu (o fundo do menu ja foi desenhado).
function C.desenhar(hover)
  love.graphics.setColor(0, 0, 0, 0.82)
  ui.preencherTela(VW, VH)
  ui.caixa(PX, PY, PW, PH, 14, COR_FUNDO, COR_BORDA, 2)
  ui.arestas(PX + 6, PY + 6, PW - 12, PH - 12, 12, COR_OURO, 2)

  ui.txtEspacado("CONFIGURACOES", PX, PY + 26, 30, COR_OURO, 3, PW)

  -- Divisor dourado translucido (igual ao do painel multiplayer).
  love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 0.25)
  love.graphics.rectangle("fill", PX + PAD, PY + 66, PW - PAD * 2, 1)

  -- Volume: musica e efeitos em linhas separadas, cada um com o seu.
  linhaVolume("VOLUME DA MUSICA", som.volumeMusica(),
    RET_MUS_MENOS, RET_MUS_MAIS, hover)
  linhaVolume("VOLUME DOS EFEITOS", som.volumeEfeitos(),
    RET_EFE_MENOS, RET_EFE_MAIS, hover)

  -- Idioma do texto: o ativo vem destacado; a troca e na hora.
  ui.txt("IDIOMA", PX, PY + 236, 16, COR_TXT, "center", PW)
  C.botao(RET_IDIOMA_PT, idioma.rotulo("pt"), hover,
    idioma.idioma() == "pt")
  C.botao(RET_IDIOMA_EN, idioma.rotulo("en"), hover,
    idioma.idioma() == "en")

  -- Progresso dos ciclos: RESETAR pede confirmacao antes de apagar.
  love.graphics.setColor(COR_OURO[1], COR_OURO[2], COR_OURO[3], 0.25)
  love.graphics.rectangle("fill", PX + PAD, PY + 318, PW - PAD * 2, 1)
  if confirmando then
    ui.txt("ISSO APAGA OS DERROTADOS E OS SOBERANOS DOS CICLOS",
      PX, PY + 332, 13, COR_TXT, "center", PW)
    C.botao(RET_SIM, "SIM", hover)
    C.botao(RET_NAO, "NAO", hover)
  else
    -- Composto por partes (rotulo + nome de cada ciclo) para cada pedaco
    -- ser traduzido; montado junto fica identico ao texto antigo.
    ui.txt(idioma.tr("DERROTADOS") .. ": " .. idioma.tr("CICLO I") .. " "
      .. selecao.progressoDoCiclo(1) .. "/" .. selecao.totalInimigos(1)
      .. " - " .. idioma.tr("CICLO 2") .. " "
      .. selecao.progressoDoCiclo(2) .. "/" .. selecao.totalInimigos(2),
      PX, PY + 332, 13, COR_TXT, "center", PW)
    C.botao(RET_RESET, "RESETAR PROGRESSO", hover)
  end

  C.botao(RET_VOLTAR, "VOLTAR", hover)
end

-- Clique (coordenadas virtuais): volumes da musica e dos efeitos, idioma,
-- reset com confirmacao e VOLTAR; retorna "voltar" quando o jogador pede
-- para sair ao menu.
function C.clicado(vx, vy)
  local function dentro(r)
    return vx >= r.x and vx <= r.x + r.w and vy >= r.y and vy <= r.y + r.h
  end
  if dentro(RET_MUS_MENOS) then
    som.definirVolumeMusica(som.volumeMusica() - PASSO)
    return
  end
  if dentro(RET_MUS_MAIS) then
    som.definirVolumeMusica(som.volumeMusica() + PASSO)
    return
  end
  if dentro(RET_EFE_MENOS) then
    som.definirVolumeEfeitos(som.volumeEfeitos() - PASSO)
    return
  end
  if dentro(RET_EFE_MAIS) then
    som.definirVolumeEfeitos(som.volumeEfeitos() + PASSO)
    return
  end
  if dentro(RET_IDIOMA_PT) then
    idioma.definir("pt")
    return
  end
  if dentro(RET_IDIOMA_EN) then
    idioma.definir("en")
    return
  end
  if confirmando then
    if dentro(RET_SIM) then
      selecao.redefinirProgresso()
      confirmando = false
      return
    end
    if dentro(RET_NAO) then
      confirmando = false
      return
    end
  elseif dentro(RET_RESET) then
    confirmando = true
    return
  end
  if dentro(RET_VOLTAR) then
    confirmando = false
    return "voltar"
  end
end

-- Volumes e idioma expostos para a suite mexer sem depender de `som`/`idioma`
-- no main (o testesRender.completa esta no teto de 60 upvalues do LuaJIT).
C.volumeMusica = som.volumeMusica
C.definirVolumeMusica = som.definirVolumeMusica
C.volumeEfeitos = som.volumeEfeitos
C.definirVolumeEfeitos = som.definirVolumeEfeitos
C.idioma = idioma.idioma
C.definirIdioma = idioma.definir
C.tr = idioma.tr

return C
