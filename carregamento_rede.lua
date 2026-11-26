-- Carregamento da rede: tela preta de 6s antes da batalha multiplayer.
-- O Deus Mercado caminha no lugar no canto inferior direito, com
-- "CARREGANDO..." logo abaixo. A partida/intro fica congelada enquanto este
-- modulo esta ativo (o main ainda bombeia a rede para receber
-- INICIADO/SNAPSHOT).
local ui = require "ui"
local arte = require "arte"
local som = require "som"

local I = {}

local VW, VH = 1280, 720
local DURACAO = 6
local QUADROS = 8
local PASSO_QUADRO = 0.24

-- Layout de referencia: personagem pequeno no canto inferior direito e o
-- texto encostado na borda direita, logo abaixo dele.
local CHAR_CENTRO_X = VW - ui.E(37)
local CHAR_BASE_Y = VH - ui.E(32)
local CHAR_ALTURA = VH * 0.20
local TEXTO_DIREITA = VW - ui.E(9)
local TEXTO_Y = VH - ui.E(28)
local TEXTO_TAM = ui.E(13)
local TEXTO_ESP = ui.E(5)
local TEXTO_COR = { 1, 189 / 255, 89 / 255, 1 }

local st = nil

-- Smokes/render/testes pulam a espera: o foco deles e a tela final, nao o
-- carregamento. No jogo normal (sem JOGO_MULTI/TESTE) a tela sempre entra.
function I.pular()
  if os.getenv("JOGO_SEM_CARGA") == "1" then return true end
  if os.getenv("JOGO_TESTE") == "1" then return true end
  local multi = os.getenv("JOGO_MULTI")
  return multi == "partida" or multi == "mesa"
end

function I.iniciar()
  st = {
    t = 0,
    quadro = 1,
    tQuadro = 0,
    dur = DURACAO,
  }
  som.pararMusica()
end

function I.ativo()
  return st ~= nil
end

function I.atualizar(dt)
  if not st then return false end
  st.t = st.t + dt
  st.tQuadro = st.tQuadro + dt
  while st.tQuadro >= PASSO_QUADRO do
    st.tQuadro = st.tQuadro - PASSO_QUADRO
    st.quadro = st.quadro % QUADROS + 1
  end
  if st.t >= st.dur then
    st = nil
    return true
  end
  return false
end

function I.desenhar()
  if not st then return end

  love.graphics.setColor(0, 0, 0, 1)
  ui.preencherTela(VW, VH)

  local img = arte.img("intro_and_" .. st.quadro)
  if img then
    local iw, ih = img:getDimensions()
    local e = CHAR_ALTURA / ih
    love.graphics.setColor(1, 1, 1, 1)
    -- Ancorado pelo centro/base do quadro. O PNG tem margem transparente
    -- embaixo (~80px), por isso a base fica um pouco acima da borda.
    love.graphics.draw(img, CHAR_CENTRO_X, CHAR_BASE_Y, 0, e, e, iw / 2, ih)
  end

  -- Reticencias progressivas: 1 -> 2 -> 3 (nunca zero).
  local pontos = 1 + math.floor(st.t / 0.45) % 3
  local texto = "CARREGANDO" .. string.rep(".", pontos)
  -- larguraTexto cobra o espaco tambem depois do ultimo caractere; desconta
  -- um espaco para a borda direita do texto bater na margem do layout.
  local largura = ui.larguraTexto(texto, TEXTO_TAM, TEXTO_ESP) - TEXTO_ESP
  ui.txtEspacado(texto, TEXTO_DIREITA - largura, TEXTO_Y,
    TEXTO_TAM, TEXTO_COR, TEXTO_ESP)
end

function I.limpar()
  st = nil
end

return I
