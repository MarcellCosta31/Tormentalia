-- Descoberta de salas na rede local (sem digitar IP).
-- Enquanto o lobby esta aberto o cliente manda um PING UDP em broadcast a
-- cada poucos segundos; cada host com sala livre responde com nome, contagem
-- de jogadores e porta de jogo. O cliente monta a lista e da para entrar com
-- um toque. O trafego de descoberta usa luasocket na PORTA (rede.PORTA + 1),
-- separada da porta de jogo: la dentro o enet e o dono do socket e pacotes
-- estranhos seriam lixo para ele. Se a resposta nao chegar por alguns
-- segundos a sala expira da lista. Alem do broadcast (limitado e dirigido),
-- o cliente varre a subrede /24 em UNICAST, escalonada: varios roteadores
-- filtram broadcast entre aparelhos, mas unicast passa — e o IP manual ja
-- prova esse caminho.
local rede = require "rede"
local json = require "json"

local D = {}
D.PORTA = rede.PORTA + 1
-- Destino do ping. Em producao e o broadcast da rede; os testes trocam para
-- 127.0.0.1 (unicast loopback) para nao depender de placa de rede.
D.alvo = "255.255.255.255"

local INTERVALO = 0.8  -- segundos entre pings
local VIDA = 3.5       -- sem resposta por isso tempo a sala some da lista
-- Varredura unicast da subrede: leva de pings por ciclo de ping. 96 por
-- ciclo cobre a /24 (254 hosts) em ~3 voltas = 2.4s, abaixo da VIDA —
-- sala achada na varredura nao pisca na lista (cada resposta refresca
-- `visto`; se a volta demorasse mais que a VIDA ela sumiria e voltava).
local VARREDURA_LEVA = 96
-- Diagnostico opcional (JOGO_DEBUG_DESC=1): imprime pings/respostas.
local dbgDesc = os.getenv("JOGO_DEBUG_DESC") ~= nil
local function logDesc(fmt, ...)
  if dbgDesc then print(string.format(fmt, ...)) end
end

local Desc = {}
Desc.__index = Desc

local function socketNovo()
  local ok, socket = pcall(require, "socket")
  if not ok or not socket then return nil end
  local okU, s = pcall(socket.udp)
  if not okU or not s then return nil end
  pcall(s.settimeout, s, 0)  -- nao-bloqueante: receivefrom devolve nil na fila vazia
  return s
end

-- Le tudo que chegou no socket chama aoReceber(msg, ip, porta) por pacote.
local function drenar(sock, aoReceber)
  if not sock then return end
  for _ = 1, 64 do
    local ok, dados, ip, porta = pcall(sock.receivefrom, sock)
    if not ok or not dados then return end
    local okJ, msg = pcall(json.decode, dados)
    if okJ and type(msg) == "table" then
      aoReceber(msg, ip, porta)
    end
  end
end

