io.stdout:setvbuf("no")

function love.errorhandler(msg)
  local texto = "[ERRO LOVE] " .. tostring(msg) .. "\n" .. debug.traceback()
  print(texto)
  -- rodar.bat abre o love.exe sem console: guarda o erro em arquivo para
  -- diagnostico (tanto na pasta do jogo quanto no diretorio de save do LOVE).
  pcall(function()
    local f = io.open("erro.log", "w")
    if f then f:write(texto) f:close() end
  end)
  pcall(function()
    if love.filesystem.write then love.filesystem.write("erro.log", texto) end
  end)
  if os.getenv("JOGO_TESTE") == "1" then
    os.exit(1)
  end
  return function()
    return 1
  end
end

local arte = require "arte"
local ui = require "ui"
local anim = require "anim"
local jogo = require "jogo"
local madeira = require "madeira"
local teste = require "teste"
local tut = require "tutorial"
local selecao = require "selecao"
local perfilMod = require "perfil"
local introBat = require "intro_batalha"
local arenaMenu = require "arena_menu"
local multiplayer = require "multiplayer"
local partidaRede = require "partidaRede"
local som = require "som"
-- Efeitos de impacto (hit-stop/shake/flash/slow-mo): guardado em ui pelo
-- mesmo motivo de ui._dlg - o main esta no limite de 200 locals do LuaJIT.
ui._fx = require "fx"
-- Feedback visual das jogadas (impacto, numeros SAT/PROD, escudo, falencia
-- e entrada do Deus Mercado): tambem em ui para nao estourar os locals.
ui._impacto = require "impacto"
-- Conversa com o Adam antes do duelo do chefe: guardada em ui porque o
-- main esta no limite de 200 locals do LuaJIT (mesma ideia de ui._dlg).
ui._dlg = require "dialogo"
-- Tela de VS antes de cada duelo do Ciclo I: mesma razao de ui._dlg.
ui._vs = require "vs"
-- Dinheiro do jogador (moeda no menu, +10 por vitoria): mesma razao de
-- ui._dlg — o main esta no limite de 200 locals do LuaJIT.
ui._din = require "dinheiro"
-- Inventario (avatares comprados na loja): mesma razao de novo local.
ui._inv = require "inventario"
-- Tela de CONFIGURACOES (volume do som + reset do progresso do Ciclo I):
-- mesma razao de ui._dlg - o main esta no limite de 200 locals do LuaJIT.
ui._config = require "config"
-- Tela SOBRE (criadores, site e versao): mesma razao de ui._config.
ui._sobre = require "sobre"
-- Tutorial de primeiro acesso (mao do Deus Mercado + duelo assistido).
ui._onboarding = require "onboarding"
-- Meta-eventos V7 (leilao, lojinha, fusao): mesma razao de ui._dlg.
ui._meta = require "meta"
-- Layout e desenho da arena 3+ (assentos, painel completo, flutuantes):
-- mesmo workaround dos modulos acima (teto de 200 locals do LuaJIT).
ui._layout = require "layout"
-- Tela preta de carregamento antes da batalha em rede (Deus Mercado andando).
ui._carga = require "carregamento_rede"
-- Animacoes especiais das cartas Curinga (arte saltando para a frente e a
-- Probabilidade Mortal andando pela tela): guardado em ui pelo mesmo teto de
-- 200 locals do LuaJIT.
ui._curingas = require "cartas_especiais"

local VW, VH = 1280, 720
local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"

-- Mao do jogador um pouco menor que a do React (68x95): encolhe o canto
-- inferior direito para a Area Segura caber "na ponta".
local CW, CH = ui.E(64), ui.E(88)
local BW, BH = ui.E(48), ui.E(68)
local DECK_CW, DECK_CH = ui.E(50), ui.E(70)
local DECK_DW, DECK_DH = ui.E(64), ui.E(90)

local CENTRO = VW / 2
-- Mão do jogador: cards terminam ~46dp acima da base (container 30+LIFT do
-- MaoJogador.js), deixando espaço para o painel em bottom:12.
local MAO_Y = VH - ui.E(46) - CH
local DECKS_Y = math.floor(VH * 0.40)
local OP_PAINEL_Y = 16
local OP_MAO_Y = OP_PAINEL_Y + ui.E(34) + 8
local PLACA_X, PLACA_Y = 16, 34
local PAUSA = { x = VW - 16 - ui.E(36), y = 16, w = ui.E(36), h = ui.E(36) }
-- Teste (so no duelo classico vs Adam Smith): da a vitoria a ele na hora
-- para conferir a tela de derrota nova sem jogar o duelo inteiro.
-- O campo "voce" e o botao irmao (embaixo da placa de turno): vitoria
-- DIRETA do jogador, para conferir se o proximo inimigo do caminho do
-- ciclo e liberado. Guardado aqui para nao criar local novo (main no limite).
local BTN_ADAM_VENCE = { x = ui.E(186), y = 34, w = ui.E(176), h = ui.E(36),
  voce = { x = PLACA_X, y = PLACA_Y + ui.E(40) + ui.E(8),
    w = ui.E(176), h = ui.E(36) } }
-- Painel do jogador no base-centro (bottomCenterWrapper, bottom:12, z26).
local PAINEL_RECT = { x = CENTRO - ui.E(65), y = VH - ui.E(12) - ui.E(34),
  w = ui.E(130), h = ui.E(34) }
-- Área Segura: 3 slots em linha (eram 1 carta só). O slot encolheu um
-- pouco (46x64dp) para os três caberem na faixa de madeira da direita sem
-- encostar na mão; a própria fileira fica no rodapé e a do oponente no topo.
local AREA_L, AREA_A = ui.E(46), ui.E(64)
local AREA_USAR = { w = ui.E(46), h = ui.E(16) }

-- Coluna do menu. `oculto = true` num item tira ele da coluna (e do clique)
-- sem apagar o caminho, se precisar de novo.
local MENU_DEF = {
  { chave = "btn_um_jogador", acao = "jogar", rotulo = "UM JOGADOR",
    oculto = true },
  { chave = "btn_multi", acao = "multiplayer", rotulo = "MULTIPLAYER" },
  -- Partida de exibicao: todos os assentos (inclusive o 1) sao IA.
  { chave = "btn_simular", acao = "simular", rotulo = "SIMULAR PARTIDA",
    cor = ui.C.VERDE, oculto = true },
  { chave = "btn_anim_teste", acao = "anim_teste", rotulo = "TESTE ANIMAÇÕES",
    oculto = true },
  { chave = "btn_config", acao = "config", rotulo = "CONFIGURACOES" },
  { chave = "btn_sobre", acao = "sobre", rotulo = "SOBRE" },
  { chave = "btn_sair", acao = "sair", rotulo = "SAIR" },
}
-- Coluna de botoes do menu: botoes uniformes em grade unica, deslocados
-- para a direita embaixo do logo (pedido: afastar da borda esquerda). O
-- desenho mapeia a barra pintada de cada PNG sobre este retangulo (ver
-- ui.menu); 330/64 = 5,16 fica perto do aspecto medio das barras
-- (4,47..4,94) e evita esmagar o texto embutido na arte.
-- Layout centralizado: logo grande no topo e os 4 botoes logo abaixo,
-- alinhados no meio da tela. y0=380 e esp=76 deixam o ultimo (SAIR) em
-- 380+3*76=608, terminando em 670 (dentro dos 720).
local MENU_Y0 = 380
local MENU_ALT = 62
local MENU_ESP = 76
local MENU_LARG = 310

-- Perfil do jogador (TelaPerfil.js): nickname + avatar (id 1..8) + os
-- emojis equipados (1..4 vetoriais de graca; 5 = Karl Marx da loja, maximo
-- 4 equipados). Carregado do disco no love.load e atualizado pela tela de
-- perfil.
local perfilJogador = { nick = "JOGADOR_1", avatar = "1", emojis = { 1, 2, 3, 4 } }

-- Instancia da tela MULTIPLAYER (criada ao abrir o menu de rede).
local mult = nil
-- Partida em rede (Fase 2): "host" roda o motor e transmite snapshots;
-- "cliente" espelha os snapshots (proprio jogador sempre no seat 1).
local redeModo = nil
-- Cliente: aguardando snapshot de uma acao enviada (bloqueia novo envio).
local envioPendente = false
-- Cliente: Vigarice selecionada, esperando a mao do alvo (PEDIR_MAO).
local pendVigarice = nil
-- Cliente: zooms de resultado vindos do host, na ordem de chegada.
local filaCartasRede = {}
-- Host: acoes de clientes que so aplicam quando o jogo esta livre (zoom/voo).
local filaAcoesRede = {}

local escala, offX, offY = 1, 0, 0
local tela = "intro"
-- Intro do boot: andando (caminhada) -> simbolo da paz -> tela "logo"
-- (Tormentalia). A logo da Gears Studio foi retirada do fluxo.
local intro = { fase = "andando", t = 0, quadro = 1, tQuadro = 0, espera = 0 }
local logoT = 0
local pausado = false
local partida
-- ARENA: nil = duelo classico (1v1 vs Adam Smith); 2..8 = quantidade escolhida
-- no painel (arena_menu). N >= 3 usa a mesa em elipse com slots de oponentes.
local arenaN = nil
-- Seleção em lote (máx. 2 por turno, como no React): lista de uids.
local selUids = {}
-- Dobra (fold) das cartas da mão por uid: anima 0..1 ao selecionar.
local foldUids = {}
-- Fila de SAÍDA da leva: cartas já aplicadas que voam para a mesa DEPOIS do
-- zoom de resultado (paridade com o React: zoom 2s primeiro, animação depois).
local filaSaida = nil
-- Saldos antes da leva (tabela por jogador), para os popups quando a saída terminar.
local saidaAntes = nil
-- Modal do roubo às cegas (Vigarice).
local modalRoubo = nil
local modalRects = nil
-- Carta selecionada na Área Segura própria.
local selAreaUid = nil
-- Long-press no painel (800ms) para passar a vez.
local pressPanel = nil
-- Zoom da carta (CartaZoomModal): long-press 600ms na mão/área própria.
local zoomCarta, zoomT = nil, 0
local pressCarta = nil
-- Arrasto para reorganizar a mão (mouse ou dedo): começa quando a pressão
-- move além de ui.E(10) sobre uma carta; soltar reordena a mao.
local arrasto = nil
local zoomPressFechar = false
-- Dedo na tela (mobile): posicao virtual enquanto o toque esta ativo — serve
-- de "hover" para destacar a carta sob o dedo, como o mouse no desktop.
local toqueHover = nil
-- forward declaration (o corpo fica depois de `clicado`; o teste de render
-- usa o upvalue).
local solto
-- Sequência da IA (reação -> jogadas -> comprar -> descartar -> fim).
local iaEstado = nil
local batalhaIniciada = false
local introBatAtiva = false
local fase = "JOGADOR"
-- Timer de turno (20s base + efeitos TEMPO_TURNO), espelhando o React.
local AVISO_SEGUNDOS = 10
local tempo = { chave = nil, duracao = 0, restante = 0, expirado = false, aviso = 0 }
local voo = nil
local resultado = nil
-- Quick Counter: janela de reacao host/local (metodos definidos depois dos
-- helpers de desenho/acao). Uma unica tabela evita mais locals no chunk.
local qc = {}
-- Animacao ambiente das passivas (Renda Fixa / Dano Periodico).
local pas = { t = 0 }
local popups = {}
-- Aviso de saida de jogador no canto superior direito (host gera o
-- evento em partida.saida; o cliente recebe via snapshot).
local saidaToast = nil
local saidaSeqVista = nil
-- Emojis da partida em rede: seletor aberto pelo clique curto no proprio
-- painel e baloes ativos (cada um dura DUR_EMOJI segundos na tela).
local emojiAberto = nil
local emojiRects = {}
local baloes = {}
local DUR_EMOJI = 4
-- Ultima partida.vez observada no aparelho de toque: a troca de turno em
-- rede vibra so quando passa para o jogador local (nil ate o primeiro
-- snapshot, entao o comeco da partida nao vibra).
local vezVista = nil
-- Jingle de fim ja tocado nesta partida (reset em limparEstadoPartida).
local fimTocado = nil
local rectsMao = {}
local hover = { x = -1, y = -1 }
local OS_TOQUE = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local ultimoToque = -1
-- Captura offscreen (JOGO_SHOT=<segundos>): grava o frame no diretorio de
-- save e sai, sem depender do foco da janela (utel para screenshots).
local SHOT_SEG = tonumber(os.getenv("JOGO_SHOT"))
-- F3 tambem pode ser ligado por env para capturas com os retangulos do layout.
if os.getenv("JOGO_DEBUG_LAYOUT") == "1" and ui._layout then
  ui._layout.debug = true
end
local shotT0, shotFase = nil, 0

-- HELPERS ------------------------------------------------------------------
-- Tabela util agrupa funcoes auxiliares em um unico local do chunk (evita
-- estourar os 200 locais do LuaJIT no main). Elas acessam upvalues do chunk.
local util = {}

util.recalcularEscala = function()
  local w, h = love.graphics.getDimensions()
  escala = math.min(w / VW, h / VH)
  offX = (w - VW * escala) / 2
  offY = (h - VH * escala) / 2
  -- Retangulo (coordenadas virtuais) que cobre a tela fisica inteira,
  -- barras do letterbox incluidas: os fundos usam ele para preencher a
  -- tela toda em aparelhos mais largos que 16:9 (ex.: 20:9).
  ui.telaCheia = { x = -offX / escala, y = -offY / escala,
    w = w / escala, h = h / escala }
end

util.paraVirtual = function(x, y)
  return (x - offX) / escala, (y - offY) / escala
end

util.mouseVirtual = function()
  local mx, my = love.mouse.getPosition()
  return util.paraVirtual(mx, my)
end

util.adicionarPopup = function(texto, x, y, cor, tam)
  table.insert(popups, {
    texto = texto, x = x, y = y, t = 0, dur = 1.5,
    cor = cor or ui.C.OURO, tam = tam or ui.E(20),
  })
end

-- LAYOUT DO MENU -----------------------------------------------------------

local function layoutMenu()
  -- Logo e botoes centralizados. No celular (20:9) os botoes ficam um
  -- pouco maiores para compensar a tela menor; no PC vale o MENU_*.
  -- JOGO_MENU_MOBILE forca o ramo de celular para teste.
  local mobile = OS_TOQUE or os.getenv("JOGO_MENU_MOBILE") ~= nil
  local my0, mlarg, malt, mesp
  if mobile then
    my0, mlarg, malt, mesp = 340, 350, 70, 84
  else
    my0, mlarg, malt, mesp = MENU_Y0, MENU_LARG, MENU_ALT, MENU_ESP
  end
  local mx = math.floor((VW - mlarg) / 2)

  local itens = {}
  for _, def in ipairs(MENU_DEF) do
    -- `oculto`: fora da coluna (e do clique), mas a definicao fica no lugar.
    if not def.oculto then
      local n = #itens
      itens[n + 1] = {
        chave = def.chave, acao = def.acao, rotulo = def.rotulo,
        cor = def.cor,
        x = mx, y = my0 + n * mesp,
        w = mlarg, h = malt,
      }
    end
  end

  -- Arena e tutorial sairam do menu (o painel da arena continua abrindo
  -- pelos testes/debug): nenhum botao flutuante.

  -- Loja: botao quadrado no canto inferior direito (arte 500x500; a bbox
  -- opaca 370x376 e mapeada sobre o quadrado em ui.menu/BARRAS_MENU).
  itens[#itens + 1] = {
    chave = "btn_loja", acao = "loja", rotulo = "LOJA",
    x = VW - VW * 0.04 - 96, y = VH - VH * 0.04 - 96,
    w = 96, h = 96,
  }

  return itens, {}
end

-- ARENA (N >= 3): MESA EM ELIPSE + SLOTS -----------------------------------
-- Cores dos jogadores (PLAYER_COLORS.js) e avatar de cada seat.
local CORES_JOGADOR = {
  "#FFD54F", "#EF5350", "#42A5F5", "#66BB6A",
  "#AB47BC", "#FF7043", "#26C6DA", "#EC407A",
}
-- AVATARES_IA_PADRAO.js: seats 2..8 usam esses ids (seat 1 = perfil).
local AVATARES_IA = { "3", "4", "5", "6", "7", "2", "1" }

local MESA_X, MESA_Y = 640, 345
local MESA_CX, MESA_CY = 640, 385
local MESA_RX, MESA_RY = 455, 258
local SLOT_W, SLOT_H = ui.E(104), ui.E(110)

local function ehMesa()
  return (arenaN or 2) >= 3
end

local function avatarDe(i)
  if i == 1 then return arte.avatar("voce") end
  if ehMesa() then return arte.avatar(partida.jogadores[i].avatar) end
  -- Duelo em rede: o oponente e humano de verdade (avatar da sala).
  if redeModo then return arte.avatar(partida.jogadores[i].avatar or "ia") end
  -- Duelo local: no ciclo o avatar e do inimigo, fora dele e o Adam.
  return arte.avatar(partida.jogadores[i].avatar or "ia")
end

-- Quem de avatar/chave cada seat usa no painelStatus (arte.avatar resolve).
local function chaveAvatar(i)
  if i == 1 then return "voce" end
  if ehMesa() then return partida.jogadores[i].avatar end
  if redeModo then return partida.jogadores[i].avatar or "ia" end
  return partida.jogadores[i].avatar or "ia"
end

-- Habilidade de avatar equipado (taylor/marx/mayo) do seat, para o chip visual.
-- Funcao em ui._ (mesmo workaround de ui._dlg/ui._din): o chunk de main.lua
-- ja vive no limite de 200 locals do LuaJIT.
function ui._habilidadeDe(i)
  local j = partida and partida.jogadores and partida.jogadores[i]
  local av = j and j.avatar
  if av == "taylor" or av == "marx" or av == "mayo" then return av end
  return nil
end

-- Posicao do slot do oponente i (seats 2..n) no arco superior da elipse.
-- span = min(240, 90+30m): 3..5 oponentes em ~1.0, 6-7 em 0.7 (colisoes
-- com placa/pausa/mao verificadas para todo n ate 8). Quem ja SAIU da
-- partida nao conta: o arco se reorganiza para os slots restantes.
local function posSlot(i)
  -- Arco calculado por layout.lua; oponentes que sairam nao ocupam vaga.
  local vis, k = 0, 0
  for o = 2, #partida.jogadores do
    if not partida.jogadores[o].saiu then
      vis = vis + 1
      if o == i then k = vis end
    end
  end
  if k == 0 then k = 1 end
  local seats = ui._layout.assentos(math.max(1, vis), VW, VH)
  local s = seats[math.min(k, #seats)]
  return { cx = s.cx, cy = s.cy, w = s.w, h = s.h, esc = 1, seat = s }
end

-- Retangulo clicavel do slot de um oponente na arena (alvo de carta).
local function rectSlotAlvo(i)
  local p = posSlot(i)
  return { x = p.cx - p.w / 2, y = p.cy - p.h / 2, w = p.w, h = p.h }
end

-- Saldos de todos os jogadores (antes da acao) para os popups por seat.
local function snapshotSaldos()
  local s = {}
  for i, j in ipairs(partida.jogadores) do s[i] = j.saldo end
  return s
end

-- Posicao do popup de variacao de saldo de cada seat.
local function posPopup(i)
  if i == 1 then
    return CENTRO + ui.E(120), PAINEL_RECT.y - ui.E(6), ui.E(20)
  end
  if ehMesa() then
    local p = posSlot(i)
    -- Acima do painel (quarto valor = id da fila de flutuantes).
    return p.cx, p.cy - p.h / 2 - 24, ui.E(13), i
  end
  return CENTRO - ui.E(120), OP_PAINEL_Y + ui.E(34) + ui.E(40), ui.E(16)
end

-- Popup por assento: na arena entra na camada de flutuantes do painel.
util.adicionarPopupSeat = function(i, texto, cor)
  if ehMesa() and i ~= 1 then
    ui._layout.addFlutuante(i, texto, cor)
  else
    local px, py, ptam = posPopup(i)
    util.adicionarPopup(texto, px, py, cor, ptam)
  end
end

-- Ancora visual por seat (centro do painel/slot): usada pelo escudo de
-- protecao e pelo aviso de falencia. Fica em ui pelo limite de 200 locals.
ui._posSeatFx = function(i)
  if i == 1 then
    return CENTRO, PAINEL_RECT.y + PAINEL_RECT.h / 2, ui.E(16)
  end
  if ehMesa() then
    local p = posSlot(i)
    return p.cx, p.cy, ui.E(14)
  end
  return CENTRO, OP_PAINEL_Y + ui.E(17), ui.E(16)
end

-- Destino da carta em voo: mesa central (ARENA) ou pilhas (duelo).
local function destinoVoo()
  if ehMesa() then
    return MESA_X - DECK_DW / 2, MESA_Y + 10
  end
  return CENTRO - DECK_DW / 2, DECKS_Y + (DECK_CH - DECK_DH) / 2
end

-- Ponto central da area de alvo para a carta voar direto nele (Etapa 10).
-- Usado so quando ha mapa de alvos (jogador escolheu o alvo clicando).
local function pontoAlvo(tipo, idx)
  if tipo == "oponente" then
    if ehMesa() then
      local p = posSlot(idx or 2)
      return p.cx, p.cy
    end
    return CENTRO, OP_PAINEL_Y + ui.E(17)
  elseif tipo == "voce" then
    return CENTRO, PAINEL_RECT.y + PAINEL_RECT.h / 2
  elseif tipo == "todos" or tipo == "descarte" then
    if ehMesa() then
      -- Arena: o descarte fica na mesa central, nao nas pilhas do duelo.
      local mw, mh = ui.E(34), ui.E(48)
      return MESA_X + ui.E(10) / 2 + mw / 2, MESA_Y + ui.E(10)
    end
    local dx = CENTRO + (DECK_CW + ui.E(21)) / 2 + DECK_DW / 2
    return dx, DECKS_Y + DECK_DH / 2
  end
  return destinoVoo()
end

-- Dados do overlay de fim (titulo/motivo/placares) usados no desenho e no clique.
local function dadosFim()
  local v = partida.vencedor
  local titulo, motivo = "EMPATE!", partida.motivo or "O mercado decidiu por empate"
  local empate = not v or v.empate == true
  local j1, j2 = partida.jogadores[1], partida.jogadores[2]
  local res = empate and "empate" or (v == j1 and "vitoria" or "derrota")
  local etiqueta = nil
  if partida.simulacao then res, etiqueta = "empate", "FIM DA PARTIDA" end
  if not empate then
    if partida.simulacao then
      -- Na simulacao nao existe "voce": o vencedor e sempre uma IA.
      titulo = v.nome .. " " .. ui.tr("VENCEU!")
    elseif v == partida.jogadores[1] then
      titulo = "VOCE VENCEU!"
    elseif (arenaN or 2) == 2 then
      titulo = "VOCE PERDEU"
    else
      titulo = v.nome .. " " .. ui.tr("VENCEU!")
    end
    motivo = partida.motivo
      or (v == partida.jogadores[1] and "Voce dominou o mercado"
        or "O mercado te derrotou")
  end
  local placares = nil
  if (arenaN or 2) > 2 then
    placares = {}
    for i, j in ipairs(partida.jogadores) do
      placares[#placares + 1] = {
        nome = j.nome, texto = "R$ " .. tostring(j.saldo),
        vencedor = (not empate and j == v),
        saldo = j.saldo,
      }
    end
    table.sort(placares, function(a, b) return a.saldo > b.saldo end)
  end
  return {
    titulo = titulo, motivo = motivo,
    placar1 = partida.jogadores[1].nome .. ": R$ " .. partida.jogadores[1].saldo,
    placar2 = partida.jogadores[2].nome .. ": R$ " .. partida.jogadores[2].saldo,
    placares = placares,
    resultado = res, etiqueta = etiqueta,
    jog1 = { nome = j1.nome, saldo = j1.saldo, avatar = j1.avatar or "voce",
      vencedor = (not empate and v == j1) },
    jog2 = { nome = j2.nome, saldo = j2.saldo, avatar = j2.avatar or "ia",
      vencedor = (not empate and v == j2) },
    turno = math.min(partida.turno or 0, partida.maxTurnos or 0),
    maxTurnos = partida.maxTurnos,
    moedas = (res == "vitoria" and not partida.simulacao)
      and ((ui._din and ui._din.POR_VITORIA) or 10) or nil,
    -- PROXIMO OPONENTE: so no duelo de ciclo vencido e quando ha um no
    -- liberado depois do atual (a fila acaba no soberano; em rede nao).
    temProximo = (ui._cicloDuelo and not redeModo and partida and not empate
      and v == partida.jogadores[1] and selecao.temProximo()) or false,
  }
end

-- Duracoes encurtadas so em MODO_TESTE (suite): a partida completa de 8
-- precisa caber no budget de frames do smoke; a determinismo nao muda.
local VOO_SEG = MODO_TESTE and 0.06 or 0.42
local RES_SEG = MODO_TESTE and 0.3 or 2
local IA_PASSO = MODO_TESTE and 0.05 or nil -- nil = delays normais do React
-- Chance da IA guardar uma carta na Area Segura no inicio do proprio turno.
local IA_GUARDA_CHANCE = 0.5

-- Circulo tracejado girando (mesaCirculoExt: dashed + 360deg / 30s).
local function circuloTracejado(cx, cy, r, seg, gap, cor, esp, rot)
  local circ = 2 * math.pi * r
  love.graphics.setLineWidth(esp)
  love.graphics.setColor(cor[1], cor[2], cor[3], cor[4] or 1)
  local a = 0
  while a < circ do
    local b = math.min(a + seg, circ)
    love.graphics.arc("line", cx, cy, r, rot + a / circ * 2 * math.pi,
      rot + b / circ * 2 * math.pi)
    a = b + gap
  end
  love.graphics.setLineWidth(1)
end

-- FLUXO DE TURNO -----------------------------------------------------------

local function proximaFase()
  if not partida or partida.fim then return end

  -- Leilao + roleta no fim das rodadas pares (V7). No modo local roda a
  -- sequencia inteira (leilao/lojinha/fusao); no host em rede roda somente o
  -- leilao + roleta e volta para a mesa (lojinha/fusao ficam fora da rede).
  local pendente = partida.metaPendente
  if pendente then
    partida.metaPendente = nil
    if not redeModo or redeModo == "host" then
      fase = "META"
      iaEstado = nil
      -- Acoes que chegaram antes do evento nao valem mais depois dele.
      filaAcoesRede = {}
      ui._meta.abrir(partida, pendente, {
        vw = VW, vh = VH,
        rede = redeModo,
        aoFechar = function()
          proximaFase()
          if ui._redeSnapshot then ui._redeSnapshot() end
        end,
        aoMudar = function()
          if ui._redeSnapshot then ui._redeSnapshot() end
        end,
      })
      if ui._redeSnapshot then ui._redeSnapshot() end
      return
    end
  end

  -- Simulacao: nenhum assento espera o humano; inclusive o assento 1 roda
  -- a sequencia de IA (iaMaquina ja usa partida.vez, nao o indice fixo).
  if partida.simulacao then
    fase = "IA"
    iaEstado = {
      passo = "espera",
      t = IA_PASSO or 1.4,
      jogadas = 0,
    }
  elseif partida.vez == 1 then
    fase = "JOGADOR"
    iaEstado = nil
  elseif redeModo == "host" and partida.jogadores[partida.vez].isIA then
    -- Fase 3: IA preenchida na mesa em rede — so o host roda a sequencia
    -- da IA (as acoes viram snapshot/CARTA_JOGADA); o cliente nunca entra
    -- nesse ramo, ele fica em "REDE" esperando o espelho.
    fase = "IA"
    local dur = jogo.duracaoTurno(partida.jogadores[partida.vez])
    iaEstado = {
      passo = "espera",
      -- Dificuldade da IA da sala (partida.difIA) manda na reacao; sem
      -- rede (fallback) mantem o clamp classico de 2s a 6s.
      t = IA_PASSO or (partida.difIA and partida.difIA.espera)
        or math.max(2, math.min(6, dur)),
      jogadas = 0,
    }
  elseif redeModo then
    -- Turno de um jogador remoto: o motor local fica de fora (nao roda IA
    -- nem turno humano); quem manda e a rede. No cliente, `vez ~= 1` e o
    -- anfitriao (ou uma IA) jogando — mesmo estado "REDE", sem acao local.
    fase = "REDE"
    iaEstado = nil
  else
    fase = "IA"
    -- Reacao da IA no modo um jogador: 5s fixos (o humano nao tem relogio;
    -- em rede a reacao continua clampada no tempo de turno). No ciclo a
    -- espera vem do inimigo (6s no primeiro ate 3s no Adam Smith).
    local cfgCiclo = ui._cicloDuelo and selecao.dueloAtual() or nil
    iaEstado = {
      passo = "espera",
      t = IA_PASSO or (cfgCiclo and cfgCiclo.espera) or 5,
      jogadas = 0,
    }
  end
end

-- Popups de variacao de saldo (carta jogada + evento do Deus Mercado):
-- um por jogador alterado, ancorado no seat correspondente.
local function popupsSaldo(antes)
  if not antes then return end
  for i, j in ipairs(partida.jogadores) do
    local dep = j.saldo
    if not j.saiu and antes[i] and dep ~= antes[i] then
      local d = dep - antes[i]
      util.adicionarPopupSeat(i,
        (d > 0 and "+" or "-") .. "R$ " .. math.abs(d),
        d > 0 and ui.C.SUCESSO or ui.C.FALHA)
    end
  end

  if partida.evento then
    -- Efeito especial (mao dourada descendo): fica pendente ate o zoom de
    -- resultado fechar para nao tocar escondido atras do banner.
    partida.evento = nil
    ui._deusPendente = true
  end

  -- Habilidade do avatar Marx (redistribuicao no inicio do turno) ou
  -- Elton Mayo (carta negativa neutralizada durante a jogada).
  if partida.habilidade then
    local h = partida.habilidade
    partida.habilidade = nil
    if h.tipo == "marx" then
      util.adicionarPopup(ui.tr("MARX REDISTRUIU") .. " R$ " .. tostring(h.valor or 100),
        ui.E(110), 142, ui.C.OURO, ui.E(15))
    elseif h.tipo == "mayo" then
      util.adicionarPopup("MAYO NEUTRALIZOU!",
        ui.E(110), 142, ui.C.SUCESSO, ui.E(15))
    end
  end
end

local function finalizarTurno(antes, res)
  if res.consumiuTurno then
    jogo.encerrarVez(partida)
  end

  popupsSaldo(antes)

  if partida.fim then
    tela = "fim"
    return
  end
  proximaFase()
end

-- Entrada do zoom de resultado: uma por carta jogada (ResultadoJogada.js).
local function novaEntrada(res, carta)
  return {
    carta = carta or res.carta,
    sucesso = res.sucesso,
    chance = tostring(math.floor(((res.chance or 1) * 100) + 0.5)) .. "%",
    -- Probabilidade Mortal: assento sorteado (animacao de avanco no main).
    vitimaIdx = res.vitimaIdx,
  }
end

-- Zoom único com TODAS as cartas da leva (o React manda ultimasJogadas
-- inteiro; um modal só, não um por carta).
local function novoResultadoLote(entradas)
  -- Som de jogada: toca em TODO aparelho que mostra o resultado da leva
  -- (host, quem jogou e quem so assistiu — todos passam por aqui).
  som.tocar("jogar")
  -- Animacoes especiais das Curingas: a arte salta para a frente (3s) ou a
  -- Probabilidade Mortal anda pela tela e avanca na vitima (4,9s). O zoom de
  -- resultado fica aberto ate o fim da animacao.
  local durAnim = 0
  for _, e in ipairs(entradas) do
    local c = e.carta
    if c and ui._curingas.def(c) then
      local ax, ay
      if c.id == 51 and e.vitimaIdx then
        ax, ay = ui._posSeatFx(e.vitimaIdx)
      end
      local d = ui._curingas.iniciar(c, { alvoX = ax, alvoY = ay })
      if d > durAnim then durAnim = d end
    end
  end
  local dur = (partida and partida.simulacao) and 1.2 or RES_SEG
  if durAnim > 0 then dur = math.max(dur, durAnim + 0.2) end
  return {
    entradas = entradas,
    cx = CENTRO,
    vw = VW,
    vh = VH,
    tempo = 0,
    -- Na simulacao all-IA os resultados ficam um pouco mais curtos para a
    -- partida nao arrastar (ainda da tempo de ler SUcesso/Falha).
    dur = dur,
  }
end

local function novoResultado(res, carta)
  return novoResultadoLote({ novaEntrada(res, carta) })
end

-- QUICK COUNTER -------------------------------------------------------------
-- A janela roda no cliente local (host ou duelo). A carta atacante so e
-- aplicada no motor DEPOIS da defesa escolhida, portanto a protecao vale
-- contra ela. A defesa nao gasta quota nem alimenta a cadeia.
qc.SEGUNDOS = 2.6
qc.MARGEM_REDE = 0.7
qc.ativo = nil
qc.pendente = nil
qc.seq = 0

-- Copia rasa das opcoes da carta: a permissao de defesa (opts.defesaDe) e
-- especifica de UM ataque e nao pode vazar para as proximas cartas da leva.
qc.copiarOpts = function(opts)
  local o = {}
  for k, v in pairs(opts or {}) do o[k] = v end
  return o
end

qc.finalizar = function(a, res, defRes)
  local entradas = {}
  local ress = { res }
  if defRes then
    entradas[#entradas + 1] = novaEntrada(defRes, defRes.carta)
    table.insert(ress, 1, defRes)
  end
  entradas[#entradas + 1] = novaEntrada(res, res.carta)
  -- O callback da IA/rede usa esta lista para o zoom e o CARTA_JOGADA.
  res.entradasReacao = entradas
  ui._fbPendente = { ress = ress, snap = a.snap, x = a.cx, y = a.cy }
  resultado = novoResultadoLote(entradas)
  if defRes then
    util.adicionarPopup(ui.tr("CONTRA-ATAQUE:") .. " " .. (defRes.carta.nome or "DEFESA"),
      CENTRO, VH * 0.34, ui.C.SUCESSO, ui.E(15))
  end
  if a.aoFim then
    a.aoFim(res, a.antes)
  else
    finalizarTurno(a.antes, res)
  end
end

qc.abrir = function(atacante, carta, opts, alvoIdx, aoFim, antes, snap, cx, cy)
  local opcoes = jogo.reacoesDisponiveis(partida, 1, carta)
  if #opcoes == 0 then
    local res = jogo.aplicarCarta(partida, atacante, carta, opts)
    qc.finalizar({ aoFim = aoFim, antes = antes, snap = snap,
      cx = cx, cy = cy }, res, nil)
    return
  end

  qc.ativo = {
    atacante = atacante, carta = carta, opts = opts, alvoIdx = alvoIdx,
    aoFim = aoFim, antes = antes, snap = snap, cx = cx, cy = cy,
    opcoes = opcoes, restante = qc.SEGUNDOS, t = 0, rects = {},
  }
  som.tocar("tempo")
  ui._fx.flash(ui.C.VERMELHO, 0.22, 0.18)
  ui._fx.bater(0.32)
  ui._impacto.flutuante("DEFENDER OU RECEBER?", CENTRO, VH * 0.30,
    ui.C.VERMELHO, ui.E(20), 1.2)
end

-- Escolhe um alvo remoto humano com defesa disponivel para abrir a janela
-- no cliente. Usado tanto por cartas com alvo unico quanto por efeitos em
-- oponentes/todos (nesse caso o primeiro defensor recebe o pedido).
qc.alvoRemotoComDefesa = function(indiceAtacante, carta, alvoIdx)
  if redeModo ~= "host" or not partida then return nil end
  local alvos = {}
  if carta.precisaAlvo then
    if alvoIdx and alvoIdx ~= indiceAtacante then alvos[1] = alvoIdx end
  else
    for i = 1, #partida.jogadores do
      if i ~= indiceAtacante then alvos[#alvos + 1] = i end
    end
  end
  for _, alvo in ipairs(alvos) do
    local j = partida.jogadores[alvo]
    if j and alvo ~= 1 and not j.isIA and not j.falido and not j.saiu
        and jogo.ameacaContra(partida, alvo, indiceAtacante, carta,
          { alvoIdx = alvoIdx })
        and jogo.podeReagir(partida, alvo, carta) then
      return alvo
    end
  end
  return nil
end

-- Pre-scan de uma leva local do host: devolve a primeira carta que atinge um
-- cliente humano com defesa. Tambem fixa o alvo sorteado no mapa para que a
-- aplicacao posterior use exatamente o mesmo jogador.
qc.ameacaRemotaHost = function(cartasSel, alvoIdx, mapaAlvos)
  if redeModo ~= "host" then return nil end
  mapaAlvos = mapaAlvos or {}
  for _, carta in ipairs(cartasSel or {}) do
    local alvoSel = mapaAlvos and mapaAlvos[carta.uid]
    local alvoCarta = alvoSel and alvoSel.idx or alvoIdx
    local alvoResolvido = jogo.alvoDaCarta(partida, 1, carta,
      { alvoIdx = alvoCarta })
    local alvo = qc.alvoRemotoComDefesa(1, carta, alvoResolvido)
    if alvo then
      if alvoResolvido then
        local m = mapaAlvos[carta.uid] or {}
        m.idx = alvoResolvido
        mapaAlvos[carta.uid] = m
      end
      return { carta = carta, alvo = alvo, alvoIdx = alvoResolvido }, mapaAlvos
    end
  end
  return nil, mapaAlvos
end

-- Aplica uma carta atacante. Devolve true quando a janela abriu e false
-- quando a carta ja foi resolvida imediatamente.
qc.aplicarAtaque = function(indiceJog, carta, origem, aoFim, antes, snap, cx, cy)
  local opts = origem.opcoes or {}
  local alvoIdx = jogo.alvoDaCarta(partida, indiceJog, carta, opts)
  local ameaca = jogo.ameacaContra(partida, 1, indiceJog, carta,
    { alvoIdx = alvoIdx })
  if not partida.jogadores[1].isIA and ameaca
      and jogo.podeReagir(partida, 1, carta) then
    if alvoIdx then opts.alvoIdx = alvoIdx end
    qc.abrir(indiceJog, carta, opts, alvoIdx, aoFim, antes, snap, cx, cy)
    return true
  end
  local alvoRemoto = qc.alvoRemotoComDefesa(indiceJog, carta, alvoIdx)
  if alvoRemoto then
    if alvoIdx then opts.alvoIdx = alvoIdx end
    qc.abrirRemota({ alvo = alvoRemoto, atacante = indiceJog,
      carta = carta }, function(defRes, defesaDe)
      local o = qc.copiarOpts(opts)
      o.defesaDe = defesaDe
      local res = jogo.aplicarCarta(partida, indiceJog, carta, o)
      qc.finalizar({ aoFim = aoFim, antes = antes, snap = snap,
        cx = cx, cy = cy }, res, defRes)
    end)
    return true
  end
  local res = jogo.aplicarCarta(partida, indiceJog, carta, opts)
  qc.finalizar({ aoFim = aoFim, antes = antes, snap = snap,
    cx = cx, cy = cy }, res, nil)
  return false
end

qc.resolver = function(uid, origem)
  local a = qc.ativo
  if not a then return end
  qc.ativo = nil
  -- Cliente reagindo a um ataque do host: a defesa NAO e aplicada aqui. O
  -- host e a autoridade, entao so devolvemos a escolha e esperamos o snapshot.
  if a.remoto then
    if a.aoResponder then a.aoResponder(uid, origem, a.remotoSeq) end
    if uid then
      som.tocar("guardar")
      util.adicionarPopup("REACAO ENVIADA", CENTRO, VH * 0.34,
        ui.C.SUCESSO, ui.E(15))
    end
    return
  end
  -- A defesa fica ARMADA no slot. DEFENDER autoriza o motor a usa-la (e so
  -- entao consumi-la); RECEBER ATAQUE mantem a carta no slot e nao anula nada.
  local defRes = nil
  local d = partida.jogadores[1] and partida.jogadores[1].defesas
    and partida.jogadores[1].defesas[1]
  if uid and d and d.carta then
    defRes = {
      sucesso = true, chance = 1, delta = 0, carta = d.carta,
      mensagem = "Defesa ativada",
      log = "Defesa armada ativada: " .. d.carta.nome,
    }
    som.tocar("guardar")
  end
  local permissao = { [1] = uid ~= nil }
  -- Acao remota: o host aplica a mensagem inteira depois da defesa para
  -- manter a autoridade unica e o snapshot coerente.
  if a.rede and a.rede.aplicar then
    a.rede.aplicar(defRes, permissao)
    return
  end
  local o = qc.copiarOpts(a.opts)
  o.defesaDe = permissao
  local res = jogo.aplicarCarta(partida, a.atacante, a.carta, o)
  qc.finalizar(a, res, defRes)
end

-- Deteccao de ameaca remota: devolve a primeira carta da mensagem que atinge
-- o assento local (host) e fixa o alvo sorteado no `msg.alvos` para que a
-- aplicacao autoritativa use exatamente o mesmo alvo.
qc.ameacaRemota = function(assento, msg)
  if not partida or msg.tipo ~= "JOGAR" then return nil end
  local j = partida.jogadores[assento]
  if not j then return nil end
  local alvos = type(msg.alvos) == "table" and msg.alvos or {}
  msg.alvos = alvos
  for _, uid in ipairs(msg.uids or {}) do
    local carta = nil
    for _, c in ipairs(j.mao) do
      if c.uid == uid then carta = c break end
    end
    if carta then
      local opts = {}
      if alvos[uid] and type(alvos[uid].idx) == "number" then
        opts.alvoIdx = alvos[uid].idx
      elseif type(msg.alvo) == "number" then
        opts.alvoIdx = msg.alvo
      end
      local alvoIdx = jogo.alvoDaCarta(partida, assento, carta, opts)
      local ameaca = jogo.ameacaContra(partida, 1, assento, carta,
        { alvoIdx = alvoIdx })
      if ameaca and jogo.podeReagir(partida, 1, carta) then
        if alvoIdx then
          local m = alvos[uid] or {}
          m.idx = alvoIdx
          alvos[uid] = m
        end
        return { carta = carta, uid = uid, alvoIdx = alvoIdx }
      end
    end
  end
  return nil
end

qc.abrirRede = function(assento, ameaca, aplicar)
  qc.abrir(assento, ameaca.carta, {}, ameaca.alvoIdx, nil, nil, nil,
    CENTRO, VH / 2)
  if qc.ativo then
    qc.ativo.rede = { aplicar = aplicar }
  end
end

-- Host pedindo reacao a um cliente: a jogada fica suspensa ate a resposta
-- (ou ate a margem de rede expirar). O cliente escolhe e devolve REACAO.
qc.abrirRemota = function(ameaca, aoResolver)
  if qc.ativo or qc.pendente or not partida then return false end
  qc.seq = qc.seq + 1
  local ok = mult and mult:enviarPartida(ameaca.alvo, {
    tipo = "PEDIR_REACAO", seq = qc.seq, atacante = ameaca.atacante,
    segundos = qc.SEGUNDOS,
    carta = { nome = ameaca.carta and ameaca.carta.nome or "CARTA" },
  })
  if not ok then
    if aoResolver then aoResolver(nil) end
    return false
  end
  qc.pendente = {
    alvo = ameaca.alvo, atacante = ameaca.atacante, carta = ameaca.carta,
    seq = qc.seq, restante = qc.SEGUNDOS + qc.MARGEM_REDE, t = 0,
    aoResolver = aoResolver,
  }
  som.tocar("tempo")
  ui._impacto.flutuante("AGUARDANDO REACAO...", CENTRO, VH * 0.30,
    ui.C.OURO, ui.E(17), 1.4)
  return true
end

qc.resolverRemota = function(uid, origem, seq)
  local p = qc.pendente
  if not p then return end
  -- Resposta atrasada de uma janela anterior: ignora.
  if seq and seq ~= p.seq then return end
  qc.pendente = nil
  -- A defesa ja estava armada no slot do alvo. A escolha nao instala nada:
  -- devolve um resultado sintetico (zoom) e a permissao para o motor usar a
  -- defesa ao aplicar o ataque.
  local defRes = nil
  local alvo = partida.jogadores[p.alvo]
  local d = alvo and alvo.defesas and alvo.defesas[1]
  if uid and d and d.carta then
    defRes = {
      sucesso = true, chance = 1, delta = 0, carta = d.carta,
      mensagem = "Defesa ativada",
      log = "Defesa armada ativada: " .. d.carta.nome,
    }
    som.tocar("guardar")
  end
  if p.aoResolver then
    p.aoResolver(defRes, { [p.alvo] = uid ~= nil })
  end
end

-- Cliente recebendo o pedido do host: abre a janela local e devolve apenas a
-- escolha; o host aplica a defesa e a carta atacante com autoridade unica.
qc.abrirPedido = function(msg)
  if not partida then return end
  local responder = function(uid, origem, seq)
    if mult then
      mult:enviarParaServidor({ tipo = "REACAO", seq = seq, uid = uid,
        origem = origem })
    end
  end
  if qc.ativo then
    -- Ja existe uma janela local: nao empilha; responde sem defesa.
    responder(nil, nil, msg.seq)
    return
  end
  local opcoes = jogo.reacoesDisponiveis(partida, 1)
  if #opcoes == 0 then
    responder(nil, nil, msg.seq)
    return
  end
  qc.ativo = {
    remoto = true, remotoSeq = msg.seq,
    carta = msg.carta or { nome = "CARTA" },
    opcoes = opcoes,
    restante = tonumber(msg.segundos) or qc.SEGUNDOS,
    t = 0, rects = {}, aoResponder = responder,
  }
  som.tocar("tempo")
  ui._fx.flash(ui.C.VERMELHO, 0.22, 0.18)
  ui._fx.bater(0.32)
  ui._impacto.flutuante("DEFENDER OU RECEBER?", CENTRO, VH * 0.30,
    ui.C.VERMELHO, ui.E(20), 1.2)
end

qc.atualizar = function(dt)
  local a = qc.ativo
  if a then
    a.t = a.t + dt
    a.restante = a.restante - dt
    if a.restante <= 0 then
      a.restante = 0
      qc.resolver(nil)
    end
    return
  end
  local p = qc.pendente
  if p then
    p.t = p.t + dt
    p.restante = p.restante - dt
    if p.restante <= 0 then
      p.restante = 0
      qc.resolverRemota(nil)
    end
  end
end

qc.desenhar = function()
  local a = qc.ativo
  if not a then
    local p = qc.pendente
    if not p then return end
    local w, h = ui.E(440), ui.E(58)
    local x, y = (VW - w) / 2, ui.E(18)
    ui.caixa(x, y, w, h, ui.E(9), ui.hex "#140B12", ui.C.OURO, 2)
    ui.txt("AGUARDANDO REACAO", x, y + ui.E(8), 16, ui.C.OURO,
      "center", w)
    local nome = (p.carta and p.carta.nome) or "CARTA"
    if #nome > 28 then nome = nome:sub(1, 27) .. ".." end
    ui.txt(nome .. "  " .. string.format("%.1fs", p.restante),
      x, y + ui.E(31), 11, ui.C.TEXTO2, "center", w)
    return
  end
  local n = #a.opcoes
  local w = ui.E(600)
  local h = ui.E(128) + n * ui.E(46)
  local x = (VW - w) / 2
  local y = ui.E(118) + math.max(0, ui.E(34) - (VH - h) / 4)

  -- Escurece a mesa e pulsa a borda vermelha (o jogo continua visivel).
  love.graphics.setColor(0.04, 0.01, 0.03, 0.58)
  love.graphics.rectangle("fill", 0, 0, VW, VH)
  local pulso = 0.55 + 0.45 * math.abs(math.sin(a.t * 7))
  love.graphics.setColor(ui.C.VERMELHO[1], ui.C.VERMELHO[2],
    ui.C.VERMELHO[3], pulso)
  love.graphics.setLineWidth(ui.E(4))
  love.graphics.rectangle("line", ui.E(8), ui.E(8), VW - ui.E(16),
    VH - ui.E(16), ui.E(12), ui.E(12))
  love.graphics.setLineWidth(1)

  ui.caixa(x, y, w, h, ui.E(10), ui.hex "#140B12", ui.C.VERMELHO, 2)
  ui.txt(ui.tr("DEFENDER OU RECEBER?"), x, y + ui.E(10), 22, ui.C.VERMELHO,
    "center", w)
  ui.txt(ui.tr("REACAO RAPIDA") .. "  " .. string.format("%.1fs", a.restante),
    x, y + ui.E(38), 12, ui.C.OURO, "center", w)
  local nome = (a.carta and a.carta.nome) or "CARTA"
  if #nome > 30 then nome = nome:sub(1, 29) .. ".." end
  ui.txt(ui.tr("CARTA:") .. " " .. nome, x + ui.E(16), y + ui.E(58),
    11, ui.C.TEXTO2, "left", w - ui.E(32))

  a.rects = {}
  local by = y + ui.E(80)
  for i, o in ipairs(a.opcoes) do
    local r = { fact = o, x = x + ui.E(18),
      y = by + (i - 1) * ui.E(40), w = w - ui.E(36), h = ui.E(32) }
    a.rects[#a.rects + 1] = r
    local rotulo
    if o.origem == "slot" then
      rotulo = ui.tr("DEFENDER") .. "  " .. (o.carta.nome or "DEFESA")
    else
      rotulo = ui.tr(o.origem == "area" and "AREA" or "MAO") .. "  "
        .. (o.carta.nome or "DEFESA")
    end
    ui.botao(rotulo, r.x, r.y, r.w, r.h, ui.hex "#2A1020",
      ui.C.VERMELHO, 14, ui.C.TEXTO)
  end
  local pr = { passar = true, x = x + w / 2 - ui.E(90),
    y = y + h - ui.E(42), w = ui.E(180), h = ui.E(30) }
  a.rects[#a.rects + 1] = pr
  ui.botao(ui.tr("RECEBER ATAQUE"), pr.x, pr.y, pr.w, pr.h,
    ui.hex "#1E1E32", ui.C.CINZA, 12, ui.C.TEXTO2)
end

-- origem: { x, y, e, rot, opcoes = { origem = " da Area Segura", roubarUids = ...,
--          alvoIdx = ... } }
-- aoFim(res, antes): quando fornecido, NÃO encerra o turno sozinho
-- (a sequência da IA controla o fim). `antes` = snapshot de saldos por seat.
local function iniciarVoo(indiceJog, carta, origem, aoFim)
  local alvoX, alvoY = destinoVoo()
  voo = { carta = carta, x = origem.x, y = origem.y, e = origem.e or 1,
    rot = origem.rot or 0, p = 0 }
  local antes = snapshotSaldos()
  local snap = ui._impacto.snapshot(partida)

  -- p avanca linear (arco do voo); x/y aceleram (entradaCubica) e batem no
  -- destino com o estouro de impacto.
  anim.tween(voo, { p = 1 }, VOO_SEG, anim.linear)
  anim.tween(voo, { x = alvoX, y = alvoY, e = 1, rot = 0 }, VOO_SEG,
    anim.entradaCubica, function()
      voo = nil
      local cx = alvoX + DECK_DW / 2
      local cy = alvoY + DECK_DH / 2
      -- Quick Counter: se a carta atinge o humano, a aplicacao fica suspensa
      -- ate a janela fechar. Sem reacao, aplica e entrega na hora.
      qc.aplicarAtaque(indiceJog, carta, origem, aoFim, antes, snap, cx, cy)
    end)
end

-- avatarDe(): perfil no seat 1; avatares da IA (ids) no modo ARENA; "ia" no duelo.
-- Zera os transients da tela de jogo (compartilhado entre o duelo local e o
-- bootstrap da partida em rede no cliente).
local function limparEstadoPartida()
  selUids = {}
  foldUids = {}
  filaSaida = nil
  modalRoubo = nil
  modalRects = nil
  selAreaUid = nil
  pressPanel = nil
  zoomCarta, zoomT = nil, 0
  pressCarta = nil
  arrasto = nil
  zoomPressFechar = false
  iaEstado = nil
  tempo.chave, tempo.duracao, tempo.restante = nil, 0, 0
  tempo.expirado, tempo.aviso = false, 0
  voo = nil
  resultado = nil
  qc.ativo = nil
  qc.pendente = nil
  pas.t = 0
  popups = {}
  ui._saidaSnap = nil
  ui._saidaRess = nil
  ui._fbPendente = nil
  ui._deusPendente = nil
  ui._impacto.limpar()
  ui._curingas.limpar()
  pausado = false
  saidaToast = nil
  saidaSeqVista = nil
  emojiAberto = nil
  emojiRects = {}
  baloes = {}
  vezVista = nil
  fimTocado = nil
  -- Modo alvo (selecao de alvo por carta): reset ao reiniciar partida.
  ui._alvoModo = nil
  ui._alvoCartaIdx = nil
  ui._alvoMapa = nil
  -- Estado da rede local (o host/cliente reapassa o proprio ao iniciar).
  redeModo = nil
  envioPendente = false
  pendVigarice = nil
  filaCartasRede = {}
  filaAcoesRede = {}
  -- Meta-evento da partida anterior (leilao/roleta) nao pode vazar para a
  -- proxima partida/rede.
  if ui._meta then ui._meta.cancelar() end
end

-- opts.rede = { papel = "host", nomes = {...}, avatares = {...} }: partida
-- de 2+ humanos em rede (Fase 2). Sem opts mantem o duelo/AI local.
local function iniciarJogo(arena, opts)
  anim.limpar()
  introBat.limpar()
  arenaN = arena
  ui._cicloDuelo = false
  ui._cicloArena = nil
  -- Simulacao: todos os assentos sao IA. O ritmo fica entre o modo de teste
  -- (quase instantaneo) e a espera normal do oponente, para dar para assistir.
  local sim = opts and opts.simulacao or nil
  IA_PASSO = MODO_TESTE and 0.05 or (sim and 0.35 or nil)
  local rede = opts and opts.rede or nil
  local n = arenaN or 2
  local avatares = nil
  if not rede then
    -- Sempre leva o avatar do perfil no seat 1 (habilidades taylor/marx);
    -- no arena N as IAs preenchem os demais assentos, no duelo o Adam
    -- continua sem id (chaveAvatar cai no retrato "ia").
    avatares = { perfilJogador.avatar }
    if n > 2 then
      for i = 2, n do avatares[i] = AVATARES_IA[i - 1] end
    end
  end
  if rede then
    -- rede.n e obrigatorio quando o host preenche com IA: os nomes das
    -- IAs sao sparse (caem no NOMES_ARENA do criarPartida) e #nomes
    -- continuaria sendo so os humanos da sala.
    partida = jogo.criarPartida({
      n = rede.n or #rede.nomes, nomes = rede.nomes, avatares = rede.avatares,
    })
  else
    partida = jogo.criarPartida(avatares and { n = n, avatares = avatares } or nil)
    -- GameProvider nomeJogador={perfil.nick}: o nome vem do perfil.
    partida.jogadores[1].nome = perfilJogador.nick
    -- Ciclo: o duelo vem da roda (nome/avatar do inimigo selecionado) e
    -- vale como marca de "duelo de ciclo" para o resto da rodada; a arena
    -- da mesa e a do ciclo em foco (CICLO I, CICLO II...).
    local cfgCiclo = opts and opts.ciclo and selecao.dueloAtual() or nil
    if cfgCiclo then
      partida.jogadores[2].nome = cfgCiclo.nome
      partida.jogadores[2].avatar = cfgCiclo.avatar
      ui._cicloDuelo = true
      ui._cicloArena = selecao.cicloAtual()
      -- Enfrentou o soberano: a partir daqui o retrato dele aparece na
      -- roda (antes o no usa a arte de bloqueado).
      if cfgCiclo.soberano then selecao.registrarChefe() end
    end
  end
  -- Simulacao: assento 1 tambem e IA. A flag fica na partida (sem novo
  -- local no main, que esta no limite do LuaJIT) e libera o assento 1 nos
  -- meta-eventos do jogo.lua (leilao/lojinha/fusao).
  if sim then
    partida.simulacao = true
    for _, j in ipairs(partida.jogadores) do j.isIA = true end
  end
  limparEstadoPartida()
  redeModo = rede and rede.papel or nil
  tela = "jogo"
  proximaFase()

  -- Hooks/debug pulam a animação de início de batalha (batalhaIniciada na hora).
  local pular = MODO_TESTE or sim or os.getenv("JOGO_TELA") == "arena"
    or os.getenv("JOGO_SELCARTA") ~= nil
    or os.getenv("JOGO_GUARDAR") ~= nil
  if pular then
    batalhaIniciada = true
    introBatAtiva = false
  else
    batalhaIniciada = false
    introBatAtiva = true
    local lista = {}
    for i, j in ipairs(partida.jogadores) do
      lista[i] = { nome = j.nome, avatar = avatarDe(i) }
    end
    introBat.iniciar({
      ativo = partida.vez - 1,
      jogadores = lista,
    })
  end
end

-- REDE: HOST E CLIENTE (Fase 2) --------------------------------------------
-- O host e o dono do motor: aplica as acoes dos clientes com
-- partidaRede.aplicarAcao e transmite CARTA_JOGADA (zoom) + SNAPSHOT
-- (estado rotacionado por destinatario). O cliente so espelha snapshots e
-- envia intencoes — nunca roda regra local.

local function tempoSnapshot()
  local dur = tempo.duracao
  if dur <= 0 and partida then
    dur = jogo.duracaoTurno(partida.jogadores[partida.vez])
  end
  local rest = tempo.restante
  if not tempo.expirado and (not rest or rest <= 0) then rest = dur end
  return { duracao = dur, restante = rest }
end

local function transmitirSnapshot()
  if redeModo ~= "host" or not mult or not partida then return end
  local tempoEnv = tempoSnapshot()
  for _, j in ipairs(mult:estado().jogadores) do
    if j.id ~= 0 then
      mult:enviarPartida(j.assento, {
        tipo = "SNAPSHOT",
        p = partidaRede.serializar(partida, j.assento, tempoEnv),
      })
    end
  end
end
-- O meta.lua roda fora do main (limite de locals): expos o transmissor para
-- os callbacks de leilao/roleta sem criar mais um upvalue no chunk principal.
ui._redeSnapshot = transmitirSnapshot

local function enviarCartaJogada(entradas)
  if redeModo ~= "host" or not mult or not partida then return end
  if not entradas or #entradas == 0 then return end
  for _, j in ipairs(mult:estado().jogadores) do
    if j.id ~= 0 then
      mult:enviarPartida(j.assento,
        { tipo = "CARTA_JOGADA", entradas = entradas })
    end
  end
end

-- Assento do remetente de uma mensagem (o host e id 0, nunca remetente).
local function assentoDoPeer(id)
  if not mult then return nil end
  for _, j in ipairs(mult:estado().jogadores) do
    if j.id == id and j.id ~= 0 then return j.assento end
  end
  return nil
end

-- Emojis da partida em rede: os helpers ficam todos DENTRO de uma tabela
-- local (uma unica variavel no chunk). O chunk principal estoura o limite
-- de 200 locals do LuaJIT se cada function do topo virar um local.
local emo = {}
-- Maximo de emojis equipados (bate com o limite da tela de perfil).
emo.MAX = 4

-- Balao de emoji do seat (o mais novo substitui o anterior do mesmo seat).
-- Codigos 1..4 = vetoriais (emoji.wav); 5+ = emojis de sprite da loja
-- (psicar.wav, a arte e animada no desenho).
function emo.novoBalao(assento, codigo)
  local c = tonumber(codigo)
  if not c or c ~= math.floor(c) or c < 1 then return end
  if c > 4 and not ui._inv.emojiPorCodigo(c) then return end
  if not partida or not partida.jogadores[assento] then return end
  for i = #baloes, 1, -1 do
    if baloes[i].assento == assento then table.remove(baloes, i) end
  end
  -- Sprites (codigo 5+, catalogo da loja): o balao vive SO a animacao
  -- (dur total em arte.emojiSpriteDur, hoje 1,5s) e encerra; os
  -- vetoriais continuam com DUR_EMOJI fixo.
  local dur = DUR_EMOJI
  if c >= 5 then dur = arte.emojiSpriteDur() end
  baloes[#baloes + 1] = { assento = assento, codigo = c, t = 0, dur = dur }
  som.tocar(c >= 5 and "psicar" or "emoji")
end

-- Host: valida o EMOJI de um cliente (ou o proprio, id 0), cria o balao
-- local e transmite para TODOS os clientes da sala — inclusive o
-- remetente, que assim ve o proprio balao.
function emo.processarEmojiHost(id, msg)
  if not partida or partida.fim then return end
  local assento = id == 0 and 1 or assentoDoPeer(id)
  local j = assento and partida.jogadores[assento]
  if not j or j.saiu then return end
  local c = tonumber(msg and msg.codigo)
  -- 1..4 = vetoriais de graca; 5+ precisa existir no catalogo da loja
  -- (passa tambem quando o cliente ja comprou e o host nao — nao e gating
  -- de posse, so anti-codigo-inventado na rede).
  if not c or c ~= math.floor(c) or c < 1 then return end
  if c > 4 and not ui._inv.emojiPorCodigo(c) then return end
  emo.novoBalao(assento, c)
  if redeModo == "host" and mult then
    for _, jg in ipairs(mult:estado().jogadores) do
      if jg.id ~= 0 then
        mult:enviarPartida(jg.assento,
          { tipo = "EMOJI", assento = assento, codigo = c })
      end
    end
  end
end

-- Lancamento do proprio emoji: o host aplica na hora (e transmite); o
-- cliente manda pro host que e o autoritativo.
function emo.lancarEmoji(codigo)
  if redeModo == "host" then
    emo.processarEmojiHost(0, { codigo = codigo })
  elseif redeModo == "cliente" and mult then
    mult:enviarParaServidor({ tipo = "EMOJI", codigo = codigo })
  end
end

-- Emojis equipados no perfil (maximo 4; default os 4 vetoriais de graca).
-- Lista invalida cai no default; vazia = jogador desquipou todos.
function emo.listaEquipados()
  local lista = perfilJogador and perfilJogador.emojis
  if type(lista) ~= "table" then return { 1, 2, 3, 4 } end
  return lista
end

-- Geometria do seletor: painel pequeno sobreposto acima do proprio painel.
function emo.geomPainelEmoji()
  local lista = emo.listaEquipados()
  local n = math.max(1, math.min(emo.MAX, #lista))
  local bw, gap, pad = ui.E(46), ui.E(8), ui.E(10)
  local w = pad * 2 + n * bw + (n - 1) * gap
  local h = pad * 2 + bw
  local x = PAINEL_RECT.x + PAINEL_RECT.w / 2 - w / 2
  x = math.min(math.max(x, ui.E(8)), VW - ui.E(8) - w)
  local y = PAINEL_RECT.y - h - ui.E(6)
  return x, y, w, h, bw, gap, pad
end

-- Desenho do seletor (emojis equipados no perfil; rects salvos pro clique).
function emo.desenharPainelEmoji()
  local x, y, w, h, bw, gap, pad = emo.geomPainelEmoji()
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill", x + 2, y + 3, w, h, ui.E(10))
  ui.caixa(x, y, w, h, ui.E(10), { 0.05, 0.06, 0.13 }, ui.C.OURO, ui.E(1.5))
  emojiRects = {}
  for i, c in ipairs(emo.listaEquipados()) do
    local r = { x = x + pad + (i - 1) * (bw + gap), y = y + pad,
      w = bw, h = bw, codigo = c }
    if ui.dentro(hover.x, hover.y, r) then
      ui.caixa(r.x - ui.E(2), r.y - ui.E(2), bw + ui.E(4), bw + ui.E(4),
        ui.E(8), { 1, 1, 1 }, ui.C.OURO, ui.E(1), 0.14)
    end
    ui.emoji(c, r.x + bw / 2, r.y + bw / 2, bw * 0.42, 1)
    emojiRects[#emojiRects + 1] = r
  end
end

-- Clique com o seletor aberto: escolhe (fecha e lanca) ou fecha no toque
-- fora dos botoes (o `entrada` ja so deixa chegar aqui o toque dentro do
-- seletor ou do proprio painel).
function emo.clicadoPainelEmoji(vx, vy)
  for _, r in ipairs(emojiRects) do
    if ui.dentro(vx, vy, r) then
      emojiAberto = nil
      emo.lancarEmoji(r.codigo)
      return
    end
  end
  emojiAberto = nil
end

-- Abre/fecha o seletor pelas condicoes de partida (usado no clique curto
-- do painel, que la embaixo so chega quando NAO e long-press). Nao abre
-- com a lista equipada vazia (desquipou todos no perfil).
function emo.alternarPainelEmoji()
  if emojiAberto then
    emojiAberto = nil
  elseif tela == "jogo" and redeModo and mult and partida
      and not partida.fim and batalhaIniciada and not introBatAtiva
      and not pausado and not modalRoubo
      and #emo.listaEquipados() > 0 then
    emojiAberto = true
  end
end

-- Ancora do balao: acima do proprio painel (seat 1), acima do slot na
-- mesa ou ABAIXO do painel do oponente no duelo (topo da tela, nao sobra
-- espaco em cima). O 3o valor e a direcao do rabo (-1 = balao por cima).
function emo.posBalao(assento)
  if assento == 1 then
    return PAINEL_RECT.x + PAINEL_RECT.w / 2, PAINEL_RECT.y - ui.E(4), -1
  end
  if ehMesa() then
    local p = posSlot(assento)
    return p.cx, p.cy - p.h / 2 - ui.E(4), -1
  end
  return CENTRO, OP_PAINEL_Y + ui.E(34) + ui.E(4), 1
end

-- Baloes de emoji estilo HQ: caixa branca com rabo apontando para o
-- avatar; cada um vive DUR_EMOJI segundos com fade so no fim.
function emo.desenharBaloes()
  for _, b in ipairs(baloes) do
    local j = partida and partida.jogadores[b.assento]
    if j and not j.saiu then
      local ax, ay, dir = emo.posBalao(b.assento)
      local w, h = ui.E(52), ui.E(48)
      -- fade so no fim: 0.6s nos baloes longos; nos curtos (sprites, que
      -- encerram junto com a animacao) um quarto da duracao.
      local dur = b.dur or DUR_EMOJI
      local fade = math.min(0.6, dur * 0.25)
      local alfa = b.t > dur - fade
        and math.max(0, 1 - (b.t - (dur - fade)) / fade) or 1
      local x = math.min(math.max(ax - w / 2, ui.E(6)), VW - ui.E(6) - w)
      local y = dir < 0 and (ay - h) or ay
      y = math.min(math.max(y, ui.E(6)), VH - ui.E(6) - h)
      -- rabo (preenchido em branco com o mesmo contorno escuro da caixa,
      -- sem linha na base pra nao cortar a juncao)
      local base = dir < 0 and (y + h) or y
      local ponta = dir < 0 and (base + ui.E(9)) or (base - ui.E(9))
      local tx = math.min(math.max(ax, x + ui.E(9)), x + w - ui.E(9))
      love.graphics.setColor(1, 1, 1, 0.97 * alfa)
      love.graphics.polygon("fill", tx - ui.E(6), base, tx + ui.E(6), base,
        tx, ponta)
      love.graphics.setColor(0.12, 0.12, 0.16, alfa)
      love.graphics.setLineWidth(ui.E(2))
      love.graphics.line(tx - ui.E(6), base, tx, ponta)
      love.graphics.line(tx + ui.E(6), base, tx, ponta)
      love.graphics.setLineWidth(1)
      -- caixa + emoji (codigo 5+ = sprite do catalogo animado; o passo e
      -- duracao total / total de quadros, entao repete em qualquer emoji)
      ui.caixa(x, y, w, h, ui.E(10), { 1, 1, 1 }, { 0.12, 0.12, 0.16 },
        ui.E(2), 0.97 * alfa, alfa)
      local prodSpr = b.codigo >= 5 and ui._inv.emojiPorCodigo(b.codigo)
      if prodSpr then
        -- quadro avanca sem repetir (trava no ultimo; o balao some junto)
        local nq = arte.emojiSpriteTotal(prodSpr.id)
        local quadro = math.min(nq, 1 + math.floor(b.t / dur * nq))
        local img = arte.emojiSprite(prodSpr.id, quadro)
        if img then
          local d = ui.E(34)
          love.graphics.setColor(1, 1, 1, alfa)
          love.graphics.draw(img, x + w / 2 - d / 2, y + h / 2 - d / 2,
            0, d / img:getWidth(), d / img:getHeight())
        else
          ui.emoji(b.codigo, x + w / 2, y + h / 2, ui.E(17), alfa)
        end
      else
        ui.emoji(b.codigo, x + w / 2, y + h / 2, ui.E(17), alfa)
      end
    end
  end
end

local function responderMao(id, msg)
  local assento = assentoDoPeer(id)
  if not assento or not partida then return end
  local alvo = tonumber(msg.alvo)
  local alvoJ = alvo and partida.jogadores[alvo]
  if not alvoJ or alvo == assento then return end
  mult:enviarPartida(assento,
    { tipo = "MAO", alvo = alvo, cartas = alvoJ.mao })
end

-- Acao de um cliente: aplica no motor, avisa (zoom) e ressincroniza. Uma
-- acao por chamada; o chamador so chama com o jogo livre (sem zoom/voo).
local function processarAcaoRemota(assento, msg)
  if not partida then return false end

  -- Quick Counter no host: se a acao remota atinge o assento local e ha
  -- defesa disponivel, a aplicacao autoritativa espera a janela fechar.
  if not qc.ativo and not qc.pendente and msg.tipo == "JOGAR" then
    local ameaca = qc.ameacaRemota(assento, msg)
    if ameaca then
      qc.abrirRede(assento, ameaca, function(defRes, defesaDe)
        local antes = snapshotSaldos()
        msg.defesaDe = defesaDe
        local r = partidaRede.aplicarAcao(partida, assento, msg)
        if not r.ok then
          mult:enviarPartida(assento,
            { tipo = "RECUSADO", motivo = r.motivo })
          transmitirSnapshot()
          return
        end
        local entradas = {}
        if defRes then
          entradas[#entradas + 1] = novaEntrada(defRes, defRes.carta)
        end
        for _, e in ipairs(r.entradas or {}) do
          entradas[#entradas + 1] = e
        end
        if #entradas > 0 then enviarCartaJogada(entradas) end
        transmitirSnapshot()
        popupsSaldo(antes)
        if partida.fim then
          tela = "fim"
        else
          proximaFase()
        end
      end)
      return true
    end
  end

  local antes = snapshotSaldos()
  local r = partidaRede.aplicarAcao(partida, assento, msg)
  if not r.ok then
    -- Recusa silenciosa: o SNAPSHOT novo ja leva o cliente de volta ao
    -- estado verdadeiro (ex.: PASSAR duplicado apos o turno ter virado).
    mult:enviarPartida(assento, { tipo = "RECUSADO", motivo = r.motivo })
    transmitirSnapshot()
    return false
  end
  if r.entradas and #r.entradas > 0 then enviarCartaJogada(r.entradas) end
  transmitirSnapshot()
  popupsSaldo(antes)
  if partida.fim then
    tela = "fim"
  else
    proximaFase()
  end
  return true
end

-- SNAPSHOT no cliente: troca o espelho inteiro e recalcula fase/tempo. O
-- primeiro snapshot monta a partida (tela de jogo + intro de batalha).
local function aplicarSnapshotCliente(snap)
  if type(snap) ~= "table" then return end
  local primeiro = partida == nil
  local antes = not primeiro and snapshotSaldos() or nil

  -- Fase 3: mesa (>=3) liga o desenho de slots pelo tamanho da partida;
  -- duelo em rede mantem o layout de 2. Calculado antes de montar porque
  -- o primeiro desenho (intro/avatars) ja consulta ehMesa().
  local nSnap = snap.n or #(snap.jogadores or {})
  arenaN = nSnap >= 3 and nSnap or nil

  if primeiro then
    limparEstadoPartida()
    redeModo = "cliente"
    partida = partidaRede.montar(snap)
    tela = "jogo"
    if MODO_TESTE then
      batalhaIniciada = true
      introBatAtiva = false
    else
      batalhaIniciada = false
      introBatAtiva = true
      local lista = {}
      for i, j in ipairs(partida.jogadores) do
        lista[i] = { nome = j.nome, avatar = avatarDe(i) }
      end
      introBat.iniciar({ ativo = partida.vez - 1, jogadores = lista })
    end
  else
    partida = partidaRede.montar(snap)
    -- O estado do jogo mudou: descarta qualquer modo alvo pendente no cliente.
    ui._alvoModo = nil
    ui._alvoCartaIdx = nil
    ui._alvoMapa = nil
    -- Selecoes que apontavam para cartas que sairam da mao/area.
    local valida = {}
    for _, c in ipairs(partida.jogadores[1].mao) do valida[c.uid] = true end
    for _, c in ipairs(partida.jogadores[1].areaSegura) do valida[c.uid] = true end
    local novoSel = {}
    for _, u in ipairs(selUids) do
      if valida[u] then novoSel[#novoSel + 1] = u end
    end
    selUids = novoSel
    if selAreaUid and not valida[selAreaUid] then selAreaUid = nil end
    if arrasto and not valida[arrasto.uid] then arrasto = nil end
    if pendVigarice then
      for _, c in ipairs(pendVigarice.cartas) do
        if not valida[c.uid] then pendVigarice = nil break end
      end
    end
    if antes then popupsSaldo(antes) end
  end

  tempo.chave = partida.vez .. "_" .. partida.turno
  tempo.duracao = jogo.duracaoTurno(partida.jogadores[partida.vez])
  tempo.restante = (snap.tempo and snap.tempo.restante) or tempo.duracao
  tempo.expirado = false
  envioPendente = false

  -- Meta-evento em rede: o host publica `metaFase` no snapshot enquanto o
  -- leilao/roleta esta aberto. O cliente abre o espelho, manda lances e
  -- confirmacoes, mas nunca resolve nada localmente.
  if snap.metaFase then
    if not (ui._meta and ui._meta.ativo()) then
      fase = "META"
      iaEstado = nil
      ui._meta.abrir(partida, "leilao", {
        vw = VW, vh = VH, rede = "cliente",
        fase = snap.metaFase,
        tempo = snap.metaT,
        -- Entrada atrasada no resultado: nao reabre a roleta.
        roleta = snap.metaFase == "leilao",
        aoLance = function(valor)
          if redeModo == "cliente" and mult then
            mult:enviarParaServidor({ tipo = "LANCE_LEILAO", valor = valor })
          end
        end,
        aoConfirmar = function()
          if redeModo == "cliente" and mult then
            mult:enviarParaServidor({ tipo = "CONFIRMAR_LEILAO" })
          end
        end,
      })
    end
    if ui._meta and ui._meta.ativo() then
      ui._meta.aplicarRede(partida, snap)
    end
    return
  end
  -- O host fechou o meta: o cliente volta ao fluxo normal da mesa.
  if ui._meta and ui._meta.ativo() then ui._meta.cancelar() end

  if partida.fim then
    tela = "fim"
  else
    proximaFase()
  end
end

-- Resposta do PEDIR_MAO: com o modal fechado, abre a Vigarice (fluxo
-- inicial); com ele aberto — troca de alvo por chip na Fase 3 — troca a
-- mao exibida do alvo pedido (casada pelo assento real `msg.alvo`).
local function receberMao(msg)
  local mao = type(msg.cartas) == "table" and msg.cartas or {}
  local pend = pendVigarice
  if pend then
    pendVigarice = nil
    envioPendente = false
    if #pend.alvos == 0 then return end
    pend.alvos[1].mao = mao
    modalRoubo = {
      cartas = pend.cartas,
      uidCarta = pend.uidCarta,
      quantidade = pend.quantidade,
      alvos = pend.alvos,
      alvoSel = 1,
      mao = mao,
      nome = pend.alvos[1].nome,
      sel = {},
    }
    return
  end
  if not modalRoubo or type(msg.alvo) ~= "number" then return end
  for k, a in ipairs(modalRoubo.alvos) do
    if a.idx == msg.alvo then
      a.mao = mao
      if modalRoubo.alvoSel == k then
        modalRoubo.mao = mao
        modalRoubo.texto = nil
        modalRoubo.sel = {}
      end
      return
    end
  end
end

-- Saida de um jogador no meio da partida (fila de saidas do host): a
-- partida CONTINUA sem ele — marca o seat como saiu (some da arena e pelas
-- regras vira eliminado), gera o aviso no canto superior direito, passa o
-- turno adiante se era dele e reorganiza a arena. So encerra se sobrar um
-- vivo. A saida do HOST e o outro caminho: o cliente detecta sozinho
-- (DESCONECTADO DO ANFITRIAO) e volta ao menu.
local function aplicarSaidaJogador(s)
  if not partida or partida.fim then return end
  local j = s and partida.jogadores[s.assento or 0]
  if not j or j.saiu then return end
  j.saiu = true
  -- Eliminado pelas regras: sai de alvos, vivos e do placar.
  j.falido = true
  jogo.sincronizarStatus(j)
  partida.saidaSeq = (partida.saidaSeq or 0) + 1
  partida.saida = { nome = j.nome, seq = partida.saidaSeq }
  jogo.registrar(partida, tostring(j.nome) .. " saiu da partida")
  -- Se era a vez dele, passa adiante (pulando quem ja saiu) e reabre o
  -- ciclo de jogadas do novo turno.
  local eraVez = partida.vez == s.assento
  if eraVez then
    jogo.avancarVez(partida)
    partida.jogadasTurno = 0
    jogo.processarInicioTurno(partida, partida.vez)
  end
  jogo.verificarFim(partida)
  transmitirSnapshot()
  if partida.fim then
    iaEstado = nil
    tela = "fim"
  elseif eraVez then
    proximaFase()
  end
end

-- Consome as mensagens de partida conforme o papel de quem esta rodando.
local function processarPartidaRede()
  if not mult then return end
  -- Saidas em partida (so o host gera): aplicadas ANTES das acoes — o
  -- seat ja saiu do mapeamento da sala, entao acoes pendentes do que saiu
  -- caem sozinhas (assentoDoPeer = nil) e os demais nao mudam de assento.
  if redeModo == "host" then
    for _, s in ipairs(mult:consumirSaios()) do
      aplicarSaidaJogador(s)
    end
  end
  local fila = mult:consumirPartida()
  if redeModo == "host" then
    for _, ev in ipairs(fila) do
      local msg = ev.msg
      if msg.tipo == "REACAO" then
        -- Resposta da janela remota: so vale para o alvo e a janela atuais.
        local assento = assentoDoPeer(ev.id)
        if assento and qc.pendente and qc.pendente.alvo == assento then
          qc.resolverRemota(msg.uid, msg.origem, msg.seq)
        end
      elseif msg.tipo == "PEDIR_MAO" then
        responderMao(ev.id, msg) -- leitura pura: responde na hora
      elseif msg.tipo == "PEDIR_SNAPSHOT" then
        -- Cliente travado no limbo pos-INICIADO (snapshot do bootstrap
        -- perdido): reenvia o estado SO para este peer, na hora — igual ao
        -- PEDIR_MAO, sem esperar o livro livre da partida.
        local assento = assentoDoPeer(ev.id)
        if assento and partida then
          mult:enviarPartida(assento, {
            tipo = "SNAPSHOT",
            p = partidaRede.serializar(partida, assento, tempoSnapshot()),
          })
        end
      elseif msg.tipo == "EMOJI" then
        -- Reacao visual: valida, cria o balao e transmite pra sala sem
        -- esperar o livro livre (da pra reagir em qualquer momento).
        emo.processarEmojiHost(ev.id, msg)
      elseif msg.tipo == "LANCE_LEILAO" then
        local assento = assentoDoPeer(ev.id)
        local ok = assento and ui._meta and ui._meta.ativo()
          and ui._meta.receberLance(assento, msg.valor)
        if not ok and assento then
          mult:enviarPartida(assento,
            { tipo = "RECUSADO", motivo = "leilao" })
        end
      elseif msg.tipo == "CONFIRMAR_LEILAO" then
        local assento = assentoDoPeer(ev.id)
        local ok = assento and ui._meta and ui._meta.ativo()
          and ui._meta.receberConfirmacao(assento)
        if not ok and assento then
          mult:enviarPartida(assento,
            { tipo = "RECUSADO", motivo = "leilao" })
        end
      elseif ui._meta and ui._meta.ativo() then
        -- Acao de mesa durante o leilao/roleta: recusa em vez de aplicar
        -- depois do evento (o estado ja mudou).
        local assento = assentoDoPeer(ev.id)
        if assento then
          mult:enviarPartida(assento,
            { tipo = "RECUSADO", motivo = "meta" })
        end
      else
        filaAcoesRede[#filaAcoesRede + 1] = { id = ev.id, msg = msg }
      end
    end
    local function livre()
      return tela == "jogo" and batalhaIniciada and not introBatAtiva
        and not voo and not resultado and not filaSaida and not modalRoubo
        and not pausado and not qc.ativo and not qc.pendente and partida
        and not partida.fim
        and not (ui._meta and ui._meta.ativo())
    end
    while livre() and #filaAcoesRede > 0 do
      local ev = table.remove(filaAcoesRede, 1)
      local assento = assentoDoPeer(ev.id)
      if assento then processarAcaoRemota(assento, ev.msg) end
    end
  elseif redeModo == "cliente" or mult:emPartida() then
    -- O primeiro INICIADO/SNAPSHOT chega antes do redeModo existir; o
    -- emPartida (marcado pelo INICIADO) destrava a leitura nessa janela.
    for _, ev in ipairs(fila) do
      local msg = ev.msg
      if msg.tipo == "INICIADO" then
        -- Batalha confirmada: mostra a tela de carregamento ate o host
        -- mandar o primeiro SNAPSHOT (que chega logo depois).
        if not ui._carga.pular() then ui._carga.iniciar() end
      elseif msg.tipo == "SNAPSHOT" and type(msg.p) == "table" then
        aplicarSnapshotCliente(msg.p)
        -- Sincronizado: o cliente para de mandar PEDIR_SNAPSHOT (o reenvio
        -- so existe para destravar o limbo pos-INICIADO).
        mult:marcarSincronizado()
      elseif msg.tipo == "CARTA_JOGADA" and type(msg.entradas) == "table" then
        filaCartasRede[#filaCartasRede + 1] = msg.entradas
      elseif msg.tipo == "PEDIR_REACAO" then
        qc.abrirPedido(msg)
      elseif msg.tipo == "MAO" then
        receberMao(msg)
      elseif msg.tipo == "EMOJI" and type(msg.assento) == "number" then
        -- O assento do broadcast vem no espaco GLOBAL (o host resolve o
        -- seat real do remetente), mas o balao e desenhado por indice
        -- LOCAL (1 = proprio painel; no cliente o quadro e espelhado).
        -- Sem converter, o emoji do host (seat 1) caia no painel de baixo
        -- do cliente. Sem partida/meuAssento na janela de bootstrap a
        -- conversao fica de fora (identidade, como antes).
        local ass = msg.assento
        if partida and mult and mult:estado().meuAssento then
          ass = partidaRede.paraLocal(#partida.jogadores,
            mult:estado().meuAssento, ass)
        end
        emo.novoBalao(ass, msg.codigo)
      elseif msg.tipo == "RECUSADO" then
        envioPendente = false
      end
    end
  end
end

-- Encerra a partida em rede e volta ao menu (fechando a conexao).
local function sairPartidaRede(motivo)
  redeModo = nil
  qc.ativo = nil
  qc.pendente = nil
  envioPendente = false
  pendVigarice = nil
  filaCartasRede = {}
  filaAcoesRede = {}
  emojiAberto = nil
  emojiRects = {}
  baloes = {}
  vezVista = nil
  if ui._meta then ui._meta.cancelar() end
  if ui._carga then ui._carga.limpar() end
  if mult then mult:fechar() end
  mult = nil
  partida = nil
  tela = "menu"
  if motivo then
    util.adicionarPopup(motivo, CENTRO, VH * 0.5, ui.C.OURO, ui.E(22))
  end
end

-- Host: comeca a partida com quem esta na sala e envia INICIARD +
-- SNAPSHOT inicial personalizado para cada cliente.
local function iniciarPartidaRede()
  if not mult or mult:estado().papel ~= "anfitriao" then return false end
  local st = mult:estado()
  -- Fase 3: quantas cadeiras vazias a IA preenche. qtdIA e a escolha
  -- apertada na sala (0 = so humanos); o booleano preencherIA vira
  -- fallback no formato antigo (smokes/boot: encher ate o maximo). O
  -- numero final e SEMPRE limitado as vagas livres (8 - humanos).
  local livre = math.max(0, 8 - #st.jogadores)
  local qtd = math.floor(tonumber(st.qtdIA) or 0)
  if qtd <= 0 and st.preencherIA then qtd = livre end
  if qtd < 0 then qtd = 0 elseif qtd > livre then qtd = livre end
  -- Minimo de 2 na mesa: 1 humano + IA escolhida ja da para iniciar.
  local total = #st.jogadores + qtd
  if total < 2 then return false end
  -- Tela de pre-batalha: os dois lados entram nela (o cliente no INICIADO).
  -- A partida e a intro nascem aqui atras do preto e ficam congeladas no
  -- love.update ate os 6s terminarem.
  if not ui._carga.pular() then ui._carga.iniciar() end
  -- Sorteia os assentos 2..total (clientes remotos e IAs comecam em
  -- posicoes diferentes a cada partida; o host fica no 1). Devolve a
  -- lista de assentos que viram IA.
  local assentosIA = mult:embaralharAssentos(total)
  local nomes, avatares = {}, {}
  for _, j in ipairs(st.jogadores) do
    nomes[j.assento] = j.nome
    avatares[j.assento] = j.avatar
  end
  for _, s in ipairs(assentosIA) do
    avatares[s] = AVATARES_IA[s - 1]
  end
  -- Mesa (>=3) liga o desenho de slots; duelo mantem o layout de 2.
  iniciarJogo(total >= 3 and total or nil, {
    rede = { papel = "host", nomes = nomes, avatares = avatares, n = total },
  })
  -- Arena escolhida na sala (nil = madeira padrao): entra no snapshot e o
  -- desenho (host e clientes) le o mesmo partida.arena.
  partida.arena = st.arena
  -- Dificuldade da IA escolhida na sala (1 facil, 2 media, 3 dificil):
  -- parametros lidos por iaMaquina (chances/guarda) e proximaFase
  -- (espera de reacao) so no host; gravado na propria partida.
  local DIFS = {
    { espera = 6,   chanceJogar = 0.5,  chanceMelhor = 0.4, guarda = 0.1 },
    { espera = 4,   chanceJogar = 0.85, chanceMelhor = 0.75, guarda = 0.4 },
    { espera = 2.5, chanceJogar = 1,    chanceMelhor = 1,   guarda = 0.65 },
  }
  partida.difIA = DIFS[math.min(3, math.max(1,
    math.floor(tonumber(st.dificuldade) or 2)))]
  -- Humanos remotos (os assentos da sorte) ficam isIA=false; as cadeiras
  -- de IA preenchidas mantem isIA=true: a IA roda aqui no host (fase
  -- "IA") e o cliente so espera snapshots com o rotulo serializado.
  for _, j in ipairs(st.jogadores) do
    if j.id ~= 0 then partida.jogadores[j.assento].isIA = false end
  end
  mult:marcarPartida(true)
  for _, j in ipairs(st.jogadores) do
    if j.id ~= 0 then
      mult:enviarPartida(j.assento, { tipo = "INICIADO" })
    end
  end
  transmitirSnapshot()
  return true
end

-- LAYOUT DA MÃO (definido cedo: executarLote usa para achar a origem da saída)
-- Mão RETA: todas as cartas na mesma linha horizontal e sem rotação (antes
-- era um leque em arco, com curv e rot por posição). `norm` continua no
-- retângulo porque é ele que diz o quanto a carta está na ponta.
local function layoutMao(n)
  local disp = ui.E(510)
  local passo = CW * 0.35
  if n > 1 then
    passo = math.min(CW * 0.72, math.max(CW * 0.35, (disp - CW) / (n - 1)))
  end
  local total = CW + passo * (n - 1)
  local inicio = CENTRO - total / 2
  local lista = {}
  local meio = (n + 1) / 2
  for i = 1, n do
    local norm = n > 1 and (i - meio) / meio or 0
    table.insert(lista, {
      x = inicio + (i - 1) * passo,
      y = MAO_Y,
      w = CW, h = CH,
      rot = 0,
      idx = i,
      norm = norm,
    })
  end
  return lista
end

-- Condições para agir no turno humano (isMinhaVez do React + bloqueios
-- durante voo/resultado/leva/modal/pausa).
local function podeAgirAgora()
  return tela == "jogo" and batalhaIniciada and fase == "JOGADOR"
    and not voo and not resultado and not filaSaida and not modalRoubo
    and not pausado and not (partida and partida.fim)
    and not (partida and partida.jogadores[1].falido)
    -- Quota efetiva do turno (2 base + bonus de cadeia; max. 4).
    and (not partida or jogo.jogadasRestantes(partida, 1) > 0)
    and not (qc and qc.ativo) and not (qc and qc.pendente)
    -- Em rede (cliente): uma acao por vez, ate o snapshot do host chegar.
    and not (redeModo == "cliente" and envioPendente)
    and not (ui._meta and ui._meta.ativo())
end

local function alternarSelecao(uid)
  if not podeAgirAgora() then return end
  -- Fluxo novo: uma carta por vez. Clicar de novo na carta selecionada
  -- cancela a selecao/modo alvo; clicar em outra troca a selecao.
  if selUids[1] == uid then
    selUids = {}
    ui._alvoModo = nil
    ui._alvoCartaIdx = nil
    ui._alvoMapa = nil
    return
  end
  local carta = nil
  for _, c in ipairs(partida.jogadores[1].mao) do
    if c.uid == uid then carta = c break end
  end
  if not carta then return end
  selUids = { uid }
  -- Pulso de seleção da carta (game feel, sem tocar em regras).
  ui.pulsoSelecao(carta)
  -- Toda carta tem uma area de confirmacao: as que nao exigem alvo usam o
  -- descarte como area generica de "usar carta". Excecao: a Defesa se arma
  -- no Slot de Defesa (clique na carta + clique no slot), portanto nao abre
  -- modo alvo.
  emojiAberto = nil
  if jogo.ehDefesa(carta) then
    ui._alvoModo = nil
    ui._alvoCartaIdx = nil
    ui._alvoMapa = nil
    return
  end
  ui._alvoModo = true
  ui._alvoCartaIdx = 1
  ui._alvoMapa = {}
end

-- Fim da leva: popups do lote e passagem de turno (JOGAR_CARTAS_E_PASSAR).
local function fimSaida()
  filaSaida = nil
  -- Host em rede: transmite ANTES dos popups — popupsSaldo zera
  -- partida.evento e o snapshot carrega ele pro cliente.
  if redeModo == "host" then transmitirSnapshot() end
  popupsSaldo(saidaAntes)
  -- Feedback da leva (depois do zoom e dos voos): numeros de SAT/PROD,
  -- escudo de protecao, falencia e impacto/estilhaco no ponto de pouso.
  if ui._saidaSnap then
    local fxX, fxY = destinoVoo()
    ui._impacto.feedback(partida, ui._saidaRess, ui._saidaSnap,
      fxX + DECK_DW / 2, fxY + DECK_DH / 2, posPopup, ui._posSeatFx)
    ui._saidaSnap = nil
    ui._saidaRess = nil
  end
  if partida.vez == 1 and not partida.fim then
    -- Fluxo novo: cada carta e jogada sozinha. O turno so encerra quando a
    -- quota efetiva (base + cadeia) foi atingida; apos a 1a carta o jogador
    -- continua no turno para selecionar a 2a (ou a 3a/4a da cadeia).
    if jogo.jogadasRestantes(partida, 1) <= 0 then
      local a = snapshotSaldos()
      jogo.encerrarVez(partida)
      if redeModo == "host" then transmitirSnapshot() end
      popupsSaldo(a)
      if partida.fim then
        tela = "fim"
      else
        proximaFase()
      end
    end
  end
end

-- Próxima carta da SAÍDA (roda depois que o zoom fecha, como no React:
-- "SO DEPOIS as cartas saem da mão pro descarte").
local function proximaSaida()
  if not filaSaida then return end
  if #filaSaida == 0 then
    fimSaida()
    return
  end

  local prox = table.remove(filaSaida, 1)
  local alvoX, alvoY = prox.alvoDestX, prox.alvoDestY
  if not alvoX or not alvoY then alvoX, alvoY = destinoVoo() end
  voo = { carta = prox.carta, x = prox.x, y = prox.y, e = prox.e,
    rot = prox.rot, p = 0 }
  anim.tween(voo, { p = 1 }, VOO_SEG, anim.linear)
  anim.tween(voo, { x = alvoX, y = alvoY, e = 1, rot = 0 }, VOO_SEG,
    anim.entradaCubica, function()
      voo = nil
      -- Pouso da carta: batida leve na mesa (o feedback grande da leva vem
      -- depois, quando a fila esvaziar). A cor/forca seguem o tipo da carta
      -- (Etapa 6): acao = vinho, efeito = azul, protecao/coringa = ouro.
      local corPouso = ui.corDoTipo(prox.carta)
      local forcaPouso = 0.45
      if prox.carta.tipo == "ACAO" then forcaPouso = 0.9
      elseif prox.carta.tipo == "EFEITO" then forcaPouso = 0.75
      elseif prox.carta.tipo == "CORINGA" then forcaPouso = 1.05 end
      ui._impacto.impacto(alvoX + DECK_DW / 2, alvoY + DECK_DH / 2,
        corPouso, forcaPouso)
    end)
end

local function executarLote(cartasSel, mapaRoubo, alvoIdx, mapaAlvos,
    pularReacao, reacaoRes, defesaDe)
  local j = partida.jogadores[1]
  -- Nunca aplica mais cartas do que a quota restante do turno (protege o
  -- fluxo de uma-carta-por-vez e os testes que chamam jogarSelecao em lote).
  local restante = jogo.jogadasRestantes(partida, 1)
  if restante <= 0 then return end

  -- Host atacando um cliente humano: pergunta antes de aplicar a leva. A
  -- defesa escolhida la e aplicada aqui, e so entao as cartas atacantes
  -- entram (mantendo o host como autoridade unica).
  if redeModo == "host" and not pularReacao and not qc.ativo
      and not qc.pendente then
    local ameaca, mapaAjustado = qc.ameacaRemotaHost(cartasSel, alvoIdx,
      mapaAlvos)
    if ameaca then
      mapaAlvos = mapaAjustado
      qc.abrirRemota({ alvo = ameaca.alvo, atacante = 1,
        carta = ameaca.carta }, function(defRes, permissao)
        executarLote(cartasSel, mapaRoubo, alvoIdx, mapaAlvos, true,
          defRes, permissao)
      end)
      return
    end
  end
  selUids = {}
  local antes = snapshotSaldos()
  local snap = ui._impacto.snapshot(partida)

  -- Posições na mão ANTES de aplicar (as cartas voam de onde estavam).
  local rects = layoutMao(#j.mao)
  local posPorUid = {}
  for _, r in ipairs(rects) do
    local c = j.mao[r.idx]
    if c then posPorUid[c.uid] = r end
  end

  -- 1) Aplica a leva inteira de uma vez (JOGAR_CARTAS_SEM_COMPRA), limitada
  -- a quota restante do turno.
  local entradas, saidas = {}, {}
  local ress = {}
  if reacaoRes then
    entradas[1] = novaEntrada(reacaoRes, reacaoRes.carta)
    ress[1] = reacaoRes
    local nomeDef = reacaoRes.carta and reacaoRes.carta.nome or "DEFESA"
    util.adicionarPopup(ui.tr("CONTRA-ATAQUE:") .. " " .. nomeDef, CENTRO, VH * 0.34,
      ui.C.SUCESSO, ui.E(15))
  end
  local aplicadas = 0
  for _, c in ipairs(cartasSel) do
    if aplicadas >= restante then break end
    local idx = nil
    for i, m in ipairs(j.mao) do
      if m.uid == c.uid then idx = i break end
    end
    if idx then
      local carta = table.remove(j.mao, idx)
      local r = posPorUid[carta.uid]
      if r then
        local alvoInfo = mapaAlvos and mapaAlvos[carta.uid]
        local alvoTipo = alvoInfo and alvoInfo.tipo
        local ax, ay = destinoVoo()
        if alvoTipo then
          ax, ay = pontoAlvo(alvoTipo, alvoInfo and alvoInfo.idx)
        end
        saidas[#saidas + 1] = {
          carta = carta,
          x = r.x + r.w / 2 - DECK_DW / 2,
          y = r.y + r.h / 2 - DECK_DH / 2,
          e = 0.6,
          rot = r.rot,
          alvoDestX = ax,
          alvoDestY = ay,
        }
      end
      local alvoSel = mapaAlvos and mapaAlvos[carta.uid]
      local alvoIdxCarta = alvoSel and alvoSel.idx or nil
      local optsCarta = {
        roubarUids = mapaRoubo and mapaRoubo[carta.uid] or nil,
        alvoIdx = alvoIdxCarta or alvoIdx,
      }
      if defesaDe then optsCarta.defesaDe = defesaDe end
      local res = jogo.aplicarCarta(partida, 1, carta, optsCarta)
      entradas[#entradas + 1] = novaEntrada(res, carta)
      ress[#ress + 1] = res
      if res.chainTexto then
        util.adicionarPopup(res.chainTexto .. "!", CENTRO, VH * 0.40,
          ui.C.OURO, ui.E(18))
      end
      aplicadas = aplicadas + 1
      if partida.fim then break end
    end
  end

  -- 2) Zoom único com todas as cartas; as saídas voam quando ele fechar.
  saidaAntes = antes
  ui._saidaSnap = snap
  ui._saidaRess = ress
  if #entradas == 0 then
    fimSaida()
    return
  end
  resultado = novoResultadoLote(entradas)
  if redeModo == "host" then enviarCartaJogada(entradas) end
  if partida.fim then
    filaSaida = nil
    if redeModo == "host" then transmitirSnapshot() end
    popupsSaldo(antes)
    tela = "fim"
  else
    filaSaida = saidas
  end
end

-- Cliente em rede: manda a leva escolhida ao host (usado pelo botao e pelos
-- atalhos de teclado do modal do roubo).
local function enviarJogarCliente(cartasSel, mapaRoubo, alvoIdx, mapaAlvos)
  local uids = {}
  for _, c in ipairs(cartasSel) do uids[#uids + 1] = c.uid end
  local msg = { tipo = "JOGAR", uids = uids }
  if mapaRoubo then msg.roubo = mapaRoubo end
  if alvoIdx then msg.alvo = alvoIdx end
  if mapaAlvos then msg.alvos = mapaAlvos end
  selUids = {}
  envioPendente = true
  -- Alvo escolhido ja vai na mensagem; o modo alvo local termina aqui.
  ui._alvoModo = nil
  ui._alvoCartaIdx = nil
  ui._alvoMapa = nil
  mult:enviarParaServidor(msg)
end

local function jogarSelecao()
  if not podeAgirAgora() or #selUids == 0 then
    -- Recusa visual: tremor das cartas + hit-stop leve, sem alterar regras.
    ui._recusaT0 = love.timer.getTime()
    ui._fx.bater(0.3)
    return
  end
  -- Em modo alvo, a aplicacao so acontece depois que o jogador clica na
  -- area de alvo da carta (o antigo botao JOGAR foi removido).
  if ui._alvoModo then return end
  local j = partida.jogadores[1]
  local cartasSel, vigarice = {}, nil
  for _, uid in ipairs(selUids) do
    for _, c in ipairs(j.mao) do
      if c.uid == uid then
        cartasSel[#cartasSel + 1] = c
        if c.efeito and c.efeito.tipo == "ROUBA_CARTAS" and not vigarice then
          vigarice = c
        end
      end
    end
  end
  if #cartasSel == 0 then
    selUids = {}
    return
  end

  -- Cliente em rede: NAO aplica nada aqui — manda intencao ao host.
  if redeModo == "cliente" then
    if vigarice then
      -- Roubo às cegas: pede a mao real do alvo; o modal abre quando a
      -- resposta MAO chegar (no 1v1 tem um so alvo; chips de troca vem
      -- na Fase 3, quando for preciso pedir MAO de novo por chip).
      local n = #partida.jogadores
      local alvos = {}
      for i = 2, n do
        local alvo = partida.jogadores[i]
        if not alvo.falido and #alvo.mao > 0 then
          alvos[#alvos + 1] = {
            idx = partidaRede.paraEng(n, mult:estado().meuAssento, i),
            nome = alvo.nome, mao = alvo.mao,
          }
        end
      end
      if #alvos > 0 then
        pendVigarice = {
          cartas = cartasSel, uidCarta = vigarice.uid,
          quantidade = vigarice.efeito.quantidade or 2,
          alvos = alvos,
        }
        envioPendente = true
        mult:enviarParaServidor({ tipo = "PEDIR_MAO", alvo = alvos[1].idx })
        return
      end
    end
    enviarJogarCliente(cartasSel, nil, nil, ui._alvoMapa)
    return
  end

  -- Roubo às cegas: abre o modal ANTES de jogar (handleJogarMao do React);
  -- cancelar mantém as cartas selecionadas. Modo ARENA lista todos os
  -- oponentes vivos com mao (trocarAlvo do ModalRouboCego).
  if vigarice then
    local alvos = {}
    for i = 2, #partida.jogadores do
      local alvo = partida.jogadores[i]
      if not alvo.falido and #alvo.mao > 0 then
        alvos[#alvos + 1] = { idx = i, nome = alvo.nome, mao = alvo.mao }
      end
    end
    if #alvos > 0 then
      modalRoubo = {
        cartas = cartasSel,
        uidCarta = vigarice.uid,
        quantidade = vigarice.efeito.quantidade or 2,
        alvos = alvos,
        alvoSel = 1,
        mao = alvos[1].mao,
        nome = alvos[1].nome,
        sel = {},
      }
      -- O modal define o alvo do roubo; encerra o modo alvo da mao.
      ui._alvoModo = nil
      ui._alvoCartaIdx = nil
      ui._alvoMapa = nil
      return
    end
  end
  executarLote(cartasSel, nil, nil, ui._alvoMapa)
  ui._alvoModo = nil
  ui._alvoCartaIdx = nil
  ui._alvoMapa = nil
end

local function guardarSelecionada()
  if not podeAgirAgora() or #selUids == 0 then
    -- Recusa visual: tremor das cartas + hit-stop leve, sem alterar regras.
    ui._recusaT0 = love.timer.getTime()
    ui._fx.bater(0.3)
    return
  end
  local uid = selUids[1]
  if #partida.jogadores[1].areaSegura >= jogo.AREA_SEGURA_MAX then
    -- Area Segura cheia (3): nao guarda nem perde a selecao.
    return
  end
  -- Guardar tambem encerra o modo alvo local (fluxo de clique por area).
  selUids = {}
  ui._alvoModo = nil
  ui._alvoCartaIdx = nil
  ui._alvoMapa = nil
  som.tocar("guardar")
  if redeModo == "cliente" then
    envioPendente = true
    mult:enviarParaServidor({ tipo = "GUARDAR", uid = uid })
    return
  end
  if not jogo.colocarAreaSegura(partida, 1, uid) then return end
  if redeModo == "host" then transmitirSnapshot() end
end

-- USAR da Área Segura: funciona até fora do turno (handleJogarAreaSegura).
local function usarAreaSegura()
  if not batalhaIniciada or pausado or modalRoubo or voo or resultado
      or filaSaida or not partida or partida.fim then
    return
  end
  local uid = selAreaUid
  if not uid then return end
  selAreaUid = nil
  if redeModo == "cliente" then
    if not envioPendente then
      envioPendente = true
      mult:enviarParaServidor({ tipo = "USAR_AREA", uid = uid })
    end
    return
  end
  local antes = snapshotSaldos()
  local res = jogo.jogarAreaSegura(partida, 1, uid)
  if not res then return end
  if redeModo == "host" then
    enviarCartaJogada({ novaEntrada(res) })
    transmitirSnapshot()
  end
  popupsSaldo(antes)
  resultado = novoResultado(res)
  if partida.fim then tela = "fim" end
end

local function passarJogador()
  if not partida or not batalhaIniciada or partida.fim then return end
  if fase ~= "JOGADOR" or voo or resultado or filaSaida or modalRoubo
      or pausado then
    return
  end
  selUids = {}
  selAreaUid = nil
  pressPanel = nil
  -- Som do PASSAR explicito: o timeout ja toca o "tempo" (expirado) e o
  -- passo automatico do eliminado nao precisa de aviso.
  if not tempo.expirado and not partida.jogadores[1].falido then
    som.tocar("passar")
  end
  if redeModo == "cliente" then
    if not envioPendente then
      envioPendente = true
      mult:enviarParaServidor({ tipo = "PASSAR" })
    end
    return
  end
  local antes = snapshotSaldos()
  jogo.passar(partida, 1)
  if redeModo == "host" then transmitirSnapshot() end
  popupsSaldo(antes)
  if partida.fim then
    tela = "fim"
  else
    proximaFase()
  end
end

-- Contagem regressiva do turno humano: pausa durante voo/resultado/pausa/
-- modal/leva, só roda depois da animação de início (batalhaIniciada), reseta
-- a cada turno (chave vez_turno) e, ao esgotar, passa a vez — mesma regra
-- do useTimerTurno + handleTempoEsgotado do React. No modo um jogador nao
-- ha contagem para o humano: sem decremento e sem expiracao (só em rede).
local function atualizarTempoTurno(dt)
  -- Local: so o meu turno. Em rede, o host tambem conta o turno dos
  -- clientes (auto-pass por expiracao, igual a IA) — o relogio do cliente
  -- e apenas visual e reseta a cada snapshot.
  local turnoHostRede = redeModo == "host" and fase == "REDE"
  local ativo = tela == "jogo" and (fase == "JOGADOR" or turnoHostRede)
    and not partida.fim and batalhaIniciada
  local duracao = jogo.duracaoTurno(partida.jogadores[partida.vez])
  local chave = partida.vez .. "_" .. partida.turno

  if not ativo or tempo.chave ~= chave or tempo.duracao ~= duracao then
    -- Sino da vez: so na transicao do RELOGIO para um turno meu (chave
    -- nova e anterior existente — o comeco da partida nao toca; uma
    -- duracao que muda no MEIO do turno reusa a mesma chave e nao repete).
    if ativo and fase == "JOGADOR" and tempo.chave ~= nil
        and tempo.chave ~= chave and not partida.jogadores[1].falido then
      som.tocar("turno")
    end
    tempo.chave = chave
    tempo.duracao = duracao
    tempo.restante = duracao
    -- Captura: mostra o relogio ja na faixa de aviso para a cena do tempo.
    local iniTemp = tonumber(os.getenv("JOGO_TEMPO_INICIAL"))
    if ativo and iniTemp and iniTemp > 0 then
      tempo.restante = math.min(duracao, iniTemp)
    end
    tempo.expirado = false
  end

  local pausadoT = pausado or voo ~= nil or resultado ~= nil
    or modalRoubo ~= nil or filaSaida ~= nil
  -- Modo um jogador (redeModo nil): o humano nao tem relogio — sem
  -- decremento nem expiracao, a vez so cai na acao explicita.
  if ativo and not pausadoT and not tempo.expirado
      and (redeModo or os.getenv("JOGO_TEMPO_VISIVEL") ~= nil) then
    tempo.restante = tempo.restante - dt
    if tempo.restante <= 0 then
      tempo.restante = 0
      tempo.expirado = true
      -- Bipe so quando a MINHA vez expira (eu que perco o turno); o host
      -- contando o turno do cliente nao avisa aqui.
      if fase == "JOGADOR" then som.tocar("tempo") end
      if turnoHostRede then
        -- Turno do cliente: o host auto-passa (o motor e dele).
        processarAcaoRemota(partida.vez, { tipo = "PASSAR" })
      elseif redeModo == "cliente" then
        -- So avisa o host; quem passa de verdade e o motor dele.
        if not envioPendente then
          envioPendente = true
          mult:enviarParaServidor({ tipo = "PASSAR" })
        end
      else
        passarJogador()
      end
      return
    end
  end

  -- Fade do aviso (aparece com 10s ou menos, some ao trocar de turno).
  local alvo = (ativo and tempo.restante <= AVISO_SEGUNDOS) and 1 or 0
  local vel = dt / 0.35
  if tempo.aviso < alvo then
    tempo.aviso = math.min(alvo, tempo.aviso + vel)
  elseif tempo.aviso > alvo then
    tempo.aviso = math.max(alvo, tempo.aviso - vel)
  end
end

-- Sequência da IA (useIA.js): reação -> até 2 cartas (800ms entre elas)
-- -> comprar (+600ms) -> descartar 1 aleatória (+500ms) -> fim (+500ms),
-- com fimDeTurno comprando mais 1 (paridade com o React).
local function iaMaquina(dt)
  if not iaEstado or not batalhaIniciada or introBatAtiva then return end
  if fase ~= "IA" or pausado or voo or resultado or modalRoubo or filaSaida
      or qc.ativo or qc.pendente then return end
  if not partida or partida.fim then return end

  iaEstado.t = iaEstado.t - dt
  if iaEstado.t > 0 then return end

  local vez = partida.vez
  local ia = partida.jogadores[vez]
  if iaEstado.passo == "espera" then
    -- Puxa a carta guardada na Area Segura (nao consome quota do turno).
    if not ia.falido and ia.areaSegura[1] then
      local antes = snapshotSaldos()
      local res = jogo.jogarAreaSegura(partida, vez, ia.areaSegura[1].uid)
      if res then
        if redeModo == "host" then
          enviarCartaJogada({ novaEntrada(res) })
          transmitirSnapshot()
        end
        popupsSaldo(antes)
        resultado = novoResultado(res)
        if partida.fim then
          iaEstado = nil
          tela = "fim"
          return
        end
      end
    end
    iaEstado.passo = "guardar"
    iaEstado.t = IA_PASSO or 0.5
  elseif iaEstado.passo == "guardar" then
    -- Guarda uma carta na Area Segura (com chance) para puxar no prox turno.
    -- No ciclo a chance sobe com o inimigo (0.1 no primeiro ate 0.7 no
    -- chefe); na rede a dificuldade escolhida na sala (partida.difIA)
    -- manda (0.1 facil ate 0.65 dificil).
    local cfg = (ui._cicloDuelo and selecao.dueloAtual()) or partida.difIA
    if not ia.falido and love.math.random()
        < (cfg and cfg.guarda or IA_GUARDA_CHANCE) then
      local uid = jogo.iaGuardarCarta(partida, vez)
      if uid then
        jogo.colocarAreaSegura(partida, vez, uid)
        if redeModo == "host" then transmitirSnapshot() end
      end
    end
    iaEstado.passo = "jogar"
    iaEstado.t = IA_PASSO or 0.3
  elseif iaEstado.passo == "jogar" then
    local idx = nil
    if jogo.jogadasRestantes(partida, vez) > 0 and not ia.falido and #ia.mao > 0 then
      -- No ciclo a IA escolhe com um "modo fraco": no primeiro inimigo ela
      -- as vezes nem joga ou pega uma carta qualquer; no chefe e segura.
      -- Na rede o mesmo modelo vem de partida.difIA (dificuldade da sala).
      local cfg = (ui._cicloDuelo and selecao.dueloAtual()) or partida.difIA
      if not cfg or love.math.random() <= cfg.chanceJogar then
        idx = jogo.jogadaIA(partida, vez)
        if cfg and idx and love.math.random() > cfg.chanceMelhor then
          idx = love.math.random(#ia.mao)
        end
      end
    end
    if idx then
      iaEstado.jogadas = iaEstado.jogadas + 1
      iaEstado.passo = "jogar"
      iaEstado.t = IA_PASSO or 0.8
      local carta = table.remove(ia.mao, idx)
      local antes = snapshotSaldos()
      local origem = { x = CENTRO - DECK_DW / 2, y = OP_MAO_Y + ui.E(10), e = 0.6 }
      if ehMesa() then
        local p = posSlot(vez)
        origem = { x = p.cx - DECK_DW / 2, y = p.cy - DECK_DH / 2, e = 0.6 }
      end
      iniciarVoo(vez, carta, origem, function(res)
        -- Host em rede: o zoom da IA vai no mesmo formato do humano
        -- (CARTA_JOGADA) e o snapshot fecha o estado ja aplicado — ANTES
        -- dos popups, que zeram partida.evento (mesmo criterio do fimSaida).
        if redeModo == "host" then
          enviarCartaJogada(res.entradasReacao or { novaEntrada(res, carta) })
          transmitirSnapshot()
        end
        popupsSaldo(antes)
        if partida.fim then
          iaEstado = nil
          tela = "fim"
        end
      end)
      return
    end
    iaEstado.passo = "comprar"
    iaEstado.t = IA_PASSO or 0.6
  elseif iaEstado.passo == "comprar" then
    jogo.comprar(partida, ia)
    if redeModo == "host" then transmitirSnapshot() end
    iaEstado.passo = "descartar"
    iaEstado.t = IA_PASSO or 0.5
  elseif iaEstado.passo == "descartar" then
    if not ia.falido and #ia.mao > 0 then
      local c = table.remove(ia.mao, love.math.random(#ia.mao))
      table.insert(partida.pilhaDescarte, c)
      table.insert(partida.log, ia.nome .. " descartou " .. c.nome)
      if redeModo == "host" then transmitirSnapshot() end
    end
    iaEstado.passo = "fim"
    iaEstado.t = IA_PASSO or 0.5
  elseif iaEstado.passo == "fim" then
    iaEstado = nil
    local antes = snapshotSaldos()
    jogo.encerrarVez(partida)
    if redeModo == "host" then transmitirSnapshot() end
    popupsSaldo(antes)
    if partida.fim then
      tela = "fim"
    else
      proximaFase()
    end
  end
end

-- LAYOUT DO OPONENTE --------------------------------------------------------

local function layoutOponente(n)
  if n == 0 then return {} end
  local passo = math.min(ui.E(22) + BW * 0.25, BW * 0.75)
  if n == 1 then passo = 0 end
  local total = BW + passo * (n - 1)
  local inicio = CENTRO - total / 2
  local lista = {}
  local meio = (n + 1) / 2
  for i = 1, n do
    local norm = n > 1 and (i - meio) / meio or 0
    table.insert(lista, {
      x = inicio + (i - 1) * passo,
      y = OP_MAO_Y + (math.abs(norm) ^ 1.3) * ui.E(4),
      w = BW, h = BH,
      rot = math.rad(norm * 6),
    })
  end
  return lista
end

-- ÁREA SEGURA (AreaSegura.js): agora são 3 slots em linha, encostados na
-- ponta da direita. A própria fica no rodapé (y = VH-12-AREA_A) e a do
-- oponente no topo (abaixo do botão de pausa); em duelo as duas fileiras
-- aparecem ao mesmo tempo, uma em cima e outra embaixo.
-- O USAR sobe para cima do slot selecionado (embaixo não há espaço).
local function retAreaPropria(i)
  local passo = AREA_L + ui.E(4)
  local total = AREA_L * jogo.AREA_SEGURA_MAX + ui.E(4) * (jogo.AREA_SEGURA_MAX - 1)
  return {
    x = VW - ui.E(12) - total + ((i or 1) - 1) * passo,
    y = VH - ui.E(12) - AREA_A,
    w = AREA_L, h = AREA_A,
  }
end

local function retAreaUsar(slot)
  return {
    x = slot.x + (slot.w - AREA_USAR.w) / 2,
    y = slot.y - AREA_USAR.h - ui.E(4),
    w = AREA_USAR.w, h = AREA_USAR.h,
  }
end

-- Slot unico de Defesa: centralizado acima dos 3 slots da Area Segura.
-- Mesma geometria usada pelo desenho (meta.desenharPilhas). Dentro de qc
-- porque o main esta no limite de 200 locals do LuaJIT.
qc.retSlot = function()
  local s1, s3 = retAreaPropria(1), retAreaPropria(3)
  local w, h = ui.E(46), ui.E(64)
  return {
    x = (s1.x + s3.x + s3.w - w) / 2,
    y = s1.y - h - ui.E(22),
    w = w, h = h,
  }
end

local function retAreaOponente(i)
  local passo = AREA_L + ui.E(4)
  local total = AREA_L * jogo.AREA_SEGURA_MAX + ui.E(4) * (jogo.AREA_SEGURA_MAX - 1)
  return {
    x = VW - ui.E(12) - total + ((i or 1) - 1) * passo,
    y = ui.E(60),
    w = AREA_L, h = AREA_A,
  }
end

-- ZOOM (CartaZoomModal.js) --------------------------------------------------
-- Long-press de 250ms na mão ou na carta da área própria abre o zoom; o
-- clique curto só dispara no release (Pressable do React).
local function cartaZoomavel(vx, vy)
  if tela ~= "jogo" or not partida or not batalhaIniciada then return nil end
  if pausado or modalRoubo or introBatAtiva then return nil end
  if ui._meta and ui._meta.ativo() then return nil end
  local j = partida.jogadores[1]
  for i = 1, jogo.AREA_SEGURA_MAX do
    if ui.dentro(vx, vy, retAreaPropria(i)) then
      local c = j.areaSegura[i]
      if c then return c end
      -- slot vazio: o toque atravessa, como no React
    end
  end
  for i = 1, jogo.AREA_SEGURA_MAX do
    local c = j.areaSegura[i]
    if c and c.uid == selAreaUid
        and ui.dentro(vx, vy, retAreaUsar(retAreaPropria(i))) then
      return nil
    end
  end
  for i = #rectsMao, 1, -1 do
    local r = rectsMao[i]
    if ui.pontoNaCarta(vx, vy, r) then
      return partida.jogadores[1].mao[r.idx]
    end
  end
  return nil
end

local function acharCartaZoom(uid)
  if not partida then return nil end
  for _, m in ipairs(partida.jogadores[1].mao) do
    if m.uid == uid then return m end
  end
  for _, a in ipairs(partida.jogadores[1].areaSegura) do
    if a.uid == uid then return a end
  end
  return nil
end

-- ARRASTO DA MÃO (reorganizar) --------------------------------------------
-- Pressão numa carta da mão + movimento além de ui.E(10) vira arrasto: a
-- carta segue o ponteiro, as demais compactam e um marcador dourado mostra
-- onde ela vai cair. A ordem da mao é só visual — a engine não muda.

local function iniciarArrasto(hx, hy)
  if not pressCarta then return false end
  local de = nil
  local mao = partida and partida.jogadores[1] and partida.jogadores[1].mao
  if mao then
    for i, c in ipairs(mao) do
      if c.uid == pressCarta.uid then de = i break end
    end
  end
  -- layoutMao direto: rectsMao pode estar vazio/stale (ex.: no love.load,
  -- antes do primeiro desenho).
  local r = de and mao and layoutMao(#mao)[de]
  if not r then
    pressCarta = nil
    return false
  end
  arrasto = {
    uid = pressCarta.uid,
    de = de,
    x = hx, y = hy,
    dx = (r.x + r.w / 2) - hx,
    dy = (r.y + r.h / 2) - hy,
    alvo = de,
  }
  pressCarta = nil
  return true
end

-- Índice de solta: menor slot (do layout SEM a carta arrastada) à direita
-- do cursor; passou do último = vai para o fim da mão.
local function atualizarAlvoArrasto()
  if not arrasto then return end
  local mao = partida and partida.jogadores[1] and partida.jogadores[1].mao
  if not mao then return end
  local n = #mao
  if n <= 1 then arrasto.alvo = 1 return end
  local rets = layoutMao(n - 1)
  local cx = arrasto.x + arrasto.dx
  local alvo = n
  for j = 1, #rets do
    if cx <= rets[j].x + rets[j].w / 2 then alvo = j break end
  end
  arrasto.alvo = alvo
end

local function moverArrasto(hx, hy)
  if not arrasto then return end
  arrasto.x, arrasto.y = hx, hy
  atualizarAlvoArrasto()
end

local function soltarArrasto()
  if not arrasto then return end
  local a = arrasto
  arrasto = nil
  local mao = partida and partida.jogadores[1] and partida.jogadores[1].mao
  if not mao then return end
  local n = #mao
  local de = math.max(1, math.min(a.de, n))
  local k = math.max(1, math.min(a.alvo or de, n))
  if de == k then return end
  local c = table.remove(mao, de)
  table.insert(mao, k, c)
end

-- INPUT --------------------------------------------------------------------

-- Modal do roubo às cegas: cartas viradas, CANCELAR, ROUBAR e (ARENA) chips
-- para trocar de alvo (trocarAlvo do ModalRouboCego).
local function clicadoModalRoubo(vx, vy)
  if not modalRoubo or not modalRects then return end
  for _, r in ipairs(modalRects.cartas) do
    if ui.dentro(vx, vy, r) then
      local sel = modalRoubo.sel
      for i, u in ipairs(sel) do
        if u == r.uid then
          table.remove(sel, i)
          return
        end
      end
      if #sel < modalRoubo.quantidade then
        sel[#sel + 1] = r.uid
      end
      return
    end
  end
  if modalRects.alvos then
    for _, r in ipairs(modalRects.alvos) do
      if ui.dentro(vx, vy, r) then
        modalRoubo.alvoSel = r.idx
        modalRoubo.nome = modalRoubo.alvos[r.idx].nome
        modalRoubo.sel = {}
        if redeModo == "cliente" then
          -- Fase 3: a mao do novo alvo nao veio no primeiro PEDIR_MAO —
          -- pede de novo e mostra o aviso ate a resposta (sem cartas na
          -- tela o botao ROUBAR fica travado por #sel == 0).
          modalRoubo.mao = {}
          modalRoubo.texto = "PEDINDO A MAO DO OPONENTE..."
          mult:enviarParaServidor({ tipo = "PEDIR_MAO",
            alvo = modalRoubo.alvos[r.idx].idx })
        else
          modalRoubo.mao = modalRoubo.alvos[r.idx].mao
        end
        return
      end
    end
  end
  if modalRects.cancelar and ui.dentro(vx, vy, modalRects.cancelar) then
    modalRoubo = nil
    modalRects = nil
    return
  end
  if modalRects.confirmar and ui.dentro(vx, vy, modalRects.confirmar)
      and #modalRoubo.sel > 0 then
    local pend = modalRoubo
    modalRoubo = nil
    modalRects = nil
    if redeModo == "cliente" then
      enviarJogarCliente(pend.cartas, { [pend.uidCarta] = pend.sel },
        pend.alvos[pend.alvoSel].idx)
    else
      executarLote(pend.cartas, { [pend.uidCarta] = pend.sel },
        pend.alvos[pend.alvoSel].idx)
    end
  end
end

-- AREA DE ALVO ------------------------------------------------------------

-- Retorna o retangulo de alvo para o tipo dado (oponente / todos / voce).
-- Calculado inline nos chamantes para economizar locais do chunk principal.
local function areaAlvo(tipo, cx, opY, painelX, painelY, painelW, painelH,
                        deckCW, deckDW, deckDH, decksY)
  if tipo == "oponente" then
    return { x = cx - ui.E(65) - ui.E(10), y = opY - ui.E(10),
      w = ui.E(130) + ui.E(20), h = ui.E(34) + ui.E(20) }
  elseif tipo == "todos" then
    if ehMesa() then
      -- Arena: area clicavel do descarte na mesa central.
      local mw, mh = ui.E(34), ui.E(48)
      local mx2 = MESA_X + ui.E(10) / 2
      local my = MESA_Y - mh / 2 + ui.E(10)
      return { x = mx2 - ui.E(8), y = my - ui.E(8),
        w = mw + ui.E(16), h = mh + ui.E(16) }
    end
    local dx = cx + (deckCW + ui.E(21)) / 2
    return { x = dx, y = decksY, w = deckDW, h = deckDH }
  elseif tipo == "voce" then
    return { x = painelX - ui.E(10), y = painelY - ui.E(10),
      w = painelW + ui.E(20), h = painelH + ui.E(20) }
  end
  return nil
end

-- ARMAR DEFESA: com uma carta de Defesa selecionada, o clique no Slot de
-- Defesa a move para o slot (sem quota, sem dado, sem cadeia). A defesa so
-- entra em acao quando o dono escolhe DEFENDER na janela do Quick Counter.
qc.armar = function()
  if not podeAgirAgora() then return end
  local uid = selUids[1]
  if not uid then return end
  local carta = nil
  for _, c in ipairs(partida.jogadores[1].mao) do
    if c.uid == uid then carta = c break end
  end
  if not carta or not jogo.ehDefesa(carta) then return end
  selUids = {}
  ui._alvoModo = nil
  ui._alvoCartaIdx = nil
  ui._alvoMapa = nil
  if redeModo == "cliente" then
    if not envioPendente then
      envioPendente = true
      mult:enviarParaServidor({ tipo = "ARMAR_DEFESA", uid = uid })
    end
    return
  end
  local res = jogo.armarDefesa(partida, 1, uid)
  if not res then return end
  som.tocar("guardar")
  if redeModo == "host" then transmitirSnapshot() end
  util.adicionarPopup(ui.tr("DEFESA ARMADA"), CENTRO, VH * 0.36,
    ui.C.SUCESSO, ui.E(15))
end

-- Processa um clique enquanto esta no modo alvo. Devolve true se consumiu.
-- Fluxo novo: cada clique de area aplica UMA carta imediatamente.
local function processarCliqueAlvo(vx, vy)
  if not ui._alvoModo or not ui._alvoCartaIdx or not ui._alvoMapa then
    return false
  end
  local uid = selUids[1]
  if not uid then return false end

  local carta = nil
  for _, c in ipairs(partida.jogadores[1].mao) do
    if c.uid == uid then carta = c break end
  end
  if not carta then return false end

  local tipo = ui.areaDaCarta(carta)
  local escolhido, idxEscolhido = nil, nil

  local aOpo = areaAlvo("oponente", CENTRO, OP_PAINEL_Y,
    PAINEL_RECT.x, PAINEL_RECT.y, PAINEL_RECT.w, PAINEL_RECT.h,
    DECK_CW, DECK_DW, DECK_DH, DECKS_Y)
  local aTodos = areaAlvo("todos", CENTRO, OP_PAINEL_Y,
    PAINEL_RECT.x, PAINEL_RECT.y, PAINEL_RECT.w, PAINEL_RECT.h,
    DECK_CW, DECK_DW, DECK_DH, DECKS_Y)
  local aVoce = areaAlvo("voce", CENTRO, OP_PAINEL_Y,
    PAINEL_RECT.x, PAINEL_RECT.y, PAINEL_RECT.w, PAINEL_RECT.h,
    DECK_CW, DECK_DW, DECK_DH, DECKS_Y)

  -- Retorna o assento do oponente clicado (arena: cada slot; duelo: painel).
  local function oponenteEm(px, py)
    if ehMesa() then
      for i = 2, #partida.jogadores do
        if not partida.jogadores[i].saiu
            and ui.dentro(px, py, rectSlotAlvo(i)) then
          return i
        end
      end
      return nil
    end
    if ui.dentro(px, py, aOpo) then return 2 end
    return nil
  end

  if tipo == "descarte" or tipo == "todos" then
    if ui.dentro(vx, vy, aTodos) then escolhido = tipo end
  elseif tipo == "voce" then
    if ui.dentro(vx, vy, aVoce) then escolhido = "voce" end
  elseif tipo == "oponente" then
    local i = oponenteEm(vx, vy)
    if i then escolhido, idxEscolhido = "oponente", i end
  elseif tipo == "voceOuOponente" then
    if ui.dentro(vx, vy, aVoce) then
      escolhido = "voce"
    else
      local i = oponenteEm(vx, vy)
      if i then escolhido, idxEscolhido = "oponente", i end
    end
  end

  if not escolhido then return false end

  ui._alvoMapa[uid] = {
    tipo = escolhido,
    idx = idxEscolhido or ui.alvoIdxDeTipo(escolhido),
  }

  -- Sai do modo alvo e usa o caminho normal de jogada (local ou cliente de
  -- rede, com o mapa de alvos). Uma carta por vez.
  ui._alvoModo = nil
  ui._alvoCartaIdx = nil
  jogarSelecao()
  return true
end

local function clicado(vx, vy)
  -- Tela de VS aberta: o clique avanca a cena (antes do impacto salta
  -- para ele; depois dele encerra e o duelo abre).
  if ui._vs.ativo() then
    ui._vs.clique()
    return
  end
  -- Dialogo do chefe aberto: clique fora do botao PULAR avanca a cena (o
  -- ultimo clique dispara o aoFim, que la dentro abre o duelo de verdade).
  if ui._dlg.ativo() then
    ui._dlg.clique(vx, vy)
    return
  end

  if tela == "tutorial" then
    local acao = tut.clicado(vx, vy)
    if acao == "jogar" then
      tut.liberar()
      iniciarJogo()
    elseif acao == "menu" then
      tut.liberar()
      tela = "menu"
    end
    return
  end

  if tela == "selecao" then
    local acao = selecao.clicado(vx, vy)
    if acao == "voltar" then
      tela = "menu"
    elseif acao == "iniciar" then
      -- Tela de VS antes do duelo (jogador a esquerda, inimigo a direita);
      -- o no com `dialogo` (Adam) ainda passa pela conversa de abertura
      -- antes da VS. Mesmo caminho do PROXIMO OPONENTE do painel de fim.
      ui.abrirVS(selecao.dueloAtual(), perfilJogador.nick,
        perfilJogador.avatar, function() iniciarJogo(nil, { ciclo = true }) end)
    end
    return
  end

  if tela == "perfil" then
    local acao = perfilMod.clicado(vx, vy)
    if acao == "voltar" then
      tela = "menu"
    elseif acao == "confirmar" then
      perfilJogador = perfilMod.confirmar()
      arte.definirAvatar(perfilJogador.avatar)
      perfilMod.salvar(perfilJogador)
      tela = "menu"
    end
    return
  end

  if tela == "sobre" then
    local acao = ui._sobre.clicado(vx, vy)
    -- "site" ainda nao tem link: so o botao VOLTAR fecha a tela.
    if acao == "voltar" then tela = "menu" end
    return
  end

  if tela == "intro" then
    tela = "logo"
    logoT = 0
    return
  end

  if tela == "arena_menu" then
    local acao = arenaMenu.clicado(vx, vy)
    if acao == "fechar" then
      ui._simMenuAberto = nil
      tela = "menu"
    elseif type(acao) == "number" then
      local sim = ui._simMenuAberto
      ui._simMenuAberto = nil
      iniciarJogo(acao, sim and { simulacao = true } or nil)
    end
    return
  end

  if tela == "multiplayer" then
    local acao = mult and mult:clicado(vx, vy) or nil
    if acao == "menu" then
      if mult then mult:fechar() end
      tela = "menu"
    elseif acao == "iniciar" then
      if not iniciarPartidaRede() then
        util.adicionarPopup("ESPERE O SEGUNDO JOGADOR", CENTRO, VH * 0.5,
          ui.C.OURO, ui.E(20))
      end
    end
    return
  end

  if tela == "logo" then
    tela = "menu"
    return
  end

  if tela == "menu" then
    -- Avatar no canto superior direito abre a tela de perfil (TelaInicial).
    local rPerf = ui.rectPerfilMenu(VW, VH)
    if ui.dentro(vx, vy, rPerf) then
      perfilMod.iniciar(perfilJogador)
      if love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(true)
      end
      tela = "perfil"
      return
    end
    local itens = layoutMenu()
    for _, item in ipairs(itens) do
      if ui.dentro(vx, vy, item) then
        if item.acao == "jogar" then
          selecao.iniciar()
          tela = "selecao"
        elseif item.acao == "multiplayer" then
          mult = multiplayer.novo()
          mult:iniciar(perfilJogador)
          tela = "multiplayer"
        elseif item.acao == "simular" then
          -- Reusa o seletor de 2..8 da arena; a flag decide, no clique do
          -- numero, que a partida inteira sera controlada pela IA.
          ui._simMenuAberto = true
          arenaMenu.iniciar("SIMULAR PARTIDA")
          tela = "arena_menu"
        elseif item.acao == "anim_teste" then
          local animTeste = require "anim_teste"
          animTeste.iniciar(perfilJogador)
          tela = "anim_teste"
        elseif item.acao == "loja" then
          ui._lojaMsg = nil
          ui._lojaAnimInicio = nil -- preview do emoji anima de novo ao entrar
          ui._lojaAba = "avatares" -- abre na secao de avatares
          ui._lojaAvatarSel = nil
          tela = "loja"
        elseif item.acao == "config" then
          ui._config.abrir()
          tela = "config"
        elseif item.acao == "sobre" then
          ui._sobre.abrir()
          tela = "sobre"
        elseif item.acao == "sair" then
          love.event.quit()
        else
          util.adicionarPopup("EM BREVE", CENTRO, VH * 0.5, ui.C.OURO, ui.E(24))
        end
        return
      end
    end
    return
  end

  if tela == "config" then
    if ui._config.clicado(vx, vy) == "voltar" then
      tela = "menu"
    end
    return
  end

  if tela == "loja" then
    -- Abas da loja (secoes): troca o conteudo visivel; limpa mensagem,
    -- selecao e ancora do preview (emoji repete ao entrar na aba).
    for _, ab in ipairs(ui.rectsLojaAbas(VW, VH)) do
      if ui.dentro(vx, vy, ab) then
        if ui._lojaAba ~= ab.id then
          ui._lojaAba = ab.id
          ui._lojaMsg = nil
          ui._lojaAvatarSel = nil
          ui._lojaAnimInicio = nil
        end
        return
      end
    end
    -- Compra pelo botao do card (dentro do card, testado primeiro) e
    -- selecao pelo corpo do card (so na aba de avatares: abre o painel
    -- de habilidade/teorico). Comprado so avisa, sem mexer no dinheiro.
    for _, pr in ipairs(ui.rectsLoja(VW, VH)) do
      if ui.dentro(vx, vy, pr.btn) then
        if pr.comprado then
          ui._lojaMsg = { texto = pr.nome .. " " .. ui.tr("JA E SEU"), ok = true }
        elseif ui._inv.comprar(pr.id) then
          ui._lojaMsg = { texto = pr.nome .. " " .. ui.tr("COMPRADO!"), ok = true }
        else
          ui._lojaMsg = { texto = "DINHEIRO INSUFICIENTE", ok = false }
        end
        return
      end
      if pr.tipo == "avatar" and ui.dentro(vx, vy, pr) then
        ui._lojaAvatarSel = pr.id
        ui._lojaMsg = nil
        return
      end
    end
    if ui.dentro(vx, vy, ui.rectVoltarLoja(VW, VH)) then
      tela = "menu"
    end
    return
  end

  if tela == "fim" then
    -- So aceita clique depois que a animacao de entrada assenta: com o
    -- painel em escala, a area clicavel ainda nao bate com o desenho.
    if (ui._fimT or 1) < ui.FIM_ANIM then return end
    local dFim = dadosFim()
    local gFim = ui.geomFim(VW, VH, dFim.placares and #dFim.placares or 0,
      dFim.temProximo)
    -- PROXIMO OPONENTE: leva direto ao no recem-liberado (mesmo caminho da
    -- roda: a selecao fica atras, a VS - e a conversa do Adam - na frente).
    if gFim.btnProx and ui.dentro(vx, vy, gFim.btnProx) then
      local cfgProx = selecao.proximoNo()
      if cfgProx then
        tela = "selecao"
        ui.abrirVS(cfgProx, perfilJogador.nick, perfilJogador.avatar,
          function() iniciarJogo(nil, { ciclo = true }) end)
      end
      return
    end
    if ui.dentro(vx, vy, gFim.btnNovo) then
      if redeModo then
        -- Em rede nao da pra reiniciar sozinho: volta e cria outra sala.
        util.adicionarPopup("EM REDE: VOLTE E CRIE NOVA SALA", CENTRO, VH * 0.5,
          ui.C.OURO, ui.E(20))
      else
        -- No ciclo, JOGAR NOVAMENTE repete o MESMO inimigo. Na simulacao,
        -- repete a mesa com a mesma quantidade de jogadores, tudo em IA.
        iniciarJogo(arenaN,
          (partida and partida.simulacao) and { simulacao = true }
          or (ui._cicloDuelo and { ciclo = true } or nil))
      end
    end
    if ui.dentro(vx, vy, gFim.btnMenu) then
      if redeModo then
        sairPartidaRede()
      else
        -- No ciclo o "menu" volta para a roda do ciclo em andamento.
        tela = ui._cicloDuelo and "selecao" or "menu"
      end
    end
    return
  end

  -- Modal do roubo às cegas fica por cima de tudo (Modal do React).
  if modalRoubo then
    clicadoModalRoubo(vx, vy)
    return
  end

  if pausado then
    local w, h = ui.E(360), ui.E(260)
    local x = (VW - w) / 2
    local y = (VH - h) / 2
    if ui.dentro(vx, vy, { x = x + w / 2 - ui.E(140), y = y + ui.E(100), w = ui.E(280), h = ui.E(54) }) then
      pausado = false
    elseif ui.dentro(vx, vy, { x = x + w / 2 - ui.E(140), y = y + ui.E(170), w = ui.E(280), h = ui.E(54) }) then
      pausado = false
      if redeModo then
        -- Sai da partida em rede: derruba a conexao (o outro lado ve o
        -- disconnect e tambem volta ao menu).
        sairPartidaRede("PARTIDA ENCERRADA")
      else
        tela = "menu"
      end
    end
    return
  end

  if ui.dentro(vx, vy, PAUSA) then
    pausado = true
    return
  end

  -- Animacao de inicio de batalha bloqueia os toques (pointerEvents auto).
  if introBatAtiva or not batalhaIniciada then return end

  -- Placa de turno clicavel: passa a vez (botao PASSAR desenhado nela).
  if tela == "jogo" and partida and not partida.fim and partida.vez == 1
      and ui._placaRect and ui._placaRect.passar
      and ui.dentro(vx, vy, ui._placaRect.passar) then
    passarJogador()
    return
  end

  -- Teste (duelo classico vs Adam Smith): vitoria direta dele para abrir a
  -- tela de derrota nova.
  if tela == "jogo" and not arenaN and not redeModo and not partida.fim
      and ui.dentro(vx, vy, BTN_ADAM_VENCE) then
    partida.fim = true
    partida.vencedor = partida.jogadores[2]
    tela = "fim"
    return
  end

  -- Teste (ciclo): vitoria DIRETA do jogador na hora - o hook de vitoria
  -- do love.update registra a marca e libera o proximo do caminho.
  if tela == "jogo" and not redeModo and not partida.fim
      and ui.dentro(vx, vy, BTN_ADAM_VENCE.voce) then
    partida.fim = true
    partida.vencedor = partida.jogadores[1]
    tela = "fim"
    return
  end

  -- Seletor de emoji (partida em rede): com ele aberto o clique escolhe
  -- um emoji ou fecha; sem ele, o clique no proprio painel abre.
  if emojiAberto then
    emo.clicadoPainelEmoji(vx, vy)
    return
  end
  if tela == "jogo" and redeModo and mult and partida and not partida.fim
      and not ui._alvoModo and ui.dentro(vx, vy, PAINEL_RECT) then
    emojiAberto = true
    return
  end

  local podeAgir = podeAgirAgora()
  local temSel = #selUids > 0

  -- Armar defesa: carta de Defesa selecionada + clique no Slot de Defesa.
  -- Prioridade sobre as areas porque o slot fica logo acima delas.
  if podeAgir and temSel then
    local selC = nil
    for _, c in ipairs(partida.jogadores[1].mao) do
      if c.uid == selUids[1] then selC = c break end
    end
    if selC and jogo.ehDefesa(selC)
        and ui.dentro(vx, vy, qc.retSlot()) then
      qc.armar()
      return
    end
  end

  -- Guardar na Área Segura: com uma carta da mão selecionada, clicar num
  -- slot vazio guarda a carta (substitui o antigo botão GUARDAR).
  if podeAgir and temSel then
    local jAreaG = partida.jogadores[1]
    for i = 1, jogo.AREA_SEGURA_MAX do
      if ui.dentro(vx, vy, retAreaPropria(i)) then
        if not jAreaG.areaSegura[i] then guardarSelecionada() end
        return
      end
    end
  end

  -- Modo alvo: o jogador clica na area do alvo para usar a carta selecionada.
  if ui._alvoModo then
    if processarCliqueAlvo(vx, vy) then return end
    -- Clicar em outra carta da mão cancela a selecao atual e re-seleciona.
    for i = #rectsMao, 1, -1 do
      local r = rectsMao[i]
      if ui.pontoNaCarta(vx, vy, r) then
        local carta = partida.jogadores[1].mao[r.idx]
        if carta then alternarSelecao(carta.uid) end
        return
      end
    end
    return
  end

  -- Área Segura própria: selecionar carta / USAR (funciona fora do turno).
  -- z26 > mão z25: a área recebe o toque antes das cartas (React).
  -- Slot vazio não é pressable no React: o toque atravessa para a mão.
  local jArea = partida.jogadores[1]
  for i = 1, jogo.AREA_SEGURA_MAX do
    if ui.dentro(vx, vy, retAreaPropria(i)) then
      local carta = jArea.areaSegura[i]
      if carta then
        if selAreaUid == carta.uid then
          selAreaUid = nil
        else
          selAreaUid = carta.uid
        end
        return
      end
    end
  end
  if selAreaUid then
    for i = 1, jogo.AREA_SEGURA_MAX do
      local c = jArea.areaSegura[i]
      if c and c.uid == selAreaUid
          and ui.dentro(vx, vy, retAreaUsar(retAreaPropria(i))) then
        usarAreaSegura()
        return
      end
    end
  end

  -- Cartas da mão (z25, por baixo da área).
  for i = #rectsMao, 1, -1 do
    local r = rectsMao[i]
    if ui.pontoNaCarta(vx, vy, r) then
      if podeAgir then
        local carta = partida.jogadores[1].mao[r.idx]
        if carta then alternarSelecao(carta.uid) end
      end
      return
    end
  end

  -- Clique no fundo não limpa a seleção (React só limpa na troca de turno).
end

-- DESENHO ------------------------------------------------------------------

local function desenharMaoIA()
  local lista = layoutOponente(#partida.jogadores[2].mao)
  for _, r in ipairs(lista) do
    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
    love.graphics.rotate(r.rot)
    ui.verso(-r.w / 2, -r.h / 2, r.w, r.h)
    love.graphics.pop()
  end
end

local function desenharDecks()
  local gap = ui.E(21)
  local total = DECK_CW + gap + DECK_DW
  local x = CENTRO - total / 2
  local cyCompra = DECKS_Y + (DECK_DH - DECK_CH) / 2

  -- Baralho infinito (V7): sempre ha cartas para comprar.
  ui.verso(x, cyCompra, DECK_CW, DECK_CH)
  ui.txtCabe("COMPRA", x - ui.E(6),
    DECKS_Y + DECK_DH + ui.E(10), 13, DECK_CW + ui.E(12), ui.C.OURO, "center", 10)

  local dx = x + DECK_CW + gap
  local topoDescarte = partida.pilhaDescarte[#partida.pilhaDescarte]
  if topoDescarte then
    ui.carta(topoDescarte, dx, DECKS_Y, DECK_DW, DECK_DH, {})
  else
    ui.caixaTracejada(dx, DECKS_Y, DECK_DW, DECK_DH, ui.E(6),
      ui.hex "#1E1E32", 0.4, ui.hex "#777777", 1, ui.E(2), ui.E(5), ui.E(4))
  end
  ui.txtCabe("DESCARTE", dx - ui.E(6), DECKS_Y + DECK_DH + ui.E(10),
    13, DECK_DW + ui.E(12), ui.C.OURO, "center", 10)
end

local function desenharMao()
  rectsMao = layoutMao(#partida.jogadores[1].mao)
  local mao = partida.jogadores[1].mao

  local function estaSel(uid)
    for _, u in ipairs(selUids) do
      if u == uid then return true end
    end
    return false
  end

  -- Ponteiro: mouse (desktop) ou dedo (mobile) — mesmo eixo do hover.
  local hx, hy = util.mouseVirtual()
  if toqueHover then hx, hy = toqueHover.x, toqueHover.y end

  -- Recusa (shake): tremor curto quando a acao nao pode ser executada.
  local rx, ry = 0, 0
  local agora = love.timer.getTime()
  if ui._recusaT0 and agora - ui._recusaT0 < 0.35 then
    rx = math.sin(agora * 80) * 5
    ry = math.cos(agora * 60) * 3
  else
    ui._recusaT0 = nil
  end

  -- ARRASTO: as cartas restantes compactam (layout n-1), um marcador
  -- dourado mostra a posição de solta e a carta alvo segue o ponteiro.
  if arrasto then
    local de = arrasto.de
    if de < 1 or de > #mao or partida.fim then
      arrasto = nil
    else
      local rets = layoutMao(#mao - 1)
      if #rets > 0 then
        for ci = 1, #rets do
          local oi = ci < de and ci or ci + 1
          local carta = mao[oi]
          local r = rets[ci]
          if carta then
            local sel = estaSel(carta.uid)
            local lift = sel and ui.E(14) or 0
            love.graphics.push()
            love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2 - lift)
            love.graphics.rotate(r.rot)
            ui.carta(carta, -r.w / 2, -r.h / 2, r.w, r.h,
              { dobra = foldUids[carta.uid] or 0,
                destaque = sel and ui.C.OURO or nil })
            love.graphics.pop()
          end
        end

        -- Marcador POR CIMA das cartas (a leva se sobrepõe): mostra onde a
        -- carta arrastada vai cair. Nos extremos fica no vão antes/depois
        -- da última carta, para não sumir embaixo dela.
        local function meio(r) return r.x + r.w / 2 end
        local alvo = math.max(1, math.min(arrasto.alvo or de, #rets + 1))
        local mx
        if alvo == 1 then
          mx = rets[1].x - ui.E(6)
        elseif alvo > #rets then
          mx = rets[#rets].x + rets[#rets].w + ui.E(6)
        else
          mx = (meio(rets[alvo - 1]) + meio(rets[alvo])) / 2
        end
        love.graphics.setColor(ui.C.OURO[1], ui.C.OURO[2], ui.C.OURO[3], 0.95)
        love.graphics.rectangle("fill", mx - ui.E(2),
          rets[1].y + ui.E(8), ui.E(4), rets[1].h - ui.E(16),
          ui.E(2), ui.E(2), 2)
      end

      local cartaArr = mao[de]
      if cartaArr then
        local ax = arrasto.x + arrasto.dx
        -- Levante maior que o cursor: o vão/marcador embaixo continua visível.
        local ay = arrasto.y + arrasto.dy - ui.E(44)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", ax - CW / 2 + ui.E(3),
          ay - CH / 2 + ui.E(4), CW, CH, ui.E(8), ui.E(8), 8)
        love.graphics.push()
        love.graphics.translate(ax, ay)
        love.graphics.rotate(math.rad(-4))
        ui.carta(cartaArr, -CW / 2, -CH / 2, CW, CH,
          { escala = 1.08, destaque = ui.C.OURO, destaqueAlfa = 0.5,
            dobra = foldUids[cartaArr.uid] or 0 })
        love.graphics.pop()
      end
      return
    end
  end

  -- Carta sob o ponteiro: da direita para a esquerda (mesma pilha de z do
  -- desenho — as da direita ficam por cima).
  local hoverIdx = nil
  for i = #rectsMao, 1, -1 do
    if ui.pontoNaCarta(hx, hy, rectsMao[i]) then
      hoverIdx = i
      break
    end
  end

  local selecionadas = {}
  local hoverRect = nil
  for i, r in ipairs(rectsMao) do
    local carta = mao[i]
    if carta and estaSel(carta.uid) then
      selecionadas[#selecionadas + 1] = r
    elseif i == hoverIdx then
      hoverRect = r
    else
      love.graphics.push()
      love.graphics.translate(r.x + r.w / 2 + rx, r.y + r.h / 2 + ry)
      love.graphics.rotate(r.rot)
      ui.carta(carta, -r.w / 2, -r.h / 2, r.w, r.h,
        { dobra = foldUids[carta.uid] or 0 })
      -- Veículo de bloqueio: carta precisa de alvo mas não há oponente vivo.
      if ui.cartaBloqueada(carta, partida, 1) then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", -r.w / 2 + 1, -r.h / 2 + 1,
          r.w - 2, r.h - 2, ui.E(3), ui.E(3), 6)
        love.graphics.setLineWidth(ui.E(2))
        love.graphics.setColor(1, 1, 1, 0.7)
        local m = ui.E(7)
        love.graphics.line(-r.w / 2 + m, -r.h / 2 + m,
          -r.w / 2 + r.w - m, -r.h / 2 + r.h - m)
        love.graphics.line(-r.w / 2 + r.w - m, -r.h / 2 + m,
          -r.w / 2 + m, -r.h / 2 + r.h - m)
        love.graphics.setLineWidth(1)
      end
      love.graphics.pop()
    end
  end

  -- HOVER (mouse/dedo): a carta "vai para frente" das vizinhas — lift +
  -- escala + brilho creme, desenhada por cima das demais.
  if hoverRect then
    hoverRect.y = hoverRect.y - ui.E(10)
    love.graphics.push()
    love.graphics.translate(hoverRect.x + hoverRect.w / 2 + rx,
      hoverRect.y + hoverRect.h / 2 + ry)
    love.graphics.rotate(hoverRect.rot)
    ui.carta(mao[hoverIdx], -hoverRect.w / 2, -hoverRect.h / 2,
      hoverRect.w, hoverRect.h,
      { dobra = foldUids[mao[hoverIdx].uid] or 0, escala = 1.06,
        destaque = ui.C.CREME, destaqueAlfa = 0.14 })
    love.graphics.pop()
  end

  -- Selecionadas por cima, com lift (handleToggleSelectCarta/MaoJogador).
  for _, r in ipairs(selecionadas) do
    local destaque = nil
    if ui.pontoNaCarta(hx, hy, r) then
      destaque = ui.C.OURO
    end
    r.y = r.y - ui.E(16)
    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2 + rx, r.y + r.h / 2 + ry)
    love.graphics.rotate(r.rot)
    ui.carta(mao[r.idx], -r.w / 2, -r.h / 2, r.w, r.h,
      { escala = ui._cartaScale[mao[r.idx]] or 1.05, destaque = destaque,
        dobra = foldUids[mao[r.idx].uid] or 0 })
    love.graphics.pop()
  end

  -- PREVIA INSTANTANEA (V7 UX): ao passar o mouse/dedo sobre uma carta, mostra
  -- a ARTE grande a esquerda da mao; sem arte cai na face textual. O
  -- long-press de 250ms continua abrindo o modal com o texto completo.
  -- Fica visivel tambem enquanto os outros jogam; some so nos overlays.
  local podePrevia = partida and not partida.fim and not pausado
    and not modalRoubo and not zoomCarta and not arrasto and batalhaIniciada
  if hoverIdx and mao[hoverIdx] and podePrevia then
    local pvH = ui.E(150)
    local pvW = math.floor(pvH * CW / CH + 0.5)
    local vao = ui.E(14)
    local maoEsq = rectsMao[1] and rectsMao[1].x or (CENTRO - CW / 2)
    local deckEsq = CENTRO - (DECK_CW + ui.E(21) + DECK_DW) / 2
    local px = maoEsq - pvW - vao
    local maxPx = deckEsq - pvW - vao
    if px > maxPx then px = maxPx end
    px = math.max(ui.E(8), px)
    local py = PAINEL_RECT.y - pvH - ui.E(8)
    local carta = mao[hoverIdx]
    local img = arte.arte(carta)
    if img and arte.temArte(carta) then
      ui.imagemContain(img, px, py, pvW, pvH)
    else
      ui.caixa(px, py, pvW, pvH, ui.E(8), ui.C.CORPO_CARTA,
        ui.corBorda(carta), ui.E(3))
      ui.faceCompleta(carta, px + ui.E(3), py + ui.E(3),
        pvW - ui.E(6), pvH - ui.E(6))
      ui.caixa(px, py, pvW, pvH, ui.E(8), nil, { 1, 1, 1 }, ui.E(2))
    end
  end
end

local function desenharPopups(dt)
  for i = #popups, 1, -1 do
    local p = popups[i]
    p.t = p.t + dt
    p.y = p.y - 34 * dt
    if p.t >= p.dur then
      table.remove(popups, i)
    else
      local alfa = p.t > p.dur - 0.5 and (p.dur - p.t) / 0.5 or 1
      local fonteTam = p.tam
      local larg = ui.larguraTexto(ui.tr(p.texto), fonteTam)
      love.graphics.setColor(0, 0, 0, 0.7 * alfa)
      love.graphics.rectangle("fill", p.x - larg / 2 - 8, p.y - 4, larg + 16, fonteTam + 12, 6, 6, 6)
      ui.txt(p.texto, p.x, p.y, fonteTam, p.cor, "center", larg + 16, alfa)
    end
  end
end

-- Modal do roubo às cegas (ModalRouboCego.js): cartas viradas escolhíveis
-- até `quantidade`, CANCELAR e ROUBAR. Registra modalRects p/ o clique.
local function desenharModalRoubo()
  if not modalRoubo then return end
  local m = modalRoubo
  modalRects = {}

  love.graphics.setColor(0, 0, 0, 0.75)
  local fx, fy, fw, fh = ui.retTelaCheia(VW, VH)
  love.graphics.rectangle("fill", fx, fy, fw, fh)

  local w = math.min(ui.E(760), VW - ui.E(40))
  local n = #m.mao
  local gap = ui.E(10)
  local cw = math.min(ui.E(90), (w - ui.E(80) - gap * (n - 1)) / n)
  if cw < ui.E(48) then cw = ui.E(48) end
  local ch = cw * (80 / 56)
  local wtot = math.min(w - ui.E(80), cw * n + gap * (n - 1))
  local temAlvos = m.alvos and #m.alvos > 1
  local h = ch + ui.E(200) + (temAlvos and ui.E(40) or 0)
  local x0 = (VW - w) / 2
  local y0 = (VH - h) / 2

  ui.caixa(x0, y0, w, h, ui.E(14), ui.hex "#14161F", ui.hex "#FFD54F", 3)
  ui.txt("VIGARICE!", x0, y0 + ui.E(24), ui.E(30), ui.hex "#FFD54F",
    "center", w)
  ui.txt(ui.tr("Escolha ate") .. " " .. m.quantidade .. " "
    .. ui.tr("cartas do oponente"),
    x0, y0 + ui.E(64), 14, { 1, 1, 1, 0.85 }, "center", w)
  ui.txt(m.texto or (ui.tr("Mao:") .. " " .. n .. " " .. ui.tr("cartas")),
    x0, y0 + ui.E(86), 13, { 1, 1, 1, 0.6 }, "center", w)

  local cx0 = x0 + (w - wtot) / 2
  local cy = y0 + ui.E(116)
  modalRects.cartas = {}
  for i = 1, n do
    local c = m.mao[i]
    local rx = cx0 + (i - 1) * (cw + gap)
    local selecionada = false
    for _, u in ipairs(modalRoubo.sel) do
      if u == c.uid then selecionada = true break end
    end
    ui.verso(rx, cy, cw, ch, { destaque = selecionada and ui.hex "#FFD54F" or nil })
    if selecionada then
      love.graphics.setColor(0, 0, 0, 0.45)
      love.graphics.rectangle("fill", rx, cy, cw, ch, ui.E(6))
    end
    ui.caixa(rx + cw - ui.E(20), cy - ui.E(8), ui.E(20), ui.E(20), ui.E(4),
      ui.hex "#FFD54F", ui.hex "#3E2723", 2)
    ui.txt(tostring(i), rx + cw - ui.E(20), cy - ui.E(5), 12,
      ui.hex "#3E2723", "center", ui.E(20))
    modalRects.cartas[#modalRects.cartas + 1] =
      { x = rx, y = cy, w = cw, h = ch, uid = c.uid }
  end

  local bw = ui.E(220)
  local bh = ui.E(50)
  local by = y0 + h - ui.E(30) - bh

  -- Chips de alvo (ARENA): "ROBO", "RAPOSA"... — trocarAlvo do React.
  modalRects.alvos = nil
  if temAlvos then
    local cyChip = by - ui.E(36)
    local nChip = #m.alvos
    local largChip = math.min(ui.E(150),
      (w - ui.E(60) - ui.E(10) * (nChip - 1)) / nChip)
    local largTotal = largChip * nChip + ui.E(10) * (nChip - 1)
    local cxChip = x0 + (w - largTotal) / 2
    modalRects.alvos = {}
    ui.txt("Alvo:", cxChip - ui.E(46), cyChip + ui.E(6), 14,
      { 1, 1, 1, 0.7 })
    for k, alvo in ipairs(m.alvos) do
      local r = { idx = k, x = cxChip + (k - 1) * (largChip + ui.E(10)),
        y = cyChip, w = largChip, h = ui.E(28) }
      modalRects.alvos[k] = r
      local selChip = m.alvoSel == k
      ui.caixa(r.x, r.y, r.w, r.h, ui.E(6),
        selChip and { 1, 213 / 255, 79 / 255, 0.18 } or ui.hex "#2A2E3D",
        selChip and ui.hex "#FFD54F" or ui.hex "#3A3A5C", 1)
      ui.txtCabe(alvo.nome, r.x + ui.E(6), r.y + ui.E(7), 14,
        r.w - ui.E(12), selChip and ui.hex "#FFD54F" or { 1, 1, 1, 0.85 },
        "center", 9)
    end
  end

  modalRects.cancelar = { x = x0 + w / 2 - bw - ui.E(12), y = by, w = bw, h = bh }
  modalRects.confirmar = { x = x0 + w / 2 + ui.E(12), y = by, w = bw, h = bh }
  ui.botao("CANCELAR", modalRects.cancelar.x, by, bw, bh,
    ui.hex "#2A2E3D", ui.hex "#9AA3B8", 18)
  local podeRoubar = #modalRoubo.sel > 0
  ui.botao(ui.tr("ROUBAR") .. " (" .. #modalRoubo.sel .. ")", modalRects.confirmar.x, by,
    bw, bh,
    podeRoubar and ui.hex "#2E7D32" or ui.hex "#1E2A1E",
    podeRoubar and ui.hex "#66BB6A" or ui.hex "#3A4A3A", 18)
end

-- Escudo (badge de protegido) — vetor, a fonte nao tem emoji.
local function escudo(cx, cy, s, cor)
  love.graphics.setColor(cor[1], cor[2], cor[3], cor[4] or 1)
  love.graphics.polygon("fill",
    cx - s * 0.4, cy - s * 0.5,
    cx + s * 0.4, cy - s * 0.5,
    cx + s * 0.4, cy + s * 0.1,
    cx, cy + s * 0.5,
    cx - s * 0.4, cy + s * 0.1)
end

-- Slot de oponente (SlotOponente.js): VEZ pulsando, avatar, nome, saldo,
-- maquinhas de verso, protecao/area e overlay FALIU. Tudo em coordenadas
-- base (104x110 dp em E) dentro do transform com esc do slot.
local function desenharSlot(i)
  local j = partida.jogadores[i]
  local p = posSlot(i)
  if p.seat then
    -- Novo painel COMPLETO (modo = "completo"; "compacto" vira depois).
    ui._layout.painelOponente({
      seat = p.seat, modo = "completo",
      cor = CORES_JOGADOR[i] or "#FFD54F",
      avatar = avatarDe(i),
      nome = j.nome, saldo = j.saldo,
      ocultarSaldo = partida.ocultarSaldos and i ~= 1,
      satisfacao = j.satisfacao, produtividade = j.produtividade,
      greve = j.greve,
      mao = #j.mao, area = j.areaSegura,
      defesa = j.defesas and j.defesas[1],
      vez = partida.vez == i and not partida.fim,
      falido = j.falido,
    })
    ui._layout.definirChips(i, j)
    return
  end
  local cor = ui.hex(CORES_JOGADOR[i] or "#FFD54F")
  local baseW, baseH = SLOT_W, SLOT_H
  local ehVez = partida.vez == i and not partida.fim
  local hab = ui._habilidadeDe(i)

  local pulse = 1
  if ehVez then
    pulse = 1.025 + 0.025 * math.sin(love.timer.getTime() * (2 * math.pi / 1.2))
  end

  love.graphics.push()
  love.graphics.translate(p.cx, p.cy)
  love.graphics.scale(p.esc * pulse)

  ui.caixa(-baseW / 2, -baseH / 2, baseW, baseH, ui.E(12),
    { 10 / 255, 10 / 255, 26 / 255, 0.9 }, cor, ui.E(2))

  -- Badge "VEZ" acima do slot.
  if ehVez then
    local bw, bh = ui.E(46), ui.E(17)
    ui.caixa(-bw / 2, -baseH / 2 - bh - ui.E(4), bw, bh, ui.E(5),
      cor, { 0, 0, 0 }, ui.E(1))
    ui.txt("VEZ", -bw / 2, -baseH / 2 - bh - ui.E(4) + ui.E(3), 11,
      { 0, 0, 0 }, "center", bw)
  end

  -- Avatar circular com borda da cor do seat.
  local av = avatarDe(i)
  local d = ui.E(40)
  local ay = -baseH / 2 + ui.E(8)
  love.graphics.setColor(28 / 255, 34 / 255, 56 / 255, 1)
  love.graphics.circle("fill", 0, ay + d / 2, d / 2)
  if av then
    love.graphics.stencil(function()
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("fill", 0, ay + d / 2, d / 2)
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)
    ui.imagemContain(av, -d / 2, ay, d, d)
    love.graphics.setStencilTest()
  end
  love.graphics.setLineWidth(2)
  love.graphics.setColor(cor[1], cor[2], cor[3], 1)
  love.graphics.circle("line", 0, ay + d / 2, d / 2)
  love.graphics.setLineWidth(1)

  -- Protecao (escudo) ao lado do avatar. (A Area Segura do oponente tem o
  -- proprio slot dedicado embaixo do painel — ver abaixo.)
  local bx = d / 2 + ui.E(7) + (hab and ui.E(11) or 0)
  if j.protegido then
    escudo(bx, ay + ui.E(9), ui.E(14), ui.hex "#42A5F5")
  end

  -- Habilidade de avatar (taylor/marx/mayo): bolinha M/T/Y ao lado do avatar.
  if hab then
    local hbT = ui.E(13)
    local hbx, hby = d / 2 + ui.E(1), ay + ui.E(2)
    local corH = hab == "marx" and ui.hex "#B71C1C"
      or (hab == "mayo" and ui.hex "#00695C" or ui.hex "#E65100")
    ui.caixa(hbx, hby, hbT, hbT, hbT / 2,
      corH, ui.hex "#FFD54F", ui.E(1))
    ui.txt(hab == "marx" and "M" or (hab == "mayo" and "Y" or "T"),
      hbx, hby + ui.E(2), ui.E(8), { 1, 1, 1 }, "center", hbT)
  end

  -- Nome.
  local nomeY = ay + d + ui.E(5)
  ui.txtCabe(j.nome, -baseW / 2 + ui.E(6), nomeY, ui.E(10),
    baseW - ui.E(12), cor, "center", ui.E(7))

  -- Saldo: "R$" + valor com cor por limiar (RN: >10 verde, >5 ouro).
  -- V7 5.3: no turno anterior ao evento do Deus Mercado os saldos dos
  -- demais ficam ocultos.
  local saldoY = nomeY + ui.E(13)
  local oculto = partida.ocultarSaldos and i ~= 1
  if oculto then
    ui.txtCabe("SALDO OCULTO", -baseW / 2 + ui.E(6), saldoY, ui.E(11),
      baseW - ui.E(12), ui.hex "#8A8FB0", "center", ui.E(9))
  else
    local txtR, txtVal = "R$", tostring(j.saldo)
    local tamL, tamV = ui.E(9), ui.E(12)
    local wR = ui.larguraTexto(txtR, tamL)
    local wV = ui.larguraTexto(txtVal, tamV)
    local sx = -(wR + ui.E(3) + wV) / 2
    ui.txt(txtR, sx, saldoY + (tamV - tamL) / 2, tamL, ui.hex "#AAB0D0",
      "left", wR + 2)
    local corSaldo = j.saldo > 10 and ui.hex "#66BB6A"
      or (j.saldo > 5 and ui.hex "#FFD54F" or ui.hex "#EF5350")
    ui.txt(txtVal, sx + wR + ui.E(3), saldoY, tamV, corSaldo, "left", wV + 2)
  end

  -- Barra de Satisfacao (V7 5.3) + Produtividade (5.4) no rodape do slot.
  local sat = math.max(0, math.min(200, tonumber(j.satisfacao) or 100))
  local prod = tonumber(j.produtividade) or 0
  local barW = baseW - ui.E(16)
  local barX = -baseW / 2 + ui.E(8)
  local barY = baseH / 2 - ui.E(14)
  ui.caixa(barX, barY, barW, ui.E(10), ui.E(4), ui.hex "#12162B", nil, 0)
  local corSat = j.greve and ui.hex "#EF5350"
    or (sat >= 200 and ui.hex "#FFD54F" or ui.hex "#42A5F5")
  if sat > 0 then
    ui.caixa(barX, barY, barW * (sat / 200), ui.E(10), ui.E(4), corSat,
      nil, 0)
  end
  local txtSat
  if j.greve then
    txtSat = "GREVE!"
  else
    txtSat = "SAT " .. math.floor(sat)
    if (j.bonusSatisfacao or 0) > 0 then txtSat = txtSat .. " MAXx2" end
    if prod ~= 0 then
      txtSat = txtSat .. string.format(" %+0.0f%%", prod * 100)
    end
  end
  ui.txtCabe(txtSat, barX, barY + ui.E(1), ui.E(8), barW,
    (sat >= 200 or j.greve) and ui.hex "#10121F" or ui.hex "#0B0E1A",
    "center", ui.E(7))

  -- Maquinhas (ate 6) com leve rotacao.
  local miniW, miniH = ui.E(11), ui.E(16)
  local nMini = math.min(#j.mao, 6)
  local rowY = baseH / 2 - ui.E(14) - miniH / 2
  for c = 1, nMini do
    local rot = math.rad((c - nMini / 2) * 5)
    local px = (c - (nMini + 1) / 2) * (miniW + ui.E(1.5))
    love.graphics.push()
    love.graphics.translate(px, rowY)
    love.graphics.rotate(rot)
    ui.verso(-miniW / 2, -miniH / 2, miniW, miniH,
      { destaque = cor })
    love.graphics.pop()
  end

  -- Area Segura do oponente (AreaSegura.js): as cartas guardadas viram
  -- mini versos lado a lado; vazio vira um slot tracejado "VAZIA".
  local aw, ah = ui.E(24), ui.E(34)
  local aay = baseH / 2 + ui.E(4)
  local nArea = math.min(#j.areaSegura, jogo.AREA_SEGURA_MAX)
  if nArea > 0 then
    for c = 1, nArea do
      local px = (c - (nArea + 1) / 2) * aw * 0.46
      ui.verso(px - aw / 2, aay, aw, ah, { alfa = 0.7 })
      ui.caixa(px - aw / 2, aay, aw, ah, ui.E(5), nil, { 1, 1, 1, 0.35 }, ui.E(1))
    end
  else
    ui.caixaTracejada(-aw / 2, aay, aw, ah, ui.E(4), ui.hex "#1E1E32", 0.4,
      ui.hex "#FFD54F", 0.3, ui.E(1.5), ui.E(4), ui.E(3))
    ui.txt("VAZIA", -aw / 2, aay + ah / 2 - ui.E(4), 7, ui.hex "#FFD54F",
      "center", aw, 0.55)
  end

  -- Falido: overlay cinza dessaturado + "FALIU".
  if j.falido then
    love.graphics.setColor(0.18, 0.18, 0.22, 0.78)
    love.graphics.rectangle("fill", -baseW / 2, -baseH / 2, baseW, baseH,
      ui.E(12))
    ui.txt("FALIU", -baseW / 2, -ui.E(8), ui.E(13), ui.C.VERMELHO,
      "center", baseW)
  end

  love.graphics.pop()
end

local function desenharSlots()
  for i = 2, #partida.jogadores do
    -- Quem ja saiu some da arena (o arco do posSlot fecha o buraco).
    if not partida.jogadores[i].saiu then
      desenharSlot(i)
    end
  end
end

-- MesaCentral.js: circulo externo tracejado girando (30s), interno com
-- espadas + "ARENA" + "NvN" + miniaturas de compra/descarte.
local function desenharMesaCentral()
  -- Arena reduzida conforme o numero de oponentes (minimo 24 px de folga).
  local vivos = 0
  for o = 2, #partida.jogadores do
    if not partida.jogadores[o].saiu then vivos = vivos + 1 end
  end
  local ar = ui._layout.arena(vivos, VW, VH)
  local re, ri = ar.r, ar.r * 0.85
  local rot = love.timer.getTime() * (2 * math.pi / 30)
  circuloTracejado(ar.cx, ar.cy, re, 10, 8, ui.hex "#FFD54F", 2, rot)
  ui.caixa(ar.cx - ri, ar.cy - ri, ri * 2, ri * 2, ri, ui.hex "#0F1322",
    ui.hex "#7A5C29", 2, 0.92)

  -- Espadas cruzadas somente com a arena vazia, longe dos painéis e do
  -- slot "VAZIA" (que so existe no duelo, nunca nesta mesa).
  if #partida.pilhaDescarte == 0 and re >= ui.E(52) then
    ui.iconeEspadas(ar.cx, ar.cy - ri + ui.E(20), math.min(ui.E(30), ri * 0.4))
  end

  -- Compra + descarte maiores, para enxergar as ultimas cartas descartadas.
  local mw, mh = ui.E(34), ui.E(48)
  local gap = ui.E(10)
  local mx1 = ar.cx - mw - gap / 2
  local mx2 = ar.cx + gap / 2
  local my = ar.cy - mh / 2 + ui.E(10)

  -- Baralho infinito (V7): sempre ha cartas para comprar.
  ui.verso(mx1, my, mw, mh, {})
  ui.txt("∞", mx1 - ui.E(6), my + mh + ui.E(2), 11,
    ui.hex "#AAB0D0", "center", mw + ui.E(12))

  -- Descarte: mostra só a ultima carta jogada, com a arte da carta
  -- (ui.carta usa o mesmo caminho da mao/paineis; faceMini era o fallback
  -- textual das cartas sem arte).
  if #partida.pilhaDescarte == 0 then
    ui.caixaTracejada(mx2, my, mw, mh, ui.E(4), ui.hex "#1E1E32", 0.4,
      ui.hex "#777777", 1, ui.E(1.5), ui.E(4), ui.E(3))
  else
    local c = partida.pilhaDescarte[#partida.pilhaDescarte]
    ui.carta(c, mx2, my, mw, mh, { preencherArte = true })
  end
  ui.txt(tostring(#partida.pilhaDescarte), mx2 - ui.E(6), my + mh + ui.E(2),
    11, ui.hex "#AAB0D0", "center", mw + ui.E(12))
end

-- Desenha os halos de alvo e a mensagem quando o jogador está escolhendo o
-- alvo de cada carta selecionada (modo alvo da Etapa 9).
local function desenharModoAlvo()
  if not ui._alvoModo or not ui._alvoCartaIdx then return end
  local uid = selUids[ui._alvoCartaIdx]
  if not uid then return end

  local carta = nil
  for _, c in ipairs(partida.jogadores[1].mao) do
    if c.uid == uid then carta = c break end
  end
  if not carta then return end

  local tipo = ui.areaDaCarta(carta)

  local pulso = 0.5 + 0.5 * math.sin(love.timer.getTime() * 8)
  local function halo(x, y, w, h)
    love.graphics.setColor(1, 0.84, 0.2, 0.12 + 0.18 * pulso)
    love.graphics.rectangle("fill", x, y, w, h, ui.E(8))
    love.graphics.setColor(1, 0.84, 0.2, 0.5 + 0.3 * pulso)
    love.graphics.setLineWidth(ui.E(2.5))
    love.graphics.rectangle("line", x, y, w, h, ui.E(8))
    love.graphics.setLineWidth(1)
  end

  local aOpo = areaAlvo("oponente", CENTRO, OP_PAINEL_Y,
    PAINEL_RECT.x, PAINEL_RECT.y, PAINEL_RECT.w, PAINEL_RECT.h,
    DECK_CW, DECK_DW, DECK_DH, DECKS_Y)
  local aTodos = areaAlvo("todos", CENTRO, OP_PAINEL_Y,
    PAINEL_RECT.x, PAINEL_RECT.y, PAINEL_RECT.w, PAINEL_RECT.h,
    DECK_CW, DECK_DW, DECK_DH, DECKS_Y)
  local aVoce = areaAlvo("voce", CENTRO, OP_PAINEL_Y,
    PAINEL_RECT.x, PAINEL_RECT.y, PAINEL_RECT.w, PAINEL_RECT.h,
    DECK_CW, DECK_DW, DECK_DH, DECKS_Y)

  local function desenharArea(r, texto)
    if not r then return end
    halo(r.x, r.y, r.w, r.h)
    ui.txt(texto, r.x, r.y - ui.E(10), 12, ui.C.OURO, "center", r.w)
  end

  if tipo == "descarte" or tipo == "todos" then
    desenharArea(aTodos, tipo == "descarte" and "USAR CARTA (DESCARTE)"
      or "ALVO: TODOS (DESCARTE)")
  end
  if tipo == "voce" or tipo == "voceOuOponente" then
    desenharArea(aVoce, "ALVO: SEU PAINEL")
  end
  if tipo == "oponente" or tipo == "voceOuOponente" then
    if ehMesa() then
      -- Arena: cada oponente e um alvo clicavel (o slot escolhe o assento).
      for i = 2, #partida.jogadores do
        if not partida.jogadores[i].saiu then
          desenharArea(rectSlotAlvo(i), "ALVO: " .. partida.jogadores[i].nome)
        end
      end
    else
      desenharArea(aOpo, "ALVO: OPONENTE")
    end
  end

  -- Instrução no centro inferior da tela.
  local instrucao
  if tipo == "descarte" then
    instrucao = ui.tr("CLIQUE NO DESCARTE PARA USAR:") .. " " .. carta.nome
  else
    instrucao = ui.tr("SELECIONE O ALVO PARA:") .. " " .. carta.nome .. "  ->  "
      .. ui.alvoTipoNome(tipo)
  end
  ui.txt(instrucao, 0, VH - ui.E(46), 14, ui.C.OURO, "center", VW)
end

local function desenharJogo(dt)
  love.graphics.setColor(1, 1, 1, 1)
  -- Madeira em cover da tela inteira: preenche as barras do letterbox
  -- (celular 20:9 etc.) sem distorcer a textura. No duelo do ciclo a mesa
  -- vem da arte topdown do ciclo em foco; na partida em rede, da arena que
  -- o host escolheu na sala (partida.arena, via snapshot).
  local chaveArena = ui._cicloDuelo
    and (ui._cicloArena or 1) or (partida and partida.arena)
  local fundoMesa = (chaveArena and arte.arena(chaveArena)) or madeiraCanvas
  ui.imagemCover(fundoMesa, ui.retTelaCheia(VW, VH))

  if ehMesa() then
    -- ARENA N >= 3: mesa central atras + slots em elipse (sem pilhas top).
    desenharMesaCentral()
    desenharSlots()
  else
    -- oponente (PainelStatus via MaoOponente: gold, minWidth 130, top:10)
    local ia = partida.jogadores[2]
    ui.painelStatus({
      nome = ia.nome, saldo = ia.saldo,
      ocultarSaldo = partida.ocultarSaldos,
      -- duelo local = "ia"; duelo em rede = o avatar real do oponente.
      quem = chaveAvatar(2), x = CENTRO - ui.E(65), y = OP_PAINEL_Y,
      corDestaque = ui.C.OURO,
      habilidade = ui._habilidadeDe(2),
    })
    -- Barras verticais de Satisfacao/Produtividade a ESQUERDA do painel.
    ui.barrasStatus(CENTRO - ui.E(65) - ui.larguraBarrasStatus() - ui.E(6),
      OP_PAINEL_Y, ui.E(34), ia)
    desenharMaoIA()

    -- pilhas
    desenharDecks()
  end

  -- placa de turno (TurnoIndicador.js: "TURNO DE <NOME>" + pill "TURNO n/max").
  -- No modo um jogador nao ha relogio para o humano: sem a linha de tempo.
  local tempoPlaca = (fase == "JOGADOR" and not partida.fim and batalhaIniciada
    and (redeModo or os.getenv("JOGO_TEMPO_VISIVEL") ~= nil))
    and { restante = tempo.restante, duracao = tempo.duracao, aviso = tempo.aviso }
    or nil
  ui._placaRect = ui.placaTurno({
    x = PLACA_X, y = PLACA_Y, largura = ui.E(170),
    turno = math.min(partida.turno, partida.maxTurnos),
    max = partida.maxTurnos,
    nome = partida.jogadores[partida.vez].nome,
    -- Humano de verdade (eu, o remoto ou a IA preenchida): o rotulo isIA
    -- vem serializado no snapshot, entao o cliente pinta igual o host.
    isHumano = not partida.jogadores[partida.vez].isIA,
    -- Sentido real do turno: depois de cada jogador a vez cai no jogador a
    -- sua esquerda (do seat 1 o proximo fica no lado esquerdo do anel), entao
    -- o chip fica fixo em "PARA A ESQUERDA" e nunca muda com quem joga.
    fluxo = "PARA A ESQUERDA",
    tempo = tempoPlaca,
    -- Botao PASSAR na placa; visor de curingas encostado nela.
    passar = true,
    passarAtivo = partida.vez == 1 and fase == "JOGADOR",
    mouse = util.mouseVirtual,
    jogadas = {
      quota = jogo.quotaTurno(partida, partida.vez),
      restantes = math.max(0, jogo.quotaTurno(partida, partida.vez)
        - math.min(partida.jogadasTurno or 0, jogo.quotaTurno(partida, partida.vez))),
    },
    cadeia = ((partida.jogadores[partida.vez].chainBonus or 0) > 0)
      and ("CADEIA " .. string.upper(tostring(partida.jogadores[partida.vez].chainClasse or ""))
        .. " +" .. partida.jogadores[partida.vez].chainBonus) or nil,
    visor = function(vx, vy, vw, vh)
      ui._meta.desenharVisorCompacto(partida, vx, vy, vw, vh)
    end,
  })

  local jog = partida.jogadores[1]

  -- área segura do oponente (opacity 0.7, AreaSegura isOpponent) — so no duelo.
  -- Agora sao 3 slots: as cartas guardadas viram versos e os vazios ficam
  -- tracejados (o rotulo "VAZIA" so aparece com a area toda vazia).
  if not ehMesa() then
    local op = partida.jogadores[2]
    local opVazia = #op.areaSegura == 0
    for i = 1, jogo.AREA_SEGURA_MAX do
      local s = retAreaOponente(i)
      if op.areaSegura[i] then
        ui.verso(s.x, s.y, s.w, s.h, { dobra = 1, alfa = 0.7 })
      else
        ui.caixaTracejada(s.x, s.y, s.w, s.h, ui.E(6),
          ui.hex "#808080", 0.105, ui.C.OURO, 0.21, ui.E(1.5), ui.E(4), ui.E(3))
        if opVazia then
          ui.txt("VAZIA", s.x, s.y + s.h / 2 - ui.E(5), 10,
            ui.C.OURO, "center", s.w, 0.28)
        end
      end
    end
  end

  -- mão (z25: por baixo da área segura própria e do painel, como no React)
  desenharMao()
  desenharModoAlvo()

  -- painel do jogador (z26, base-centro, por cima da mão)
  ui.painelStatus({
    nome = jog.nome, saldo = jog.saldo,
    quem = "voce", x = PAINEL_RECT.x, y = PAINEL_RECT.y,
    largura = PAINEL_RECT.w,
    habilidade = ui._habilidadeDe(1),
  })
  -- Barras verticais de Satisfacao/Produtividade a ESQUERDA do painel.
  ui.barrasStatus(PAINEL_RECT.x - ui.larguraBarrasStatus() - ui.E(6),
    PAINEL_RECT.y, ui.E(34), jog)

  -- Pilha de Defesa: centralizada acima dos 3 slots da Area Segura do jogador.
  -- O espaco entre a pilha e os slots fica livre para o botao USAR.
  local rdSlot = qc.retSlot()
  ui._meta.desenharPilhas(partida, VW, VH, rdSlot.x, rdSlot.y)

  -- Carta de Defesa selecionada: o slot vira o destino (clique arma).
  local selDef = acharCartaZoom(selUids[1])
  if selDef and jogo.ehDefesa(selDef) then
    local pulso = 0.45 + 0.55 * math.abs(math.sin(love.timer.getTime() * 5))
    ui.caixaTracejada(rdSlot.x - ui.E(3), rdSlot.y - ui.E(3),
      rdSlot.w + ui.E(6), rdSlot.h + ui.E(6), ui.E(8),
      ui.hex "#2A1020", 0.18, ui.C.OURO, pulso, ui.E(2.5), ui.E(6), ui.E(4))
    ui.txt(ui.tr("ARMAR"), rdSlot.x - ui.E(6), rdSlot.y + rdSlot.h + ui.E(2),
      10, ui.C.OURO, "center", rdSlot.w + ui.E(12))
  end

  -- Visor de Curingas agora faz parte da placa de turno (ver opts.visor).

  -- área segura própria (z26, por cima da mão): o dono vê a FACE da carta
  -- (AreaSegura.js isOwner → CartaArena), seleciona e usa fora do turno.
  -- 3 slots em linha: o USAR sobe acima do slot selecionado.
  local areaVazia = #jog.areaSegura == 0
  for i = 1, jogo.AREA_SEGURA_MAX do
    local s = retAreaPropria(i)
    local cartaP = jog.areaSegura[i]
    if cartaP then
      local selP = selAreaUid == cartaP.uid
      ui.carta(cartaP, s.x, s.y, s.w, s.h,
        { dobra = 1, destaque = selP and ui.C.OURO or nil })
      if selP then
        local ua = retAreaUsar(s)
        ui.botao("USAR", ua.x, ua.y, ua.w, ua.h,
          ui.hex "#1565C0", ui.hex "#42A5F5", 11)
      end
    else
      ui.caixaTracejada(s.x, s.y, s.w, s.h,
        ui.E(6), ui.hex "#808080", 0.15, ui.C.OURO, 0.3, ui.E(1.5),
        ui.E(4), ui.E(3))
      if areaVazia then
        ui.txt("VAZIA", s.x, s.y + s.h / 2 - ui.E(5),
          10, ui.C.OURO, "center", s.w, 0.4)
      end
    end
  end

  -- overlay de passar (long-press no painel)
  if pressPanel then
    love.graphics.setColor(230 / 255, 81 / 255, 0, 0.88)
    love.graphics.rectangle("fill", PAINEL_RECT.x, PAINEL_RECT.y,
      PAINEL_RECT.w, PAINEL_RECT.h, ui.E(8))
    ui.txt("SOLTAR PARA PASSAR", PAINEL_RECT.x,
      PAINEL_RECT.y + PAINEL_RECT.h / 2 - ui.E(8), 13,
      { 1, 1, 1, 1 }, "center", PAINEL_RECT.w)
  end

  -- carta voando (sombra projetada acompanhando o voo)
  if voo then
    local esc = voo.e or 1
    -- Arco parabolico: a carta sobe no meio do voo e desce no destino. A
    -- sombra continua na mesa e enfraquece conforme a carta sobe.
    local arcoMax = math.max(1, ui.E(46))
    local arco = math.sin(math.pi * (voo.p or 1)) * arcoMax
    local sw = DECK_DW * 0.86 * esc
    local sh = DECK_DH * 0.26 * esc
    local sx = voo.x + DECK_DW / 2 + ui.E(7)
    local sy = voo.y + DECK_DH / 2 * (1 + esc) + ui.E(3)
    love.graphics.setColor(0, 0, 0, 0.38 * math.min(1, esc + 0.2)
      * (1 - 0.35 * (arco / arcoMax)))
    love.graphics.ellipse("fill", sx, sy, sw / 2, sh / 2)
    love.graphics.push()
    love.graphics.translate(voo.x + DECK_DW / 2,
      voo.y + DECK_DH / 2 - arco)
    love.graphics.rotate(voo.rot or 0)
    ui.carta(voo.carta, -DECK_DW / 2, -DECK_DH / 2, DECK_DW, DECK_DH,
      { escala = voo.e })
    love.graphics.pop()
  end

  -- botao pausa
  ui.caixa(PAUSA.x, PAUSA.y, PAUSA.w, PAUSA.h, PAUSA.w / 2,
    { 0, 0, 0 }, ui.C.OURO, 1, 0.6)
  local imgPause = arte.img("pause")
  if imgPause then
    ui.imagemCover(imgPause, PAUSA.x + ui.E(10), PAUSA.y + ui.E(10),
      PAUSA.w - ui.E(20), PAUSA.h - ui.E(20))
  end

  -- botao de teste (so duelo classico vs Adam Smith): vitoria dele.
  if not arenaN and not redeModo and not partida.fim and not pausado
      and batalhaIniciada and not introBatAtiva
      and not (partida and partida.tutorial)
      and os.getenv("JOGO_UI_LIMPA") == nil then
    ui.botao("TESTE: ADAM VENCE", BTN_ADAM_VENCE.x, BTN_ADAM_VENCE.y,
      BTN_ADAM_VENCE.w, BTN_ADAM_VENCE.h, ui.C.VERMELHO, ui.hex "#FF5252", 13)
  end

  -- botao de teste irmao: vitoria direta do jogador (libera o proximo
  -- inimigo do caminho do ciclo; fica embaixo da placa de turno).
  if not redeModo and not partida.fim and not pausado and not partida.simulacao
      and batalhaIniciada and not introBatAtiva
      and not (partida and partida.tutorial)
      and os.getenv("JOGO_UI_LIMPA") == nil then
    ui.botao("TESTE: VOCE VENCE", BTN_ADAM_VENCE.voce.x, BTN_ADAM_VENCE.voce.y,
      BTN_ADAM_VENCE.voce.w, BTN_ADAM_VENCE.voce.h,
      ui.C.VERDE, ui.C.VERDE_CLARO, 13)
  end

  -- resultado (depois dos popups: no React o Modal cobre o arena inteiro)
  desenharPopups(dt)
  -- Feedback visual das jogadas: impacto, numeros SAT/PROD, escudo, etc.
  ui._impacto.desenhar()

  if resultado then
    ui.bannerResultado(resultado)
  end

  -- Animacoes especiais das Curingas (por cima do banner de resultado, mas
  -- abaixo do modal de zoom e da pausa).
  ui._curingas.desenhar(VW, VH)

  desenharModalRoubo()

  -- Zoom da carta (CartaZoomModal.js): sprite da carta a ESQUERDA e painel
  -- de informacoes a DIREITA (nome, chance, alvo, descricao, efeito e
  -- duracao). Overlay preto com fade + spring 0.5->1 dos dois lados juntos.
  if zoomCarta then
    local alfa = math.min(1, zoomT / 0.2)
    love.graphics.setColor(0, 0, 0, alfa)
    love.graphics.rectangle("fill", -4, -4, VW + 8, VH + 8)
    local k = math.min(1, zoomT / 0.35)
    local esc = 0.5 + 0.5 * (1 - (1 - k) ^ 3)
    local cw, ch = ui.E(200), ui.E(280)
    local gap = ui.E(14)
    local pw = ui.E(230)
    local x0 = math.floor((VW - (cw + gap + pw)) / 2)
    local y0 = math.floor((VH - ch) / 2)
    love.graphics.push()
    love.graphics.translate(CENTRO, VH / 2)
    love.graphics.scale(esc)
    love.graphics.translate(-CENTRO, -VH / 2)
    ui.cartaZoom(zoomCarta, x0, y0, cw, ch)
    ui.faceCompleta(zoomCarta, x0 + cw + gap, y0, pw, ch)
    love.graphics.pop()
  end

  if pausado then
    ui.overlayPausa({ larguraVirtual = VW, alturaVirtual = VH })
  end

  -- Camada separada: flutuantes e chips por painel, por cima de tudo.
  if ehMesa() then
    local vivos = 0
    for o = 2, #partida.jogadores do
      if not partida.jogadores[o].saiu then vivos = vivos + 1 end
    end
    local seats = ui._layout.assentos(vivos, VW, VH)
    ui._layout.desenhar(seats)
    ui._layout.desenharDebug(seats, ui._layout.arena(vivos, VW, VH))
  end
end

local function desenharFim(dt)
  desenharJogo(dt)
  local d = dadosFim()
  ui.overlayFim({
    larguraVirtual = VW, alturaVirtual = VH,
    titulo = d.titulo, motivo = d.motivo,
    placar1 = d.placar1, placar2 = d.placar2,
    placares = d.placares, temProximo = d.temProximo,
    dados = d,
  })

  -- Adam Smith zombando na derrota do duelo classico: retrato + balao NA
  -- FAIXA ABAIXO da caixa, alinhados pela esquerda (estilo do print). O
  -- tamanho cola na faixa livre entao nunca cobre as informacoes.
  local v = partida.vencedor
  if not redeModo and not partida.simulacao and (arenaN or 2) == 2
      and v and v.empate ~= true
      and v ~= partida.jogadores[1] and v.nome == "Adam Smith" then
    local g = ui.geomFim(VW, VH, d.placares and #d.placares or 0,
      d.temProximo)
    local faixa = VH - (g.y + g.h)
    local s = math.min(ui.E(146), faixa - ui.E(10))
    local gap = ui.E(10)
    local x0 = g.x - ui.E(14)
    local bx = x0 + s + gap
    local bw = math.min(ui.E(488), VW - bx - ui.E(14))
    local bh = math.min(ui.E(45), s)
    local y0 = g.y + g.h + (faixa - s) / 2
    if s >= ui.E(40) then
      -- Mesmo transform do painel: retrato e balao entram junto na animacao.
      local k, yoff = ui.fimAnimacao()
      local cxm, cym = g.x + g.w / 2, g.y + g.h / 2
      love.graphics.push()
      love.graphics.translate(cxm, cym + yoff)
      love.graphics.scale(k)
      love.graphics.translate(-cxm, -cym)

      local img = arte.avatar(v.avatar or "ia")
      if img then
        love.graphics.setColor(1, 1, 1, 1)
        ui.imagemCover(img, x0, y0, s, s)
        love.graphics.setColor(ui.C.OURO)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x0 + 1, y0 + 1, s - 2, s - 2)
        love.graphics.setLineWidth(1)
      end
      local by = y0 + (s - bh) / 2
      -- cauda do balao apontando para o retrato (antes da caixa: a borda da
      -- caixa cobre a base da cauda e o desenho fica costurado).
      love.graphics.setColor(ui.C.CORPO_CARTA)
      local cauda = { bx, by + bh * 0.30, bx, by + bh * 0.66,
        bx - ui.E(20), by + bh * 0.50 }
      love.graphics.polygon("fill", cauda)
      love.graphics.setColor(ui.C.OURO)
      love.graphics.setLineWidth(2)
      love.graphics.polygon("line", cauda)
      love.graphics.setLineWidth(1)
      ui.caixa(bx, by, bw, bh, ui.E(12), ui.C.CORPO_CARTA, ui.C.OURO, ui.E(2))

      -- Fala escrita letra a letra (o cursor some quando termina). O x de
      -- inicio fica fixo no centro do balao da frase completa: o texto
      -- cresce para a direita sem "pular" a cada letra.
      local frase = "O mercado nao perdoa os fracos."
      local vis, escrevendo = ui.falsaTexto(frase)
      if vis ~= "" or escrevendo then
        local tam = 22
        local largTot = ui.larguraTexto(frase, tam)
        local tx = bx + (bw - largTot) / 2
        local ty = by + (bh - ui.alturaTexto(tam)) / 2
        if vis ~= "" then
          ui.txt(vis, tx, ty, tam, { 1, 1, 1 }, "left", bw)
        end
        if escrevendo then
          ui.txt("_", tx + ui.larguraTexto(vis, tam), ty, tam,
            { 1, 1, 1 }, "left", bw)
        end
      end

      love.graphics.pop()
    end
  end
end

local function desenharMenu(dt)
  local itens, flutuantes = layoutMenu()
  ui.menu({
    larguraVirtual = VW, alturaVirtual = VH,
    itensMenu = itens,
    flutuantes = flutuantes,
    hover = { x = hover.x, y = hover.y },
    nick = perfilJogador.nick,
  })
  desenharPopups(dt)
end

local function desenharArenaMenu(dt)
  desenharMenu(dt)
  arenaMenu.desenhar()
end

-- Menu ao fundo + painel da rede + popups por cima (ex.: PARTIDA EM BREVE).
local function desenharMultiplayer(dt)
  local itens, flutuantes = layoutMenu()
  ui.menu({
    larguraVirtual = VW, alturaVirtual = VH,
    itensMenu = itens,
    flutuantes = flutuantes,
    hover = { x = hover.x, y = hover.y },
    nick = perfilJogador.nick,
  })
  if mult then mult:desenhar(hover) end
  desenharPopups(dt)
end

local FUNDO_INTRO = ui.hex "#07060B"

local function desenharIntro()
  love.graphics.setColor(FUNDO_INTRO)
  local fx, fy, fw, fh = ui.retTelaCheia(VW, VH)
  love.graphics.rectangle("fill", fx, fy, fw, fh)

  local chave = (intro.fase == "andando" and "intro_and_" or "intro_sim_") .. intro.quadro
  local img = arte.img(chave)
  if not img then return end

  local caixa = VH * 0.3
  local w, h = img:getWidth(), img:getHeight()
  local e = math.min(caixa / w, caixa / h)
  local p = math.min(intro.t / 4, 1)
  p = p * p * (3 - 2 * p)
  local dx = intro.fase == "andando" and (VW * (1 - p)) or 0

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, CENTRO + dx, VH / 2, 0, e, e, w / 2, h / 2)
end

local function desenharLogo()
  -- Preto puro para emendar com o fundo preto da propria imagem.
  love.graphics.setColor(0, 0, 0, 1)
  local fx, fy, fw, fh = ui.retTelaCheia(VW, VH)
  love.graphics.rectangle("fill", fx, fy, fw, fh)

  local img = arte.img("intro_logo")
  if not img then return end

  local w, h = img:getWidth(), img:getHeight()
  local e = math.min((VW * 0.8) / w, (VH * 0.8) / h)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, CENTRO, VH / 2, 0, e, e, w / 2, h / 2)
end

-- LOOP ---------------------------------------------------------------------

madeiraCanvas = nil

-- Smoke do bootstrap do cliente em rede (Fases 2 e 3): SNAPSHOT injetado
-- (sem socket) monta a partida, abre a tela de jogo, gira as fases e liga
-- a mesa quando n >= 3. E funcao de nivel de arquivo de proposito: dentro
-- de testarRenderizacao ela estouraria o limite de 60 upvalues do LuaJIT.
-- Smokes de render/em rede agrupados em UMA tabela local (mesmo motivo do
-- `emo`: o chunk estoura os 200 locals do LuaJIT se cada um virar local).
local testesRender = {}

function testesRender.cliente()
  local snapVar = nil
  local multFake = {
    consumirPartida = function()
      if not snapVar then return {} end
      return { { id = 9, msg = { tipo = "SNAPSHOT", p = snapVar } } }
    end,
    emPartida = function() return true end,
    partidaEncerrada = function() return nil end,
    marcarSincronizado = function() end,
  }
  local multReal = mult
  local telaReal = tela
  mult = multFake
  partida = nil
  redeModo = nil

  -- Duelo (n = 2): proprio na posicao 1, turno proprio = JOGADOR.
  local psR = jogo.criarPartida({ n = 2, nomes = { "HOST_REDE", "CLIENTE" } })
  psR.vez = 2
  snapVar = partidaRede.serializar(psR, 2, { duracao = 30, restante = 30 })
  processarPartidaRede()
  if tela ~= "jogo" then
    error("rede: snapshot do cliente nao abriu o jogo (tela=" ..
      tostring(tela) .. ")")
  end
  if not partida or partida.jogadores[1].nome ~= "CLIENTE" then
    error("rede: cliente nao montou o proprio jogador na posicao 1 = "
      .. tostring(partida and partida.jogadores[1].nome))
  end
  if redeModo ~= "cliente" then
    error("rede: snapshot nao marcou redeModo = " .. tostring(redeModo))
  end
  if fase ~= "JOGADOR" then
    error("rede: turno proprio deveria ser fase JOGADOR = " .. tostring(fase))
  end
  if ehMesa() then
    error("rede: duelo de 2 nao deveria ligar a mesa (arenaN=" ..
      tostring(arenaN) .. ")")
  end
  -- Segundo snapshot com a vez do host: o cliente vira fase REDE.
  psR.vez = 1
  snapVar = partidaRede.serializar(psR, 2, { duracao = 30, restante = 30 })
  processarPartidaRede()
  if fase ~= "REDE" then
    error("rede: turno do host no cliente deveria ser REDE = " ..
      tostring(fase))
  end

  -- Mesa de 5 (Fase 3): arenaN liga pelo snapshot (mesmo no espelho ja
  -- montado), a rotacao coloca o proprio na posicao 1 e a vez remota
  -- (seat 4 visto do 3 = display 2) fica em REDE.
  local psM = jogo.criarPartida({ n = 5, nomes = { "A", "B", "C", "D", "E" } })
  psM.vez = 4
  snapVar = partidaRede.serializar(psM, 3, { duracao = 30, restante = 30 })
  processarPartidaRede()
  if not ehMesa() then
    error("rede: mesa de 5 no cliente deveria ligar ehMesa (arenaN=" ..
      tostring(arenaN) .. ")")
  end
  if not partida or partida.jogadores[1].nome ~= "C" then
    error("rede: mesa 5p: proprio (seat 3) na posicao 1 = " ..
      tostring(partida and partida.jogadores[1] and partida.jogadores[1].nome))
  end
  if fase ~= "REDE" then
    error("rede: mesa 5p: turno remoto deveria ser REDE = " .. tostring(fase))
  end
  -- Turno proprio na mesa: snap.vez = 1 => JOGADOR.
  psM.vez = 3
  snapVar = partidaRede.serializar(psM, 3, { duracao = 30, restante = 30 })
  processarPartidaRede()
  if fase ~= "JOGADOR" then
    error("rede: mesa 5p: turno proprio deveria ser JOGADOR = " ..
      tostring(fase))
  end

  -- Restaura o estado para o resto da suite.
  mult = multReal
  tela = telaReal
  partida = nil
  redeModo = nil
  envioPendente = false
  batalhaIniciada = false
  arenaN = nil
  limparEstadoPartida()
end

-- Protocolo de Quick Counter remoto: host pede reacao, cliente devolve a
-- escolha, host aplica a defesa ANTES da carta atacante. Tambem cobre a
-- rejeicao de respostas de janelas anteriores (seq).
function testesRender.reacaoRemota()
  local multReal, telaReal, partidaReal = mult, tela, partida
  local redeReal, faseReal = redeModo, fase
  local batalhaReal, introReal = batalhaIniciada, introBatAtiva
  local arenaReal, envioReal = arenaN, envioPendente
  local qcAtivo, qcPend, qcSeq = qc.ativo, qc.pendente, qc.seq
  local resReal, filaReal = resultado, filaSaida
  local saidaRessReal, saidaSnapReal = ui._saidaRess, ui._saidaSnap

  local function encontrarCartas(p)
    local def = nil
    for _ = 1, 400 do
      local c = jogo.novaCarta(p)
      if c and jogo.ehDefesa(c) then def = c break end
    end
    if not def then
      error("reacao-remota: nao sortearam defesa para o teste")
    end
    -- Ataque sintetico compativel com a defesa sorteada: tipo que ela
    -- bloqueia, negativo, com alvo e chance 1. Assim a janela sempre abre
    -- e a defesa e consumida ao defender (sem depender de sorteio).
    local atk = {
      id = 999, nome = "Ataque Remoto", tipo = def.protegeContra or "ACAO",
      classe = "Efeito", uid = "atk-remota", chanceSucesso = 1,
      precisaAlvo = true, dinheiroEm = "alvo",
      alteracaoSaldoBase = -100, alteracaoSaldoFalha = 0, efeito = nil,
    }
    return def, atk
  end

  -- HOST -------------------------------------------------------------------
  local pH = jogo.criarPartida({ n = 2, nomes = { "HOST", "CLIENTE" } })
  pH.vez, pH.jogadasTurno = 1, 0
  local defH, atkH = encontrarCartas(pH)
  defH.uid, atkH.uid = "def-remota-host", "atk-remota-host"
  -- Garante o bloqueio/consumo da defesa (a mitigacao ja consome de qualquer
  -- forma; o bloqueio de efeito depende do sucesso do ataque).
  atkH.chanceSucesso = 1
  pH.jogadores[2].isIA = false
  pH.jogadores[1].mao = { atkH }
  pH.jogadores[2].mao = { defH }
  -- Nova regra: a defesa precisa estar ARMADA no slot antes do ataque.
  jogo.armarDefesa(pH, 2, defH.uid)

  local pedido = nil
  local filaReacao = {}
  local multHost = {
    estado = function()
      return { jogadores = { { assento = 1, id = 0 }, { assento = 2, id = 77 } } }
    end,
    consumirSaios = function() return {} end,
    consumirPartida = function() return filaReacao end,
    emPartida = function() return true end,
    partidaEncerrada = function() return nil end,
    enviarPartida = function(self, assento, msg)
      if msg.tipo == "PEDIR_REACAO" then pedido = msg end
      return true
    end,
    marcarSincronizado = function() end,
  }
  mult, redeModo, partida = multHost, "host", pH
  tela, fase = "jogo", "JOGADOR"
  batalhaIniciada, introBatAtiva, arenaN = true, false, nil
  qc.ativo, qc.pendente = nil, nil

  -- A leva do host nao pode ser aplicada antes da resposta do cliente.
  executarLote({ atkH }, nil, 2, nil)
  if not pedido or pedido.tipo ~= "PEDIR_REACAO" or not pedido.seq then
    error("reacao-remota: host nao enviou PEDIR_REACAO com seq")
  end
  if not qc.pendente or qc.pendente.alvo ~= 2 then
    error("reacao-remota: janela remota do host nao abriu")
  end
  if #pH.jogadores[1].mao ~= 1 or #pH.jogadores[2].mao ~= 0 then
    error("reacao-remota: cartas foram aplicadas antes da resposta")
  end

  -- Resposta com seq antigo deve ser ignorada.
  qc.resolverRemota(nil, nil, pedido.seq - 1)
  if not qc.pendente then
    error("reacao-remota: resposta de janela anterior nao foi ignorada")
  end

  filaReacao[1] = { id = 77, msg = { tipo = "REACAO", seq = pedido.seq,
    uid = defH.uid, origem = "slot" } }
  processarPartidaRede()
  if qc.pendente then
    error("reacao-remota: janela do host nao fechou apos REACAO")
  end
  local function aindaNaMao(j, uid)
    for _, c in ipairs(j.mao) do
      if c.uid == uid then return true end
    end
    return false
  end
  if aindaNaMao(pH.jogadores[1], atkH.uid)
      or aindaNaMao(pH.jogadores[2], defH.uid) then
    error("reacao-remota: ataque/defesa nao foram resolvidos apos REACAO")
  end
  if pH.jogadores[2].protegido then
    error("reacao-remota: defesa armada nao foi consumida ao defender")
  end
  if not ui._saidaRess or #ui._saidaRess < 2
      or ui._saidaRess[1].carta.uid ~= defH.uid
      or ui._saidaRess[2].carta.uid ~= atkH.uid then
    error("reacao-remota: defesa remota nao foi aplicada antes do ataque")
  end

  -- CLIENTE ----------------------------------------------------------------
  local pC = jogo.criarPartida({ n = 2, nomes = { "HOST", "CLIENTE" } })
  local defC = encontrarCartas(pC)
  defC.uid = "def-remota-cliente"
  pC.jogadores[1].mao = { defC }
  jogo.armarDefesa(pC, 1, defC.uid)

  local resposta, filaPedido = nil, {}
  local multCli = {
    consumirPartida = function() return filaPedido end,
    emPartida = function() return true end,
    partidaEncerrada = function() return nil end,
    marcarSincronizado = function() end,
    enviarParaServidor = function(self, msg) resposta = msg end,
  }
  filaPedido[1] = { id = 0, msg = { tipo = "PEDIR_REACAO", seq = 4321,
    segundos = 2.6, carta = { nome = "ATAQUE REMOTO" } } }
  mult, redeModo, partida = multCli, "cliente", pC
  tela, fase = "jogo", "REDE"
  batalhaIniciada, introBatAtiva = true, false
  qc.ativo, qc.pendente = nil, nil

  processarPartidaRede()
  if not qc.ativo or not qc.ativo.remoto or #qc.ativo.opcoes == 0 then
    error("reacao-remota: cliente nao abriu a janela de resposta")
  end
  qc.resolver(defC.uid, "slot")
  if qc.ativo then
    error("reacao-remota: janela do cliente nao fechou apos responder")
  end
  if not resposta or resposta.tipo ~= "REACAO" or resposta.seq ~= 4321
      or resposta.uid ~= defC.uid or resposta.origem ~= "slot" then
    error("reacao-remota: cliente nao devolveu REACAO valida")
  end
  if #pC.jogadores[1].mao ~= 0 or not pC.jogadores[1].protegido then
    error("reacao-remota: cliente nao deve aplicar a defesa localmente")
  end

  -- Restaura o estado para o resto da suite.
  mult, tela, partida = multReal, telaReal, partidaReal
  redeModo, fase = redeReal, faseReal
  batalhaIniciada, introBatAtiva = batalhaReal, introReal
  arenaN, envioPendente = arenaReal, envioReal
  qc.ativo, qc.pendente, qc.seq = qcAtivo, qcPend, qcSeq
  resultado, filaSaida = resReal, filaReal
  ui._saidaRess, ui._saidaSnap = saidaRessReal, saidaSnapReal
end

-- Smoke do host com IA preenchida (Fase 3): o proximaFase roda a IA so no
-- anfitriao (o turno do humano remoto fica em REDE) e cada passo da
-- sequencia da IA transmite snapshot pelo mult fake — sem voo (a quota de
-- jogadas ja estoura, entao o caminho e comprar/descartar/fim).
function testesRender.hostIA()
  local enviadas = 0
  local multFake = {
    estado = function()
      return {
        papel = "anfitriao",
        jogadores = {
          { assento = 1, id = 0 },
          { assento = 2, id = 1 },
          { assento = 3, id = 2 },
        },
      }
    end,
    enviarPartida = function()
      enviadas = enviadas + 1
      return true
    end,
    consumirPartida = function() return {} end,
    consumirSaios = function() return {} end,
    emPartida = function() return false end,
    partidaEncerrada = function() return nil end,
    -- Identidade: devolve os assentos de IA em ordem (sem sortear). A
    -- embaralhada real e testada no teste unitario de multiplayer.
    embaralharAssentos = function(self, total)
      local t = {}
      for i = #self.estado().jogadores + 1, total do t[#t + 1] = i end
      return t
    end,
  }
  local multReal, telaReal = mult, tela
  local redeReal, partidaReal = redeModo, partida
  local batalhaReal, introReal = batalhaIniciada, introBatAtiva
  local qcAtivo, qcPend, qcSeq = qc.ativo, qc.pendente, qc.seq
  mult = multFake
  redeModo = "host"
  batalhaIniciada = true
  introBatAtiva = false
  tela = "jogo"
  qc.ativo, qc.pendente = nil, nil
  partida = jogo.criarPartida({ n = 3, nomes = { "HOST", "REMOto", "IA_ZE" } })
  partida.jogadores[1].isIA = false
  partida.jogadores[2].isIA = false
  partida.jogadores[3].isIA = true

  -- Mapeamento de fases do host: IA (so aqui), remoto = REDE, eu = JOGADOR.
  partida.vez = 3
  proximaFase()
  if fase ~= "IA" or not iaEstado then
    error("rede-ia: turno da IA no host deveria ser fase IA = " ..
      tostring(fase))
  end
  partida.vez = 2
  proximaFase()
  if fase ~= "REDE" then
    error("rede-ia: turno remoto no host deveria ser REDE = " ..
      tostring(fase))
  end
  partida.vez = 1
  proximaFase()
  if fase ~= "JOGADOR" then
    error("rede-ia: turno proprio no host deveria ser JOGADOR = " ..
      tostring(fase))
  end

  -- Sequencia da IA completa transmitindo snapshot a cada passo.
  partida.vez = 3
  proximaFase()
  -- Quota estourada: o caminho e comprar/descartar/fim, sem voo.
  partida.jogadasTurno = jogo.quotaTurno(partida, partida.vez)
  local antes = enviadas
  for _ = 1, 6 do
    if not iaEstado then break end
    iaEstado.t = 0
    iaMaquina(0)
    -- A IA pode atingir o cliente humano: nesse caso o host abre a janela
    -- remota. O cliente fake responde "deixar passar" para nao travar a
    -- sequencia (o protocolo em si e testado em reacaoRemota).
    if qc.pendente then
      qc.resolverRemota(nil, nil, qc.pendente.seq)
    end
  end
  if iaEstado then
    error("rede-ia: sequencia da IA nao terminou (passo=" ..
      tostring(iaEstado.passo) .. ")")
  end
  if enviadas <= antes then
    error("rede-ia: nenhum snapshot transmitido pela IA (" .. antes ..
      " -> " .. enviadas .. ")")
  end
  if partida.fim then
    if tela ~= "fim" then
      error("rede-ia: fim de partida sem tela fim (tela=" .. tostring(tela) .. ")")
    end
  elseif partida.vez ~= 1 or fase ~= "JOGADOR" then
    error("rede-ia: apos a IA a vez volta ao host (vez=" ..
      tostring(partida.vez) .. " fase=" .. tostring(fase) .. ")")
  end

  -- AI fill (Fase 3):3 humanos na sala + qtdIA=5 => partida de 8.
  -- O n tem que vir explicito (rede.n): os nomes das IAs sao sparse e
  -- #nomes continuaria 2 — so os humanos, com a mesa desenhando vazia.
  local stFake = {
    papel = "anfitriao",
    qtdIA = 5,
    preencherIA = true,
    jogadores = {
      { assento = 1, nome = "HOST", avatar = "1" },
      { assento = 2, nome = "CLI_A", avatar = "2" },
      { assento = 3, nome = "CLI_B", avatar = "3" },
    },
  }
  multFake.estado = function() return stFake end
  multFake.marcarPartida = function() end
  if iniciarPartidaRede() ~= true then
    error("rede-ia: host nao iniciou a mesa com IA preenchida")
  end
  if not partida or #partida.jogadores ~= 8 then
    error("rede-ia: AI fill deveria criar partida de 8 (n=" ..
      tostring(partida and #partida.jogadores) .. ")")
  end
  if arenaN ~= 8 then
    error("rede-ia: AI fill deveria ligar arenaN 8 = " .. tostring(arenaN))
  end
  if partida.jogadores[2].isIA or partida.jogadores[3].isIA then
    error("rede-ia: humanos remotos deveriam ter isIA=false")
  end
  if not partida.jogadores[4].isIA then
    error("rede-ia: cadeiras vazias deveriam virar IA")
  end
  if partida.jogadores[1].nome ~= "HOST" then
    error("rede-ia: nome do anfitriao = " .. tostring(partida.jogadores[1].nome))
  end
  if partida.jogadores[4].nome ~= "DRAGAO" then
    error("rede-ia: nome da IA deveria cair no NOMES_ARENA = "
      .. tostring(partida.jogadores[4].nome))
  end
  if partida.jogadores[4].avatar ~= AVATARES_IA[3] then
    error("rede-ia: avatar da IA = " .. tostring(partida.jogadores[4].avatar))
  end

  -- Restaura o estado para o resto da suite.
  mult = multReal
  tela = telaReal
  redeModo = redeReal
  partida = partidaReal
  batalhaIniciada = batalhaReal
  introBatAtiva = introReal
  arenaN = nil
  iaEstado = nil
  qc.ativo, qc.pendente, qc.seq = qcAtivo, qcPend, qcSeq
end

-- Smoke: saida de um jogador no meio da partida (Fase 3): o host marca o
-- seat como saiu (some da arena, vira eliminado pelas regras), gera o
-- aviso (partida.saida), passa adiante se era a vez dele e a partida SO
-- acaba quando sobra 1 vivo — a partida NUNCA encerra por saida alheia.
local filaSaiosFake, enviadasSaiu
function testesRender.saiu()
  local multFake = {
    consumirPartida = function() return {} end,
    consumirSaios = function()
      local f = filaSaiosFake
      filaSaiosFake = {}
      return f
    end,
    enviarPartida = function() enviadasSaiu = enviadasSaiu + 1 return true end,
    emPartida = function() return true end,
    partidaEncerrada = function() return nil end,
    atualizar = function() end,
    estado = function()
      return {
        papel = "anfitriao",
        jogadores = {
          { assento = 1, id = 0 },
          { assento = 2, id = 1 },
          { assento = 3, id = 2 },
          { assento = 4, id = 3 },
        },
      }
    end,
  }
  local multReal, telaReal = mult, tela
  local redeReal, partidaReal = redeModo, partida
  local batalhaReal, introReal = batalhaIniciada, introBatAtiva
  mult = multFake
  redeModo = "host"
  batalhaIniciada = true
  introBatAtiva = false
  tela = "jogo"
  filaSaiosFake = {}
  enviadasSaiu = 0
  partida = jogo.criarPartida({
    n = 4, nomes = { "HOST", "SAIU_A", "SOBRA_B", "SOBRA_C" },
  })
  for i = 1, 4 do partida.jogadores[i].isIA = false end

  -- Vez do jogador que vai sair: seat marcado, vez passa e nada encerra.
  partida.vez = 2
  filaSaiosFake[#filaSaiosFake + 1] = { assento = 2, nome = "SAIU_A" }
  processarPartidaRede()
  local j2 = partida.jogadores[2]
  if not j2.saiu or not j2.falido or j2.status ~= "ELIMINADO" then
    error("rede-saiu: seat 2 deveria marcar saiu+falido+ELIMINADO = " ..
      tostring(j2.saiu) .. "/" .. tostring(j2.falido) .. "/" ..
      tostring(j2.status))
  end
  if partida.vez ~= 3 then
    error("rede-saiu: vez deveria passar 2 -> 3 = " .. tostring(partida.vez))
  end
  if not partida.saida or partida.saida.nome ~= "SAIU_A"
      or partida.saida.seq ~= 1 then
    error("rede-saiu: aviso de saida nao gerado (seq=" ..
      tostring(partida.saida and partida.saida.seq) .. ")")
  end
  if partida.fim or tela ~= "jogo" then
    error("rede-saiu: partida de 4 nao pode acabar com uma saida")
  end
  if enviadasSaiu <= 0 then
    error("rede-saiu: a saida deveria transmitir snapshot")
  end
  -- O trigger do aviso (amoroso com o seq de saida) roda no love.update.
  saidaToast, saidaSeqVista = nil, nil
  for _ = 1, 3 do love.update(1 / 60) end
  if not saidaToast or saidaToast.texto ~= "JOGADOR SAIU_A SAIU DA PARTIDA" then
    error("rede-saiu: aviso no canto superior direito nao montou = " ..
      tostring(saidaToast and saidaToast.texto))
  end

  -- Sobram 2 adversarios e os dois saem de uma vez: ultimo vivo vence.
  filaSaiosFake[#filaSaiosFake + 1] = { assento = 3, nome = "SOBRA_B" }
  filaSaiosFake[#filaSaiosFake + 1] = { assento = 4, nome = "SOBRA_C" }
  processarPartidaRede()
  if not partida.fim or tela ~= "fim" then
    error("rede-saiu: com 1 vivo a partida deveria acabar (fim=" ..
      tostring(partida and partida.fim) .. " tela=" .. tostring(tela) .. ")")
  end
  if partida.vencedor ~= partida.jogadores[1] then
    error("rede-saiu: host e o ultimo vivo -> vencedor")
  end
  if partida.saida.seq ~= 3 then
    error("rede-saiu: cada saida gera um aviso (seq=" ..
      tostring(partida.saida.seq) .. ")")
  end

  -- Restaura o estado para o resto da suite.
  mult = multReal
  tela = telaReal
  redeModo = redeReal
  partida = partidaReal
  batalhaIniciada = batalhaReal
  introBatAtiva = introReal
  arenaN = nil
  iaEstado = nil
  filaSaiosFake = nil
  enviadasSaiu = nil
  limparEstadoPartida()
end

-- Emoji da partida em rede: host valida e transmite (codigo ruim cai
-- fora), cliente cria o balao pelo broadcast e o balao expira sozinho
-- em DUR_EMOJI (o draw do seletor + balao roda sem erro).
function testesRender.emoji()
  local filaEmojiFake, enviadasEmoji
  -- meuAssento do multFake: 1 no trecho de host (identidade) e 2 no de
  -- cliente (quadro espelhado, para exercitar a conversao global -> local).
  local meuAssentoFake = 1
  local multFake = {
    consumirPartida = function()
      local f = filaEmojiFake
      filaEmojiFake = {}
      return f
    end,
    consumirSaios = function() return {} end,
    enviarPartida = function() enviadasEmoji = enviadasEmoji + 1 return true end,
    enviarParaServidor = function() return true end,
    emPartida = function() return true end,
    partidaEncerrada = function() return nil end,
    atualizar = function() end,
    desenhar = function() end,
    estado = function()
      return {
        papel = "anfitriao",
        meuAssento = meuAssentoFake,
        jogadores = {
          { assento = 1, id = 0 },
          { assento = 2, id = 1 },
          { assento = 3, id = 2 },
        },
      }
    end,
  }
  local multReal, telaReal = mult, tela
  local redeReal, partidaReal = redeModo, partida
  local batalhaReal, introReal = batalhaIniciada, introBatAtiva
  local emojiReal, rectsReal, baloesReal = emojiAberto, emojiRects, baloes
  mult = multFake
  redeModo = "host"
  batalhaIniciada = true
  introBatAtiva = false
  tela = "jogo"
  emojiAberto = nil
  baloes = {}
  filaEmojiFake = {}
  enviadasEmoji = 0
  partida = jogo.criarPartida({
    n = 3, nomes = { "HOST", "CLI_A", "CLI_B" },
  })
  for i = 1, 3 do partida.jogadores[i].isIA = false end

  -- Host recebe o EMOJI de um cliente: balao no seat certo e avisa os 2.
  filaEmojiFake[#filaEmojiFake + 1] =
    { id = 1, msg = { tipo = "EMOJI", codigo = 3 } }
  processarPartidaRede()
  if #baloes ~= 1 or baloes[1].assento ~= 2 or baloes[1].codigo ~= 3 then
    error("rede-emoji: host deveria criar balao (seat 2, codigo 3) = " ..
      #baloes .. "/" .. tostring(baloes[1] and baloes[1].assento) .. "/" ..
      tostring(baloes[1] and baloes[1].codigo))
  end
  if enviadasEmoji ~= 2 then
    error("rede-emoji: broadcast deveria ir pros 2 clientes = " ..
      tostring(enviadasEmoji))
  end

  -- Codigo invalido nao vira balao nem sai do host.
  filaEmojiFake[#filaEmojiFake + 1] =
    { id = 2, msg = { tipo = "EMOJI", codigo = 99 } }
  processarPartidaRede()
  if #baloes ~= 1 or enviadasEmoji ~= 2 then
    error("rede-emoji: codigo 99 deveria ser ignorado (baloes=" ..
      #baloes .. " enviadas=" .. enviadasEmoji .. ")")
  end

  -- Cliente: o broadcast do host vira balao local pelo caminho real. O
  -- assento chega GLOBAL e o quadro do cliente e espelhado (meuAssento 2
  -- num mesa de 3): seat 3 -> display 2 e seat 1 (host) -> display 3.
  redeModo = "cliente"
  meuAssentoFake = 2
  baloes = {}
  filaEmojiFake[#filaEmojiFake + 1] =
    { id = 0, msg = { tipo = "EMOJI", assento = 3, codigo = 1 } }
  processarPartidaRede()
  if #baloes ~= 1 or baloes[1].assento ~= 2 or baloes[1].codigo ~= 1 then
    error("rede-emoji: cliente deveria mapear seat 3 -> display 2 = " ..
      #baloes .. "/" .. tostring(baloes[1] and baloes[1].assento) .. "/" ..
      tostring(baloes[1] and baloes[1].codigo))
  end
  filaEmojiFake[#filaEmojiFake + 1] =
    { id = 0, msg = { tipo = "EMOJI", assento = 1, codigo = 4 } }
  processarPartidaRede()
  if #baloes ~= 2 or baloes[2].assento ~= 3 or baloes[2].codigo ~= 4 then
    error("rede-emoji: cliente deveria mapear seat 1 (host) -> display 3 = " ..
      #baloes .. "/" .. tostring(baloes[2] and baloes[2].assento) .. "/" ..
      tostring(baloes[2] and baloes[2].codigo))
  end

  -- Codigo 5 (Marx piscante, loja): aceito pela rede como os vetoriais.
  redeModo = "host"
  meuAssentoFake = 1
  baloes = {}
  filaEmojiFake[#filaEmojiFake + 1] =
    { id = 2, msg = { tipo = "EMOJI", codigo = 5 } }
  processarPartidaRede()
  if #baloes ~= 1 or baloes[1].codigo ~= 5 or enviadasEmoji ~= 4 then
    error("rede-emoji: codigo 5 deveria vira balao e broadcast = " ..
      #baloes .. "/" .. tostring(baloes[1] and baloes[1].codigo) ..
      "/" .. tostring(enviadasEmoji))
  end
  som.ultimo = nil
  emo.novoBalao(1, 5)
  if som.ultimo ~= "psicar" then
    error("rede-emoji: balao do Marx nao tocou psicar (ultimo=" ..
      tostring(som.ultimo) .. ")")
  end
  -- Codigo 6 (Adam Smith, loja): mesmo caminho do 5 (sprite + psicar).
  baloes = {}
  filaEmojiFake[#filaEmojiFake + 1] =
    { id = 2, msg = { tipo = "EMOJI", codigo = 6 } }
  processarPartidaRede()
  if #baloes ~= 1 or baloes[1].codigo ~= 6 then
    error("rede-emoji: codigo 6 deveria virar balao = " ..
      #baloes .. "/" .. tostring(baloes[1] and baloes[1].codigo))
  end
  som.ultimo = nil
  emo.novoBalao(1, 6)
  if som.ultimo ~= "psicar" then
    error("rede-emoji: balao do Adam nao tocou psicar (ultimo=" ..
      tostring(som.ultimo) .. ")")
  end
  -- Draw com baloes dos codigos 5 e 6: exercita o caminho animado (carrega
  -- os 8 canvases de cada emoji uma vez, ~2-4s — aceito no suite).
  emo.novoBalao(3, 5)
  love.draw()

  -- Expiracao: DUR_EMOJI + folga em passos de 0.05 (update real).
  for _ = 1, math.ceil((DUR_EMOJI + 0.2) / 0.05) do love.update(0.05) end
  if #baloes ~= 0 then
    error("rede-emoji: balao deveria sumir em " .. DUR_EMOJI ..
      "s = " .. #baloes)
  end

  -- Balao novo + seletor aberto no draw (o caminho visual da captura).
  emo.novoBalao(1, 2)
  emojiAberto = true
  love.draw()
  emojiAberto = nil

  -- Restaura o estado para o resto da suite.
  mult = multReal
  tela = telaReal
  redeModo = redeReal
  partida = partidaReal
  batalhaIniciada = batalhaReal
  introBatAtiva = introReal
  emojiAberto = emojiReal
  emojiRects = rectsReal
  baloes = baloesReal
  limparEstadoPartida()
end

function testesRender.completa()
  local r, err = pcall(function()
    madeiraCanvas = madeira.gerar(VW, VH)

    tela = "intro"
    intro = { fase = "andando", t = 0, quadro = 1, tQuadro = 0, espera = 0 }
    som.ultimo = nil
    for _ = 1, 120 do love.update(1 / 60); love.draw() end
    if tela ~= "intro" then
      error("intro terminou cedo (tela=" .. tostring(tela) .. ")")
    end
    if som.ultimo ~= "passo" then
      error("caminhada da intro nao tocou passo (ultimo=" ..
        tostring(som.ultimo) .. ")")
    end
    -- Transicao NATURAL da caminhada para o simbolo da paz (t no fim): o
    -- update troca de fase e dispara a festa.
    intro.t = 3.99
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    if intro.fase ~= "simbolo" then
      error("intro nao passou para o simbolo (fase=" ..
        tostring(intro.fase) .. ")")
    end
    if som.ultimo ~= "festa" then
      error("simbolo da paz nao tocou festa (ultimo=" ..
        tostring(som.ultimo) .. ")")
    end
    -- Simbolo terminado: a logo da Gears foi removida do boot, entao o
    -- simbolo entrega direto a logo do Tormentalia (tela "logo").
    intro.fase = "simbolo"
    intro.quadro = 8
    intro.tQuadro = 0
    intro.espera = 0
    for _ = 1, 80 do love.update(1 / 60); love.draw() end
    if tela ~= "logo" then
      error("simbolo nao avancou direto para a logo do Tormentalia (tela="
        .. tostring(tela) .. ")")
    end
    for _ = 1, 300 do love.update(1 / 60); love.draw() end
    if tela ~= "menu" then
      error("logo nao avancou para menu (tela=" .. tostring(tela) .. ")")
    end

    desenharMenu(1 / 60)

    testesRender.cliente()
    testesRender.reacaoRemota()
    testesRender.hostIA()
    testesRender.saiu()
    testesRender.emoji()

    iniciarJogo()
    -- Partida completa no loop real: seleção em lote (1-2 cartas), vigarice
    -- (modal) e passada. IA reage com até 6s de reação => budget 15000.
    local quadros = 0
    while quadros < 15000 do
      quadros = quadros + 1
      if tela == "jogo" and modalRoubo then
        if #modalRoubo.sel == 0 then
          modalRoubo.sel[1] = modalRoubo.mao[1].uid
        end
        local pend = modalRoubo
        modalRoubo = nil
        modalRects = nil
        executarLote(pend.cartas, { [pend.uidCarta] = pend.sel })
      end
      if tela == "jogo" and podeAgirAgora() then
        local mao = partida.jogadores[1].mao
        if #mao > 0 and love.math.random(100) <= 80 then
          rectsMao = layoutMao(#mao)
          local ordem = {}
          for i = 1, #mao do ordem[i] = i end
          for i = #ordem, 2, -1 do
            local j = love.math.random(i)
            ordem[i], ordem[j] = ordem[j], ordem[i]
          end
          local n = math.min(#ordem, love.math.random(2))
          selUids = {}
          for k = 1, n do
            selUids[k] = mao[ordem[k]].uid
          end
          jogarSelecao()
        else
          passarJogador()
        end
      end
      love.update(1 / 60)
      love.draw()
      if tela == "fim" then break end
    end
    if tela ~= "fim" then
      error("partida nao terminou em 15000 frames (tela=" .. tostring(tela) ..
        " fila=" .. tostring(filaSaida ~= nil) ..
        " modal=" .. tostring(modalRoubo ~= nil) ..
        " voo=" .. tostring(voo ~= nil) ..
        " resultado=" .. tostring(resultado ~= nil))
    end
    desenharFim(1 / 60)

    -- Animacao do painel de fim: no meio do tempo ele esta encolhido e com
    -- o tempo cheio nasce pronto (os dois caminhos rodam aqui dentro).
    ui._fimT = 0
    if ui.fimAnimacao() >= 1 then
      error("fimAnimacao no meio do tempo nao anima")
    end
    ui._fimT = ui.FIM_ANIM + ui.FALSA_ANIM

    -- Derrota vs Adam Smith: balao de zombaria no overlay de fim (forca a
    -- vitoria dele e redesenha — caminho novo do desenharFim).
    partida.vencedor = partida.jogadores[2]
    partida.motivo = nil
    tela = "fim"
    desenharFim(1 / 60)

    -- Botao de teste do duelo classico: a vitoria direta dele abre a
    -- mesma tela de derrota pelo caminho do clique real.
    iniciarJogo()
    partida.vez = 1
    fase = "JOGADOR"
    modalRoubo = nil
    modalRects = nil
    clicado(BTN_ADAM_VENCE.x + BTN_ADAM_VENCE.w / 2,
      BTN_ADAM_VENCE.y + BTN_ADAM_VENCE.h / 2)
    if tela ~= "fim" or partida.vencedor ~= partida.jogadores[2] then
      error("TESTE ADAM VENCE nao abriu a derrota (tela=" .. tostring(tela) ..
        ")")
    end
    ui._fimT = ui.FIM_ANIM + ui.FALSA_ANIM
    desenharFim(1 / 60)
    -- Derrota nao paga: o dinheiro so cai quando o jogador vence.
    local dinDerrota = ui._din.valor()
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    if ui._din.valor() ~= dinDerrota then
      error("derrota pagou dinheiro (" .. tostring(dinDerrota) .. " -> "
        .. tostring(ui._din.valor()) .. ")")
    end

    iniciarJogo()
    desenharJogo(1 / 60)
    local mao2 = partida.jogadores[1].mao
    if #mao2 > 0 then
      selUids = { mao2[1].uid }
      jogarSelecao()
      modalRoubo = nil
      modalRects = nil
    end
    pausado = true
    for _ = 1, 300 do
      love.update(1 / 60)
      love.draw()
    end
    pausado = false
    -- Área segura pelos cliques reais: slot vazio (guardar) e USAR (slot).
    iniciarJogo()
    partida.vez = 1
    fase = "JOGADOR"
    local mao3 = partida.jogadores[1].mao
    if #mao3 > 0 then
      selUids = { mao3[1].uid }
      -- Clicar num slot vazio da Área Segura guarda a carta selecionada.
      local slotG = retAreaPropria(1)
      clicado(slotG.x + slotG.w / 2, slotG.y + slotG.h / 2)
      local cG = partida.jogadores[1].areaSegura[1]
      if not cG then error("clique no slot vazio nao guardou a carta") end
      if #selUids > 0 then error("GUARDAR manteve a selecao da mao") end
      local slot = retAreaPropria()
      clicado(slot.x + slot.w / 2, slot.y + slot.h / 2)
      if selAreaUid ~= cG.uid then
        error("slot da area nao selecionou a carta guardada")
      end
      local usar = retAreaUsar(retAreaPropria())
      clicado(usar.x + usar.w / 2, usar.y + usar.h / 2)
      if partida.jogadores[1].areaSegura[1] then
        error("USAR nao consumiu a carta da area")
      end
      if selAreaUid then error("USAR manteve a selecao da area") end
      resultado = nil
      selAreaUid = nil
      selUids = {}
    end

    -- Zoom da carta: long-press de 600ms abre o modal; o toque fecha.
    iniciarJogo()
    partida.vez = 1
    fase = "JOGADOR"
    desenharJogo(1 / 60)
    local maoZ = partida.jogadores[1].mao
    if #maoZ > 0 and #rectsMao > 0 then
      local rz = rectsMao[1]
      pressCarta = { x = rz.x + rz.w / 2, y = rz.y + rz.h / 2, t = 0,
        uid = maoZ[1].uid }
      for _ = 1, 60 do love.update(1 / 60) end
      if not zoomCarta then error("long-press de 600ms nao abriu o zoom") end
      if zoomCarta.uid ~= maoZ[1].uid then error("zoom abriu a carta errada") end
      desenharJogo(1 / 60)
      zoomPressFechar = true
      solto()
      if zoomCarta then error("toque nao fechou o zoom") end

      -- clique curto (< 600ms): seleção acontece no release, sem zoom.
      pressCarta = { x = rz.x + rz.w / 2, y = rz.y + rz.h / 2, t = 0,
        uid = maoZ[1].uid }
      for _ = 1, 10 do love.update(1 / 60) end
      if zoomCarta then error("clique curto abriu o zoom") end
      if #selUids > 0 then error("clique curto selecionou antes do release") end
      solto()
      if #selUids == 0 then error("clique curto nao selecionou no release") end
      selUids = {}
    end
    pressCarta, zoomCarta, zoomT, zoomPressFechar = nil, nil, 0, false

    -- RESULTADO: clique e ESC dispensam o painel na hora; a placa (ancorada,
    -- sem overlay de tela cheia) não pode cobrir a mão nem sair da tela.
    iniciarJogo()
    partida.vez = 1
    fase = "JOGADOR"
    desenharJogo(1 / 60)
    local maoR = partida.jogadores[1].mao
    if #maoR > 0 then
      resultado = novoResultado({ carta = maoR[1], sucesso = true, chance = 0.9 })
      local pr = ui.bannerResultado(resultado)
      if not pr then error("painel de resultado nao devolveu retangulo") end
      if pr.y + pr.h > MAO_Y - ui.E(10) then
        error(string.format("painel de resultado cobre a mao (fim=%d > %d)",
          pr.y + pr.h, MAO_Y))
      end
      if pr.x < 0 or pr.x + pr.w > VW then
        error("painel de resultado fora da tela")
      end
      ultimoToque = -1
      love.mousepressed(30 * escala + offX, 400 * escala + offY, 1)
      if resultado then error("clique fora nao dispensou o resultado") end
      resultado = novoResultado({ carta = maoR[1], sucesso = false, chance = 0.5 })
      local rr = rectsMao[1]
      ultimoToque = -1
      love.mousepressed((rr.x + 10) * escala + offX, (rr.y + 10) * escala + offY, 1)
      if resultado then error("clique na mao nao dispensou o resultado") end
      if pressCarta then error("clique durante o resultado iniciou pressao") end
      if #selUids > 0 then error("clique durante o resultado selecionou carta") end
      resultado = novoResultado({ carta = maoR[1], sucesso = true, chance = 0.9 })
      love.keypressed("escape")
      if resultado then error("ESC nao dispensou o resultado") end
      if pausado then error("ESC com resultado aberto pausou o jogo") end
      if #maoR >= 2 then
        resultado = novoResultadoLote({
          novaEntrada({ carta = maoR[1], sucesso = true, chance = 0.9 }),
          novaEntrada({ carta = maoR[2], sucesso = false, chance = 0.7 }),
        })
        local pr2 = ui.bannerResultado(resultado)
        if pr2 and pr2.y + pr2.h > MAO_Y - ui.E(10) then
          error(string.format("lote de resultado cobre a mao (fim=%d > %d)",
            pr2.y + pr2.h, MAO_Y))
        end
        if pr2 and (pr2.x < 0 or pr2.x + pr2.w > VW) then
          error("lote de resultado fora da tela")
        end
      end
      resultado = nil
      selUids = {}
    end

    -- ARRASTO: pressão + movimento além do limite reordena a mão, sem
    -- selecionar nada e sem mudar o tamanho da mao.
    iniciarJogo()
    partida.vez = 1
    fase = "JOGADOR"
    desenharJogo(1 / 60)
    local maoD = partida.jogadores[1].mao
    if #maoD >= 3 and #rectsMao >= 3 then
      local uids = {}
      for i, c in ipairs(maoD) do uids[i] = c.uid end
      local rz = rectsMao[1]
      local px0, py0 = rz.x + rz.w / 2, rz.y + rz.h / 2
      pressCarta = { x = px0, y = py0, t = 0, uid = uids[1] }
      love.mousemoved((px0 + ui.E(20)) * escala + offX, py0 * escala + offY)
      if not arrasto then error("movimento alem do limite nao iniciou o arrasto") end
      if pressCarta then error("arrasto manteve a pressao da carta") end
      if arrasto.de ~= 1 then error("arrasto comecou no indice errado") end
      local fim = layoutMao(#maoD - 1)
      local alvoX = fim[#fim].x + fim[#fim].w + ui.E(60)
      love.mousemoved(alvoX * escala + offX, py0 * escala + offY)
      if arrasto.alvo ~= #maoD then
        error(string.format("solta no fim deveria ser %d, veio %s",
          #maoD, tostring(arrasto.alvo)))
      end
      desenharJogo(1 / 60)
      solto()
      if arrasto then error("solto nao encerrou o arrasto") end
      local maoF = partida.jogadores[1].mao
      if #maoF ~= #uids then error("arrasto mudou o tamanho da mao") end
      if maoF[#maoF].uid ~= uids[1] then error("arrasto nao moveu a carta para o fim") end
      if #selUids > 0 then error("arrasto selecionou a carta") end

      -- e a ultima carta de volta para o inicio
      desenharJogo(1 / 60)
      local rzF = rectsMao[#rectsMao]
      local uF = maoF[#maoF].uid
      local pyF = rzF.y + rzF.h / 2
      pressCarta = { x = rzF.x + rzF.w / 2, y = pyF, t = 0, uid = uF }
      love.mousemoved((rzF.x + rzF.w / 2 + ui.E(20)) * escala + offX,
        pyF * escala + offY)
      if not arrasto then error("segundo arrasto nao iniciou") end
      local ini = layoutMao(#maoD - 1)
      love.mousemoved((ini[1].x - ui.E(30)) * escala + offX, pyF * escala + offY)
      if arrasto.alvo ~= 1 then
        error(string.format("solta no inicio deveria ser 1, veio %s",
          tostring(arrasto.alvo)))
      end
      desenharJogo(1 / 60)
      solto()
      if partida.jogadores[1].mao[1].uid ~= uF then
        error("arrasto nao levou a carta para o inicio")
      end
    end
    arrasto, pressCarta, zoomCarta = nil, nil, nil
    zoomT, zoomPressFechar = 0, false
    resultado, selUids = nil, {}

    tela = "menu"
    local itensMenu, flutsMenu = layoutMenu()
    -- Cada botao do menu precisa estar dentro da tela: um Y fora vaza a
    -- coluna pra fora e some com os botoes no jogo real (ja aconteceu).
    for _, it in ipairs(itensMenu) do
      if it.x < 0 or it.y < 0 or it.x + it.w > VW + 1 or it.y + it.h > VH + 1 then
        error("menu: item " .. tostring(it.chave) .. " fora da tela (y="
          .. string.format("%.0f", it.y) .. ")")
      end
    end
    for _, it in ipairs(itensMenu) do
      hover = { x = it.x + it.w / 2, y = it.y + it.h / 2 }
      desenharMenu(1 / 60)
    end
    for _, fl in ipairs(flutsMenu) do
      hover = { x = fl.x + fl.w / 2, y = fl.y + fl.h / 2 }
      desenharMenu(1 / 60)
    end
    hover = { x = -10, y = -10 }

    -- MULTIPLAYER pelo acao (a coluna mudou: UM JOGADOR esta oculto).
    for _, it in ipairs(itensMenu) do
      if it.acao == "multiplayer" then
        clicado(it.x + 4, it.y + 4)
      end
    end
    if tela ~= "multiplayer" then
      error("menu MULTIPLAYER nao abriu a tela de rede (tela="
        .. tostring(tela) .. ")")
    end
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    love.keypressed("escape")
    if tela ~= "menu" then
      error("escape nao saiu da tela multiplayer (tela=" .. tostring(tela) .. ")")
    end
    popups = {}

    -- Smoke: tela LOJA (botao do canto inferior direito -> tela vazia ->
    -- ESC volta; e o caminho do botao VOLTAR pelo clique).
    local itLoja = itensMenu[#itensMenu]
    if itLoja.acao ~= "loja" then
      error("menu: ultimo item nao e o da loja (=" .. tostring(itLoja.acao) .. ")")
    end
    if itLoja.x + itLoja.w < VW - 80 or itLoja.y + itLoja.h < VH - 80 then
      error("menu: loja nao esta no canto inferior direito (fim="
        .. string.format("%.0f,%.0f", itLoja.x + itLoja.w, itLoja.y + itLoja.h)
        .. ")")
    end
    clicado(itLoja.x + itLoja.w / 2, itLoja.y + itLoja.h / 2)
    if tela ~= "loja" then
      error("menu LOJA nao abriu a tela da loja (tela=" .. tostring(tela) .. ")")
    end
    for _ = 1, 3 do love.update(1 / 60); love.draw() end

    -- Compra de avatares (aba AVATARES): saldo +150 -> compra Marx (100)
    -- -> Taylor sem saldo e recusado -> +100 -> compra Taylor -> recompra
    -- recusada -> clique em COMPRADO nao mexe no dinheiro. O clique no
    -- CORPO do card (fora do botao) seleciona e abre o painel do teorico.
    local dBase = ui._din.valor()
    ui._din.ganhar(150)
    if ui._lojaAba ~= "avatares" then
      error("loja: deveria abrir na aba AVATARES (aba="
        .. tostring(ui._lojaAba) .. ")")
    end
    local prodsAv = ui.rectsLoja(VW, VH)
    if #prodsAv ~= 3 or prodsAv[1].id ~= "taylor"
      or prodsAv[2].id ~= "marx" or prodsAv[3].id ~= "mayo" then
      error("loja: esperava 3 avatares (taylor, marx, mayo), veio "
        .. #prodsAv)
    end
    if prodsAv[1].comprado or prodsAv[2].comprado or prodsAv[3].comprado then
      error("loja: produto aparecia comprado sem posse")
    end
    if not ui.rectLojaDetalhe(VW, VH) then
      error("loja: painel de detalhe sumiu na aba de avatares")
    end
    clicado(prodsAv[2].x + 5, prodsAv[2].y + 5)
    if ui._lojaAvatarSel ~= "marx" then
      error("loja: clique no card nao selecionou o marx (sel="
        .. tostring(ui._lojaAvatarSel) .. ")")
    end
    clicado(prodsAv[3].x + 5, prodsAv[3].y + 5)
    if ui._lojaAvatarSel ~= "mayo" then
      error("loja: clique no card nao selecionou o mayo")
    end
    clicado(prodsAv[2].btn.x + 3, prodsAv[2].btn.y + 3)
    if not ui._inv.temAvatar("marx") or ui._din.valor() ~= dBase + 50 then
      error("loja: compra do Marx nao debitou 100 (valor="
        .. ui._din.valor() .. ")")
    end
    clicado(prodsAv[1].btn.x + 3, prodsAv[1].btn.y + 3)
    if ui._inv.temAvatar("taylor") or ui._din.valor() ~= dBase + 50 then
      error("loja: Taylor foi comprado sem saldo")
    end
    if not ui._lojaMsg or ui._lojaMsg.ok then
      error("loja: compra sem saldo nao mostrou erro")
    end
    ui._din.ganhar(100)
    clicado(prodsAv[1].btn.x + 3, prodsAv[1].btn.y + 3)
    if not ui._inv.temAvatar("taylor") or ui._din.valor() ~= dBase + 50 then
      error("loja: compra do Taylor nao debitou 100 (valor="
        .. ui._din.valor() .. ")")
    end
    clicado(prodsAv[2].btn.x + 3, prodsAv[2].btn.y + 3)
    if ui._din.valor() ~= dBase + 50 then
      error("loja: clique em COMPRADO mexeu no dinheiro")
    end

    -- Botao MOEDAS +100 removido: a area antiga fica dentro da tela, mas
    -- clicar nela nao soma mais nada.
    local rMoedLoja = ui.rectMoedasLoja(VW, VH)
    if rMoedLoja.y + rMoedLoja.h > VH - 10 then
      error("loja: area do antigo MOEDAS +100 fora da tela")
    end
    clicado(rMoedLoja.x + 3, rMoedLoja.y + 3)
    if ui._din.valor() ~= dBase + 50 then
      error("loja: area do MOEDAS +100 ainda soma dinheiro (valor="
        .. ui._din.valor() .. ")")
    end
    -- O restante do teste precisa de saldo para os emojis; injeta direto,
    -- ja que o botao de reposicao nao existe mais na tela.
    ui._din.ganhar(200)

    -- Aba EMOJIS: trocar de secao limpa a selecao e mostra os 2 emojis
    -- (karl_marx codigo 5, adam_smith codigo 6); compra por 100 cada ->
    -- posse via temEmoji; recompra recusada sem mexer no saldo.
    local abasLoja = ui.rectsLojaAbas(VW, VH)
    if #abasLoja ~= 3 or abasLoja[1].id ~= "avatares"
      or abasLoja[2].id ~= "emojis" or abasLoja[3].id ~= "pacotes" then
      error("loja: esperava 3 abas (avatares, emojis, pacotes), veio "
        .. #abasLoja)
    end
    clicado(abasLoja[2].x + 3, abasLoja[2].y + 3)
    if ui._lojaAba ~= "emojis" then
      error("loja: clique na aba EMOJIS nao trocou (aba="
        .. tostring(ui._lojaAba) .. ")")
    end
    local prodsEm = ui.rectsLoja(VW, VH)
    if #prodsEm ~= 2 or prodsEm[1].id ~= "karl_marx"
      or prodsEm[1].tipo ~= "emoji" or prodsEm[1].codigo ~= 5
      or prodsEm[2].id ~= "adam_smith" or prodsEm[2].codigo ~= 6 then
      error("loja: esperava 2 emojis (karl_marx, adam_smith) na aba, veio "
        .. #prodsEm)
    end
    clicado(prodsEm[1].btn.x + 3, prodsEm[1].btn.y + 3)
    if not ui._inv.temEmoji("karl_marx") or ui._din.valor() ~= dBase + 150 then
      error("loja: compra do emoji karl_marx nao debitou 100 (valor="
        .. ui._din.valor() .. ")")
    end
    clicado(prodsEm[1].btn.x + 3, prodsEm[1].btn.y + 3)
    if ui._din.valor() ~= dBase + 150 then
      error("loja: recompra do emoji mexeu no saldo")
    end
    clicado(prodsEm[2].btn.x + 3, prodsEm[2].btn.y + 3)
    if not ui._inv.temEmoji("adam_smith") or ui._din.valor() ~= dBase + 50 then
      error("loja: compra do emoji adam_smith nao debitou 100 (valor="
        .. ui._din.valor() .. ")")
    end

    -- Aba PACOTES: secao vazia por enquanto (0 cards) e a area do antigo
    -- MOEDAS +100 nao soma nada; voltar pra AVATARES recoloca os 3 cards.
    clicado(abasLoja[3].x + 3, abasLoja[3].y + 3)
    if ui._lojaAba ~= "pacotes" then
      error("loja: clique na aba PACOTES nao trocou (aba="
        .. tostring(ui._lojaAba) .. ")")
    end
    if #ui.rectsLoja(VW, VH) ~= 0 then
      error("loja: aba PACOTES deveria estar vazia (veio "
        .. #ui.rectsLoja(VW, VH) .. ")")
    end
    clicado(rMoedLoja.x + 3, rMoedLoja.y + 3)
    if ui._din.valor() ~= dBase + 50 then
      error("loja: area do MOEDAS +100 ainda soma na aba PACOTES (valor="
        .. ui._din.valor() .. ")")
    end
    clicado(abasLoja[1].x + 3, abasLoja[1].y + 3)
    if ui._lojaAba ~= "avatares" or #ui.rectsLoja(VW, VH) ~= 3 then
      error("loja: volta pra aba AVATARES falhou")
    end

    love.draw()  -- cartao COMPRADO, painel do teorico e saldo novos

    love.keypressed("escape")
    if tela ~= "menu" then
      error("escape nao saiu da tela loja (tela=" .. tostring(tela) .. ")")
    end
    clicado(itLoja.x + itLoja.w / 2, itLoja.y + itLoja.h / 2)
    if tela ~= "loja" then
      error("reabrir a tela loja falhou (tela=" .. tostring(tela) .. ")")
    end
    if ui._lojaAba ~= "avatares" then
      error("loja: reabrir nao resetou a aba (aba="
        .. tostring(ui._lojaAba) .. ")")
    end
    local rVoltLoja = ui.rectVoltarLoja(VW, VH)
    clicado(rVoltLoja.x + rVoltLoja.w / 2, rVoltLoja.y + rVoltLoja.h / 2)
    if tela ~= "menu" then
      error("VOLTAR da loja nao voltou ao menu (tela=" .. tostring(tela) .. ")")
    end

    -- Com os avatares comprados: a aba AVATARES do perfil cresce para 10
    -- (item 10 na segunda linha de 5 colunas), o taylor e equipavel e
    -- limpar o inventario volta para 8.
    local rPerfInv = ui.rectPerfilMenu(VW, VH)
    clicado(rPerfInv.x + rPerfInv.w / 2, rPerfInv.y + 8)
    if tela ~= "perfil" then
      error("perfil nao abriu com avatares comprados (tela="
        .. tostring(tela) .. ")")
    end
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    -- Abre no RESUMO: as grades das outras abas so existem na propria aba.
    if perfilMod.abaAtual() ~= "resumo" then
      error("perfil nao abriu no RESUMO (aba="
        .. tostring(perfilMod.abaAtual()) .. ")")
    end
    if perfilMod.rectAvatar(1) ~= nil or perfilMod.rectEmoji(1) ~= nil then
      error("grade do perfil apareceu fora da aba dela")
    end
    -- Nav bar da esquerda: clique na aba AVATARES mostra a grade dos
    -- comprados (a grade sobe para caber acima da FICHA do selecionado).
    local rAbaAv = perfilMod.rectAba("avatares")
    if not rAbaAv then error("nav bar do perfil sem o botao AVATARES") end
    clicado(rAbaAv.x + rAbaAv.w / 2, rAbaAv.y + rAbaAv.h / 2)
    if perfilMod.abaAtual() ~= "avatares" then
      error("nav bar nao trocou para AVATARES")
    end
    if not perfilMod.rectAvatar(9) or not perfilMod.rectAvatar(10) then
      error("grade do perfil nao mostrou os avatares comprados")
    end
    if perfilMod.rectAvatar(10).y <= perfilMod.rectAvatar(4).y then
      error("item 10 da grade nao caiu numa linha abaixo")
    end
    local rUltAv = perfilMod.rectAvatar(10)
    if rUltAv.x < rAbaAv.x + rAbaAv.w then
      error("grade de avatares invadiu a nav bar")
    end
    local rFichaAv = perfilMod.rectFicha()
    if not rFichaAv then error("aba AVATARES sem a ficha do avatar") end
    if rUltAv.y + rUltAv.h > rFichaAv.y then
      error("grade de avatares invadiu a ficha do avatar")
    end
    clicado(perfilMod.rectAvatar(9).x + 5, perfilMod.rectAvatar(9).y + 5)
    if perfilMod.selecionado() ~= "taylor" then
      error("grade do perfil nao selecionou o taylor comprado")
    end
    if perfilMod.confirmar().avatar ~= "taylor" then
      error("confirmar do perfil nao levou o taylor comprado")
    end
    -- A ficha segue o avatar selecionado: comprado mostra habilidade +
    -- descricao; padrao nao mostra nenhuma das duas.
    local fTaylor = perfilMod.fichaInfo()
    if fTaylor.nome ~= "FREDERICK TAYLOR" or not fTaylor.hab
      or not fTaylor.desc then
      error("ficha do taylor sem nome/habilidade/descricao")
    end
    clicado(perfilMod.rectAvatar(1).x + 5, perfilMod.rectAvatar(1).y + 5)
    local fPadrao = perfilMod.fichaInfo()
    if fPadrao.nome ~= "AVATAR PADRAO" or fPadrao.hab or fPadrao.desc then
      error("ficha do avatar padrao deveria vir sem habilidade/descricao")
    end
    perfilMod.selecionar("taylor")
    -- Emotes comprados: concede os dois, entra na aba EMOTES (agora 6 itens)
    -- e confirma a troca por toque + o teto de 4.
    ui._inv.conceder("karl_marx")
    ui._inv.conceder("adam_smith")
    perfilMod.iniciar(perfilJogador)
    local rAbaEm = perfilMod.rectAba("emotes")
    clicado(rAbaEm.x + rAbaEm.w / 2, rAbaEm.y + rAbaEm.h / 2)
    if perfilMod.abaAtual() ~= "emotes" then
      error("nav bar nao trocou para EMOTES")
    end
    local rEm5 = perfilMod.rectEmoji(5)
    if not rEm5 or rEm5.codigo ~= 5 then
      error("aba EMOTES nao mostrou o Marx comprado")
    end
    local rEm6 = perfilMod.rectEmoji(6)
    if not rEm6 or rEm6.codigo ~= 6 then
      error("aba EMOTES nao mostrou o Adam Smith comprado")
    end
    local rEm1g = perfilMod.rectEmoji(1)
    if rEm6.y ~= rEm1g.y or rEm6.x <= perfilMod.rectEmoji(4).x then
      error("grade de emotes nao caiu em 6 colunas")
    end
    if perfilMod.equipado(5) then
      error("Marx deveria nascer fora com o teto cheio")
    end
    clicado(rEm5.x + 5, rEm5.y + 5)
    if perfilMod.equipado(5) then
      error("Marx equipou sem vaga (teto de 4)")
    end
    -- desquipa um inicial (vaga) e o Marx entra/sai por toque
    local rEm1 = perfilMod.rectEmoji(1)
    clicado(rEm1.x + 5, rEm1.y + 5)
    clicado(rEm5.x + 5, rEm5.y + 5)
    if not perfilMod.equipado(5) then
      error("Marx nao entrou na vaga aberta")
    end
    clicado(rEm5.x + 5, rEm5.y + 5)
    if perfilMod.equipado(5) then
      error("segundo clique no Marx nao desquipou")
    end
    if #perfilMod.emojis() > 4 then
      error("aba EMOTES passou do teto de 4 equipados")
    end
    ui._inv.limpar()
    perfilMod.iniciar(perfilJogador)
    -- RESUMO: sem nenhuma das grades (so preview do avatar + nick e os
    -- quadros de emotes/cartas selecionados, que nao tem retangulo clicavel).
    if perfilMod.rectAvatar(1) ~= nil or perfilMod.rectEmoji(1) ~= nil then
      error("grade apareceu no RESUMO")
    end
    if perfilMod.rectVoltarAba() ~= nil then
      error("seta de voltar ao resumo apareceu no proprio RESUMO")
    end
    -- CARTAS (aba): so o desenho — grade vazia + deck com 7 slots vagos.
    local rAbaCa = perfilMod.rectAba("cartas")
    clicado(rAbaCa.x + rAbaCa.w / 2, rAbaCa.y + rAbaCa.h / 2)
    if perfilMod.abaAtual() ~= "cartas" then
      error("nav bar nao trocou para CARTAS")
    end
    if perfilMod.rectAvatar(1) ~= nil or perfilMod.rectEmoji(1) ~= nil then
      error("aba CARTAS nao deveria ter grade clicavel (sem cartas ainda)")
    end
    if not perfilMod.rectVoltarAba() then
      error("aba CARTAS sem a seta de voltar ao resumo")
    end
    -- Inventario limpo: as grades voltam ao normal (8 avatares, 4 emotes).
    perfilMod.iniciar(perfilJogador)
    local rAbaAv = perfilMod.rectAba("avatares")
    clicado(rAbaAv.x + rAbaAv.w / 2, rAbaAv.y + rAbaAv.h / 2)
    if perfilMod.rectAvatar(9) ~= nil then
      error("grade do perfil nao voltou para 8 apos limpar")
    end
    local rAbaEm = perfilMod.rectAba("emotes")
    clicado(rAbaEm.x + rAbaEm.w / 2, rAbaEm.y + rAbaEm.h / 2)
    if perfilMod.rectEmoji(5) ~= nil then
      error("aba EMOTES nao voltou para 4 apos limpar o inventario")
    end
    local rVoltInv = perfilMod.rectVoltar()
    clicado(rVoltInv.x + rVoltInv.w / 2, rVoltInv.y + rVoltInv.h / 2)
    if tela ~= "menu" then
      error("voltar do perfil de teste nao voltou ao menu (tela="
        .. tostring(tela) .. ")")
    end

    -- Smoke: tela PERFIL (avatar do menu -> digita -> grid -> voltar ->
    -- reabre -> CONFIRMAR -> menu com perfil atualizado).
    local rPerfMenu = ui.rectPerfilMenu(VW, VH)
    clicado(rPerfMenu.x + rPerfMenu.w / 2, rPerfMenu.y + 8)
    if tela ~= "perfil" then
      error("avatar do menu nao abriu o perfil (tela=" .. tostring(tela) .. ")")
    end
    for _ = 1, 5 do love.update(1 / 60); love.draw() end
    love.textinput("z")
    if not perfilMod.estado().nick:find("z$") then
      error("textinput nao digitou no perfil")
    end
    love.keypressed("backspace")
    if perfilMod.estado().nick ~= "JOGADOR_1" then
      error("backspace nao apagou no perfil")
    end
    -- A grade de avatares vive na aba AVATARES: troca pela nav bar antes.
    local rAbaAv1 = perfilMod.rectAba("avatares")
    clicado(rAbaAv1.x + rAbaAv1.w / 2, rAbaAv1.y + rAbaAv1.h / 2)
    local rItem3 = perfilMod.rectAvatar(3)
    clicado(rItem3.x + rItem3.w / 2, rItem3.y + rItem3.h / 2)
    if perfilMod.selecionado() ~= "3" then
      error("grade do perfil nao selecionou o avatar 3")
    end
    local rVolt = perfilMod.rectVoltar()
    clicado(rVolt.x + rVolt.w / 2, rVolt.y + rVolt.h / 2)
    if tela ~= "menu" then
      error("voltar do perfil nao voltou ao menu (tela=" .. tostring(tela) .. ")")
    end
    clicado(rPerfMenu.x + rPerfMenu.w / 2, rPerfMenu.y + 8)
    if tela ~= "perfil" then
      error("reabrir perfil falhou")
    end
    -- Reabriu no RESUMO: volta para AVATARES antes de clicar no item 3.
    local rAbaAv2 = perfilMod.rectAba("avatares")
    clicado(rAbaAv2.x + rAbaAv2.w / 2, rAbaAv2.y + rAbaAv2.h / 2)
    local rItem3b = perfilMod.rectAvatar(3)
    clicado(rItem3b.x + rItem3b.w / 2, rItem3b.y + rItem3b.h / 2)
    local rConf = perfilMod.rectConfirmar()
    clicado(rConf.x + rConf.w / 2, rConf.y + rConf.h / 2)
    if tela ~= "menu" then
      error("CONFIRMAR do perfil nao voltou ao menu")
    end
    if perfilJogador.avatar ~= "3" then
      error("perfil nao atualizou o avatar (=" .. tostring(perfilJogador.avatar) .. ")")
    end
    -- restaura o perfil padrao para o resto do smoke
    perfilJogador = { nick = "JOGADOR_1", avatar = "1", emojis = { 1, 2, 3, 4 } }
    arte.definirAvatar("1")

    -- Smoke: ARENA (botao fora do menu; abre o painel direto para manter
    -- o smoke do ModalSelecionarJogadores).
    arenaMenu.iniciar()
    tela = "arena_menu"
    for _ = 1, 5 do love.update(1 / 60); love.draw() end
    clicado(4, 4)
    if tela ~= "menu" then
      error("clique fora do painel nao fechou (tela=" .. tostring(tela) .. ")")
    end
    arenaMenu.iniciar()
    tela = "arena_menu"
    local rCancel = arenaMenu.rectCancelar()
    clicado(rCancel.x + rCancel.w / 2, rCancel.y + rCancel.h / 2)
    if tela ~= "menu" then
      error("CANCELAR do painel nao voltou ao menu (tela=" .. tostring(tela) .. ")")
    end
    arenaMenu.iniciar()
    tela = "arena_menu"
    local rLinha2 = arenaMenu.rectLinha(2)
    clicado(rLinha2.x + rLinha2.w / 2, rLinha2.y + rLinha2.h / 2)
    if tela ~= "jogo" or #partida.jogadores ~= 2 then
      error("DUELO do painel nao iniciou partida de 2 (tela=" ..
        tostring(tela) .. " n=" .. tostring(partida and #partida.jogadores) .. ")")
    end

    -- Arena completa com 8 jogadores no loop real (mesa + slots + IA).
    iniciarJogo(8)
    if #partida.jogadores ~= 8 then
      error("ARENA 8: partida tem " .. #partida.jogadores .. " jogadores")
    end
    if not partida.jogadores[8].isIA or partida.jogadores[1].isIA then
      error("ARENA 8: distribuicao humana/IA incorreta")
    end
    desenharJogo(1 / 60)
    local quadros8 = 0
    local viuAreaIA, usouAreaIA = false, false
    while quadros8 < 15000 do
      quadros8 = quadros8 + 1
      for i = 2, #partida.jogadores do
        if #partida.jogadores[i].areaSegura > 0 then viuAreaIA = true end
      end
      if tela == "jogo" and modalRoubo then
        if #modalRoubo.sel == 0 then
          modalRoubo.sel[1] = modalRoubo.mao[1].uid
        end
        local pend8 = modalRoubo
        modalRoubo = nil
        modalRects = nil
        executarLote(pend8.cartas, { [pend8.uidCarta] = pend8.sel },
          pend8.alvos[pend8.alvoSel].idx)
      end
      if tela == "jogo" and podeAgirAgora() then
        local mao8 = partida.jogadores[1].mao
        if #mao8 > 0 and love.math.random(100) <= 80 then
          rectsMao = layoutMao(#mao8)
          local ordem = {}
          for i = 1, #mao8 do ordem[i] = i end
          for i = #ordem, 2, -1 do
            local jt = love.math.random(i)
            ordem[i], ordem[jt] = ordem[jt], ordem[i]
          end
          local nSel8 = math.min(#ordem, love.math.random(2))
          selUids = {}
          for k = 1, nSel8 do selUids[k] = mao8[ordem[k]].uid end
          jogarSelecao()
        else
          passarJogador()
        end
      end
      love.update(1 / 60)
      love.draw()
      if tela == "fim" then break end
    end
    if tela ~= "fim" then
      error("ARENA 8 nao terminou em 15000 frames (tela=" .. tostring(tela) ..
        " turno=" .. tostring(partida.turno) .. " vez=" .. tostring(partida.vez) ..
        " voo=" .. tostring(voo ~= nil) ..
        " res=" .. tostring(resultado ~= nil) ..
        " fila=" .. tostring(filaSaida ~= nil) ..
        " modal=" .. tostring(modalRoubo ~= nil) .. ")")
    end
    -- A IA precisa ter guardado E puxado carta da Area Segura na partida.
    for _, linha in ipairs(partida.log) do
      if linha:find(" da Area Segura ", 1, true) then usouAreaIA = true end
    end
    if not viuAreaIA then
      error("ARENA 8: nenhuma IA guardou carta na Area Segura")
    end
    if not usouAreaIA then
      error("ARENA 8: nenhuma IA puxou/jogou carta da Area Segura")
    end
    desenharFim(1 / 60)
    local d8 = dadosFim()
    if not d8.placares or #d8.placares ~= 8 then
      error("fim da ARENA 8 nao gerou 8 placares")
    end
    if d8.titulo == "OPONENTE VENCEU!" then
      error("fim da ARENA 8 usou titulo de duelo")
    end
    -- JOGAR NOVAMENTE reinicia a MESMA arena (8 jogadores de novo). O clique
    -- so passa depois que a animacao do painel assenta — simula a espera.
    ui._fimT = ui.FIM_ANIM + ui.FALSA_ANIM
    local gF8 = ui.geomFim(VW, VH, 8)
    clicado(gF8.btnNovo.x + 3, gF8.btnNovo.y + 3)
    if tela ~= "jogo" or #partida.jogadores ~= 8 then
      error("JOGAR NOVAMENTE nao reiniciou a arena de 8")
    end

    -- Smoke: animacao de inicio de batalha (IntroBatalha) completa sozinha.
    iniciarJogo()
    introBatAtiva = true
    batalhaIniciada = false
    introBat.iniciar({
      ativo = 0,
      jogadores = {
        { nome = "JOGADOR_1", avatar = arte.avatar("voce") },
        { nome = "Adam Smith", avatar = arte.avatar("ia") },
      },
    })
    local nIntro = 0
    while introBatAtiva and nIntro < 900 do
      nIntro = nIntro + 1
      love.update(1 / 60)
      love.draw()
    end
    if introBatAtiva then
      error("intro de batalha nao terminou em 900 frames")
    end
    if not batalhaIniciada then
      error("intro de batalha nao liberou o turno")
    end

    -- Smoke: tela UM JOGADOR (selecao de ciclos: ilhas + setas que
    -- folheiam o caminho).
    tela = "menu"
    selecao.iniciar()
    tela = "selecao"
    selecao.rolagem(1)
    hover = { x = 640, y = 400 }
    for _ = 1, 30 do love.update(1 / 60); love.draw() end
    -- Trilha da tela: a selecao de ciclos roda o VENTO constante (nao a
    -- musica do menu nem a da batalha).
    if som.musicaUltima ~= "vento" then
      error("selecao: trilha deveria ser o vento (musicaUltima="
        .. tostring(som.musicaUltima) .. ")")
    end
    -- Formato do saldo do HUD (mockup: 9.306 com ponto de milhar).
    if selecao.milhar(9306) ~= "9.306" or selecao.milhar(100) ~= "100"
        or selecao.milhar(1000000) ~= "1.000.000" or selecao.milhar(50) ~= "50"
    then
      error("selecao: saldo do HUD fora do formato 9.306 (milhar="
        .. tostring(selecao.milhar(9306)) .. ")")
    end
    if selecao.clicado(48, 46) ~= "voltar" then
      error("selecao: botao voltar nao devolveu 'voltar'")
    end
    selecao.iniciar()
    tela = "selecao"
    hover = { x = 640, y = 400 }
    selecao.desenhar(hover)
    -- Setas laterais: folheiam as ilhas (Ciclo I <-> Ciclo 2 - A
    -- EFICIENCIA) e param nas pontas do caminho; cada ilha tem a sua roda.
    if selecao.totalCiclos() ~= 2 or selecao.cicloAtual() ~= 1 then
      error("selecao: deveria abrir no Ciclo I de 2 ilhas (ciclos="
        .. tostring(selecao.totalCiclos()) .. " foco="
        .. tostring(selecao.cicloAtual()) .. ")")
    end
    if selecao.clicado(62, 324) ~= nil or selecao.cicloAtual() ~= 1 then
      error("selecao: seta esquerda na primeira ilha nao deveria andar")
    end
    if selecao.clicado(1218, 324) ~= nil or selecao.cicloAtual() ~= 2 then
      error("selecao: seta direita nao folheou para o Ciclo 2")
    end
    local c2 = selecao.ciclo()
    if c2.arte ~= "sel_ilha_2" or #c2.inimigos ~= 6 then
      error("selecao: Ciclo 2 deveria ser a ilha da eficiencia com 6 nos")
    end
    -- Ilha do Ciclo 2: abre a roda dos 6 nos da eficiencia (o ultimo e o
    -- soberano Frederick Taylor, escondido ate ser enfrentado).
    if selecao.clicado(407, 214) ~= nil then
      error("selecao: clique na ilha do Ciclo 2 devolveu acao")
    end
    for _ = 1, 45 do selecao.atualizar(1 / 60); selecao.desenhar(hover) end
    local no1 = selecao.inimigo(1)
    local chefao = selecao.inimigo(7)
    if no1.nome ~= "Operario Desgastado" or no1.avatar ~= "inimigo2_1" then
      error("selecao: primeiro no do Ciclo 2 fora da ordem ("
        .. tostring(no1 and no1.nome) .. ")")
    end
    if chefao.nome ~= "Frederick Taylor" or not chefao.soberano then
      error("selecao: ultimo no do Ciclo 2 deveria ser o soberano Taylor")
    end
    if selecao.rotuloNo(6) ~= "??????" then
      error("selecao: soberano do Ciclo 2 nao comecou oculto (="
        .. tostring(selecao.rotuloNo(6)) .. ")")
    end
    if selecao.clicado(selecao.coordsNo(1)) ~= "iniciar" then
      error("selecao: primeiro no do Ciclo 2 nao abriu o duelo")
    end
    if not selecao.dueloAtual()
        or selecao.dueloAtual().avatar ~= "inimigo2_1" then
      error("selecao: dueloAtual nao apontou o inimigo 1 do Ciclo 2")
    end
    -- De volta ao Ciclo I: trocar a ilha fecha a roda e limpa o duelo.
    if not selecao.selecionarCiclo(1) or selecao.cicloAtual() ~= 1 then
      error("selecao: nao voltou para o Ciclo I")
    end
    if selecao.dueloAtual() ~= nil then
      error("selecao: trocar de ciclo nao limpou o duelo selecionado")
    end
    -- No Ciclo I a ilha reergue a roda do ciclo.
    if selecao.clicado(407, 214) ~= nil then
      error("selecao: clique na ilha nao deveria devolver acao")
    end
    if selecao.clicado(640, 682) ~= nil then
      error("selecao: clique fora da ilha devolveu acao")
    end

    -- Smoke: roda de inimigos (sobe ao clicar na ilha, estilo stage select).
    for _ = 1, 45 do selecao.atualizar(1 / 60); selecao.desenhar(hover) end
    if selecao.clicado(48, 46) ~= nil then
      error("selecao: voltar com a roda aberta nao recolheu os circulos")
    end
    if selecao.clicado(407, 214) ~= nil then
      error("selecao: ilha nao reergueu a roda em silencio")
    end
    for _ = 1, 45 do selecao.atualizar(1 / 60); selecao.desenhar(hover) end
    -- Em MODO_TESTE o progresso nasce zerado: o proximo da fila e o 1.
    if selecao.clicado(selecao.coordsNo(1)) ~= "iniciar" then
      error("selecao: clique no proximo inimigo nao devolveu 'iniciar'")
    end
    local duelSel = selecao.dueloAtual()
    if not duelSel or duelSel.idx ~= 1 or duelSel.avatar ~= "inimigo_5" then
      error("selecao: dueloAtual nao apontou o inimigo 1")
    end
    if selecao.clicado(selecao.coordsNo(2)) ~= nil then
      error("selecao: inimigo bloqueado devolveu acao")
    end
    if not selecao.esc() or selecao.esc() then
      error("selecao: esc da roda/selecao fora do esperado")
    end
    selecao.iniciar()
    tela = "selecao"

    -- Smoke: o clique do MAIN no proximo inimigo abre o duelo do ciclo
    -- (nome + avatar do inimigo na mesa e a marca de duelo de ciclo).
    if selecao.clicado(407, 214) ~= nil then
      error("selecao: ilha nao reergueu a roda (duelo)")
    end
    for _ = 1, 45 do selecao.atualizar(1 / 60); selecao.desenhar(hover) end
    clicado(selecao.coordsNo(1))
    if not ui._vs.ativo() then
      error("ciclo: clique no inimigo nao abriu a tela de VS")
    end
    love.draw()
    for _ = 1, 20 do love.update(1 / 60); love.draw() end
    ui._vs.pular()
    if tela ~= "jogo" then
      error("ciclo: clique do main no inimigo nao abriu o duelo")
    end
    if not partida or partida.jogadores[2].nome ~= "Consumidor Desesperado"
        or partida.jogadores[2].avatar ~= "inimigo_5" then
      error("ciclo: duelo nao pegou nome/avatar do inimigo 1")
    end
    if not ui._cicloDuelo then
      error("ciclo: ui._cicloDuelo nao marcado no duelo do ciclo")
    end
    if not selecao.dueloAtual() then
      error("ciclo: dueloAtual sumiu durante o duelo")
    end
    -- Desenha o duelo do ciclo (fundo da arena do ciclo + zoom fechado).
    love.draw()

    -- Botao de teste da arena "TESTE: VOCE VENCE": vitoria direta do
    -- jogador abre o fim e o hook do love.update libera o proximo no.
    -- dinBase cobre vitorias de smokes anteriores (relativo, nao 0).
    local dinBase = ui._din.valor()
    clicado(BTN_ADAM_VENCE.voce.x + BTN_ADAM_VENCE.voce.w / 2,
      BTN_ADAM_VENCE.voce.y + BTN_ADAM_VENCE.voce.h / 2)
    if tela ~= "fim" or not partida or partida.vencedor ~= partida.jogadores[1] then
      error("ciclo: botao 'VOCE VENCE' nao deu a vitoria ao jogador")
    end
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    if ui._din.valor() ~= dinBase + 10 then
      error("ciclo: vitoria nao pagou 10 (base=" .. tostring(dinBase)
        .. " valor=" .. tostring(ui._din.valor()) .. ")")
    end
    -- Vitoria do jogador: alem do JOGAR NOVAMENTE e do VOLTAR AO MENU, o
    -- painel de fim abre o PROXIMO OPONENTE, que leva direto ao no
    -- recem-liberado (VS -> duelo do 2), sem passar pela roda.
    local gFim = ui.geomFim(VW, VH, 0, true)
    if not gFim.btnProx then
      error("fim: painel de vitoria sem o botao PROXIMO OPONENTE")
    end
    -- A caixa so aceita clique depois da animacao de entrada (0,45s).
    for _ = 1, 40 do love.update(1 / 60); love.draw() end
    clicado(gFim.btnProx.x + gFim.btnProx.w / 2,
      gFim.btnProx.y + gFim.btnProx.h / 2)
    if not ui._vs.ativo() or tela ~= "selecao" then
      error("fim: PROXIMO OPONENTE nao abriu a VS do proximo")
    end
    if ui._vs.avatarInimigo() ~= "inimigo_1" then
      error("fim: VS do proximo nao apontou o inimigo 2 (avatar="
        .. tostring(ui._vs.avatarInimigo()) .. ")")
    end
    love.draw()
    ui._vs.pular()
    if tela ~= "jogo" or not partida
        or partida.jogadores[2].nome ~= "Funcionario Condenado" then
      error("fim: PROXIMO OPONENTE nao abriu o duelo do inimigo 2")
    end
    if selecao.progresso() ~= 1 then
      error("fim: abrir o proximo oponente mexeu no progresso (="
        .. tostring(selecao.progresso()) .. ")")
    end
    love.draw()
    clicado(BTN_ADAM_VENCE.voce.x + BTN_ADAM_VENCE.voce.w / 2,
      BTN_ADAM_VENCE.voce.y + BTN_ADAM_VENCE.voce.h / 2)
    if tela ~= "fim" then
      error("ciclo: vitoria no inimigo 2 nao abriu o fim")
    end
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    if ui._din.valor() ~= dinBase + 20 then
      error("ciclo: vitoria no inimigo 2 nao pagou 20 (base=" .. tostring(dinBase)
        .. " valor=" .. tostring(ui._din.valor()) .. ")")
    end
    local px2, py2 = selecao.coordsProximo()
    local px3, py3 = selecao.coordsNo(3)
    if px2 ~= px3 or py2 ~= py3 then
      error("ciclo: vitoria no inimigo 2 nao liberou o 3 ("
        .. tostring(px2) .. "," .. tostring(py2) .. ")")
    end
    -- Revanche: o inimigo 1 ja derrotado volta a ser clicavel (na roda
    -- o primeiro clique so centraliza o circulo, o segundo abre o duelo), o
    -- bloqueado (4) continua fechado, e vencer a revanche NAO regride o
    -- progresso.
    if selecao.clicado(selecao.coordsNo(1)) ~= nil then
      error("ciclo: clique fora do centro nao centralizou o inimigo 1")
    end
    for _ = 1, 30 do selecao.atualizar(1 / 60) end
    if selecao.clicado(selecao.coordsNo(1)) ~= "iniciar" then
      error("ciclo: inimigo ja derrotado nao permitiu revanche")
    end
    local revancheSel = selecao.dueloAtual()
    if not revancheSel or revancheSel.idx ~= 1 then
      error("ciclo: revanche nao apontou o inimigo 1")
    end
    if selecao.clicado(selecao.coordsNo(4)) ~= nil then
      error("ciclo: inimigo 4 bloqueado devolveu acao na revanche")
    end
    tela = "selecao"
    clicado(selecao.coordsNo(1))
    if ui._vs.ativo() then ui._vs.pular() end
    if tela ~= "jogo" or not partida
        or partida.jogadores[2].nome ~= "Consumidor Desesperado" then
      error("ciclo: revanche nao abriu o duelo do inimigo 1")
    end
    love.draw()
    clicado(BTN_ADAM_VENCE.voce.x + BTN_ADAM_VENCE.voce.w / 2,
      BTN_ADAM_VENCE.voce.y + BTN_ADAM_VENCE.voce.h / 2)
    if tela ~= "fim" then
      error("ciclo: vitoria na revanche nao abriu o fim")
    end
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    if ui._din.valor() ~= dinBase + 30 then
      error("ciclo: vitoria na revanche nao pagou 30 (base=" .. tostring(dinBase)
        .. " valor=" .. tostring(ui._din.valor()) .. ")")
    end
    local rxRev, ryRev = selecao.coordsProximo()
    local rx3, ry3 = selecao.coordsNo(3)
    if rxRev ~= rx3 or ryRev ~= ry3 then
      error("ciclo: vitoria na revanche regrideu o progresso ("
        .. tostring(rxRev) .. "," .. tostring(ryRev) .. ")")
    end
    -- API do chefe: registrar o enfrentamento nao pode dar erro em MODO_TESTE.
    selecao.registrarChefe()
    selecao.iniciar()
    tela = "selecao"

    -- Smoke: CONFIGURACOES (abre pelo botao do menu; volume do som com
    -- clamps + reset do progresso com confirmacao; MODO_TESTE: so memoria,
    -- disco intocado). Sem locals/upvalues novos: completa esta no teto
    -- de 60 upvalues do LuaJIT.
    tela = "menu"
    for _, mIt in ipairs(layoutMenu()) do
      if mIt.acao == "config" then
        clicado(mIt.x + mIt.w / 2, mIt.y + mIt.h / 2)
      end
    end
    if tela ~= "config" then
      error("menu: botao CONFIGURACOES nao abriu a tela de config")
    end
    -- Prepara progresso 1: vitoria real no no 1 (mesma receita do smoke
    -- de ciclo) para o reset ter o que zerar.
    -- Antes do primeiro duelo o chefe aparece oculto (nome = ??????).
    if selecao.rotuloNo(7) ~= "??????" then
      error("selecao: nome do chefe nao comecou oculto (="
        .. tostring(selecao.rotuloNo(7)) .. ")")
    end
    tela = "selecao"
    selecao.irParaCirculos()
    clicado(selecao.coordsNo(1))
    -- A arte da VS segue o inimigo 1 (Consumidor = avatar inimigo_5).
    if ui._vs.ativo() and ui._vs.avatarInimigo() ~= "inimigo_5" then
      error("vs: arte do inimigo 1 nao seguiu o avatar (="
        .. tostring(ui._vs.avatarInimigo()) .. ")")
    end
    if ui._vs.ativo() then ui._vs.pular() end
    if tela ~= "jogo" then
      error("config: smoke nao abriu o duelo para preparar o progresso")
    end
    love.draw()
    clicado(BTN_ADAM_VENCE.voce.x + BTN_ADAM_VENCE.voce.w / 2,
      BTN_ADAM_VENCE.voce.y + BTN_ADAM_VENCE.voce.h / 2)
    for _ = 1, 3 do love.update(1 / 60); love.draw() end
    selecao.vitoria() -- no-op se o fim ja pagou; garante prog=1 senao
    if selecao.progresso() ~= 1 then
      error("config: smoke nao preparou o progresso (="
        .. tostring(selecao.progresso()) .. ")")
    end
    tela = "config"
    -- Volume da musica e dos efeitos: dois controles independentes, cada
    -- um em passos de 10% com clamp proprio - mexer num nao pode mexer no
    -- outro.
    ui._config.definirVolumeMusica(0.5)
    ui._config.definirVolumeEfeitos(0.5)
    clicado(ui._config.RET_MUS_MAIS.x + 2, ui._config.RET_MUS_MAIS.y + 2)
    if ui._config.volumeMusica() ~= 0.6 then
      error("config: + da musica nao subiu (="
        .. tostring(ui._config.volumeMusica()) .. ")")
    end
    if ui._config.volumeEfeitos() ~= 0.5 then
      error("config: + da musica mexeu nos efeitos (="
        .. tostring(ui._config.volumeEfeitos()) .. ")")
    end
    clicado(ui._config.RET_MUS_MENOS.x + 2, ui._config.RET_MUS_MENOS.y + 2)
    clicado(ui._config.RET_MUS_MENOS.x + 2, ui._config.RET_MUS_MENOS.y + 2)
    if ui._config.volumeMusica() ~= 0.4 then
      error("config: - da musica nao desceu (="
        .. tostring(ui._config.volumeMusica()) .. ")")
    end
    for _ = 1, 6 do
      clicado(ui._config.RET_MUS_MENOS.x + 2, ui._config.RET_MUS_MENOS.y + 2)
    end
    if ui._config.volumeMusica() ~= 0 then
      error("config: musica nao zerou no minimo (="
        .. tostring(ui._config.volumeMusica()) .. ")")
    end
    for _ = 1, 11 do
      clicado(ui._config.RET_MUS_MAIS.x + 2, ui._config.RET_MUS_MAIS.y + 2)
    end
    if ui._config.volumeMusica() ~= 1 then
      error("config: musica nao bateu o maximo (="
        .. tostring(ui._config.volumeMusica()) .. ")")
    end
    -- Mesma bateria para os efeitos, provando que o controle e separado.
    clicado(ui._config.RET_EFE_MENOS.x + 2, ui._config.RET_EFE_MENOS.y + 2)
    if ui._config.volumeEfeitos() ~= 0.4 then
      error("config: - dos efeitos nao desceu (="
        .. tostring(ui._config.volumeEfeitos()) .. ")")
    end
    if ui._config.volumeMusica() ~= 1 then
      error("config: - dos efeitos mexeu na musica (="
        .. tostring(ui._config.volumeMusica()) .. ")")
    end
    for _ = 1, 4 do
      clicado(ui._config.RET_EFE_MENOS.x + 2, ui._config.RET_EFE_MENOS.y + 2)
    end
    if ui._config.volumeEfeitos() ~= 0 then
      error("config: efeitos nao zerou no minimo (="
        .. tostring(ui._config.volumeEfeitos()) .. ")")
    end
    for _ = 1, 11 do
      clicado(ui._config.RET_EFE_MAIS.x + 2, ui._config.RET_EFE_MAIS.y + 2)
    end
    if ui._config.volumeEfeitos() ~= 1 then
      error("config: efeitos nao bateu o maximo (="
        .. tostring(ui._config.volumeEfeitos()) .. ")")
    end
    -- Idioma: padrao pt, troca para en (o texto passa a traduzir) e volta;
    -- o painel inteiro reescreve na hora, sem reiniciar.
    if ui._config.idioma() ~= "pt" then
      error("config: idioma padrao nao foi pt (="
        .. tostring(ui._config.idioma()) .. ")")
    end
    clicado(ui._config.RET_IDIOMA_EN.x + 2, ui._config.RET_IDIOMA_EN.y + 2)
    if ui._config.idioma() ~= "en" then
      error("config: EN nao trocou o idioma (="
        .. tostring(ui._config.idioma()) .. ")")
    end
    if ui._config.tr("CONFIGURACOES") ~= "SETTINGS" then
      error("config: EN nao traduziu o titulo (="
        .. tostring(ui._config.tr("CONFIGURACOES")) .. ")")
    end
    clicado(ui._config.RET_IDIOMA_PT.x + 2, ui._config.RET_IDIOMA_PT.y + 2)
    if ui._config.idioma() ~= "pt"
      or ui._config.tr("CONFIGURACOES") ~= "CONFIGURACOES" then
      error("config: voltar para pt nao restaurou o texto")
    end
    -- RESET: o NAO cancela sem tocar; o SIM zera os DERROTADOS.
    clicado(ui._config.RET_RESET.x + 2, ui._config.RET_RESET.y + 2)
    clicado(ui._config.RET_NAO.x + 2, ui._config.RET_NAO.y + 2)
    if selecao.progresso() ~= 1 then
      error("config: NAO do reset nao manteve o progresso")
    end
    clicado(ui._config.RET_RESET.x + 2, ui._config.RET_RESET.y + 2)
    clicado(ui._config.RET_SIM.x + 2, ui._config.RET_SIM.y + 2)
    if selecao.progresso() ~= 0 then
      error("config: reset nao zerou o progresso (="
        .. tostring(selecao.progresso()) .. ")")
    end
    if selecao.rotuloNo(7) ~= "??????" then
      error("selecao: reset nao escondeu o nome do chefe (="
        .. tostring(selecao.rotuloNo(7)) .. ")")
    end
    love.draw() -- painel de config desenha por cima do menu sem erro
    clicado(ui._config.RET_VOLTAR.x + 2, ui._config.RET_VOLTAR.y + 2)
    if tela ~= "menu" then
      error("config: VOLTAR nao voltou ao menu")
    end
    tela = "config"
    love.keypressed("escape")
    if tela ~= "menu" then
      error("config: ESC nao voltou ao menu")
    end
    -- Devolve a tela que o smoke de dialogo logo abaixo espera.
    tela = "selecao"

    -- Dialogo do chefe: na roda aberta, com dueloAtual fingindo o Adam
    -- (dialogo = true), o main no no abre a conversa (sem chamar o duelo);
    -- avancando ate o fim, o ultimo clique dispara o aoFim e a mesa do
    -- ciclo abre de verdade.
    -- Roteiro inteiro no lugar. O texto das falas e do usuario (ele edita o
    -- dialogo livre): a checagem e por faixa, para edicao de conteudo nao
    -- quebrar o smoke, pegando apenas truncamento quebrado.
    local totalDlg = ui._dlg.total()
    if totalDlg < 30 or totalDlg > 60 then
      error("dialogo: total de falas fora da faixa 30..60 e veio "
        .. tostring(totalDlg))
    end
    local realDuelo = selecao.dueloAtual
    selecao.dueloAtual = function()
      local c = realDuelo()
      if not c then return nil end
      local d = {}
      for k, v in pairs(c) do d[k] = v end
      -- Finge o no do Adam (o `dialogo` e o que abre a conversa; o idx 7
      -- fica junto para o resto do roteiro).
      d.idx = 7
      d.dialogo = true
      d.soberano = true
      return d
    end
    selecao.irParaCirculos()
    clicado(selecao.coordsNo(1))
    if not ui._dlg.ativo() then
      error("dialogo: no do chefe nao abriu a conversa")
    end
    if tela ~= "selecao" then
      error("dialogo: conversa abriu com a tela " .. tostring(tela))
    end
    -- Botao PULAR: o clique nele encerra a conversa e vai direto para a
    -- batalha (mesmo caminho do fim natural, sem passar por todas as falas).
    local rxP, ryP, rwP, rhP = ui._dlg.retPular()
    if not rxP or not rwP or rwP <= 0 or rhP <= 0 then
      error("dialogo: botao PULAR sem retangulo com a conversa aberta")
    end
    clicado(rxP + rwP / 2, ryP + rhP / 2)
    if ui._dlg.ativo() then
      error("dialogo: PULAR nao encerrou a conversa")
    end
    if not ui._vs.ativo() then
      error("dialogo: PULAR nao abriu a tela de VS")
    end
    for _ = 1, 20 do love.update(1 / 60); love.draw() end
    ui._vs.pular()
    if tela ~= "jogo" or not partida
        or partida.jogadores[2].nome ~= "Consumidor Desesperado" then
      error("dialogo: PULAR nao foi direto para a batalha")
    end
    -- Reabre a conversa para exercitar tambem o avanco normal linha a linha.
    selecao.iniciar()
    tela = "selecao"
    selecao.irParaCirculos()
    clicado(selecao.coordsNo(1))
    if not ui._dlg.ativo() or tela ~= "selecao" then
      error("dialogo: reabertura apos o PULAR falhou")
    end
    local guardaDlg = 0
    while ui._dlg.ativo() and guardaDlg < 300 do
      guardaDlg = guardaDlg + 1
      clicado(640, 360)
      love.update(1 / 60)
      love.draw()
    end
    if ui._dlg.ativo() then
      error("dialogo: conversa nao terminou em " .. tostring(guardaDlg)
        .. " cliques")
    end
    if not ui._vs.ativo() then
      error("dialogo: fim da conversa nao abriu a tela de VS")
    end
    ui._vs.pular()
    if tela ~= "jogo" or not partida or not ui._cicloDuelo
        or partida.jogadores[2].nome ~= "Consumidor Desesperado" then
      error("dialogo: fim da conversa nao abriu o duelo do ciclo")
    end
    selecao.dueloAtual = realDuelo
    selecao.iniciar()
    tela = "selecao"

    local function passo(n)
      for _ = 1, n do love.update(1 / 60); love.draw() end
    end

    tut.iniciar()
    tela = "tutorial"
    if tut.estado().fase ~= "intro" then
      error("tutorial nao comecou na intro")
    end
    passo(5)
    tut.clicado(640, 360)
    if tut.estado().fraseIdx ~= 2 then
      error("intro nao avancou a frase 2")
    end
    passo(34)
    tut.clicado(640, 360)
    if tut.estado().fraseIdx ~= 3 then
      error("intro nao avancou a frase 3")
    end
    passo(34)
    tut.clicado(640, 360)
    if tut.estado().fase ~= "cena" then
      error("intro nao entrou na cutscene")
    end
    passo(40)

    local cliques = 0
    while not tut.estado().fim and cliques < 6000 do
      cliques = cliques + 1
      local e = tut.estado()
      if e.overlayDeck then
        if not e.revelado then
          local rd = tut.retDeck()
          tut.clicado(rd.x + rd.w / 2, rd.y + rd.h / 2)
          passo(45)
        else
          passo(60)
          local rc = tut.retContinuar()
          tut.clicado(rc.x + rc.w / 2, rc.y + rc.h / 2)
          passo(70)
        end
      else
        tut.clicado(640, 700)
        passo(15)
      end
    end
    if not tut.estado().fim then
      local e = tut.estado()
      error("tutorial nao terminou em " .. tostring(cliques) .. " cliques" ..
        " fase=" .. tostring(e.fase) .. " quadro=" .. tostring(e.indice) ..
        " fala=" .. tostring(e.falaIdx) .. " overlay=" .. tostring(e.overlayDeck) ..
        " rev=" .. tostring(e.revelado) .. " busy=" .. tostring(e.busy) ..
        " pausa=" .. tostring(e.pausa))
    end
    local rFim = tut.retFim()
    if tut.clicado(rFim.principal.x + 3, rFim.principal.y + 3) ~= "jogar" then
      error("painel final nao iniciou o duelo")
    end
    if tut.clicado(rFim.secundario.x + 3, rFim.secundario.y + 3) ~= "menu" then
      error("painel final nao voltou ao menu")
    end
    tut.debug("quadro6")
    passo(30)
    tut.debug("quadro13")
    passo(30)
    tut.liberar()

    popups = {}
    iniciarJogo()
    for _ = 1, 60 do love.update(1 / 60); love.draw() end
  end)

  if not r then
    print("[FALHOU] renderizacao: " .. tostring(err))
    return false
  end
  print("[OK] renderizacao + partida completa no loop real")
  return true
end

-- Helpers de janela numa tabela local (mesmo motivo do `emo`: o chunk
-- principal tem teto de 200 locals no LuaJIT).
local janela = {}

-- Em telas menores que a janela pedida, maximiza para nao cortar a interface.
function janela.ajustar()
  local ok, mw, mh = pcall(love.window.getDesktopDimensions)
  if not ok or not mw then return end
  -- desktop vem em pixels; a janela pedida esta em unidades logicas
  local dpci = 1
  local okDpi, escala = pcall(love.window.getDPIScale)
  if okDpi and type(escala) == "number" and escala > 0 then dpci = escala end
  local lw, lh = mw / dpci, mh / dpci
  if lw < VW + 40 or lh < VH + 90 then
    pcall(love.window.maximize)
  end
end

function janela.debug(titulo)
  if os.getenv("JOGO_DEBUG") ~= "1" then return end
  local f = io.open("janela_debug.txt", titulo == "inicio" and "w" or "a")
  if not f then return end
  local gw, gh = love.graphics.getDimensions()
  local dmw, dmh = love.window.getDesktopDimensions()
  local mw, mh = love.window.getMode()
  local dpi = love.window.getDPIScale and love.window.getDPIScale()
  f:write(string.format("%s: graphics=%sx%s mode=%sx%s dpci=%s desktop=%sx%s escala=%.3f off=%s,%s\n",
    titulo, tostring(gw), tostring(gh), tostring(mw), tostring(mh), tostring(dpi),
    tostring(dmw), tostring(dmh), escala, tostring(offX), tostring(offY)))
  f:close()
end

-- Trava a tela no paisagem (Android/iOS): se o sistema abriu na vertical,
-- troca os lados — a razao de aspecto (largura > altura) e o que pede o
-- paisagem no SDL. No desktop nao faz nada.
function janela.travar()
  local osNome = love.system.getOS()
  if osNome ~= "Android" and osNome ~= "iOS" then return end
  local w, h, flags = love.window.getMode()
  if h > w then
    pcall(love.window.setMode, h, w, flags)
    util.recalcularEscala()
  end
end

-- Tela cheia em todas as plataformas. No Android o setFullscreen liga o modo
-- imersivo (esconde a barra de status e a de navegacao), que por cima ficavam
-- sobre o logo/menu e deixavam a tela "baguncada" so no celular; em MODO_TESTE
-- a suite roda janelada (chamado so fora do modo teste).
function janela.telaCheia()
  pcall(love.window.setFullscreen, true)
end

function love.load()
  janela.travar()
  arte.carregar()
  som.carregar()
  -- Inventario antes do perfil: sanearAvatar checa a posse na grade.
  ui._inv.carregar()
  perfilJogador = perfilMod.carregar()
  arte.definirAvatar(perfilJogador.avatar)
  ui._din.carregar()
  util.recalcularEscala()
  janela.debug("inicio")
  love.graphics.setBackgroundColor(0, 0, 0)
  madeiraCanvas = madeira.gerar(VW, VH)
  if not MODO_TESTE then
    janela.telaCheia()
    janela.ajustar()
    util.recalcularEscala()
    janela.debug("final")
  end

  if MODO_TESTE then
    -- Semente fixa: suite deterministica (e ajuda a isolar crashes de teardown).
    love.math.setRandomSeed(12345)
    local okLogica = teste.rodar()
    local okRender = true
    if os.getenv("JOGO_SKIP_RENDER") ~= "1" then
      okRender = testesRender.completa()
    end
    -- Reseta estado da GPU antes de sair (evita crash de teardown no Windows).
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setCanvas()
    love.graphics.setLineWidth(1)
    love.event.quit((okLogica and okRender) and 0 or 1)
  elseif os.getenv("JOGO_TELA") == "menu" then
    tela = "menu"
  elseif os.getenv("JOGO_TELA") == "config" then
    -- Captura da tela de configuracoes (volume + reset do progresso).
    ui._config.abrir()
    tela = "config"
  elseif os.getenv("JOGO_TELA") == "sobre" then
    -- Captura da tela de criadores (fotos, papeis, site e versao).
    ui._sobre.abrir()
    tela = "sobre"
  elseif os.getenv("JOGO_TELA") == "onboarding" then
    -- Captura/teste do tutorial de primeiro acesso.
    ui._onboarding.iniciar()
    if os.getenv("JOGO_ONB_FASE") then
      ui._onboarding.definirFase(os.getenv("JOGO_ONB_FASE"))
    end
    tela = "onboarding"
  elseif os.getenv("JOGO_TELA") == "loja" then
    -- Captura da loja (JOGO_LOJA_ABA=avatares|emojis|pacotes abre numa
    -- secao; JOGO_LOJA_AV pre-seleciona um avatar no painel de detalhe).
    tela = "loja"
    ui._lojaAba = os.getenv("JOGO_LOJA_ABA") or "avatares"
    ui._lojaAvatarSel = os.getenv("JOGO_LOJA_AV")
    ui._lojaAnimInicio = nil
  elseif os.getenv("JOGO_TELA") == "anim" then
    -- Tela de teste de animacoes e ataque (anim_teste.lua).
    -- JOGO_ANIM_CARTA=<idx> pre-seleciona a carta; JOGO_ANIM_ATACAR=1 dispara o ataque.
    local animTeste = require "anim_teste"
    animTeste.iniciar()
    tela = "anim_teste"
  elseif os.getenv("JOGO_TELA") == "logo" then
    -- Captura da logo pos-intro (usar com JOGO_SHOT; vale 3s ate o menu).
    tela = "logo"
  elseif os.getenv("JOGO_TELA") == "selecao" then
    -- JOGO_CICLO=1|2 escolhe a ilha em foco (captura do Ciclo 2).
    selecao.iniciar()
    local cic = tonumber(os.getenv("JOGO_CICLO"))
    if cic then selecao.selecionarCiclo(cic) end
    tela = "selecao"
  elseif os.getenv("JOGO_TELA") == "mapa" then
    -- Captura da selecao com a roda de inimigos levantada.
    selecao.iniciar()
    selecao.irParaCirculos()
    tela = "selecao"
  elseif os.getenv("JOGO_TELA") == "perfil" then
    -- Captura da tela de perfil (JOGO_PERFIL_AV pre-seleciona, JOGO_PERFIL_NICK
    -- digita o nick, JOGO_PERFIL_ABA=1..4 escolhe a aba da nav bar,
    -- JOGO_PERFIL_EMOTE=<codigo> foca um emote da grade (a demonstracao
    -- anima com JOGO_SHOT em tempos diferentes) e JOGO_EMOJI_CAPTURA=1
    -- concede os emojis da loja na memoria antes de abrir — captura das abas
    -- sem tocar o disco).
    tela = "perfil"
    if os.getenv("JOGO_EMOJI_CAPTURA") ~= nil then
      ui._inv.conceder("karl_marx")
      ui._inv.conceder("adam_smith")
    end
    perfilMod.iniciar(perfilJogador)
    local avPerfil = os.getenv("JOGO_PERFIL_AV")
    if avPerfil then perfilMod.selecionar(avPerfil) end
    local emPerfil = os.getenv("JOGO_PERFIL_EMOTE")
    if emPerfil then perfilMod.focarEmoji(emPerfil) end
    local nickPerfil = os.getenv("JOGO_PERFIL_NICK")
    if nickPerfil then perfilMod.definirNick(nickPerfil) end
    local abaPerfil = os.getenv("JOGO_PERFIL_ABA")
    if abaPerfil then
      local nomeAba = ({ "resumo", "avatares", "emotes", "cartas" })[tonumber(abaPerfil) or 0]
      if nomeAba then perfilMod.mudarAba(nomeAba) end
    end
  elseif os.getenv("JOGO_TELA") == "intro" then
    -- Intro de batalha rodando de verdade (pular so cobre arena/teste).
    iniciarJogo()
  elseif os.getenv("JOGO_TELA") == "fim" then
    -- Captura da tela de derrota vs Adam (usar com JOGO_SHOT): mesmo
    -- caminho do botao de teste, com a intro de batalha ja resolvida.
    iniciarJogo()
    partida.vez = 1
    fase = "JOGADOR"
    modalRoubo = nil
    modalRects = nil
    batalhaIniciada = true
    introBatAtiva = false
    clicado(BTN_ADAM_VENCE.x + BTN_ADAM_VENCE.w / 2,
      BTN_ADAM_VENCE.y + BTN_ADAM_VENCE.h / 2)
  elseif os.getenv("JOGO_TELA") == "vs" then
    -- Captura da tela de VS antes de um duelo do ciclo (usar com
    -- JOGO_SHOT≈1.2 para pegar o impacto do VS no meio). No chefe a
    -- conversa abre antes: pula ela para chegar na VS. JOGO_CICLO=1|2
    -- escolhe a fila, JOGO_VS_IDX forca o inimigo (1..7 no Ciclo I, 1..6
    -- no Ciclo 2) e JOGO_VS_AV o avatar do jogador ("7" mostra a pose
    -- grande do cinza), sem depender do progresso do save.
    selecao.iniciar()
    selecao.irParaCirculos()
    tela = "selecao"
    local idxVS = tonumber(os.getenv("JOGO_VS_IDX"))
    if idxVS then
      -- Nome e arte vemem da propria fila (sem copia da ordem aqui).
      local cfgVSBoot = selecao.inimigo(idxVS)
      ui._vs.iniciar({
        nomeJog = perfilJogador.nick,
        avatarJog = os.getenv("JOGO_VS_AV")
          or tostring(perfilJogador.avatar),
        nomeInimigo = cfgVSBoot.nome,
        avatarInimigo = cfgVSBoot.avatar,
        aoFim = function() end,
      })
    else
      local nxVS, nyVS = selecao.coordsProximo()
      clicado(nxVS, nyVS)
      if ui._dlg.ativo() then
        ui._dlg.pular()
      end
    end
  elseif os.getenv("JOGO_TELA") == "ciclo" then
    -- Captura do duelo do ciclo (fundo da arena do ciclo em foco:
    -- JOGO_CICLO=1|2). Clica no proximo inimigo da fila real do save.
    -- JOGO_ZOOM=1 abre o zoom da 1a carta por cima (sprite + painel de
    -- informacoes).
    selecao.iniciar()
    selecao.irParaCirculos()
    tela = "selecao"
    local nxProx, nyProx = selecao.coordsProximo()
    clicado(nxProx, nyProx)
    -- No chefe o clique abre a conversa antes do duelo: sem JOGO_DIALOGO a
    -- cena avanca ate o duelo comecar (mesmo caminho do jogador); com
    -- JOGO_DIALOGO=1 ela fica na primeira fala para captura e com
    -- JOGO_DIALOGO=<n> avanca ate a fala n.
    local envDlg = os.getenv("JOGO_DIALOGO")
    if envDlg == nil or envDlg == "" then
      local guardaDlg = 0
      while ui._dlg.ativo() and guardaDlg < 300 do
        guardaDlg = guardaDlg + 1
        ui._dlg.clique()
      end
    else
      local alvoDlg = tonumber(envDlg) or 1
      while ui._dlg.ativo() and ui._dlg.idxAtual() < alvoDlg do
        ui._dlg.clique()
      end
    end
    -- A tela de VS abre antes do duelo (direto, ou no fim da conversa do
    -- chefe): para a captura da mesa, pula a animacao na hora.
    if ui._vs.ativo() then
      ui._vs.pular()
    end
    batalhaIniciada = true
    introBatAtiva = false
    -- JOGO_FIM_CICLO=1: vence o duelo na hora para capturar o painel de
    -- vitoria do ciclo (com o PROXIMO OPONENTE); usar JOGO_SHOT>=1 para a
    -- caixa terminar a animacao de entrada.
    if os.getenv("JOGO_FIM_CICLO") ~= nil then
      clicado(BTN_ADAM_VENCE.voce.x + BTN_ADAM_VENCE.voce.w / 2,
        BTN_ADAM_VENCE.voce.y + BTN_ADAM_VENCE.voce.h / 2)
    end
    if os.getenv("JOGO_ZOOM") ~= nil and partida
        and #partida.jogadores[1].mao > 0 then
      zoomCarta = partida.jogadores[1].mao[1]
      zoomT = 1
    end
  elseif os.getenv("JOGO_TELA") == "arena_menu" then
    -- Captura do painel "Quantos jogadores?" (JOGO_SIM_MENU=1 usa o titulo
    -- da simulacao).
    tela = "arena_menu"
    arenaMenu.iniciar(os.getenv("JOGO_SIM_MENU") and "SIMULAR PARTIDA" or nil)
  elseif os.getenv("JOGO_TELA") == "multiplayer" then
    -- Captura da tela de rede: lobby por padrao; JOGO_MULTI=sala abre a
    -- sala com um convidado simulado (injecao via processar, sem rede).
    mult = multiplayer.novo()
    mult:iniciar(perfilJogador)
    tela = "multiplayer"
    if os.getenv("JOGO_MULTI") == "sala" and mult:criarSala() then
      mult:processar({ tipo = "mensagem", id = 99,
        msg = { tipo = "ENTRAR", nick = "CONVIDADO", avatar = "3" } })
      mult:processar({ tipo = "mensagem", id = 99,
        msg = { tipo = "PRONTO", pronto = true } })
      -- JOGO_CHAT=1 injeta mensagens no chat pelo caminho REAL do host (o
      -- nome sai da lista de jogadores, nao do pacote); JOGO_CHAT=foco deixa
      -- o campo aberto com um rascunho, para a captura do campo em uso.
      local chatSel = os.getenv("JOGO_CHAT")
      if chatSel then
        mult:processar({ tipo = "mensagem", id = 99,
          msg = { tipo = "CHAT", texto = "Boa noite, pessoal!" } })
        mult:estado().chatTexto = "Bora comecar?"
        mult:enviarChat()
        mult:processar({ tipo = "mensagem", id = 99,
          msg = { tipo = "CHAT", texto = "Pronto aqui, pode iniciar." } })
        if chatSel == "foco" then
          mult:estado().chatTexto = "Falta um jogador"
          mult:focarChat()
          -- JOGO_MOVEL=1 finge celular: o par sala+chat sobe para o campo
          -- nao ficar atras do teclado software (captura desse caso).
          if os.getenv("JOGO_MOVEL") then
            multiplayer.aparelhoMovel = true
          end
        end
      end
      -- Auxilios de captura (nao afetam o jogo): JOGO_ARENA=1..9 escolhe a
      -- miniatura, JOGO_IA_QTD a quantidade de IA e JOGO_IA_DIF a
      -- dificuldade visiveis na sala.
      local arenaSel = tonumber(os.getenv("JOGO_ARENA"))
      if arenaSel then mult:estado().arena = arenaSel end
      local qtdSel = tonumber(os.getenv("JOGO_IA_QTD"))
      if qtdSel then
        mult:estado().qtdIA = qtdSel
        mult:estado().preencherIA = qtdSel > 0
      end
      local difSel = tonumber(os.getenv("JOGO_IA_DIF"))
      if difSel then mult:estado().dificuldade = difSel end
    end
    -- JOGO_MULTI=partida: vai direto para o jogo 1v1 em rede (host com um
    -- convidado sintetico), sem animacao de intro (mesmo criterio do
    -- testarRenderizacao).
    if os.getenv("JOGO_MULTI") == "partida" and mult:criarSala() then
      mult:processar({ tipo = "mensagem", id = 99,
        msg = { tipo = "ENTRAR", nick = "CONVIDADO", avatar = "3" } })
      mult:processar({ tipo = "mensagem", id = 99,
        msg = { tipo = "PRONTO", pronto = true } })
      if iniciarPartidaRede() then
        introBat.limpar()
        introBatAtiva = false
        batalhaIniciada = true
        partida.vez = 1
        proximaFase()
        local sel0 = tonumber(os.getenv("JOGO_SELCARTA"))
        if sel0 then
          local mao = partida.jogadores[1].mao
          local i = math.max(1, math.min(math.floor(sel0), #mao))
          selUids = { mao[i].uid }
        end
      end
    end
    -- JOGO_MULTI=mesa: mesa de 8 em rede (Fase 3) — um convidado na sala
    -- + IA preenchendo as 6 cadeiras restantes: o desenho de slots liga
    -- pelo total. Sem intro (mesmo criterio acima).
    if os.getenv("JOGO_MULTI") == "mesa" and mult:criarSala() then
      mult:processar({ tipo = "mensagem", id = 99,
        msg = { tipo = "ENTRAR", nick = "CONVIDADO", avatar = "3" } })
      mult:estado().qtdIA = 6
      mult:estado().preencherIA = true
      if iniciarPartidaRede() then
        introBat.limpar()
        introBatAtiva = false
        batalhaIniciada = true
        partida.vez = 1
        proximaFase()
        local sel0 = tonumber(os.getenv("JOGO_SELCARTA"))
        if sel0 then
          local mao = partida.jogadores[1].mao
          local i = math.max(1, math.min(math.floor(sel0), #mao))
          selUids = { mao[i].uid }
        end
      end
    end
    -- JOGO_SAIO=<seat>: injeta a saida de um jogador com o caminho REAL do
    -- host (aviso no canto superior direito + slot some + arco fecha).
    local saioSeat = tonumber(os.getenv("JOGO_SAIO"))
    if saioSeat and partida and partida.jogadores[saioSeat] then
      aplicarSaidaJogador({ assento = saioSeat,
        nome = partida.jogadores[saioSeat].nome })
    end
    -- JOGO_EMOJI=1 (com JOGO_MULTI=mesa): abre o seletor sobre o proprio
    -- painel + um balao ja na mesa — prova visual da Fase 3 na captura.
    -- JOGO_EMOJI=5/6: balao do emoji de sprite (animado + psicar) e o
    -- seletor ja com ele; concede o emoji na memoria (captura, sem disco).
    local envEmoji = os.getenv("JOGO_EMOJI")
    if envEmoji ~= nil and partida and redeModo then
      local codEmoji = tonumber(envEmoji) or 2
      local prodSpr = ui._inv.emojiPorCodigo(codEmoji)
      if prodSpr then
        ui._inv.conceder(prodSpr.id)
        perfilJogador.emojis = { 1, 2, 3, codEmoji }
      end
      emojiAberto = true
      emo.novoBalao(2, codEmoji)
    end
  elseif os.getenv("JOGO_TELA") == "tutorial" then
    tut.iniciar(os.getenv("JOGO_TUT"))
    tela = "tutorial"
  elseif os.getenv("JOGO_TELA") == "simular" then
    -- Simulacao all-IA para captura/inspecao: JOGO_ARENA=<2..8>.
    iniciarJogo(tonumber(os.getenv("JOGO_ARENA")) or 2, { simulacao = true })
  elseif os.getenv("JOGO_TELA") == "arena" then
    -- JOGO_ARENA=<n> abre o modo ARENA com n jogadores (padrao: duelo).
    iniciarJogo(tonumber(os.getenv("JOGO_ARENA")))
    -- Auxilio de captura (nao afeta o jogo): JOGO_BARRA="sat,prod" fixa
    -- Satisfacao (0..200) e Produtividade (%) do jogador para inspecao visual.
    if os.getenv("JOGO_BARRA") then
      do
        local s, p = os.getenv("JOGO_BARRA"):match("(-?%d+)%s*,%s*(-?%d+)")
        partida.jogadores[1].satisfacao = tonumber(s or 100)
        partida.jogadores[1].produtividade = (tonumber(p) or 0) / 100
      end
    end
    -- Captura: troca a 1a carta da mao por uma carta especifica do catalogo.
    -- Serve para focar ataque/defesa/reacao/zoom sem depender do sorteio.
    local cartaForcada = tonumber(os.getenv("JOGO_CARTA_FORCADA"))
    if cartaForcada and partida and partida.jogadores[1] then
      local cartasCap = require "cartas"
      local baseCap = cartasCap.porId(cartaForcada)
      if baseCap then
        partida.jogadores[1].mao[1] =
          jogo.novaCartaBase(partida.jogadores[1], baseCap)
      end
    end
    -- Captura da Área Segura: JOGO_GUARDAR=1 guarda a primeira da mão; =2
    -- também seleciona a área (exibe o botão USAR); =3 enche os 3 slots.
    -- Vem antes do JOGO_SELCARTA para a captura poder mostrar a área cheia
    -- COM uma carta da mão selecionada.
    local guard = tonumber(os.getenv("JOGO_GUARDAR"))
    if guard then
      partida.vez = 1
      fase = "JOGADOR"
      local quantos = guard >= 3 and jogo.AREA_SEGURA_MAX or 1
      for _ = 1, quantos do
        local maoG = partida.jogadores[1].mao
        if #maoG > 0 and #partida.jogadores[1].areaSegura < jogo.AREA_SEGURA_MAX then
          selUids = { maoG[1].uid }
          guardarSelecionada()
        end
      end
      if guard >= 2 then
        local c = partida.jogadores[1].areaSegura[1]
        if c then selAreaUid = c.uid end
      end
    end
    local sel0 = tonumber(os.getenv("JOGO_SELCARTA"))
    if sel0 then
      local mao = partida.jogadores[1].mao
      local i = math.max(1, math.min(math.floor(sel0), #mao))
      selUids = { mao[i].uid }
      partida.vez = 1
      fase = "JOGADOR"
    end
    -- JOGO_GUARDAR_IA=1: enche a Area Segura do assento 2 (captura do
    -- indicador de mini versos no painel de assento da arena).
    if os.getenv("JOGO_GUARDAR_IA") ~= nil and partida.jogadores[2] then
      local iaG = partida.jogadores[2]
      for _ = 1, jogo.AREA_SEGURA_MAX do
        if #iaG.mao > 0 then
          jogo.colocarAreaSegura(partida, 2, iaG.mao[1].uid)
        end
      end
    end
    -- Captura do modal de zoom (JOGO_ZOOM=1): abre o zoom da 1a carta.
    if os.getenv("JOGO_ZOOM") ~= nil then
      local maoZ = partida.jogadores[1].mao
      if #maoZ > 0 then
        zoomCarta = maoZ[1]
        zoomT = 1
      end
    end
    -- Captura do banner de resultado (JOGO_RESULTADO=1 sucesso, =0 falha,
    -- =2 lote com as 2 primeiras cartas): mostra o zoom sem jogar carta.
    if os.getenv("JOGO_RESULTADO") ~= nil then
      local maoR = partida.jogadores[1].mao
      if #maoR > 0 then
        partida.vez = 1
        fase = "JOGADOR"
        local modo = os.getenv("JOGO_RESULTADO")
        if modo == "2" and #maoR >= 2 then
          resultado = novoResultadoLote({
            novaEntrada({ carta = maoR[1], sucesso = true, chance = 0.9 }),
            novaEntrada({ carta = maoR[2], sucesso = false, chance = 0.7 }),
          })
        else
          resultado = novoResultado({
            carta = maoR[1],
            sucesso = modo ~= "0",
            chance = 0.9,
          })
        end
      end
    end
    -- Captura das animacoes especiais das Curingas: JOGO_CURINGA=<id>
    -- (6/18/19/26/50/51). Dispara a mesma animacao do jogo e deixa o zoom
    -- de resultado aberto pelo tempo dela.
    local envCuringa = tonumber(os.getenv("JOGO_CURINGA") or "")
    if envCuringa and ui._curingas.def({ id = envCuringa }) then
      local c = {
        id = envCuringa,
        nome = ui._curingas.nomeDoId(envCuringa) or "CARTA",
        tipo = "CORINGA", uidNum = envCuringa,
      }
      local vit = partida.jogadores[3] and 3 or 2
      resultado = novoResultadoLote({ novaEntrada({
        carta = c, sucesso = true, chance = 1, vitimaIdx = vit,
      }) })
    end
    -- Captura das habilidades de avatar (JOGO_HABILIDADE=taylor|marx|mayo):
    -- equipa no seat 1 (+ seat 2/3) e, no marx, distorce os saldos e refaz
    -- o inicio de turno para a redistribuicao acontecer na captura.
    local habEnv = os.getenv("JOGO_HABILIDADE")
    if habEnv == "taylor" or habEnv == "marx" or habEnv == "mayo" then
      partida.jogadores[1].avatar = habEnv
      if ehMesa() and partida.jogadores[3] then
        partida.jogadores[3].avatar = habEnv
      elseif partida.jogadores[2] then
        partida.jogadores[2].avatar = habEnv
      end
      if habEnv == "marx" then
        -- Gatilho REAL da redistribuicao: saldos com rico de verdade,
        -- vez no seat 1 (avatar marx) e o mesmo processarInicioTurno do
        -- jogo. popupsSaldo(antes) gera o popup MARX + os +/-R$ 100.
        partida.jogadores[1].saldo = 800
        if partida.jogadores[2] then partida.jogadores[2].saldo = 1600 end
        partida.vez = 1
        fase = "JOGADOR"
        partida.jogadasTurno = 0
        local antesM = snapshotSaldos()
        jogo.processarInicioTurno(partida, partida.vez)
        popupsSaldo(antesM)
      end
    end
    -- Captura do arrasto da mão (JOGO_ARRASTO=<indice>): segura a carta na
    -- metade do movimento para o fim da mão (marcador dourado + carta voando).
    local arr0 = tonumber(os.getenv("JOGO_ARRASTO"))
    if arr0 then
      local maoA = partida.jogadores[1].mao
      local idxA = math.max(1, math.min(math.floor(arr0), #maoA))
      local rectsA = layoutMao(#maoA)
      local rA = rectsA[idxA]
      if rA then
        partida.vez = 1
        fase = "JOGADOR"
        pressCarta = { x = rA.x + rA.w / 2, y = rA.y + rA.h / 2, t = 0,
          uid = maoA[idxA].uid }
        iniciarArrasto(rA.x + rA.w / 2 + ui.E(20), rA.y + rA.h / 2)
        if arrasto then
          local fimA = layoutMao(#maoA - 1)
          local ult = fimA[#fimA]
          moverArrasto(ult.x + ult.w / 2 + ui.E(40), rA.y + rA.h / 2)
          -- Fixa o cursor do OS no mesmo ponto: um move espúrio depois do
          -- hook não teleporta a carta para outro lugar da tela.
          love.mouse.setPosition(
            math.floor(offX + arrasto.x * escala),
            math.floor(offY + arrasto.y * escala))
        end
      end
    end
    -- Captura do hover da mao (JOGO_HOVER=<indice>): posiciona o mouse sobre
    -- a carta para o screenshot do efeito "para frente".
    local hov = tonumber(os.getenv("JOGO_HOVER"))
    if hov then
      local rectsH = layoutMao(#partida.jogadores[1].mao)
      local rh = rectsH[math.max(1, math.min(math.floor(hov), #rectsH))]
      if rh then
        love.mouse.setPosition(
          math.floor(offX + (rh.x + rh.w / 2) * escala),
          math.floor(offY + (rh.y + rh.h / 2) * escala))
      end
    end
    -- Captura do lote real (JOGO_LEVA=1): joga 2 cartas de verdade na hora
    -- (zoom com entradas reais -> saidas voando -> fim de turno).
    if os.getenv("JOGO_LEVA") ~= nil then
      local maoL = partida.jogadores[1].mao
      partida.vez = 1
      fase = "JOGADOR"
      selUids = {}
      local nSel = 0
      for _, c in ipairs(maoL) do
        -- evita a Vigarice, que abriria o modal de roubo antes do lote
        if not (c.efeito and c.efeito.tipo == "ROUBA_CARTAS") then
          nSel = nSel + 1
          selUids[nSel] = c.uid
          if nSel == 2 then break end
        end
      end
      if nSel > 0 then jogarSelecao() end
    end
  end

  if SHOT_SEG then shotT0 = love.timer.getTime() end
  if os.getenv("JOGO_SHOT") then
    local msg = string.format("[dbg] tel=%s sel=%s shot=%s introAtiva=%s batalha=%s selUids=%d tela=%s\n",
      tostring(os.getenv("JOGO_TELA")), tostring(os.getenv("JOGO_SELCARTA")),
      tostring(os.getenv("JOGO_SHOT")), tostring(introBatAtiva),
      tostring(batalhaIniciada), #selUids, tela)
    io.write(msg)
    local f = io.open("dbg_shot.txt", "a")
    if f then f:write(msg) f:close() end
  end
end

function love.resize()
  util.recalcularEscala()
end

-- Android/iOS: o sensor tentou virar para a vertical — devolve na hora.
-- Com t.window.resizable = false o proprio SO ja bloqueia; aqui e a rede
-- de seguranca para aparelhos que ignoram essa flag.
function love.displayrotated(index, orient)
  local osNome = love.system.getOS()
  if osNome ~= "Android" and osNome ~= "iOS" then return end
  if orient == "portrait" or orient == "portraitflipped" then
    local w, h, flags = love.window.getMode()
    if h > w then
      pcall(love.window.setMode, h, w, flags)
      util.recalcularEscala()
    end
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 20)

  -- Tutorial: converte qualquer fim de duelo assistido em vitoria orientada.
  if tela == "fim" and partida and partida.tutorial and ui._onboarding
      and not ui._onboarding.finalizado() then
    ui._onboarding.vitoria()
    tela = "onboarding"
  end

  -- Pre-batalha em rede: durante os 6s da tela preta a partida e a intro
  -- ficam congeladas, mas a rede continua sendo bombeada (INICIADO chega
  -- no cliente e o SNAPSHOT inicial pode ser aplicado por tras do preto).
  if ui._carga.ativo() then
    ui._carga.atualizar(dt)
    if ui._carga.ativo() then
      if mult then
        mult:atualizar(dt)
        processarPartidaRede()
        local motivo = mult:partidaEncerrada()
        if motivo and tela == "jogo" then
          sairPartidaRede(motivo)
        end
      end
      return
    end
  end

  dt = ui._fx.atualizar(dt)
  anim.update(dt)
  ui._impacto.atualizar(dt)
  ui._layout.atualizar(dt)

  -- Musica de fundo (loop infinito): toca enquanto a tela faz parte do
  -- menu (inclusive paineis por cima dela) e para em intro/fim. Na mesa
  -- roda a musica agitada da batalha; na SELECAO DE CICLOS (um jogador,
  -- roda de inimigos) roda o VENTO constante — ceu aberto do caminho.
  if tela == "menu" or tela == "arena_menu" or tela == "multiplayer"
      or tela == "loja" or tela == "config" or tela == "sobre" then
    som.musica("menu")
  elseif tela == "selecao" then
    som.musica("vento")
  elseif tela == "jogo" then
    som.musica("batalha")
  else
    som.pararMusica()
  end

  -- Conversa com o Adam (chefe do ciclo): datilografo e animacoes da cena.
  if ui._dlg.ativo() then
    ui._dlg.atualizar(dt)
  end

  -- Tela de VS antes do duelo do ciclo: impacto, faiscas e saida.
  if ui._vs.ativo() then
    ui._vs.atualizar(dt)
  end

  -- Progresso do ciclo: registra a vitoria assim que o overlay de fim abre
  -- (selecao.vitoria() e idempotente, so grava quando o proximo cai).
  if tela == "fim" and ui._cicloDuelo and partida
      and partida.vencedor == partida.jogadores[1] then
    selecao.vitoria()
  end

  -- Dinheiro: +10 por vitoria do jogador (sem empate); o guard de uma
  -- unica vez por partida fica em dinheiro.premiar (roda a cada frame).
  if tela == "fim" and partida then
    ui._din.premiar(partida)
  end

  -- Animacao de entrada do painel de fim + datilografia da fala do Adam:
  -- corre so enquanto a tela e fim (zera ao sair; em MODO_TESTE o load nao
  -- passa por aqui e o painel nasce pronto com a frase inteira).
  if tela == "fim" then
    ui._fimT = math.min((ui._fimT or 0) + dt, ui.FIM_ANIM + ui.FALSA_ANIM)
  else
    ui._fimT = 0
  end

  -- Rede do multiplayer: bombeia a fila de eventos do ENet (se aberta).
  if mult then mult:atualizar(dt) end

  -- Partida em rede (Fase 2): entrega mensagens de jogo (host aplica
  -- acoes so quando o livro esta livre; cliente espelha snapshots) e cai
  -- fora se o outro lado desconectou no meio da partida.
  if mult then
    processarPartidaRede()
    local motivo = mult:partidaEncerrada()
    if motivo and tela == "jogo" then
      sairPartidaRede(motivo)
      return
    end
  end

  -- Aviso de saida de jogador (host gera em partida.saida; o cliente
  -- recebe o mesmo numero via snapshot — vale para os dois lados).
  if partida and partida.saida and partida.saida.seq ~= saidaSeqVista then
    saidaSeqVista = partida.saida.seq
    local nome = tostring(partida.saida.nome or "?")
    if #nome > 16 then nome = nome:sub(1, 15) .. ".." end
    saidaToast = { texto = ui.tr("JOGADOR") .. " " .. nome .. " "
      .. ui.tr("SAIU DA PARTIDA"), t = 0 }
    som.tocar("saida")
  end
  if saidaToast then
    saidaToast.t = saidaToast.t + dt
    if saidaToast.t >= 4.5 then saidaToast = nil end
  end

  -- Fim da partida: jingle uma unica vez (vitoria/derrota local; empate
  -- conta como vitoria). A tela de fim so existe com a partida viva, entao
  -- o dadosFim do desenho compartilha a mesma garantia.
  if tela == "fim" and not fimTocado and partida then
    fimTocado = true
    local v = partida.vencedor
    local venci = not v or v.empate == true or v == partida.jogadores[1]
    som.tocar(venci and "vitoria" or "derrota")
    -- Slam da tela de fim: clarao curto (ouro na vitoria, vinho na derrota)
    -- e um trauma leve; o painel em si entra pelo ui.fimAnimacao.
    ui._fx.flash(venci and ui.C.OURO or ui.C.VERMELHO, 0.34, 0.20)
    ui._fx.bater(0.28)
  end

  -- Celular: vibra quando a vez passa para o jogador local em partida em
  -- rede (aviso de nao perder o turno). O indice 1 e o jogador local nos
  -- dois lados; a transicao (e nao o estado) dispara, entao o comeco da
  -- partida e a troca de turno dos outros nao vibram.
  if OS_TOQUE and redeModo and partida and not partida.fim
      and partida.vez ~= vezVista then
    if vezVista ~= nil and partida.vez == 1 then
      pcall(love.system.vibrate, 0.5)
    end
    vezVista = partida.vez
  end

  -- Baloes de emoji somem quando a duracao deles acaba (DUR_EMOJI nos
  -- vetoriais; a animacao nos do codigo 5 — o fade final roda no desenho;
  -- aqui so remove).
  for i = #baloes, 1, -1 do
    baloes[i].t = baloes[i].t + dt
    if baloes[i].t >= (baloes[i].dur or DUR_EMOJI) then
      table.remove(baloes, i)
    end
  end

  -- Long-press em carta própria (250ms) abre o zoom; escala 0.5→1 + fade do
  -- overlay (CartaZoomModal). Roda antes de qualquer return do turno.
  if pressCarta then
    pressCarta.t = pressCarta.t + dt
    if pressCarta.t >= 0.25 then
      local c = acharCartaZoom(pressCarta.uid)
      pressCarta = nil
      if c then
        zoomCarta = c
        zoomT = 0
      end
    end
  end
  if zoomCarta then zoomT = zoomT + dt end

  -- Captura offscreen: agenda no tempo pedido e sai depois de alguns
  -- frames (o arquivo so e gravado no fim do frame corrente).
  if SHOT_SEG and shotT0 then
    if shotFase == 0 and love.timer.getTime() - shotT0 >= SHOT_SEG then
      shotFase = 1
        local f = io.open("dbg_shot.txt", "a")
        if f then
          f:write(string.format("[shot] tela=%s fimT=%s fase=%s vez=%s selUids=%d area=%s selArea=%s tempo=%.1f/%.1f exp=%s fila=%s voo=%s res=%s entradas=%s rtempo=%.2f modal=%s batalha=%s intro=%s\n",
            tostring(tela), tostring(ui._fimT),
            tostring(fase), tostring(partida and partida.vez), #selUids,
            tostring(partida and partida.jogadores[1].areaSegura[1] and partida.jogadores[1].areaSegura[1].uid or nil),
            tostring(selAreaUid),
            tempo.restante or -1, tempo.duracao or -1, tostring(tempo.expirado),
            tostring(filaSaida ~= nil), tostring(voo ~= nil),
            tostring(resultado ~= nil),
            tostring(resultado and resultado.entradas and #resultado.entradas or -1),
            resultado and resultado.tempo or -1,
            tostring(modalRoubo ~= nil),
            tostring(batalhaIniciada), tostring(introBatAtiva)))
          f:close()
        end
      love.graphics.captureScreenshot("shot.png")
    elseif shotFase > 0 then
      shotFase = shotFase + 1
      if shotFase >= 4 then
        love.event.quit(0)
        return
      end
    end
  end

  if tela == "intro" then
    intro.t = intro.t + dt
    if intro.fase == "andando" then
      intro.tQuadro = intro.tQuadro + dt
      if intro.tQuadro >= 1 / 8 then
        intro.tQuadro = intro.tQuadro - 1 / 8
        intro.quadro = intro.quadro % 8 + 1
      end
      -- Passo a cada 0.5s (2 batidas por ciclo de 8 quadros = 1s): o
      -- primeiro sai ja no primeiro frame e o resto acompanha o passo.
      intro.passoT = (intro.passoT or 0.5) + dt
      if intro.passoT >= 0.5 then
        intro.passoT = intro.passoT - 0.5
        som.tocar("passo", 0.7)
      end
      if intro.t >= 4 then
        intro.fase = "simbolo"
        intro.t = 0
        intro.quadro = 1
        intro.tQuadro = 0
        -- Ele levantou o simbolo da paz: festa!
        som.tocar("festa")
      end
    elseif intro.quadro < 8 then
      intro.tQuadro = intro.tQuadro + dt
      if intro.tQuadro >= 1 / 6 then
        intro.tQuadro = intro.tQuadro - 1 / 6
        intro.quadro = intro.quadro + 1
        if intro.quadro == 8 then intro.tQuadro = 0 end
      end
    else
      intro.espera = intro.espera + dt
      if intro.espera >= 0.97 then
        -- Simbolo terminado: vai direto para a logo do Tormentalia (a logo
        -- da Gears Studio saiu do boot).
        tela = "logo"
        logoT = 0
      end
    end
    return
  end

  if tela == "logo" then
    logoT = logoT + dt
    -- JOGO_LOGO_SEG prolonga a logo para gravacoes do trailer; sem a
    -- variavel o fluxo normal continua em 3s.
    if logoT >= (tonumber(os.getenv("JOGO_LOGO_SEG")) or 3) then
      if not MODO_TESTE and not os.getenv("JOGO_TELA")
          and ui._onboarding.precisa() then
        ui._onboarding.iniciar()
        tela = "onboarding"
      else
        tela = "menu"
      end
    end
    return
  end

  if tela == "onboarding" then
    ui._onboarding.atualizar(dt)
    return
  end

  if tela == "tutorial" then
    tut.update(dt)
    return
  end

  if tela == "selecao" then
    selecao.atualizar(dt)
    return
  end

  if tela == "perfil" then
    perfilMod.atualizar(dt)
    return
  end

  if tela == "anim_teste" then
    local animTeste = require "anim_teste"
    animTeste.atualizar(dt)
    return
  end

  if resultado then
    resultado.tempo = resultado.tempo + dt
    ui._curingas.atualizar(dt)
    if resultado.tempo >= resultado.dur then
      resultado = nil
      ui._curingas.limpar()
    end
  else
    -- Clique/ESC podem dispensar o resultado antes do tempo: a animacao
    -- especial nao pode continuar sozinha por cima da mesa.
    ui._curingas.limpar()
  end

  -- Feedback represado da jogada: entra quando o zoom de resultado fecha
  -- (seja pelo tempo, clique ou ESC). Numeros SAT/PROD, escudo e falencia.
  if not resultado and not pausado and ui._fbPendente then
    local fb = ui._fbPendente
    ui._fbPendente = nil
    ui._impacto.feedback(partida, fb.ress, fb.snap, fb.x, fb.y,
      posPopup, ui._posSeatFx)
  end
  if not resultado and not pausado and ui._deusPendente then
    ui._deusPendente = nil
    ui._impacto.deusMercado()
  end

  -- Tutorial: a mao do Deus Mercado acompanha o duelo e garante a vitoria.
  if tela == "jogo" and ui._onboarding and ui._onboarding.emBatalha() then
    ui._onboarding.atualizarBatalha(dt, partida)
  end

  if tela ~= "jogo" or pausado then return end

  -- Quick Counter congela o relogio, a IA e o resto da mesa enquanto a
  -- janela de reacao estiver aberta (ou enquanto o host espera o cliente).
  if qc.ativo or qc.pendente then
    qc.atualizar(dt)
    return
  end

  -- Animação de início de batalha: ao terminar, libera o turno real.
  if introBatAtiva then
    if introBat.atualizar(dt) then
      introBat.limpar()
      introBatAtiva = false
      batalhaIniciada = true
      proximaFase()
    end
    return
  end

  -- Meta-eventos V7 (leilao/lojinha/fusao): pausa a mesa.
  if ui._meta and ui._meta.ativo() then
    ui._meta.atualizar(dt)
    return
  end

  -- Cliente em rede: zoom de resultado vindo do host (CARTA_JOGADA), um por
  -- vez e na ordem de chegada — mesma cadencia do duelo local.
  if redeModo == "cliente" and #filaCartasRede > 0 and not resultado
      and not voo and not filaSaida and not modalRoubo then
    resultado = novoResultadoLote(table.remove(filaCartasRede, 1))
  end

  -- Humano eliminado (ARENA N >= 3): passa sozinho, o turno segue girando.
  if partida and not partida.fim and partida.vez == 1
      and partida.jogadores[1].falido and batalhaIniciada and fase == "JOGADOR"
      and not voo and not resultado and not filaSaida and not modalRoubo
      and not pausado then
    passarJogador()
    return
  end

  atualizarTempoTurno(dt)

  -- Passivas ativas (Renda Fixa / Dano Periodico): numeros flutuando com
  -- cadencia propria para a mesa nunca parecer congelada enquanto espera.
  if partida and not resultado and not voo and not filaSaida then
    pas.t = pas.t + dt
    if pas.t >= 1.35 then
      pas.t = 0
      for i, j in ipairs(partida.jogadores) do
        if not j.falido and not j.saiu then
          for _, e in ipairs(j.efeitos or {}) do
            local px, py, tam = posPopup(i)
            if e.tipo == "RENDA_FIXA" then
              ui._impacto.flutuante("RENDA +R$ " .. tostring(e.valor or 0),
                px + ui.E(10), py - ui.E(8), ui.C.OURO, tam, 1.25)
              break
            elseif e.tipo == "DANO_PERIODICO" then
              ui._impacto.flutuante("DANO -R$ " .. tostring(e.valor or 0),
                px + ui.E(10), py - ui.E(8), ui.C.FALHA, tam, 1.25)
              break
            end
          end
        end
      end
    end
  end

  -- Dobra (fold) da mão: anima 0..1 para cada carta conforme a seleção.
  local novoFold = {}
  for _, c in ipairs(partida.jogadores[1].mao) do
    local alvo = 0
    for _, u in ipairs(selUids) do
      if u == c.uid then alvo = 1 break end
    end
    local atual = foldUids[c.uid] or 0
    local nv = atual + (alvo - atual) * math.min(1, dt * 12)
    if math.abs(alvo - nv) < 0.02 then nv = alvo end
    novoFold[c.uid] = nv
  end
  foldUids = novoFold

  -- Driver da saída da leva (voa DEPOIS do zoom, paridade com o React).
  if filaSaida and not voo and not resultado then
    proximaSaida()
    return
  end

  iaMaquina(dt)

  -- Long-press no painel (800ms) = passar o turno.
  if pressPanel then
    local mx, my = util.mouseVirtual()
    if not ui.dentro(mx, my, PAINEL_RECT) then
      pressPanel = nil
    else
      pressPanel = pressPanel + dt
      if pressPanel >= 0.8 then
        pressPanel = nil
        passarJogador()
      end
    end
  end
end

function love.draw()
  -- Mantem escala/offset e o retangulo de tela cheia sincronizados com a
  -- superficie atual (no celular ela pode mudar apos o load).
  util.recalcularEscala()
  local dx, dy = ui._fx.offset()
  love.graphics.push()
  love.graphics.translate(offX + dx, offY + dy)
  love.graphics.scale(escala)

  local dt = love.timer.getDelta()
  if tela == "intro" then
    desenharIntro()
  elseif tela == "logo" then
    desenharLogo()
  elseif tela == "menu" then
    desenharMenu(dt)
  elseif tela == "config" then
    -- Menu ao fundo + painel de configuracoes por cima (igual multiplayer).
    desenharMenu(dt)
    ui._config.desenhar(hover)
  elseif tela == "sobre" then
    ui._sobre.desenhar(hover)
  elseif tela == "onboarding" then
    ui._onboarding.desenhar()
  elseif tela == "arena_menu" then
    desenharArenaMenu(dt)
  elseif tela == "multiplayer" then
    desenharMultiplayer(dt)
  elseif tela == "tutorial" then
    tut.desenhar(hover)
  elseif tela == "selecao" then
    selecao.desenhar(hover)
  elseif tela == "perfil" then
    perfilMod.desenhar(hover)
  elseif tela == "loja" then
    ui.loja({
      larguraVirtual = VW, alturaVirtual = VH,
      hover = { x = hover.x, y = hover.y },
    })
  elseif tela == "jogo" then
    desenharJogo(dt)
    if qc.ativo or qc.pendente then qc.desenhar() end
    if ui._meta and ui._meta.ativo() then
      ui._meta.desenhar()
    end
    if introBatAtiva then
      introBat.desenhar()
    end
    if ui._onboarding and ui._onboarding.emBatalha() then
      ui._onboarding.desenharBatalha()
    end
  elseif tela == "anim_teste" then
    local animTeste = require "anim_teste"
    animTeste.atualizar(dt)
    animTeste.desenhar()
  else
    desenharFim(dt)
  end

  -- Conversa com o Adam: por cima da roda do ciclo (e so la).
  if tela == "selecao" and ui._dlg.ativo() then
    ui._dlg.desenhar()
  end

  -- Tela de VS antes do duelo do ciclo: por cima da roda da selecao.
  if tela == "selecao" and ui._vs.ativo() then
    ui._vs.desenhar()
  end

  -- Emojis da partida em rede: baloes (4s cada) e o seletor de escolha
  -- por cima de tudo da mesa (antes do aviso de saida). Pausa/modal do
  -- roubo ficam por baixo (desenhados dentro de desenharJogo), entao aqui
  -- so renderiza com eles fechados.
  if tela == "jogo" and partida and not pausado and not modalRoubo then
    emo.desenharBaloes()
    if emojiAberto then emo.desenharPainelEmoji() end
  end

  -- Aviso de saida de jogador: canto superior direito (abaixo da pausa),
  -- com fade nos ultimos 0.9s.
  if saidaToast and (tela == "jogo" or tela == "fim") then
    local tam = 15
    local w = ui.larguraTexto(saidaToast.texto, tam) + ui.E(30)
    local h = ui.E(30)
    local x = VW - ui.E(16) - w
    local y = PAUSA.y + PAUSA.h + ui.E(10)
    local a = saidaToast.t > 3.6
      and math.max(0, 1 - (saidaToast.t - 3.6) / 0.9) or 1
    ui.caixa(x, y, w, h, 8, { 0.06, 0.07, 0.14 }, ui.hex "#FFD54F", 1.5,
      0.95 * a)
    ui.txt(saidaToast.texto, x, y + ui.E(7), tam, { 1, 0.84, 0.31 },
      "center", w, a)
  end

  ui._fx.desenharFlash(dt)

  if ui._carga.ativo() then ui._carga.desenhar() end

  love.graphics.pop()
end

function love.mousemoved(x, y)
  hover.x, hover.y = util.paraVirtual(x, y)
  if ui._meta and ui._meta.ativo() then ui._meta.apontar(hover.x, hover.y) end
  if tela == "anim_teste" then
    local animTeste = require "anim_teste"
    animTeste.apontar(hover.x, hover.y)
    return
  end
  if arrasto then
    moverArrasto(hover.x, hover.y)
    return
  end
  if pressCarta then
    if math.abs(hover.x - pressCarta.x) > ui.E(10)
        or math.abs(hover.y - pressCarta.y) > ui.E(10) then
      -- moveu demais: vira arrasto (se a carta está na mão) ou cancela.
      iniciarArrasto(hover.x, hover.y)
    end
  end
end

local function entrada(x, y)
  if ui._carga.ativo() then return end
  if love.timer.getTime() - ultimoToque < 0.2 then return end
  ultimoToque = love.timer.getTime()
  som.tocar("clique")
  local vx, vy = util.paraVirtual(x, y)
  if tela == "onboarding" then
    local acao = ui._onboarding.clicado(vx, vy)
    if acao == "batalha" then
      ui._onboarding.ativarBatalha()
      iniciarJogo(2)
      partida.tutorial = true
    elseif acao == "menu" then
      tela = "menu"
    end
    return
  end
  if os.getenv("JOGO_DEBUG") == "1" then
    local f = io.open("janela_debug.txt", "a")
    if f then
      f:write(string.format("clique bruto=%.1f,%.1f virtual=%.1f,%.1f tela=%s fase=%s sel=%d rets=%d\n",
        x, y, vx, vy, tostring(tela), tostring(fase), #selUids, #rectsMao))
      f:close()
    end
  end

  -- Quick Counter: a janela e modal; so os botoes dela respondem. Enquanto
  -- o host espera a resposta remota, a mesa toda fica travada.
  if tela == "jogo" and qc.pendente then return end
  if tela == "jogo" and qc.ativo then
    for _, r in ipairs(qc.ativo.rects or {}) do
      if ui.dentro(vx, vy, r) then
        if r.passar then
          qc.resolver(nil)
        elseif r.fact then
          qc.resolver(r.fact.uid, r.fact.origem)
        end
        return
      end
    end
    return
  end

  -- Meta-eventos V7: consomem o clique enquanto ativos.
  if tela == "jogo" and ui._meta and ui._meta.ativo() then
    ui._meta.apontar(vx, vy)
    ui._meta.clicado(vx, vy)
    return
  end

  -- Zoom aberto: o toque fecha (overlay onPress do CartaZoomModal).
  if zoomCarta then
    zoomPressFechar = true
    return
  end

  -- Arrasto em andamento: um toque extra não começa outra ação (nem fecha
  -- o resultado) — a solta do dedo/botão principal encerra o arrasto.
  if arrasto then return end

  -- Resultado visível: um clique dispensa o painel na hora (o painel não
  -- bloqueia mais a tela — ver ui.bannerResultado).
  if resultado then
    resultado = nil
    return
  end

  -- Seletor de emoji aberto: toque FORA dele (e fora do proprio painel)
  -- fecha e consome o toque; toque dentro segue para o clicado, que
  -- escolhe o emoji ou fecha no painel.
  if emojiAberto then
    local noSeletor = false
    for _, r in ipairs(emojiRects) do
      if ui.dentro(vx, vy, r) then noSeletor = true break end
    end
    if not noSeletor and not ui.dentro(vx, vy, PAINEL_RECT) then
      emojiAberto = nil
      return
    end
  end

  -- Long-press em carta própria: o clique curto espera o release.
  local alvo = cartaZoomavel(vx, vy)
  if alvo then
    pressCarta = { x = vx, y = vy, t = 0, uid = alvo.uid }
    return
  end

  -- Tela de teste de animacoes: delega para anim_teste.
  if tela == "anim_teste" then
    local animTeste = require "anim_teste"
    animTeste.clicado(vx, vy)
    return
  end

  -- Long-press no painel: começa aqui (o passar acontece no love.update).
  -- Com o seletor aberto o clique no painel vira fechamento (via clicado).
  if tela == "jogo" and batalhaIniciada and not pausado and not modalRoubo
      and not introBatAtiva and not emojiAberto and podeAgirAgora()
      and ui.dentro(vx, vy, PAINEL_RECT) then
    -- Com carta selecionada, o clique no painel e o alvo "voce" da carta
    -- (modo alvo), nao o long-press de passar.
    if ui._alvoModo then
      clicado(vx, vy)
    else
      pressPanel = 0
    end
    return
  end

  clicado(vx, vy)
  if os.getenv("JOGO_DEBUG") == "1" then
    local f = io.open("janela_debug.txt", "a")
    if f then
      f:write(string.format("  -> apos sel=%d\n", #selUids))
      f:close()
    end
  end
end

solto = function()
  if ui._meta and ui._meta.ativo() then
    pressCarta, pressPanel, arrasto, zoomPressFechar = nil, nil, nil, false
    return
  end
  if arrasto then
    soltarArrasto()
    return
  end
  if zoomPressFechar then
    zoomPressFechar = false
    pressCarta = nil
    zoomCarta = nil
    return
  end
  if pressCarta then
    local p = pressCarta
    pressCarta = nil
    if not zoomCarta then
      clicado(p.x, p.y)
    end
    return
  end
  if pressPanel then
    -- Segurou ate o long-press disparar (passar ja aconteceu) nao abre
    -- nada; soltou cedo (curto) abre/fecha o seletor de emoji (rede).
    local curto = pressPanel < 0.8
    pressPanel = nil
    if curto then emo.alternarPainelEmoji() end
    return
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 or OS_TOQUE then return end
  entrada(x, y)
end

function love.mousereleased(x, y, button)
  if button ~= 1 then return end
  solto()
end

function love.touchpressed(id, x, y)
  if not OS_TOQUE then return end
  local vx, vy = util.paraVirtual(x, y)
  toqueHover = { id = id, x = vx, y = vy }
  entrada(x, y)
end

function love.touchmoved(id, x, y)
  if not OS_TOQUE or not toqueHover or toqueHover.id ~= id then return end
  toqueHover.x, toqueHover.y = util.paraVirtual(x, y)
  if ui._meta and ui._meta.ativo() then ui._meta.apontar(toqueHover.x, toqueHover.y) end
  if arrasto then
    moverArrasto(toqueHover.x, toqueHover.y)
  elseif pressCarta then
    if math.abs(toqueHover.x - pressCarta.x) > ui.E(10)
        or math.abs(toqueHover.y - pressCarta.y) > ui.E(10) then
      iniciarArrasto(toqueHover.x, toqueHover.y)
    end
  end
end

function love.touchreleased(id, x, y)
  if not OS_TOQUE then return end
  if toqueHover and toqueHover.id == id then toqueHover = nil end
  solto()
end

-- Digitacao da tela de perfil (TextInput do TelaPerfil.js).
function love.textinput(text)
  if ui._carga.ativo() then return end
  if tela == "perfil" then
    perfilMod.digitar(text)
  elseif tela == "multiplayer" and mult then
    mult:digitar(text)
  end
end

function love.keypressed(key)
  if ui._carga.ativo() then return end
  if tela == "perfil" and key == "backspace" then
    perfilMod.apagar()
    return
  end
  if tela == "multiplayer" and key == "backspace" then
    if mult then mult:apagar() end
    return
  end
  if tela == "onboarding" then
    local acao = ui._onboarding.tecla(key)
    if acao == "batalha" then
      ui._onboarding.ativarBatalha()
      iniciarJogo(2)
      partida.tutorial = true
    elseif acao == "menu" then
      tela = "menu"
    end
    return
  end
  -- Comparação do fundo do menu: F8 alterna entre o protótipo HTML (novo)
  -- e o vórtice antigo guardado em fundo_menu_vortex.lua.
  if key == "f8" and tela == "menu" then
    local nome = ui.alternarFundoMenu()
    util.adicionarPopup(ui.tr("FUNDO:") .. " " .. nome, VW / 2, VH * 0.10,
      ui.C.OURO, ui.E(18))
    return
  end
  -- F3: mostra os retangulos de painel/faixas/arena usados pelo layout.
  if key == "f3" then
    ui._layout.debug = not ui._layout.debug
    return
  end
  if key == "escape" then
    -- Tela de VS: ESC pula a animacao e vai direto para o duelo (a luta
    -- ja foi escolhida; nao ha cancelar alem do clique).
    if ui._vs.ativo() then
      ui._vs.pular()
      return
    end
    -- Dialogo do chefe: ESC cancela a conversa e deixa a roda aberta
    -- (clicar de novo no no do chefe recomeca do principio).
    if ui._dlg.ativo() then
      ui._dlg.limpar()
      return
    end
    -- Meta-eventos V7: ESC nao pula o evento do Deus Mercado.
    if tela == "jogo" and ui._meta and ui._meta.ativo() then
      return
    end
    if tela == "perfil" then
      tela = "menu"
    elseif tela == "loja" then
      tela = "menu"
    elseif tela == "config" then
      tela = "menu"
    elseif tela == "sobre" then
      tela = "menu"
    elseif tela == "selecao" then
      -- Da roda o ESC recolhe os circulos; na selecao volta ao menu.
      if not selecao.esc() then tela = "menu" end
    elseif tela == "arena_menu" then
      ui._simMenuAberto = nil
      tela = "menu"
    elseif tela == "multiplayer" then
      -- Chat da sala com o campo aberto: ESC so fecha o campo (e o teclado
      -- do celular) — de novo volta ao menu.
      if mult and mult:desfocarChat() then return end
      if mult then mult:fechar() end
      tela = "menu"
    elseif tela == "jogo" then
      if zoomCarta then
        zoomCarta = nil
        zoomPressFechar = false
        pressCarta = nil
      elseif resultado then
        -- ESC dispensa o painel de resultado na hora (item: dispensar).
        resultado = nil
      elseif modalRoubo then
        modalRoubo = nil
        modalRects = nil
      else
        pausado = not pausado
      end
    elseif tela == "anim_teste" then
      tela = "menu"
    elseif tela == "tutorial" then
      tut.liberar()
      tela = "menu"
    end
  elseif tela == "tutorial" then
    tut.tecla(key)
  elseif tela == "multiplayer" and (key == "return" or key == "kp_enter") then
    -- Chat da sala: ENTER manda a mensagem e o campo continua aberto para a
    -- proxima (fora do chat nao ha rascunho, entao nao faz nada).
    if mult then mult:enviarChat() end
  elseif (key == "space" or key == "return") and ui._dlg.ativo() then
    -- Dialogo do chefe: espaco/enter avanca igual ao clique.
    ui._dlg.clique()
  elseif key == "p" and ui._dlg.ativo() then
    -- Dialogo do chefe: P pula a conversa e vai direto para a batalha.
    ui._dlg.pular()
  elseif (key == "space" or key == "return") and ui._vs.ativo() then
    -- Tela de VS: espaco/enter avanca igual ao clique.
    ui._vs.clique()
  elseif key == "p" and ui._vs.ativo() then
    -- Tela de VS: P pula direto para o duelo.
    ui._vs.pular()
  elseif (key == "space" or key == "return") and tela == "intro" then
    tela = "logo"
    logoT = 0
  elseif (key == "space" or key == "return") and tela == "logo" then
    tela = "menu"
  elseif key == "space" and tela == "jogo" and batalhaIniciada
      and fase == "JOGADOR" and not voo and not resultado
      and not modalRoubo and not filaSaida and not pausado then
    passarJogador()
  elseif key == "r" and tela == "fim" then
    iniciarJogo(arenaN,
      (partida and partida.simulacao) and { simulacao = true }
      or (ui._cicloDuelo and { ciclo = true } or nil))
  end
end

function love.wheelmoved(dx, dy)
  if tela == "selecao" then
    selecao.rolagem(dy)
  elseif tela == "tutorial" then
    tut.rolagem(dx)
  end
end
