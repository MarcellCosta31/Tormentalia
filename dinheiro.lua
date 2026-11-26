-- Dinheiro do jogador: mostrado no menu ao lado do avatar e somado +10
-- a cada vitoria. Persistencia em arquivo proprio ("dinheiro"), separada
-- do progresso do ciclo; em MODO_TESTE o disco nao e tocado (mesma regra
-- de selecao.salvarProg) e o valor vale so na memoria.
local M = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local ARQUIVO = "dinheiro"
local POR_VITORIA = 10

local valor = 0
-- Ultima partida ja premiada (guard por referencia): o hook do fim roda
-- a cada frame e o botao "VOCE VENCE" da suite tambem reabre o fim.
local ultimaPremiada = nil

function M.carregar()
  ultimaPremiada = nil
  if MODO_TESTE then
    valor = 0
    return
  end
  local txt = love.filesystem.read(ARQUIVO)
  local n = tonumber(txt)
  valor = (n and n >= 0) and math.floor(n) or 0
end

function M.valor()
  return valor
end

function M.ganhar(n)
  n = math.floor(tonumber(n) or 0)
  if n <= 0 then return end
  valor = valor + n
  if not MODO_TESTE then
    love.filesystem.write(ARQUIVO, tostring(valor))
  end
end

-- Pagamento (compra na loja): deduz do saldo e devolve true; sem saldo
-- devolve false sem mexer no valor.
function M.gastar(n)
  n = math.floor(tonumber(n) or 0)
  if n <= 0 or valor < n then return false end
  valor = valor - n
  if not MODO_TESTE then
    love.filesystem.write(ARQUIVO, tostring(valor))
  end
  return true
end

-- Chamado pelo main na tela de fim: paga uma unica vez por partida e so
-- quando o jogador (jogadores[1]) venceu de fato (empate nao paga).
function M.premiar(partida)
  if not partida or ultimaPremiada == partida then return end
  local v = partida.vencedor
  if not v or v ~= partida.jogadores[1] or v.empate then return end
  ultimaPremiada = partida
  M.ganhar(POR_VITORIA)
end

return M