-- Subrede /24 de cada IP local: lista dos 254 enderecos (um por linha,
-- na ordem) para a varredura unicast. So monta a lista — nenhum pacote
-- sai daqui (os pings saem em atualizar, na leva de VARREDURA_LEVA).
local function subredesLocal()
  local lista, bases = {}, {}
  for _, ip in ipairs(rede.ipsLocais()) do
    local a, b, c = tostring(ip):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if a then
      local base = a .. "." .. b .. "." .. c .. "."
      if not bases[base] then
        bases[base] = true
        for h = 1, 254 do lista[#lista + 1] = base .. h end
      end
    end
  end
  return lista
end

function D.novo()
  return setmetatable({
    sockHost = nil,   -- responder do anfitriao (bind na PORTA)
    sockCli = nil,    -- sonda do cliente (porta efemera)
    infoHost = nil,   -- callback com os dados atuais da sala
    salas = {},       -- [ip:porta] = { ip, porta, nome, jogadores, max, visto }
    tPing = 0,
    tTotal = 0,
    tSonda = 0,       -- tempo desde que a sonda do cliente subiu
    tResposta = -9999,-- tTotal da ultima resposta recebida
    pings = 0,        -- pings que realmente sairam (diagnostico na tela)
    respostas = 0,    -- respostas de host recebidas (diagnostico na tela)
    erro = nil,       -- motivo de a sonda nao ter subido (ou nil)
    lembrado = nil,   -- IP conectado antes (ping unicast extra)
    varredura = nil,  -- subrede /24 em fila (varredura unicast escalonada)
    varreduraI = 1,   -- cursor da varredura (proximo host a pingar)
  }, Desc)
end

-- Anfitriao: comeca a responder PINGs. `cb` devolve os dados da sala (ou nil
-- quando a sala nao esta apta para entrar: cheia ou partida em andamento).
function Desc:iniciarHost(cb)
  self:pararHost()
  local s = socketNovo()
  if not s then return nil, "luasocket indisponivel" end
  local ok, res, err = pcall(s.setsockname, s, "0.0.0.0", D.PORTA)
  if not ok or res == nil then
    pcall(s.close, s)
    -- Porta ocupada (outra copia do jogo ja anunciando): segue sem anuncio;
    -- oIP manual continua funcionando.
    logDesc("[desc] host NAO anunciou: %s", tostring(err or "porta ocupada"))
    return nil, tostring(err or "porta " .. D.PORTA .. " ocupada")
  end
  logDesc("[desc] host anunciando na porta %s", tostring(D.PORTA))
  self.sockHost, self.infoHost = s, cb
  return true
end

function Desc:pararHost()
  if self.sockHost then
    pcall(self.sockHost.close, self.sockHost)
    self.sockHost, self.infoHost = nil, nil
  end
end

-- Cliente: abre a sonda. `pingar` e decidido pelo chamador (so no lobby).
function Desc:iniciarCliente()
  self:pararCliente()
  local s = socketNovo()
  if not s then
    self.erro = "luasocket indisponivel"
    return nil, self.erro
  end
  pcall(s.setoption, s, "broadcast", true)
  local ok, res = pcall(s.setsockname, s, "0.0.0.0", 0)
  if not ok or res == nil then
    pcall(s.close, s)
    self.erro = "sem porta efemera para as respostas"
    return nil, self.erro
  end
  self.sockCli = s
  self.erro = nil
  self.pings, self.respostas = 0, 0
  self.tSonda = 0
  self.tResposta = -9999
  self.tPing = INTERVALO  -- primeiro ping sai ja no proximo atualizar
  -- Varredura unicast da subrede so com o alvo de producao (broadcast).
  -- Os testes trocam D.alvo para 127.0.0.1 (unicast loopback) e nao podem
  -- sair pingando a rede real da maquina de teste.
  self.varredura = D.alvo == "255.255.255.255" and subredesLocal() or nil
  self.varreduraI = 1
  return true
end

function Desc:pararCliente()
  if self.sockCli then
    pcall(self.sockCli.close, self.sockCli)
    self.sockCli = nil
  end
  self.salas = {}
  self.tPing = 0
  self.varredura, self.varreduraI = nil, 1
end

function Desc:parar()
  self:pararHost()
  self:pararCliente()
end

-- `pingar` = cliente deve sondar agora (so faz sentido no lobby).
function Desc:atualizar(dt, pingar)
  dt = dt or 0
  self.tTotal = self.tTotal + dt
  if self.sockCli then self.tSonda = self.tSonda + dt end

  if self.sockHost then
    drenar(self.sockHost, function(msg, ip, porta)
      if msg.t == "PING" and self.infoHost then
        local info = self.infoHost()
        logDesc("[desc] host recebeu PING de %s:%s (sala=%s)",
          tostring(ip), tostring(porta), tostring(info ~= nil))
        if info then
          local resp = {
            t = "SALA", nome = info.nome, jogadores = info.jogadores,
            max = info.max, porta = info.porta,
          }
          local texto = json.encode(resp)
          -- Resposta unicast para a porta de onde veio o ping (o cliente
          -- escuta numa porta efemera que so ele conhece).
          pcall(self.sockHost.sendto, self.sockHost, texto, ip, porta)
        end
      end
    end)
  end

  if self.sockCli then
    if pingar then
      self.tPing = self.tPing + dt
      if self.tPing >= INTERVALO then
        self.tPing = 0
        local texto = json.encode({ t = "PING" })
        -- Conta so o que realmente saiu (pcall ok E sendto com retorno):
        -- sem SO_BROADCAST (ou rede que bloqueia) o envio falha calado e a
        -- tela precisa mostrar "SEM RESPOSTA" em vez de fingir que pinga.
        local function ping(alvo)
          local ok, ret = pcall(self.sockCli.sendto, self.sockCli, texto,
            alvo, D.PORTA)
          if ok and ret ~= nil then self.pings = self.pings + 1 end
          logDesc("[desc] ping %s -> %s:%s (ok=%s)", tostring(alvo),
            tostring(D.alvo == alvo and "broadcast" or "unicast"),
            tostring(D.PORTA), tostring(ok and ret ~= nil))
        end
        ping(D.alvo)
        -- Alem do broadcast limitado (255.255.255.255), que alguns
        -- roteadores filtram entre aparelhos: unicast para os IPs proprios
        -- (descoberta na mesma maquina) e broadcast dirigido da subrede
        -- (/24 heuristico), que costuma passar onde o limitado nao passa.
        for _, ip in ipairs(rede.ipsLocais()) do
          local alvo = tostring(ip)
          if alvo:match("^%d+%.%d+%.%d+%.%d+$") then
            if alvo ~= D.alvo then ping(alvo) end
            local a, b, c = alvo:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
            local dir = a .. "." .. b .. "." .. c .. ".255"
            if dir ~= alvo then ping(dir) end
          end
        end
        -- IP da ultima conexao manual: reaparece na lista sem depender de
        -- broadcast nenhum (unicast puro).
        if self.lembrado
            and self.lembrado:match("^%d+%.%d+%.%d+%.%d+$") then
          ping(self.lembrado)
        end
        -- Varredura unicast da subrede (/24), escalonada na leva: broadcast
        -- (limitado e dirigido) e filtrado por varios roteadores entre
        -- aparelhos; unicast passa, e e o mesmo caminho que o IP manual ja
        -- usa. Uma leva por ciclo cobre a subrede toda em ~2.4s.
        if self.varredura and #self.varredura > 0 then
          for _ = 1, VARREDURA_LEVA do
            ping(self.varredura[self.varreduraI])
            self.varreduraI = self.varreduraI + 1
            if self.varreduraI > #self.varredura then self.varreduraI = 1 end
          end
        end
      end
    end
    drenar(self.sockCli, function(msg, ip)
      if msg.t == "SALA" then
        self.respostas = self.respostas + 1
        self.tResposta = self.tTotal
        logDesc("[desc] cliente recebeu SALA de %s (nome=%s)",
          tostring(ip), tostring(msg.nome))
        -- O IP vem do remetente (e o caminho de volta real), nao do payload:
        -- o host pode ter varios enderecos e o cliente enxerga um deles.
        local chave = tostring(ip) .. ":" .. tostring(msg.porta or D.PORTA)
        self.salas[chave] = {
          ip = tostring(ip),
          porta = tonumber(msg.porta) or rede.PORTA,
          nome = tostring(msg.nome or ip),
          jogadores = tonumber(msg.jogadores) or 1,
          max = tonumber(msg.max) or 8,
          visto = self.tTotal,
        }
      end
    end)
  end

  for k, s in pairs(self.salas) do
    if self.tTotal - s.visto > VIDA then self.salas[k] = nil end
  end
end

-- Guarda um IP digitado/conectado para a sonda pingar tambem (unicast),
-- ja que o broadcast pode ser filtrado pelo roteador.
function Desc:lembrar(ip)
  local alvo = tostring(ip or ""):gsub("%s", "")
  if alvo:match("^%d+%.%d+%.%d+%.%d+$") then
    self.lembrado = alvo
  end
end

-- Codigo da sonda para a tela do lobby:
--   SEM_REDE      = socket/luasocket indisponivel neste aparelho
--   OK            = host respondeu nos ultimos segundos
--   PROCURANDO    = sonda recente, ainda esperando a primeira resposta
--   SEM_RESPOSTA  = pingando ha bastante tempo e ninguem respondeu
--   PARADO        = sonda desligada (fora do lobby)
function Desc:sondaStatus()
  if self.erro then return "SEM_REDE" end
  if self.tTotal - self.tResposta < VIDA then return "OK" end
  if not self.sockCli then return "PARADO" end
  if self.tSonda >= 4 then return "SEM_RESPOSTA" end
  return "PROCURANDO"
end

-- Lista ordenada das salas vivas. (Nao chama de "salas": o campo homonimo
-- da instancia e a tabela de dados e taparia o metodo.)
function Desc:listaSalas()
  local lista = {}
  for _, s in pairs(self.salas) do
    if self.tTotal - s.visto <= VIDA then
      lista[#lista + 1] = s
    end
  end
  table.sort(lista, function(a, b)
    if a.nome ~= b.nome then return a.nome < b.nome end
    return a.ip < b.ip
  end)
  return lista
end

return D
