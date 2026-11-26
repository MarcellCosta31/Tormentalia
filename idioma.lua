-- Idioma do TEXTO do jogo (pt = padrao, en). So a parte escrita: as artes
-- continuam em portugues ate haver versao traduzida delas.
--
-- Como funciona: o texto passa por idioma.tr() nos pontos de desenho
-- (ui.txt, ui.txtEspacado, ui.txtCabe, ui.textoQuebrado), e a CHAVE e o
-- proprio texto em portugues. Assim a tela continua inteira mesmo sem
-- traducao: o que nao estiver em idioma_en.lua aparece em portugues.
--
-- Persiste em "config_idioma" ("pt"/"en"); a tela de CONFIGURACOES troca
-- ao vivo, sem reiniciar. Em MODO_TESTE o arquivo e ignorado (leitura e
-- escrita) para a suite rodar sempre em portugues, seja qual for a
-- preferencia salva na maquina.
local EN = require "idioma_en"

local M = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local ARQ = "config_idioma"
local atual = "pt"

if not MODO_TESTE and love and love.filesystem then
  local ok, txt = pcall(love.filesystem.read, ARQ)
  if ok and type(txt) == "string" and (txt == "pt" or txt == "en") then
    atual = txt
  end
end

-- Idioma ativo ("pt" ou "en").
function M.idioma()
  return atual
end

-- Troca o idioma (invalido = ignora e devolve o atual). Em MODO_TESTE so
-- muda a memoria, mesmo trato do definirVolume do som.
function M.definir(id)
  if id ~= "pt" and id ~= "en" then return atual end
  atual = id
  if not MODO_TESTE then
    pcall(love.filesystem.write, ARQ, id)
  end
  return atual
end

-- Traduz `texto` (a chave e o portugues original). Idioma pt, chave
-- desconhecida ou valor nao-string: devolve como esta, sem nunca quebrar
-- o desenho por falta de traducao.
function M.tr(texto)
  if atual == "en" and type(texto) == "string" then
    local t = EN[texto]
    if t then return t end
  end
  return texto
end

-- Rotulo de um idioma na propria lingua dele (convencao de menus):
-- PORTUGUES em portugues, ENGLISH em ingles.
function M.rotulo(id)
  if id == "en" then return "ENGLISH" end
  return "PORTUGUES"
end

-- Lista dos idiomas disponiveis, na ordem em que aparecem no seletor.
function M.lista()
  return { "pt", "en" }
end

return M
