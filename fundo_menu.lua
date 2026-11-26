-- Seletor do fundo do menu. O visual novo (protótipo HTML da pasta
-- arte/menu) é o padrão; o vórtice anterior fica guardado em
-- fundo_menu_vortex.lua. Para abrir já no antigo, rode com
-- JOGO_FUNDO_MENU=antigo. No menu, F8 alterna entre os dois ao vivo.
local vortex = require "fundo_menu_vortex"
local html = require "fundo_menu_html"

local fundo = {}
local modo = (os.getenv("JOGO_FUNDO_MENU") == "antigo"
  or os.getenv("JOGO_FUNDO_MENU") == "vortex") and "antigo" or "novo"

local function atual()
  return modo == "antigo" and vortex or html
end

function fundo.desenhar(x, y, w, h)
  return atual().desenhar(x, y, w, h)
end

function fundo.nome()
  local m = atual()
  return m.nome and m.nome() or (modo == "antigo" and "VORTEX" or "HTML")
end

function fundo.alternar()
  modo = modo == "antigo" and "novo" or "antigo"
  return fundo.nome()
end

return fundo
