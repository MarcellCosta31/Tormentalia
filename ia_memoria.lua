-- ia_memoria.lua — estilo do jogador entre partidas (8.2). Depois de 5+
-- partidas a IApassa a contra-atacar o padrao mais frequente.
-- Arquivo de save: uma linha por partida com "defensivo|agressivo|misto".
local M = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local ARQ = "ia_estilo_jogador.txt"
local LIMIAR = 5

local function carregar()
  if MODO_TESTE then return {} end
  local ok, dados = pcall(love.filesystem.read, ARQ)
  if not ok or not dados then return {} end
  local lista = {}
  for linha in dados:gmatch("[^\n]+") do
    if linha == "defensivo" or linha == "agressivo" or linha == "misto" then
      lista[#lista + 1] = linha
    end
  end
  return lista
end

function M.partidas()
  return #carregar()
end

-- Chamado no fim de cada partida com o estilo observado do jogador local.
function M.registrar(estilo)
  if MODO_TESTE then return true end
  if estilo ~= "defensivo" and estilo ~= "agressivo" then estilo = "misto" end
  local lista = carregar()
  lista[#lista + 1] = estilo
  if #lista > 40 then table.remove(lista, 1) end
  return pcall(love.filesystem.write, ARQ, table.concat(lista, "\n"))
end

-- Devolve o estilo que contra-ataca o jogador, ou nil antes de 5 partidas.
function M.contra()
  local lista = carregar()
  if #lista < LIMIAR then return nil end
  local def, atk = 0, 0
  for _, s in ipairs(lista) do
    if s == "defensivo" then def = def + 1
    elseif s == "agressivo" then atk = atk + 1 end
  end
  if def > atk then return "agressivo" end  -- jogador guarda -> ataca estoque
  if atk > def then return "defensivo" end  -- jogador ataca -> protege
  return nil
end

-- Classifica o jogador a partir da partida que terminou.
function M.classificar(p)
  if not p or not p.jogadores or not p.jogadores[1] then return "misto" end
  local j = p.jogadores[1]
  local def, atk = 0, 0
  for _, c in ipairs(j.pilhaJogadas or {}) do
    if c.tipo == "DEFESA" then
      def = def + 1
    elseif c.tipo == "ACAO" or c.tipo == "EFEITO" then
      local e = c.efeito
      if e and e.tipo and e.tipo ~= "DOACAO_PERCENTUAL" then atk = atk + 1 end
    end
  end
  def = def + #(j.areaSegura or {})
  if def > atk * 1.5 then return "defensivo" end
  if atk > def * 1.5 then return "agressivo" end
  return "misto"
end

function M.limpar()
  if MODO_TESTE then return true end
  return pcall(love.filesystem.write, ARQ, "")
end

return M
