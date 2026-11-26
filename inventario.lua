-- Inventario do jogador: avatares e emojis comprados na loja. Persistencia
-- em arquivo proprio ("inventario.txt"); em MODO_TESTE o disco nao e tocado
-- (mesma regra de perfil/dinheiro) e a posse vale so na memoria. Os
-- pacotes de cartas entram aqui depois.
local json = require "json"
local dinheiro = require "dinheiro"

local M = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local ARQUIVO = "inventario.txt"

-- Catalogo da loja: id bate com a chave do sprite (avatar_<id> em arte).
local PRODUTOS = {
  { id = "taylor", nome = "FREDERICK TAYLOR", preco = 100 },
  { id = "marx", nome = "KARL MARX", preco = 100 },
  { id = "mayo", nome = "ELTON MAYO", preco = 100 },
}

-- Emojis a venda: id proprio (NUNCA colide com avatar "marx") e o codigo
-- do balao na partida. 1..4 sao os vetoriais iniciais de graca; a partir
-- do 5 sao emojis de SPRITE da loja (pasta arte/emojis/<id>/).
local PRODUTOS_EMOJI = {
  { id = "karl_marx", nome = "KARL MARX", preco = 100, codigo = 5 },
  { id = "adam_smith", nome = "ADAM SMITH", preco = 100, codigo = 6 },
}

local avatares = {}  -- set { id = true }
local emojis = {}    -- set { id = true }

function M.carregar()
  avatares = {}
  emojis = {}
  if MODO_TESTE then return end
  local ok, dados = pcall(love.filesystem.read, ARQUIVO)
  if not ok or not dados then return end
  local okJ, tab = pcall(json.decode, dados)
  if not okJ or type(tab) ~= "table" then return end
  -- Save antigo tinha so avatares; emojis ausente vira posse vazia.
  if type(tab.avatares) == "table" then
    for _, id in ipairs(tab.avatares) do
      avatares[tostring(id)] = true
    end
  end
  if type(tab.emojis) == "table" then
    for _, id in ipairs(tab.emojis) do
      emojis[tostring(id)] = true
    end
  end
end

local function salvar()
  if MODO_TESTE then return end
  pcall(love.filesystem.write, ARQUIVO, json.encode({
    avatares = M.avataresComprados(),
    emojis = M.emojisComprados(),
  }))
end

function M.produtos()
  return PRODUTOS
end

function M.emojisProdutos()
  return PRODUTOS_EMOJI
end

-- Produto de emoji pelo codigo do balao (nil para os vetoriais 1..4 e
-- para codigos fora do catalogo). Balao/seletor usam pra achar o sprite.
function M.emojiPorCodigo(codigo)
  for _, p in ipairs(PRODUTOS_EMOJI) do
    if p.codigo == codigo then return p end
  end
end

function M.temAvatar(id)
  return avatares[id] == true
end

function M.temEmoji(id)
  return emojis[id] == true
end

-- Lista na ordem do catalogo (a grade do perfil fica estavel).
function M.avataresComprados()
  local lista = {}
  for _, p in ipairs(PRODUTOS) do
    if avatares[p.id] then lista[#lista + 1] = p.id end
  end
  return lista
end

function M.emojisComprados()
  local lista = {}
  for _, p in ipairs(PRODUTOS_EMOJI) do
    if emojis[p.id] then lista[#lista + 1] = p.id end
  end
  return lista
end

-- Compra: so passa se o produto (avatar ou emoji) existe, ainda nao e seu
-- e o dinheiro cobre o preco (dinheiro.gastar debita; sem saldo nao mexe
-- em nada).
function M.comprar(id)
  local prod, posse
  for _, p in ipairs(PRODUTOS) do
    if p.id == id then
      prod, posse = p, avatares
      break
    end
  end
  if not prod then
    for _, p in ipairs(PRODUTOS_EMOJI) do
      if p.id == id then
        prod, posse = p, emojis
        break
      end
    end
  end
  if not prod or posse[id] then return false end
  if not dinheiro.gastar(prod.preco) then return false end
  posse[id] = true
  salvar()
  return true
end

-- Concede a posse em MEMORIA sem cobrar nem salvar (capturas e testes;
-- o disco fica intocado).
function M.conceder(id)
  for _, p in ipairs(PRODUTOS) do
    if p.id == id then avatares[id] = true return end
  end
  for _, p in ipairs(PRODUTOS_EMOJI) do
    if p.id == id then emojis[id] = true return end
  end
end

-- Zera a posse em memoria (usado pelos testes; o disco em MODO_TESTE nao existe).
function M.limpar()
  avatares = {}
  emojis = {}
end

return M
