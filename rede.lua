-- Camada de rede do multiplayer: ENet (lua-enet) embutido no LÖVE 11.5.
-- Cada processo tem um unico papel: servidor (PC, o host da partida) ou
-- cliente (celular/PC). Mensagens sao tabelas serializadas em JSON; o jogo
-- consome os eventos com consumirEventos() uma vez por frame.
-- Obs.: o lua-enet nao expoe destruicao de host — fechar = desconectar os
-- peers e manter o host (reutilizavel para novas conexoes no mesmo processo).
local okEnet, enet = pcall(require, "enet")
local json = require "json"

local rede = {}
rede.PORTA = 4963
rede.disponivel = okEnet and type(enet) == "table"

local Rede = {}
Rede.__index = Rede

local function empilhar(self, ev)
  self.fila[#self.fila + 1] = ev
end

local function indiceDoPeer(peer)
  if not peer then return nil end
  local ok, idx = pcall(function() return peer:index() end)
  if ok then return idx end
  return nil
end

local function processarEvento(self, ev)
  local id = indiceDoPeer(ev.peer)
  if ev.type == "connect" then
    if id then self.peers[id] = ev.peer end
    if self.papel == "cliente" then self.alvo = ev.peer end
    empilhar(self, { tipo = "conectado", id = id })
  elseif ev.type == "receive" then
    local ok, msg = pcall(json.decode, ev.data or "")
    if ok and type(msg) == "table" then
      empilhar(self, {
        tipo = "mensagem", id = id, msg = msg, canal = ev.channel,
      })
    else
      empilhar(self, { tipo = "mensagem_invalida", id = id })
    end
  elseif ev.type == "disconnect" then
    if id and self.peers[id] then self.peers[id] = nil end
    if self.papel == "cliente" then self.alvo = nil end
    empilhar(self, { tipo = "desconectado", id = id })
  end
end

local function serializar(msg)
  local ok, texto = pcall(json.encode, msg)
  if not ok then return nil, tostring(texto) end
  return texto
end

local function novo(papel)
  return setmetatable({
    papel = papel,
    host = nil,
    alvo = nil,
    peers = {},
    fila = {},
  }, Rede)
end

function rede.novo()
  return novo(nil)
end

function Rede:criarServidor(porta)
  if not rede.disponivel then return nil, "enet indisponivel" end
  if self.host then return nil, "host ja ativo" end
  local alvo = "*:" .. tostring(porta or rede.PORTA)
  local ok, res, err = pcall(enet.host_create, alvo, 16, 2)
  if not ok then return nil, tostring(res) end
  if res == nil then return nil, tostring(err or "falha ao criar host") end
  self.host = res
  self.papel = "servidor"
  return true
end

function Rede:conectar(ip, porta)
  if not rede.disponivel then return nil, "enet indisponivel" end
  if self.host then return nil, "host ja ativo" end
  local ok, res, err = pcall(enet.host_create, nil, 1, 2)
  if not ok then return nil, tostring(res) end
  if res == nil then return nil, tostring(err or "falha ao criar host") end
  self.host = res
  self.papel = "cliente"
  local destino = tostring(ip) .. ":" .. tostring(porta or rede.PORTA)
  local okC, peer = pcall(function() return self.host:connect(destino, 2) end)
  if not okC or peer == nil then
    self.host, self.papel = nil, nil
    return nil, tostring(peer or "falha ao conectar")
  end
  self.alvo = peer
  return true
end

function Rede:atualizar()
  if not self.host then return end
  local ev = self.host:service(0)
  while ev do
    processarEvento(self, ev)
    ev = self.host:service(0)
  end
end

function Rede:consumirEventos()
  local evts = self.fila
  self.fila = {}
  return evts
end

function Rede:enviar(id, msg)
  local p = self.peers[id]
  if not p then return nil, "peer " .. tostring(id) .. " desconectado" end
  local texto, err = serializar(msg)
  if not texto then return nil, err end
  local ok, e = pcall(p.send, p, texto)
  if not ok then return nil, tostring(e) end
  return true
end

function Rede:enviarTodos(msg)
  if not self.host then return nil, "sem host" end
  local texto, err = serializar(msg)
  if not texto then return nil, err end
  local ok, e = pcall(self.host.broadcast, self.host, texto)
  if not ok then return nil, tostring(e) end
  return true
end

function Rede:enviarParaServidor(msg)
  if not self.alvo then return nil, "sem conexao com o servidor" end
  local texto, err = serializar(msg)
  if not texto then return nil, err end
  local ok, e = pcall(self.alvo.send, self.alvo, texto)
  if not ok then return nil, tostring(e) end
  return true
end

function Rede:enviarBruto(id, texto)
  local p = self.peers[id]
  if not p then return nil, "peer " .. tostring(id) .. " desconectado" end
  local ok, e = pcall(p.send, p, texto)
  if not ok then return nil, tostring(e) end
  return true
end

function Rede:desconectar(id)
  local p
  if id ~= nil then
    p = self.peers[id]
  else
    p = self.alvo
  end
  if not p or not self.host then return nil, "sem peer para desconectar" end
  pcall(function() p:disconnect() end)
  pcall(function() self.host:flush() end)
  return true
end

function Rede:desconectarTodos()
  if not self.host then return nil, "sem host" end
  for _, p in pairs(self.peers) do
    pcall(function() p:disconnect() end)
  end
  if self.papel == "cliente" and self.alvo then
    pcall(function() self.alvo:disconnect() end)
  end
  pcall(function() self.host:flush() end)
  return true
end

function Rede:limpar()
  self.peers = {}
  self.alvo = nil
  self.fila = {}
end

function Rede:ativo()
  return self.host ~= nil
end

function Rede:quantidadePeers()
  local n = 0
  for _ in pairs(self.peers) do n = n + 1 end
  return n
end

-- IPs locais via luasocket (embutido no LOVE; love.system nao tem API de IP).
-- O truque do UDP nao envia pacote nenhum: so consulta a rota do sistema.
function rede.ipsLocais()
  local ips = {}
  local ok, socket = pcall(require, "socket")
  if not ok or not socket then return ips end
  local okU, udp = pcall(socket.udp)
  if okU and udp then
    pcall(udp.setpeername, udp, "8.8.8.8", 80)
    local okG, nome = pcall(udp.getsockname, udp)
    if okG and nome and tostring(nome) ~= "*" then
      ips[#ips + 1] = tostring(nome)
    end
    pcall(udp.close, udp)
  end
  if #ips == 0 then
    local okH, ip = pcall(function()
      return socket.dns.toip(socket.dns.gethostname())
    end)
    if okH and ip then ips[#ips + 1] = tostring(ip) end
  end
  return ips
end

return rede
