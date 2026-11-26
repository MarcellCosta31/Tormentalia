-- Tela MULTIPLAYER: lobby (CRIAR SALA ou CONECTAR COM IP em qualquer
-- aparelho, com lista de partidas da rede) e sala de espera (lista de
-- jogadores, PRONTO, INICIAR do anfitriao). PC ou celular podem ser o
-- anfitriao. Fluxo de mensagens (Fase 1):
--   cliente: ENTRAR {nick, avatar}  -> host: BEM_VINDO {assento} + SALA (por cliente)
--   cliente: PRONTO {pronto}        -> host: SALA (por cliente)
--   host: remove no disconnect      -> host: SALA (por cliente)
-- A SALA vai POR CLIENTE com o `seuAssento` do receptor: no lobby os
-- assentos sao renumerados quando alguem sai, e so o host sabe o numero
-- novo do cliente — sem isso ele acha que foi removido e cai fora.
-- Fase 2 (partida): as mensagens de jogo (INICIADO/SNAPSHOT/PEDIR_SNAPSHOT/
-- CARTA_JOGADA/JOGAR/EMOJI/PEDIR_REACAO/REACAO/...) sao roteadas para a fila
-- consumirPartida(); o main.lua monta e aplica as regras. O host tambem resolve
-- o assento do remetente pelo id do peer (peer:index() e 1-based; o host e o
-- unico id 0).
local ui = require "ui"
local arte = require "arte"
local rede = require "rede"
local descoberta = require "descoberta"

local M = {}
M.__index = M

-- Tipos que pertencem a partida (Fase 2), nao ao lobby.
local TIPOS_PARTIDA = {
  INICIADO = true, SNAPSHOT = true, CARTA_JOGADA = true,
  MAO = true, RECUSADO = true,
  JOGAR = true, GUARDAR = true, USAR_AREA = true, PASSAR = true,
  ARMAR_DEFESA = true,
  PEDIR_MAO = true, EMOJI = true, PEDIR_SNAPSHOT = true,
  -- Quick Counter remoto: host pede a reacao ao alvo e espera a resposta.
  PEDIR_REACAO = true, REACAO = true,
  -- Leilao em rede: host autoritativo recebe lances/confirmacoes.
  LANCE_LEILAO = true, CONFIRMAR_LEILAO = true,
}

local VW, VH = 1280, 720
local MAX_JOGADORES = 8
local PAD = 22
local TEMPO_CONEXAO = 8
-- Linhas de partida encontrada no lobby (cabecalho + linha de sala).
local CAB_SALA, ALT_SALA = 26, 46

-- CHAT DA SALA: painel que entra a direita da sala de espera; so os membros
-- da sala escrevem e todos os membros veem. CHAT_HIST limita a memoria (as
-- mais antigas saem) e CHAT_TAM limita cada mensagem (pacote e linha de
-- desenho).
local CHAT_W, CHAT_GAP = 380, 18
local CHAT_HIST, CHAT_TAM = 60, 140

-- PLAYER_COLORS do RN (mesmo ordem do arena_menu).
local CORES = {
  "#FFD54F", "#EF5350", "#42A5F5", "#66BB6A",
  "#AB47BC", "#FF7043", "#26C6DA", "#EC407A",
}

local function dentro(x, y, r)
  return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Teclado software (Android/iOS): o campo do chat so abre o teclado quando
-- esta em foco. Fica aqui em cima porque o fechar() tambem derruba o foco.
local function aoTeclado(ativo)
  if love.keyboard and love.keyboard.setTextInput then
    love.keyboard.setTextInput(ativo)
  end
end

-- Cor do autor da mensagem: aceita o "#RRGGBB" que veio no pacote; qualquer
-- coisa fora do formato (pacote estranho/versao antiga) cai no branco.
local function corChat(c)
  if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then return ui.hex(c) end
  return ui.hex "#E8EAF6"
end

-- Guarda uma mensagem no historico da sala (a mais antiga sai no limite).
-- O texto e cortado em CHAT_TAM: quem envia pode mentir no tamanho.
local function adicionarChat(st, nome, texto, cor)
  local h = st.chat
  if not h then h = {} st.chat = h end
  local limpo = tostring(texto or ""):sub(1, CHAT_TAM)
  if limpo == "" then return end
  local autor = tostring(nome or "?"):gsub("^%s+", ""):gsub("%s+$", "")
  h[#h + 1] = { nome = autor:sub(1, 20), texto = limpo, cor = cor }
  while #h > CHAT_HIST do table.remove(h, 1) end
end

-- Sobra so o texto util: sem espacos nas pontas e sem vazio.
local function limparTexto(t)
  if type(t) ~= "string" then return "" end
  t = t:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return t:sub(1, CHAT_TAM)
end

-- Aparelho com teclado na TELA (celular/tablet): so nesses o campo do chat
-- precisa subir para nao ficar atras do teclado software. Onde a altura do
-- teclado nao e confiavel (love.keyboard.isVisible nem existe em toda
-- versao), a saida e reservar a faixa de baixo da tela.
-- M.aparelhoMovel (nil = detecta pelo love.system) existe para os testes e
-- para a captura forcada; no PC a deteccao da false e o par nao sobe.
M.aparelhoMovel = nil
local function ehMovel()
  if M.aparelhoMovel ~= nil then return M.aparelhoMovel and true or false end
  local ok, osNome = pcall(love.system.getOS)
  return ok and (osNome == "Android" or osNome == "iOS") or false
end

-- Fundo do par sala+chat no CELULAR com o campo aberto: acima disto fica
-- livre para o teclado software (em paisagem ele come boa parte da tela).
-- 0.34 deixa o campo no TERCO DE CIMA: se o teclado do aparelho ainda cobrir,
-- basta baixar este numero.
local CHAT_BASE_MOVEL = 0.34

local DIF_NOMES = { "FACIL", "MEDIA", "DIFICIL" }

-- qtdIA limitado as vagas livres (8 - humanos): nunca ultrapassa o maximo
-- de espacos; preencherIA acompanha (qtdIA > 0) para o main antigo.
local function clampIA(st)
  local livre = math.max(0, MAX_JOGADORES - #st.jogadores)
  local q = math.floor(tonumber(st.qtdIA) or 0)
  if q < 0 then q = 0 elseif q > livre then q = livre end
  st.qtdIA = q
  st.preencherIA = q > 0
  return q
end

local function ipValido(ip)
  if type(ip) ~= "string" or not ip:match("^%d+%.%d+%.%d+%.%d+$") then
    return false
  end
  for bloco in ip:gmatch("%d+") do
    if tonumber(bloco) > 255 then return false end
  end
  return true
end

local function ipPrincipal()
  for _, ip in ipairs(rede.ipsLocais()) do
    if not tostring(ip):match("^127%.") and not tostring(ip):find(":") then
      return tostring(ip)
    end
  end
  local primeiro = rede.ipsLocais()[1]
  return primeiro and tostring(primeiro) or "?"
end

local function novoEstado()
  return {
    telaInterna = "lobby", -- "lobby" | "digitando" | "conectando" | "sala"
    papel = nil,           -- "anfitriao" | "cliente"
    perfil = nil,
    texto = "",
    status = nil,          -- linha de status (erro ou informacao)
    statusErro = false,
    jogadores = {},        -- { assento, nome, avatar, pronto, host, eu, id }
    meuAssento = nil,
    meuPronto = false,
    ipSala = nil,
    conectandoT = 0,
    t = 0,
    -- Fase 3: quantos lugares vazios a IA preenche na hora de iniciar
    -- (0..vagas livres, escolha do host; default = so humanos). O booleano
    -- preencherIA acompanha qtdIA > 0 (compat com smokes/boot antigos).
    -- Vai no broadcast da SALA para o cliente mostrar a mesma informacao.
    preencherIA = false,
    qtdIA = 0,
    -- Dificuldade da IA da sala: 1 = facil, 2 = media, 3 = dificil
    -- (default media). Vai no broadcast da SALA; o host grava a tabela de
    -- parametros em partida.difIA ao iniciar (iaMaquina/proximaFase).
    dificuldade = 2,
    -- Arena da partida em rede: o host escolhe na sala (nil = madeira
    -- padrao; 1..9 = arenas dos ciclos). Vai no broadcast da SALA (todos
    -- veem na espera) e no snapshot (o cliente desenha o mesmo fundo).
    arena = nil,
    -- Fase 2 (partida em andamento).
    filaPartida = {},  -- mensagens de jogo ainda nao consumidas pelo main
    filaSaios = {},    -- saidas em partida (host): { assento, nome }
    emPartida = false,
    partidaEncerrada = nil, -- motivo para o main encerrar a tela de jogo
    -- Bootstrap da partida no cliente: enquanto nao aplicar o primeiro
    -- SNAPSHOT (telaInterna = "partida", mas o main so abre o jogo com o
    -- snapshot) ele reenvia PEDIR_SNAPSHOT a cada ~1s; marcarSincronizado
    -- (chamado pelo main ao aplicar o snapshot) para o reenvio.
    sincronizado = false,
    tSnapPedido = 0,
    -- CHAT DA SALA (existe so dentro da sala): historico { nome, texto, cor }
    -- na ordem em que chegou, o rascunho em digitacao e o foco do campo (o
    -- teclado do celular so abre com o campo em foco).
    chat = {},
    chatTexto = "",
    chatFoco = false,
  }
end

-- GEOMETRIA ---------------------------------------------------------------

local function geom(st, podeCriar, desc)
  local w = 640
  -- Na SALA o painel do chat entra a direita: o PAR sala+chat fica centrado
  -- na tela (a sala sozinha continua centralizada).
  local extra = st.telaInterna == "sala" and (CHAT_W + CHAT_GAP) or 0
  local x = math.floor((VW - w - extra) / 2)
  local g = { x = x, w = w, altBtn = 52 }

  if st.telaInterna == "sala" then
    -- 2 colunas x 4 linhas (row-major: 1,2 / 3,4 / ...): os 8 slots
    -- cabem num painel bem menor que a pilha unica de 8.
    local altLinha, gap, colGap = 52, 8, 14
    local listaY = PAD + 84
    local altLista = 4 * altLinha + 3 * gap
    -- Linha de IA (quantidade escolhivel) e linha de DIFICULDADE entre a
    -- lista e os botoes; os dois papeis usam a mesma geometria (host =
    -- botao, cliente = informacao). A ARENA vem num quadrado com a
    -- miniatura da imagem (host cicla; cliente so le).
    local iaY = listaY + altLista + 14
    local difY = iaY + 40 + 8
    local arenaY = difY + 40 + 12
    local btnY = arenaY + 76 + 14
    local h = btnY + 48 + PAD
    g.y = math.floor((VH - h) / 2)
    -- CELULAR com o campo do chat em foco: sobe o par sala+chat para o campo
    -- (e o ENVIAR) nao ficarem atras do teclado software. No PC nada muda.
    if st.chatFoco and ehMovel() then
      local subir = (g.y + h) - math.floor(VH * CHAT_BASE_MOVEL)
      if subir > 0 then g.y = g.y - subir end
    end
    g.listaY = g.y + listaY
    g.altLinha, g.gap = altLinha, gap
    g.ia = { x = x + PAD, y = g.y + iaY, w = w - PAD * 2, h = 40 }
    g.dificuldade = { x = x + PAD, y = g.y + difY, w = w - PAD * 2, h = 40 }
    g.arena = { x = x + PAD, y = g.y + arenaY, w = w - PAD * 2, h = 76 }
    local largBtn = (w - PAD * 2 - 12) / 2
    g.iniciar = { x = x + PAD, y = g.y + btnY, w = largBtn, h = 48 }
    g.pronto = g.iniciar
    g.sair = { x = x + PAD + largBtn + 12, y = g.y + btnY, w = largBtn, h = 48 }
    g.h = h
    g.linhas = {}
    local colW = (w - PAD * 2 - colGap) / 2
    for i = 1, MAX_JOGADORES do
      g.linhas[i] = {
        x = x + PAD + ((i - 1) % 2) * (colW + colGap),
        y = g.listaY + math.floor((i - 1) / 2) * (altLinha + gap),
        w = colW, h = altLinha,
      }
    end
    -- CHAT: painel a direita, da mesma altura da sala, com o campo de
    -- digitacao e o ENVIAR na base (digita AQUI MESMO, sem painel a parte).
    local chatX = x + w + CHAT_GAP
    g.chat = {
      x = chatX, y = g.y, w = CHAT_W, h = h,
      campo = { x = chatX + 12, y = g.y + h - 46, w = CHAT_W - 24 - 82, h = 34 },
      enviar = { x = chatX + CHAT_W - 12 - 74, y = g.y + h - 46, w = 74, h = 34 },
    }
    return g
  end

  local altBtn = 52
  local listaY = PAD + 76
  local h
  -- Secao de partidas encontradas (só no lobby): cabecalho + ate 3 linhas,
  -- ou a linha de "procurando" quando nao ha nenhuma sala ainda.
  local salasLinhas, salasH = {}, 0
  if st.telaInterna == "digitando" then
    h = listaY + 48 + 12 + altBtn * 2 + 12 + PAD
  elseif st.telaInterna == "conectando" then
    h = listaY + 70 + altBtn + PAD
  else
    local n = (podeCriar and 1 or 0) + 2
    if st.telaInterna == "lobby" then
      local todas = desc and desc:listaSalas() or {}
      local nMostro = math.min(#todas, 3)
      for i = 1, nMostro do salasLinhas[i] = todas[i] end
      salasH = nMostro > 0
        and (CAB_SALA + nMostro * ALT_SALA + (nMostro - 1) * 8 + 16)
        or 30
    end
    -- + 34 de folga para a linha de dica embaixo dos botoes.
    h = listaY + salasH + n * altBtn + (n - 1) * 12 + 34 + PAD
  end
  -- No modo digitando o painel SEMPRE sobe para o topo: o LÖVE nao expoe a
  -- altura do teclado software e love.keyboard.isVisible nem existe em toda
  -- versao/plataforma (no celular atual ele nao detectou o teclado e o
  -- campo ficou atras dele). Garantir a visibilidade do campo vale mais
  -- que estetica; sem teclado (lobby/sala) o painel continua centralizado.
  if st.telaInterna == "digitando" then
    g.y = 16
  else
    g.y = math.floor((VH - h) / 2)
  end
  g.listaY = g.y + listaY
  g.h = h

  local largBtn = w - PAD * 2
  local y = g.listaY
  if st.telaInterna == "lobby" then
    g.salasY = y
    g.salas = {}
    for i, sala in ipairs(salasLinhas) do
      g.salas[i] = {
        x = x + PAD, y = g.salasY + CAB_SALA + (i - 1) * (ALT_SALA + 8),
        w = largBtn, h = ALT_SALA, sala = sala,
      }
    end
    y = y + salasH
    if podeCriar then
      g.criar = { x = x + PAD, y = y, w = largBtn, h = altBtn }
      y = y + altBtn + 12
    end
    g.ip = { x = x + PAD, y = y, w = largBtn, h = altBtn }
    y = y + altBtn + 12
    g.voltar = { x = x + PAD, y = y, w = largBtn, h = altBtn }
  elseif st.telaInterna == "digitando" then
    g.campo = { x = x + PAD, y = y, w = largBtn, h = 48 }
    y = y + 48 + 12
    g.conectar = { x = x + PAD, y = y, w = largBtn, h = altBtn }
    y = y + altBtn + 12
    g.voltar = { x = x + PAD, y = y, w = largBtn, h = altBtn }
  elseif st.telaInterna == "conectando" then
    g.voltar = { x = x + PAD, y = y + 70, w = largBtn, h = altBtn }
  end
  return g
end

-- INSTANCIA ---------------------------------------------------------------

function M.novo()
  -- Cada tela tem sua propria sonda de descoberta: host e cliente podem
  -- coexistir (testes) sem um matar o socket do outro.
  return setmetatable({ st = novoEstado(), net = nil, porta = rede.PORTA,
    desc = descoberta.novo() }, M)
end

function M:estado()
  return self.st
end

function M:retangulos()
  -- CRIAR SALA vale para qualquer aparelho (PC ou celular host).
  return geom(self.st, true, self.desc)
end

function M:fechar()
  -- Campo do chat em foco: o teclado do celular fecha junto com a tela.
  if self.st and self.st.chatFoco then
    self.st.chatFoco = false
    aoTeclado(false)
  end
  self.desc:parar()
  if self.net then
    self.net:desconectarTodos()
    self.net:limpar()
    self.net = nil
  end
end

function M:iniciar(perfil, porta)
  self:fechar()
  self.st = novoEstado()
  self.st.perfil = { nick = perfil and perfil.nick or "JOGADOR_1",
    avatar = perfil and perfil.avatar or "1" }
  self.porta = porta or rede.PORTA
  -- Ja comeca a procurar salas anunciadas na rede (a lista aparece so no
  -- lobby; o ping em si so sai quando atualizar() libera).
  self.desc:iniciarCliente()
end

function M:criarSala()
  local st = self.st
  if not rede.disponivel then
    st.status, st.statusErro = "REDE INDISPONIVEL NESTE APARELHO", true
    return nil
  end
  local net = rede.novo()
  local ok, err = net:criarServidor(self.porta)
  if not ok then
    st.status, st.statusErro = "ERRO AO CRIAR SALA: " .. tostring(err), true
    return nil
  end
  self.net = net
  st.papel = "anfitriao"
  st.telaInterna = "sala"
  st.status = nil
  st.jogadores = {
    { assento = 1, id = 0, nome = st.perfil.nick, avatar = st.perfil.avatar,
      pronto = false, host = true, eu = true },
  }
  st.meuAssento = 1
  st.ipSala = ipPrincipal()
  aoTeclado(false)
  -- Anuncia a sala na rede: o lobby dos outros aparelhos mostra a linha
  -- para entrar com um toque (sem digitar IP).
  self.desc:iniciarHost(function()
    local s = self.st
    if s.emPartida or #s.jogadores >= MAX_JOGADORES then return nil end
    return {
      nome = (s.jogadores[1] and s.jogadores[1].nome) or "PARTIDA",
      jogadores = #s.jogadores, max = MAX_JOGADORES, porta = self.porta,
    }
  end)
  return true
end

function M:conectar(ip, porta)
  local st = self.st
  ip = tostring(ip or ""):gsub("%s", "")
  if not ipValido(ip) then
    st.status, st.statusErro = "IP INVALIDO (ex.: 192.168.0.10)", true
    return nil
  end
  if not rede.disponivel then
    st.status, st.statusErro = "REDE INDISPONIVEL NESTE APARELHO", true
    return nil
  end
  local net = rede.novo()
  local ok, err = net:conectar(ip, porta or self.porta)
  if not ok then
    st.status, st.statusErro = "ERRO AO CONECTAR: " .. tostring(err), true
    return nil
  end
  self.net = net
  st.papel = "cliente"
  st.telaInterna = "conectando"
  st.status = ui.tr("CONECTANDO A") .. " " .. ip .. "..."
  st.statusErro = false
  st.conectandoT = 0
  -- Guarda o IP usado: a sonda passa a fazer ping tambem nele (unicast),
  -- para a sala reaparecer na lista mesmo em rede que filtra broadcast.
  self.desc:lembrar(ip)
  aoTeclado(false)
  return true
end

function M:sair()
  local st = self.st
  self:fechar()
  st.telaInterna = "lobby"
  st.papel = nil
  st.jogadores = {}
  st.meuAssento = nil
  st.meuPronto = false
  st.texto = ""
  st.status = nil
  st.preencherIA = false
  st.qtdIA = 0
  st.dificuldade = 2
  st.filaPartida = {}
  st.filaSaios = {}
  st.emPartida = false
  st.partidaEncerrada = nil
  st.sincronizado = false
  st.tSnapPedido = 0
  -- Chat e da sala: sai junto (a sala nova comeca sem historico).
  st.chat = {}
  st.chatTexto = ""
  st.chatFoco = false
  aoTeclado(false)
  -- De volta ao lobby: volta a procurar partidas na rede.
  self.desc:iniciarCliente()
end

function M:alternarPronto()
  local st = self.st
  st.meuPronto = not st.meuPronto
  if st.papel == "cliente" and self.net then
    self.net:enviarParaServidor({ tipo = "PRONTO", pronto = st.meuPronto })
  end
end

-- Escrita: no modo "digitando" vai para o campo de IP; na sala com o chat em
-- foco vai para o rascunho da mensagem (qualquer caractere imprimivel).
function M:digitar(c)
  local st = self.st
  if st.telaInterna == "digitando" then
    if c and c:match("[%d.]") and #st.texto < 15 then
      st.texto = st.texto .. c
    end
  elseif st.telaInterna == "sala" and st.chatFoco then
    if type(c) ~= "string" then return end
    c = c:gsub("[%c]", "")
    if c == "" then return end
    local livre = CHAT_TAM - #(st.chatTexto or "")
    if livre <= 0 then return end
    st.chatTexto = (st.chatTexto or "") .. c:sub(1, livre)
  end
end

function M:apagar()
  local st = self.st
  if st.telaInterna == "digitando" then
    st.texto = st.texto:sub(1, -2)
  elseif st.telaInterna == "sala" and st.chatFoco then
    st.chatTexto = (st.chatTexto or ""):sub(1, -2)
  end
end

-- CHAT DA SALA ------------------------------------------------------------

-- Abre o campo do chat (so na sala): no celular abre o teclado software.
function M:focarChat()
  if self.st.telaInterna ~= "sala" then return nil end
  self.st.chatFoco = true
  aoTeclado(true)
  return true
end

-- Fecha o campo do chat e o teclado. Devolve true se algo estava em foco (o
-- ESC usa isso para fechar o campo em vez de sair da tela).
function M:desfocarChat()
  if not self.st.chatFoco then return nil end
  self.st.chatFoco = false
  aoTeclado(false)
  return true
end

function M:chatFocado()
  return self.st.chatFoco and true or false
end

-- Manda o rascunho para a sala. No host: grava na hora e repassa a todos os
-- clientes. No cliente: manda para o anfitriao, que resolve o NOME (o cliente
-- nao escolhe o proprio nome) e repassa a todos — inclusive de volta para
-- quem escreveu, entao todos veem a mesma ordem. Devolve true se enviou.
function M:enviarChat()
  local st = self.st
  if st.telaInterna ~= "sala" or st.emPartida or not self.net then
    return nil
  end
  local texto = limparTexto(st.chatTexto)
  if texto == "" then return nil end
  st.chatTexto = ""
  if st.papel == "anfitriao" then
    local cor = CORES[st.meuAssento or 1] or CORES[1]
    local nome = (st.perfil and st.perfil.nick) or "ANFITRIAO"
    adicionarChat(st, nome, texto, cor)
    self.net:enviarTodos({ tipo = "CHAT", nome = nome, texto = texto, cor = cor })
  else
    self.net:enviarParaServidor({ tipo = "CHAT", texto = texto })
  end
  return true
end

-- PROTOCOLO ---------------------------------------------------------------

local function transmitirSala(self)
  local st = self.st
  -- Recalcula o limite antes de mandar: quem entra/sai muda o numero de
  -- vagas livres e o cliente deve ver o mesmo valor apertado do host.
  clampIA(st)
  local lista = {}
  for _, j in ipairs(st.jogadores) do
    lista[#lista + 1] = {
      assento = j.assento, nome = j.nome, avatar = j.avatar,
      pronto = j.pronto, host = j.id == 0,
    }
  end
  -- Salas por cliente com o assento ATUAL do receptor: no lobby o remover
  -- renumera (quem vem depois desce um lugar) e o cliente so tem o numero
  -- que o BEM_VINDO deu; o seuAssento na propria SALA evita o kick falso
  -- "VOCE SAIU DA SALA". Uma unica mensagem, entao nao ha dependencia de
  -- ordem entre avisos. O host le o proprio estado direto (id 0 ignora).
  for _, j in ipairs(st.jogadores) do
    if j.id ~= 0 then
      self.net:enviar(j.id, {
        tipo = "SALA", jogadores = lista, max = MAX_JOGADORES,
        ia = st.preencherIA, qtdIA = st.qtdIA, dif = st.dificuldade,
        seuAssento = j.assento, arena = st.arena,
      })
    end
  end
end

-- Remove o peer da sala. No LOBBY os assentos sao renumerados (lista
-- compacta para o proximo entrar). Em PARTIDA NAO: os assentos precisam
-- bater com os indices de partida.jogadores (acoes pendentes e snapshots
-- usam o mesmo numero), entao sobra o buraco do que saiu.
local function removerPeer(self, id, renumerar)
  local st = self.st
  for i, j in ipairs(st.jogadores) do
    if j.id == id then
      table.remove(st.jogadores, i)
      if renumerar ~= false then
        for k = i, #st.jogadores do
          st.jogadores[k].assento = k
        end
      end
      return true
    end
  end
  return false
end

local function processarAnfitriao(self, ev)
  local st = self.st
  -- Mensagens de partida (Fase 2): so enfileira; quem aplica e o main.
  if ev.tipo == "mensagem" and ev.msg and TIPOS_PARTIDA[ev.msg.tipo] then
    st.filaPartida[#st.filaPartida + 1] = { id = ev.id, msg = ev.msg }
    return
  end
  -- CHAT: o texto vem do cliente, mas o NOME sai da lista do host (ninguem
  -- escolhe o proprio nome no chat) e a cor tambem e do assento. Repassa a
  -- todos os clientes; o autor recebe a propria mensagem de volta, entao a
  -- ordem vista e sempre a do host.
  if ev.tipo == "mensagem" and ev.msg and ev.msg.tipo == "CHAT" then
    if st.emPartida then return end
    local jogador
    for _, j in ipairs(st.jogadores) do
      if j.id == ev.id then jogador = j break end
    end
    if not jogador then return end
    local texto = limparTexto(ev.msg.texto)
    if texto == "" then return end
    local cor = CORES[jogador.assento] or CORES[1]
    adicionarChat(st, jogador.nome, texto, cor)
    self.net:enviarTodos({ tipo = "CHAT", nome = jogador.nome, texto = texto,
      cor = cor })
    return
  end
  if ev.tipo == "mensagem" and ev.msg and ev.msg.tipo == "ENTRAR" then
    if st.emPartida then
      -- Partida rolando: nao entra mais ninguem.
      self.net:enviar(ev.id, { tipo = "CHEIA" })
      return
    end
    if #st.jogadores >= MAX_JOGADORES then
      self.net:enviar(ev.id, { tipo = "CHEIA" })
      return
    end
    local assento = #st.jogadores + 1
    st.jogadores[#st.jogadores + 1] = {
      assento = assento, id = ev.id,
      nome = tostring(ev.msg.nick or "JOGADOR"):sub(1, 20),
      avatar = tostring(ev.msg.avatar or "1"),
      pronto = false, host = false,
    }
    self.net:enviar(ev.id, { tipo = "BEM_VINDO", assento = assento })
    transmitirSala(self)
  elseif ev.tipo == "mensagem" and ev.msg and ev.msg.tipo == "PRONTO" then
    for _, j in ipairs(st.jogadores) do
      if j.id == ev.id then
        j.pronto = ev.msg.pronto and true or false
        transmitirSala(self)
        return
      end
    end
  elseif ev.tipo == "desconectado" then
    -- Captura seat/nome ANTES de remover (no lobby o remover renumera).
    local alvo, nome
    for _, j in ipairs(st.jogadores) do
      if j.id == ev.id then alvo, nome = j.assento, j.nome break end
    end
    if removerPeer(self, ev.id, not st.emPartida) then
      if st.emPartida then
        -- A partida CONTINUA sem quem saiu: o main marca o seat como
        -- saiu (some da arena), gera o aviso no canto e reorganiza o
        -- turno. So a saida do HOST encerra a partida — e esse caso o
        -- cliente detecta sozinho (DESCONECTADO DO ANFITRIAO).
        st.filaSaios[#st.filaSaios + 1] = { assento = alvo, nome = nome }
      else
        transmitirSala(self)
      end
    end
  end
end

local function processarCliente(self, ev)
  local st = self.st
  if ev.tipo == "mensagem" and ev.msg and TIPOS_PARTIDA[ev.msg.tipo] then
    -- Fase 2: roteia para o main. INICIADO marca o inicio da partida (usado
    -- para detectar disconnect durante o jogo).
    if ev.msg.tipo == "INICIADO" then
      st.telaInterna = "partida"
      st.emPartida = true
      -- (Re)arma o puxao de snapshot: se o INICIADO chegar sem o SNAPSHOT
      -- inicial (bootstrap incompleto/pacote perdido no meio), o cliente
      -- pede de novo em vez de ficar travado no lobby ate o host agir.
      st.sincronizado = false
      st.tSnapPedido = 0
    end
    st.filaPartida[#st.filaPartida + 1] = { id = ev.id, msg = ev.msg }
    return
  end
  if ev.tipo == "conectado" then
    self.net:enviarParaServidor({
      tipo = "ENTRAR", nick = st.perfil.nick, avatar = st.perfil.avatar,
    })
    return
  end
  if ev.tipo == "desconectado" then
    if st.telaInterna == "sala" or st.telaInterna == "conectando"
        or st.telaInterna == "partida" then
      local emPartida = st.telaInterna == "partida"
      self:fechar()
      st.telaInterna = "lobby"
      st.papel = nil
      st.meuAssento = nil
      st.meuPronto = false
      st.status = "DESCONECTADO DO ANFITRIAO"
      st.statusErro = true
      -- Continua na tela: reativa a busca por salas no lobby.
      self.desc:iniciarCliente()
      if emPartida then
        st.partidaEncerrada = "DESCONECTADO DO ANFITRIAO"
      end
    end
    return
  end
  if ev.tipo ~= "mensagem" or not ev.msg then return end
  local msg = ev.msg
  if msg.tipo == "BEM_VINDO" then
    st.meuAssento = msg.assento
    st.telaInterna = "sala"
    st.status = nil
    st.conectandoT = 0
  elseif msg.tipo == "SALA" then
    -- O host informa o assento atual do receptor: no lobby os assentos
    -- mudam quando alguem sai ANTES de mim, entao o numero do BEM_VINDO
    -- envelhece. Sem atualizar, o check la embaixo me chutaria da sala.
    if msg.seuAssento then st.meuAssento = msg.seuAssento end
    local lista = {}
    for _, j in ipairs(msg.jogadores or {}) do
      lista[#lista + 1] = {
        assento = j.assento, nome = j.nome, avatar = j.avatar,
        pronto = j.pronto, host = j.host,
        eu = st.meuAssento ~= nil and j.assento == st.meuAssento,
      }
    end
    table.sort(lista, function(a, b) return a.assento < b.assento end)
    st.jogadores = lista
    -- Quantidade de IA escolhida pelo host: qtdIA novo (Fase 3 atual) ou
    -- fallback no booleano ia dos hosts antigos (encher ate o maximo).
    st.qtdIA = math.max(0, math.floor(tonumber(msg.qtdIA)
      or ((msg.ia and (MAX_JOGADORES - #lista)) or 0)))
    st.preencherIA = st.qtdIA > 0
    st.dificuldade = math.min(3, math.max(1,
      math.floor(tonumber(msg.dif) or 2)))
    st.arena = tonumber(msg.arena) or nil
    if st.meuAssento then
      local achei = false
      for _, j in ipairs(lista) do
        if j.assento == st.meuAssento then achei = true end
      end
      if not achei then
        self:sair()
        st.status = "VOCE SAIU DA SALA"
        st.statusErro = true
      end
    end
  elseif msg.tipo == "CHEIA" then
    self:sair()
    st.status = "SALA CHEIA (8 JOGADORES)"
    st.statusErro = true
  elseif msg.tipo == "CHAT" then
    -- Ja em partida a tela nao tem chat: nao acumula historia a toa.
    if st.telaInterna ~= "partida" then
      adicionarChat(st, msg.nome, msg.texto, msg.cor)
    end
  end
end

function M:processar(ev)
  if self.st.papel == "anfitriao" then
    processarAnfitriao(self, ev)
  else
    processarCliente(self, ev)
  end
end

-- PARTIDA (Fase 2) ---------------------------------------------------------

-- Consome a fila de mensagens de jogo (INICIADO, SNAPSHOT, CARTA_JOGADA,
-- MAO, RECUSADO e as acoes JOGAR/GUARDAR/USAR_AREA/PASSAR/PEDIR_MAO).
function M:consumirPartida()
  local f = self.st.filaPartida
  self.st.filaPartida = {}
  return f
end

-- Saidas de jogadores durante a partida (so o host gera): o main marca o
-- seat como saiu, mostra o aviso e segue o jogo sem ele.
function M:consumirSaios()
  local f = self.st.filaSaios or {}
  self.st.filaSaios = {}
  return f
end

function M:emPartida()
  return self.st.emPartida
end

function M:partidaEncerrada()
  return self.st.partidaEncerrada
end

function M:marcarPartida(v)
  self.st.emPartida = v and true or nil
end

-- O main aplicou o SNAPSHOT: para o reenvio automatico de PEDIR_SNAPSHOT.
function M:marcarSincronizado()
  self.st.sincronizado = true
end

-- Envia uma mensagem de partida: no cliente vai para o servidor; no host vai
-- para o peer do `assento` (clientes tem id ~= 0, entao nao ha ambiguidade
-- com o host).
function M:enviarPartida(assento, msg)
  if not self.net then return nil, "sem rede" end
  if self.st.papel == "cliente" then
    return self.net:enviarParaServidor(msg)
  end
  for _, j in ipairs(self.st.jogadores) do
    if j.assento == assento and j.id ~= 0 then
      return self.net:enviar(j.id, msg)
    end
  end
  return nil, "assento " .. tostring(assento) .. " sem peer"
end

-- Embaralha os assentos 2..total da partida que vai comecar: os clientes
-- remotos recebem posicoes sorteadas e as cadeiras que sobram viram IA
-- (devolvidas como lista de assentos, na ordem em que as IAs devem ser
-- criadas). O host fica sempre no 1 — no quadro de cada jogador o proprio
-- painel e o de baixo, entao so a ordem dos OUTROS precisa variar; ela
-- varia em todo aparelho porque cada um se vê na posicao 1. O rand e
-- injetavel para o teste (roteirizado); no jogo usa love.math.random.
function M:embaralharAssentos(total, rand)
  local st = self.st
  rand = rand or love.math.random
  local assentos = {}
  for s = 2, total do assentos[#assentos + 1] = s end
  for i = #assentos, 2, -1 do
    local r = rand(i)
    assentos[i], assentos[r] = assentos[r], assentos[i]
  end
  -- Humanos (lista na ordem de entrada; [1] e o host, que nao muda).
  local nHum = #st.jogadores - 1
  for k = 2, #st.jogadores do
    st.jogadores[k].assento = assentos[k - 1]
  end
  local ia = {}
  for i = nHum + 1, #assentos do ia[#ia + 1] = assentos[i] end
  -- Clientes precisam do novo seuAssento ANTES do INICIADO/SNAPSHOT; a
  -- mesma SALA por cliente do renumera de saida ja faz isso.
  transmitirSala(self)
  return ia
end

-- Atalho do cliente (a acao vai direto para o servidor).
function M:enviarParaServidor(msg)
  if not self.net then return nil, "sem rede" end
  return self.net:enviarParaServidor(msg)
end

function M:atualizar(dt)
  local st = self.st
  st.t = st.t + dt
  -- Descoberta: o host responde sempre (mesmo dentro da sala, para a lista
  -- dos outros continuar viva); o cliente so sonda no lobby.
  self.desc:atualizar(dt, st.telaInterna == "lobby")
  if not self.net then return end
  if st.telaInterna == "conectando" then
    st.conectandoT = st.conectandoT + dt
    if st.conectandoT >= TEMPO_CONEXAO then
      self:sair()
      st.status = "TEMPO ESGOTADO AO CONECTAR"
      st.statusErro = true
      return
    end
  end
  -- Cliente no limbo pos-INICIADO (telaInterna "partida", mas o main ainda
  -- nao recebeu SNAPSHOT para abrir o jogo): puxa o estado a cada ~1s ate
  -- sincronizar. Roda ANTES do bombeio para nao pedir de novo no mesmo
  -- frame em que o SNAPSHOT chegou junto com o INICIADO.
  if st.papel == "cliente" and st.telaInterna == "partida"
      and not st.sincronizado then
    st.tSnapPedido = st.tSnapPedido + dt
    if st.tSnapPedido >= 1 then
      st.tSnapPedido = 0
      self.net:enviarParaServidor({ tipo = "PEDIR_SNAPSHOT" })
    end
  end
  self.net:atualizar()
  for _, ev in ipairs(self.net:consumirEventos()) do
    self:processar(ev)
  end
end

-- CLICA (devolve "menu", "iniciar" ou nil) --------------------------------

function M:clicado(vx, vy)
  local st = self.st
  local g = self:retangulos()
  if st.telaInterna == "lobby" then
    -- Entrada por toque: a partida encontrada na rede conecta direto,
    -- sem passar pela digitacao de IP.
    for _, r in ipairs(g.salas) do
      if dentro(vx, vy, r) then
        self:conectar(r.sala.ip, r.sala.porta)
        return nil
      end
    end
    if g.criar and dentro(vx, vy, g.criar) then
      self:criarSala()
    elseif dentro(vx, vy, g.ip) then
      st.telaInterna = "digitando"
      st.status = nil
      aoTeclado(true)
    elseif dentro(vx, vy, g.voltar) then
      return "menu"
    end
  elseif st.telaInterna == "digitando" then
    if dentro(vx, vy, g.conectar) then
      self:conectar(st.texto)
    elseif dentro(vx, vy, g.voltar) then
      st.telaInterna = "lobby"
      st.status = nil
      aoTeclado(false)
    end
  elseif st.telaInterna == "conectando" then
    if dentro(vx, vy, g.voltar) then
      self:sair()
    end
  elseif st.telaInterna == "sala" then
    -- Chat: o toque no campo abre para digitar e o ENVIAR manda — tudo no
    -- proprio painel, ao lado da sala. Clicar FORA do painel do chat fecha o
    -- campo (e o teclado do celular) e segue o clique normal da sala.
    if dentro(vx, vy, g.chat.enviar) then
      self:enviarChat()
      return nil
    elseif dentro(vx, vy, g.chat.campo) then
      self:focarChat()
      return nil
    elseif not dentro(vx, vy, g.chat) then
      self:desfocarChat()
    end
    if st.papel == "anfitriao" and dentro(vx, vy, g.ia) then
      -- Quantidade de IA escolhivel: 0..vagas livres em ciclo (nao e so
      -- liga/desliga) — a partida pode comecar com 1 humano + IA.
      clampIA(st)
      local prox = st.qtdIA + 1
      if prox > MAX_JOGADORES - #st.jogadores then prox = 0 end
      st.qtdIA = prox
      st.preencherIA = prox > 0
      if self.net then transmitirSala(self) end
    elseif st.papel == "anfitriao" and dentro(vx, vy, g.dificuldade) then
      -- Dificuldade da IA: facil -> media -> dificil -> facil. So o host
      -- troca; o cliente so le (mesma regra da arena).
      st.dificuldade = ((tonumber(st.dificuldade) or 2) % 3) + 1
      if self.net then transmitirSala(self) end
    elseif st.papel == "anfitriao" and dentro(vx, vy, g.arena) then
      -- Ciclo da arena: madeira (nil) -> I -> ... -> IX -> madeira. So o
      -- host troca; o cliente so le (mesma regra do PREENCHER COM IA).
      -- (if explicito: `cond and nil or prox` devolveria `prox` — nil e
      -- falsy, o or recairia no fallback.)
      local prox = (st.arena or 0) + 1
      if prox > arte.totalArenas() then
        st.arena = nil
      else
        st.arena = prox
      end
      if self.net then transmitirSala(self) end
    elseif st.papel == "anfitriao" and dentro(vx, vy, g.iniciar) then
      -- Minimo de 2 na mesa: 1 humano + IA escolhida ja vale (qtdIA e
      -- limitado as vagas livres, entao nunca passa de 8).
      clampIA(st)
      if #st.jogadores + st.qtdIA >= 2 then
        return "iniciar"
      end
      st.status = "AGUARDE MAIS JOGADORES"
      st.statusErro = false
    elseif st.papel == "cliente" and dentro(vx, vy, g.pronto) then
      self:alternarPronto()
    elseif dentro(vx, vy, g.sair) then
      self:sair()
    end
  end
  return nil
end

-- DESENHO -----------------------------------------------------------------

local function tag(texto, direitaX, cy, corTexto, tam)
  tam = tam or 12
  local larg = ui.larguraTexto(texto, tam) + 12
  local alt = tam + 8
  ui.caixa(direitaX - larg, cy - alt / 2, larg, alt, 6, { 0, 0, 0, 0.4 },
    corTexto, 1)
  ui.txt(texto, direitaX - larg, cy - ui.alturaTexto(tam) / 2, tam, corTexto,
    "center", larg)
  return direitaX - larg - 6
end

local function desenharLinha(r, j, vagaIA)
  if not j then
    ui.caixa(r.x, r.y, r.w, r.h, 10, { 1, 1, 1, 0.02 }, ui.hex "#2A2A45", 1)
    local aviso = vagaIA and "IA (PREENCHE AO INICIAR)" or "AGUARDANDO JOGADOR..."
    -- Fundo da vaga renderiza branco solido (ui.caixa ignora o alfa da cor):
    -- texto escuro para o aviso ficar legivel por cima.
    ui.txt(aviso, r.x, r.y + r.h / 2 - 8, 12,
      vagaIA and { 0.5, 0.36, 0.05 } or { 0.42, 0.42, 0.48 }, "center", r.w)
    return
  end
  local cor = ui.hex(CORES[j.assento] or CORES[8])
  ui.caixa(r.x, r.y, r.w, r.h, 10, { 1, 1, 1, 0.05 }, ui.hex "#3A3A5C", 1)

  local dot = 24
  local dx, dy = r.x + 10, r.y + (r.h - dot) / 2
  ui.caixa(dx, dy, dot, dot, dot / 2, { cor[1], cor[2], cor[3], 0.16 },
    cor, 1.5)
  ui.txt(tostring(j.assento), dx, dy + (dot - 13) / 2, 13, cor, "center", dot)

  local aT = r.h - 16
  local av = arte.avatar(j.avatar)
  if av then
    ui.imagemContain(av, dx + dot + 8, r.y + 8, aT, aT)
  end

  -- 2 linhas (slot estreito de 2 colunas): nome em cima, tags embaixo —
  -- nome e tag nunca disputam a mesma faixa horizontal.
  local nome = tostring(j.nome or "?")
  if #nome > 16 then nome = nome:sub(1, 15) .. ".." end
  ui.txt(nome, dx + dot + 8 + aT + 8, r.y + 7, 15, ui.hex "#E8EAF6")

  local tx = r.x + r.w - 12
  local cy = r.y + r.h - 15
  if j.pronto then tx = tag("PRONTO", tx, cy, ui.hex "#66BB6A", 11) end
  -- VOCE e redundante na linha do host (HOST ja identifica o proprio slot).
  if j.host then tx = tag("HOST", tx, cy, ui.hex "#FFD54F", 11)
  elseif j.eu then tx = tag("VOCE", tx, cy, ui.hex "#42A5F5", 11) end
end

-- Miniatura quadrada da arena + rotulo: o host toca para ciclar, o cliente
-- so le (mesma regra do resto da sala). Nil = madeira padrao (sem arte
-- propria no lobby: quadrado desenhado com veios de madeira).
local function desenharArena(r, arena, host)
  local sq = r.h -- quadrado de 76 na propria altura da linha
  local img = arena and arte.arena(arena) or nil
  if img then
    ui.imagemCover(img, r.x, r.y, sq, sq)
  else
    ui.caixa(r.x, r.y, sq, sq, 8, { 0.36, 0.24, 0.14 }, ui.hex "#7A5C29", 2)
    for k = 1, 4 do
      love.graphics.setColor(0.30, 0.19, 0.11, 1)
      love.graphics.rectangle("fill", r.x + 7, r.y + 13 + k * 12, sq - 14, 3)
    end
    ui.txt("MADEIRA", r.x, r.y + sq / 2 - 7, 11, ui.hex "#E8D9B5",
      "center", sq)
  end
  -- Moldura dourada: ui.caixa ignoraria o alfa do fundo e pintaria um
  -- retangulo branco solido POR CIMA da miniatura, entao o contorno e um
  -- retangulo de linha puro.
  love.graphics.setColor(ui.hex "#FFD54F")
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", r.x + 0.75, r.y + 0.75, sq - 1.5, sq - 1.5)
  love.graphics.setLineWidth(1)
  ui.txt("ARENA: " .. ui.tr(arte.nomeArena(arena)), r.x + sq + 16,
    r.y + (host and sq / 2 - 19 or sq / 2 - 9), 18, ui.hex "#FFD54F")
  if host then
    ui.txt("TOQUE NA MINIATURA PARA TROCAR", r.x + sq + 16,
      r.y + sq / 2 + 5, 12, { 1, 1, 1, 0.45 })
  end
end

-- Quebra a mensagem em linhas que cabem na largura: ui.quebrar nao parte
-- palavra, entao palavra gigante (sem espaco) e cortada na forca aqui.
local function quebrarChat(texto, tam, larg)
  local linhas = {}
  for _, l in ipairs(ui.quebrar(texto, tam, larg)) do
    while ui.larguraTexto(l, tam) > larg and #l > 1 do
      local corte = #l
      while corte > 1 and ui.larguraTexto(l:sub(1, corte), tam) > larg do
        corte = corte - 1
      end
      linhas[#linhas + 1] = l:sub(1, corte)
      l = l:sub(corte + 1)
    end
    if l ~= "" then linhas[#linhas + 1] = l end
  end
  return linhas
end

-- Historico do chat: a mensagem mais nova fica na base da area (as antigas
-- saem por cima quando nao cabem).
local function desenharChatLista(r, st)
  local tam = 13
  local lh = ui.alturaTexto(tam) + 2
  local maxLinhas = math.floor(r.h / lh)
  if maxLinhas < 1 then return end
  local linhas = {}
  for _, m in ipairs(st.chat or {}) do
    local cor = corChat(m.cor)
    local txt = tostring(m.nome or "?") .. ": " .. tostring(m.texto or "")
    for _, l in ipairs(quebrarChat(txt, tam, r.w)) do
      linhas[#linhas + 1] = { texto = l, cor = cor }
    end
  end
  local inicio = math.max(1, #linhas - maxLinhas + 1)
  local ly = r.y + r.h - (#linhas - inicio + 1) * lh
  for i = inicio, #linhas do
    ui.txt(linhas[i].texto, r.x, ly, tam, linhas[i].cor)
    ly = ly + lh
  end
end

-- Campo de digitacao + cursor piscando + ENVIAR (usado no painel da direita
-- e no modo digitacao do topo).
local function desenharChatCampo(campo, btn, st, tamFonte, dica)
  ui.caixa(campo.x, campo.y, campo.w, campo.h, 8, { 1, 1, 1 },
    ui.hex "#42A5F5", 2, 0.05)
  local ty = campo.y + campo.h / 2 - ui.alturaTexto(tamFonte) / 2
  local texto = tostring(st.chatTexto or "")
  if texto == "" then
    ui.txt(dica, campo.x + 12, ty, tamFonte, { 1, 1, 1, 0.35 })
  else
    ui.txt(texto, campo.x + 12, ty, tamFonte, ui.hex "#E8EAF6")
  end
  if st.chatFoco and st.t % 1 < 0.6 then
    local larg = texto == "" and 0 or ui.larguraTexto(texto, tamFonte)
    love.graphics.setColor(ui.hex "#42A5F5")
    love.graphics.rectangle("fill", campo.x + 12 + larg + 3, campo.y + 9, 2,
      campo.h - 18)
  end
  ui.botao("ENVIAR", btn.x, btn.y, btn.w, btn.h, ui.hex "#16213E",
    ui.hex "#42A5F5", math.min(16, btn.h - 16))
end

-- Painel do chat da sala (a direita da sala de espera): titulo, historico e
-- campo de digitacao na base — digita no proprio painel, sem tela a parte.
local function desenharChat(g, st)
  local c = g.chat
  ui.caixa(c.x, c.y, c.w, c.h, 14, ui.hex "#0F1322", ui.hex "#7A5C29", 2)
  ui.arestas(c.x + 6, c.y + 6, c.w - 12, c.h - 12, 12, ui.hex "#42A5F5", 2)
  ui.txtEspacado("CHAT DA SALA", c.x, c.y + PAD, 22, ui.hex "#42A5F5", 2, c.w)
  ui.txt("TODOS NA SALA VEEM  -  ENTER ENVIA", c.x, c.y + PAD + 30, 12,
    { 1, 1, 1, 0.45 }, "center", c.w)
  local div = ui.hex "#42A5F5"
  love.graphics.setColor(div[1], div[2], div[3], 0.25)
  love.graphics.rectangle("fill", c.x + 14, c.y + PAD + 52, c.w - 28, 1)

  local lista = { x = c.x + 14, y = c.y + PAD + 60, w = c.w - 28,
    h = c.campo.y - 8 - (c.y + PAD + 60) }
  if #(st.chat or {}) == 0 then
    ui.txt("NENHUMA MENSAGEM AINDA.", lista.x + 2, lista.y + lista.h - 20, 12,
      { 1, 1, 1, 0.3 })
  else
    desenharChatLista(lista, st)
  end
  desenharChatCampo(c.campo, c.enviar, st, 13, "ESCREVA AQUI...")
end

function M:desenhar(hover)
  local st = self.st
  -- Cliente em partida mas sem o primeiro SNAPSHOT: a tela de jogo so
  -- abre com ele (aplicarSnapshotCliente no main). Em vez do lobby
  -- fantasma, painel de espera — o PEDIR_SNAPSHOT reenviado puxa o estado.
  if st.telaInterna == "partida" then
    local pw, ph = 520, 156
    local px = math.floor((VW - pw) / 2)
    local py = math.floor((VH - ph) / 2)
    love.graphics.setColor(0, 0, 0, 0.82)
    ui.preencherTela(VW, VH)
    ui.caixa(px, py, pw, ph, 14, ui.hex "#0F1322", ui.hex "#7A5C29", 2)
    ui.arestas(px + 6, py + 6, pw - 12, ph - 12, 12, ui.hex "#FFD54F", 2)
    ui.txtEspacado("PARTIDA INICIANDO", px, py + 34, 26, ui.hex "#FFD54F",
      3, pw)
    ui.txt("aguarde o anfitriao abrir a mesa...", px, py + 92, 15,
      ui.hex "#AAB0D0", "center", pw)
    return
  end
  local podeCriar = true
  local g = geom(st, podeCriar, self.desc)
  local ehSala = st.telaInterna == "sala"

  love.graphics.setColor(0, 0, 0, 0.82)
  ui.preencherTela(VW, VH)
  ui.caixa(g.x, g.y, g.w, g.h, 14, ui.hex "#0F1322", ui.hex "#7A5C29", 2)
  ui.arestas(g.x + 6, g.y + 6, g.w - 12, g.h - 12, 12, ui.hex "#FFD54F", 2)

  -- Titulo + subtitulo.
  local titulo = ehSala and "SALA DE ESPERA" or "MULTIPLAYER"
  ui.txtEspacado(titulo, g.x, g.y + PAD, 30, ui.hex "#FFD54F", 3, g.w)
  if ehSala then
    local sub = st.papel == "anfitriao"
      and (ui.tr("SEU IP:") .. " " .. tostring(st.ipSala) .. "   "
        .. ui.tr("PORTA") .. " " .. self.porta)
      or "CONECTADO AO ANFITRIAO"
    ui.txt(sub, g.x, g.y + PAD + 44, 14, ui.hex "#AAB0D0", "center", g.w)
  else
    ui.txt("Partida local na rede (2 a 8 jogadores)", g.x, g.y + PAD + 44,
      14, ui.hex "#AAB0D0", "center", g.w)
  end

  -- Divisor.
  local corDiv = ui.hex "#FFD54F"
  love.graphics.setColor(corDiv[1], corDiv[2], corDiv[3], 0.25)
  love.graphics.rectangle("fill", g.x + PAD, g.y + PAD + 66, g.w - PAD * 2, 1)

  if st.status and not ehSala then
    ui.textoQuebrado(st.status, g.x + PAD, g.y + PAD + 74, g.w - PAD * 2, 14,
      st.statusErro and ui.hex "#EF5350" or ui.hex "#FFD54F", "center", 2)
  end

  if ehSala then
    -- Quantidade de IA visivel (limitada as vagas livres) e a dificuldade
    -- escolhida pelo host — o cliente desenha as mesmas linhas em modo
    -- informativo.
    local qtd = math.max(0, math.floor(math.min(
      tonumber(st.qtdIA) or 0, MAX_JOGADORES - #st.jogadores)))
    local preenche = qtd > 0
    for i = 1, MAX_JOGADORES do
      desenharLinha(g.linhas[i], st.jogadores[i],
        preenche and i > #st.jogadores and (i - #st.jogadores) <= qtd)
    end
    local livre = math.max(0, MAX_JOGADORES - #st.jogadores)
    local textoIA = ui.tr("PREENCHER COM IA:") .. " " .. qtd .. " / " .. livre
    local difNome = ui.tr(DIF_NOMES[math.min(3, math.max(1,
      math.floor(tonumber(st.dificuldade) or 2)))])
    if st.papel == "anfitriao" then
      ui.botao(textoIA, g.ia.x, g.ia.y, g.ia.w, g.ia.h,
        preenche and ui.hex "#3E2723" or ui.hex "#16213E",
        ui.hex(preenche and "#FFD54F" or "#42A5F5"), 16)
      ui.botao(ui.tr("DIFICULDADE DA IA:") .. " " .. difNome, g.dificuldade.x,
        g.dificuldade.y, g.dificuldade.w, g.dificuldade.h,
        ui.hex "#16213E", ui.hex "#AB47BC", 16)
      -- Ciclo de arenas na miniatura: madeira padrao + as 9 dos ciclos
      -- (o fundo e aplicado na partida via snapshot).
      desenharArena(g.arena, st.arena, true)
      -- Minimo de 2 na mesa: 2 humanos, ou 1 humano + IA escolhida.
      local podeIniciar = #st.jogadores + qtd >= 2
      if podeIniciar then
        ui.botao("INICIAR", g.iniciar.x, g.iniciar.y, g.iniciar.w,
          g.iniciar.h, ui.hex "#1B3A1B", ui.hex "#66BB6A", 18)
      else
        ui.botao("INICIAR", g.iniciar.x, g.iniciar.y, g.iniciar.w,
          g.iniciar.h, { 0.1, 0.1, 0.12, 0.6 }, ui.hex "#3A3A5C", 18)
      end
      ui.botao("SAIR DA SALA", g.sair.x, g.sair.y, g.sair.w, g.sair.h,
        { 198 / 255, 40 / 255, 40 / 255, 0.24 }, ui.hex "#C62828", 18)
      if st.status then
        ui.txt(st.status, g.x, g.y + PAD + 44, 14,
          st.statusErro and ui.hex "#EF5350" or ui.hex "#AAB0D0",
          "center", g.w)
      end
    else
      -- O cliente nao escolhe: mostra a decisao do host (mesmas linhas).
      ui.txt(textoIA, g.ia.x, g.ia.y + g.ia.h / 2 - 10, 16,
        preenche and ui.hex "#FFD54F" or ui.hex "#AAB0D0",
        "center", g.ia.w)
      ui.txt(ui.tr("DIFICULDADE DA IA:") .. " " .. difNome, g.dificuldade.x,
        g.dificuldade.y + g.dificuldade.h / 2 - 10, 16,
        ui.hex "#AB47BC", "center", g.dificuldade.w)
      desenharArena(g.arena, st.arena, false)
      local textoPronto = st.meuPronto and "PRONTO (SIM)" or "PRONTO (NAO)"
      ui.botao(textoPronto, g.pronto.x, g.pronto.y, g.pronto.w, g.pronto.h,
        st.meuPronto and { 0.11, 0.32, 0.18, 0.6 } or { 1, 1, 1, 0.06 },
        ui.hex(st.meuPronto and "#66BB6A" or "#3A3A5C"), 18,
        -- Fundo branco solido (ui.caixa ignora o alfa da cor): texto preto
        -- para dar contraste; no estado pronto o fundo e escuro e o texto
        -- volta ao branco padrao.
        st.meuPronto and nil or { 0.06, 0.06, 0.08 })
      ui.botao("SAIR DA SALA", g.sair.x, g.sair.y, g.sair.w, g.sair.h,
        { 198 / 255, 40 / 255, 40 / 255, 0.24 }, ui.hex "#C62828", 18)
      ui.txt("AGUARDANDO O ANFITRIAO INICIAR...", g.x, g.y + PAD + 44, 14,
        ui.hex "#AAB0D0", "center", g.w)
    end
    -- Chat da sala a direita: os membros escrevem e todos veem.
    desenharChat(g, st)
    return
  end

  if st.telaInterna == "lobby" then
    -- Partidas anunciadas pelos hosts da rede: toque na linha para entrar.
    if #g.salas > 0 then
      ui.txt("PARTIDAS NA REDE - TOQUE PARA ENTRAR", g.x + PAD, g.salasY + 5,
        14, ui.hex "#FFD54F")
      for _, r in ipairs(g.salas) do
        local s = r.sala
        ui.caixa(r.x, r.y, r.w, r.h, 10, ui.hex "#101830", ui.hex "#42A5F5", 1.5)
        local nome = tostring(s.nome or "?")
        if #nome > 22 then nome = nome:sub(1, 21) .. ".." end
        ui.txt(nome, r.x + 14, r.y + 7, 16, ui.hex "#E8EAF6")
        ui.txt(tostring(s.jogadores) .. "/" .. tostring(s.max),
          r.x + r.w - 114, r.y + 7, 16, ui.hex "#FFD54F", "right", 100)
        ui.txt(tostring(s.ip), r.x + 14, r.y + 27, 12, { 1, 1, 1, 0.5 })
        ui.txt("ENTRAR >", r.x + r.w - 164, r.y + 26, 16,
          ui.hex "#66BB6A", "right", 150)
      end
    else
      -- Explica o que a sonda esta fazendo: sem rede no aparelho ou rede
      -- sem resposta (broadcast filtrado pelo roteador) -> orienta a digitar
      -- o IP, que sempre funciona (unicast).
      local cod = self.desc:sondaStatus()
      local txt, cor = "PROCURANDO PARTIDAS NA REDE...", { 1, 1, 1, 0.45 }
      if cod == "SEM_REDE" then
        txt, cor = "REDE INDISPONIVEL - DIGITE O IP", ui.hex "#FF8A65"
      elseif cod == "SEM_RESPOSTA" then
        txt, cor = "SEM RESPOSTA - DIGITE O IP NA MESMA REDE",
          ui.hex "#FFD54F"
      end
      ui.txt(txt, g.x + PAD, g.salasY + 7, 13, cor)
    end
    if g.criar then
      ui.botao("CRIAR SALA", g.criar.x, g.criar.y, g.criar.w, g.criar.h,
        ui.hex "#1B3A1B", ui.hex "#66BB6A", 18)
    end
    ui.botao("CONECTAR COM IP", g.ip.x, g.ip.y, g.ip.w, g.ip.h,
      ui.hex "#16213E", ui.hex "#FFD54F", 18)
    ui.botao("VOLTAR", g.voltar.x, g.voltar.y, g.voltar.w, g.voltar.h,
      { 198 / 255, 40 / 255, 40 / 255, 0.24 }, ui.hex "#C62828", 18)
    ui.textoQuebrado(
      "TOQUE NUMA PARTIDA DA LISTA OU DIGITE O IP NA MESMA REDE.",
      g.x + PAD, g.voltar.y + g.voltar.h + 14, g.w - PAD * 2, 13,
      { 1, 1, 1, 0.45 }, "center", 2)
  elseif st.telaInterna == "digitando" then
    local c = g.campo
    ui.caixa(c.x, c.y, c.w, c.h, 8, { 0, 0, 0, 0.45 }, ui.hex "#7A5C29", 2)
    if st.texto == "" then
      ui.txt("ex.: 192.168.0.10", c.x + 14, c.y + c.h / 2 - 9, 16,
        { 1, 1, 1, 0.35 })
    else
      ui.txt(st.texto, c.x + 14, c.y + c.h / 2 - 9, 16, ui.hex "#FFD54F")
    end
    if st.t % 1 < 0.6 then
      local larg = st.texto == ""
        and ui.larguraTexto(ui.tr("ex.: 192.168.0.10"), 16)
        or ui.larguraTexto(st.texto, 16)
      love.graphics.setColor(ui.hex "#FFD54F")
      love.graphics.rectangle("fill", c.x + 14 + larg + 3, c.y + 12, 2, c.h - 24)
    end
    ui.botao("CONECTAR", g.conectar.x, g.conectar.y, g.conectar.w,
      g.conectar.h, ui.hex "#16213E", ui.hex "#FFD54F", 18)
    ui.botao("VOLTAR", g.voltar.x, g.voltar.y, g.voltar.w, g.voltar.h,
      { 198 / 255, 40 / 255, 40 / 255, 0.24 }, ui.hex "#C62828", 18)
  elseif st.telaInterna == "conectando" then
    ui.txt(st.status or "CONECTANDO...", g.x, g.listaY + 8, 16,
      ui.hex "#FFD54F", "center", g.w)
    ui.botao("CANCELAR", g.voltar.x, g.voltar.y, g.voltar.w, g.voltar.h,
      { 198 / 255, 40 / 255, 40 / 255, 0.24 }, ui.hex "#C62828", 18)
  end
end

return M
