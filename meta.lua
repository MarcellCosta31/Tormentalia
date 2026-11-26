-- Meta-eventos do manual V7: Curinga global, Leilao, Lojinha e Fusao, alem
-- das pilhas da mesa (Defesa / Jogadas / Curinga) e do Visor de Curingas.
-- Fica fora do main por causa do limite de 200 locals do LuaJIT.
local ui = require "ui"
local jogo = require "jogo"
local som = require "som"
local cartas = require "cartas"
local arte = require "arte"

local M = {}

local VW, VH = 1280, 720
local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"

M.fase = nil
M.partida = nil
M.aoFechar = nil
M.t = 0
M.bannerT = 0
M.hover = { x = -1, y = -1 }
M.rects = {}
M.leilao = nil
M.lojinha = nil
M.roleta = nil
-- "host" ou "cliente" quando o meta-evento roda em rede; nil = local.
M.rede = nil
M.aoMudar = nil
M.aoLance = nil
M.aoConfirmar = nil
M.confirmado = false
M.resultadoPendente = false

local function viva(j)
  return j and not j.falido and not j.saiu
end

-- Duracao dos meta-eventos. Na simulacao all-IA o humano nao decide nada:
-- mantem a cena visivel, mas encurta os 15s de leilao/lojinha para 4s.
local function duracaoMeta(seg, teste)
  if MODO_TESTE then return teste or 0.8 end
  if M.partida and M.partida.simulacao then return math.min(seg, 4) end
  return seg
end

local function dentro(x, y, r)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function M.ativo()
  return M.fase ~= nil
end

local function limpar()
  if M.partida then
    M.partida.eventoMeta = false
    M.partida.fusao = nil
    -- O snapshot em rede usa estes campos para abrir/fechar o meta no
    -- cliente; limpar aqui encerra o espelho quando o host volta a mesa.
    M.partida.metaFase = nil
    M.partida.metaT = nil
    M.partida.metaRodada = nil
  end
  M.fase = nil
  M.partida = nil
  M.aoFechar = nil
  M.t = 0
  M.bannerT = 0
  M.rects = {}
  M.leilao = nil
  M.lojinha = nil
  M.roleta = nil
  M.fusaoSel = {}
  M.fusaoResultado = nil
  M.rede = nil
  M.aoMudar = nil
  M.aoLance = nil
  M.aoConfirmar = nil
  M.confirmado = false
  M.resultadoPendente = false
end

function M.cancelar()
  limpar()
end

-- Curingas globais possíveis (ids do catalogo que o motor suporta como global).
local CURINGAS_GLOBAIS = { 6, 18, 19 } -- Monstro Inflação, Seletividade Taylor, Flutuação Mercado

-- Mao do Deus Mercado: na arte o punho fica a ~58.6% da largura e ~96.9% da
-- altura, e o dedo aponta ~0.186 rad a esquerda da vertical. A roleta gira em
-- torno do punho e compensa esse desvio para acertar a carta sorteada.
local MAO_PIVO_X, MAO_PIVO_Y = 0.586, 0.969
local MAO_GIRO = 0.186

-- Catalogo por id (CARTAS é uma lista; o id nao deve ser usado como indice).
local CARTA_POR_ID = {}
for _, c in ipairs(cartas.CARTAS) do
  CARTA_POR_ID[c.id] = c
end

-- Publica a fase/tempo no proprio `partida` para o snapshot do host. O
-- cliente ignora esses campos (ele e espelho), mas nao ha custo em mante-los.
local function publicarEstado()
  if not M.partida then return end
  M.partida.metaFase = M.fase
  M.partida.metaT = M.t
  -- metaRodada e do jogo (rodada concluida, setada no fim de turno); nao
  -- sobrescrever com o turno atual.
end

-- Sorteia o Curinga global (ja aplicado em aplicarCuringaGlobal) e arma a
-- roleta para a mao parar apontando exatamente para a carta sorteada.
local function iniciarRoleta(partida)
  M.roleta = nil
  local cg = partida.curingaGlobal
  if not (cg and cg.carta) then return end
  local n = #CURINGAS_GLOBAIS
  local passo = 2 * math.pi / n
  local indice = 1
  for i, id in ipairs(CURINGAS_GLOBAIS) do
    if id == cg.carta.id then indice = i break end
  end
  -- No modo teste a cena e curta; ainda assim a roleta roda inteira (o timer
  -- do leilao fica pausado enquanto ela aparece).
  local dur = MODO_TESTE and 1.1 or 2.8
  -- A carta i fica no angulo -pi/2 + (i-1)*passo. A rotacao final leva em
  -- conta o desvio MAO_GIRO para o dedo (nao o eixo da imagem) apontar para
  -- a carta. O numero de voltas e inteiro para nao "pular" no encaixe.
  local alvo = -math.pi / 2 + (indice - 1) * passo
  local delta = (alvo + math.pi / 2 + MAO_GIRO) % (2 * math.pi)
  local voltas = math.max(6, math.ceil(18 * dur / 3))
  M.roleta = {
    ativa = true,
    mostrar = true,
    t = 0,
    dur = dur,
    hold = 1.2,
    holdT = 0,
    parada = false,
    angulo = 0,
    anguloFinal = voltas * 2 * math.pi + delta,
    indiceFinal = indice,
    itens = CURINGAS_GLOBAIS,
  }
  som.tocar("roleta")
end

function M.abrir(partida, pendente, opts)
  opts = opts or {}
  limpar()
  if not partida or partida.fim then return end
  M.partida = partida
  M.aoFechar = opts.aoFechar
  -- "host"/"cliente" = evento em rede; nil = partida local.
  M.rede = opts.rede
  M.aoMudar = opts.aoMudar
  M.aoLance = opts.aoLance
  M.aoConfirmar = opts.aoConfirmar
  VW = opts.vw or VW
  VH = opts.vh or VH
  M.bannerT = 0

  -- Estado da roleta do curinga global (só no leilão).
  M.roleta = nil

  if pendente == "lojinha" then
    -- Lojinha/fusao continuam fora da rede: o host pula direto para a mesa
    -- depois do leilao, entao este ramo so serve ao fluxo local.
    if M.rede ~= "cliente" then jogo.iniciarLojinha(partida) end
    M.lojinha = partida.lojinha
    M.fase = "lojinha"
    M.t = tonumber(opts.tempo) or duracaoMeta(jogo.LOJINHA_SEGUNDOS)
    M.bannerT = partida.curingaGlobal and 4.5 or 0
    publicarEstado()
    return
  end

  if M.rede == "cliente" then
    -- Cliente: o host ja criou o leilao e aplicou o Curinga global; aqui so
    -- espelhamos. Nunca chamar jogo.iniciarLeilao no cliente (sortearia um
    -- global/produto diferente do host).
    M.leilao = partida.leilao
    M.fase = opts.fase or "leilao"
    M.t = tonumber(opts.tempo) or duracaoMeta(jogo.LEILAO_SEGUNDOS)
    M.bannerT = partida.curingaGlobal and 4.5 or 0
    -- Entrada atrasada (host ja no resultado): nao reabre a roleta.
    if opts.roleta ~= false and M.fase == "leilao" then
      iniciarRoleta(partida)
    end
    publicarEstado()
    return
  end

  jogo.iniciarLeilao(partida)
  M.leilao = partida.leilao
  M.fase = "leilao"
  M.t = duracaoMeta(jogo.LEILAO_SEGUNDOS)
  M.bannerT = partida.curingaGlobal and 4.5 or 0
  iniciarRoleta(partida)
  publicarEstado()
end

function M.fechar()
  if M.fase == "lojinha" and M.partida then jogo.fecharLojinha(M.partida) end
  local cb = M.aoFechar
  limpar()
  if cb then cb() end
end

function M.apontar(x, y)
  M.hover.x, M.hover.y = x or -1, y or -1
end

local function hovered(r)
  return M.hover.x >= 0 and dentro(M.hover.x, M.hover.y, r)
end

local function totalLanceHumano()
  if not M.leilao then return 0 end
  return math.max(0, tonumber(M.leilao.lances[1]) or 0)
end

-- Visor do leilao (V7): mostra apenas o MAIOR lance e o nome de quem fez.
local function maiorLance()
  if not M.leilao then return 0, nil end
  local melhor, quem = 0, nil
  for i, v in pairs(M.leilao.lances or {}) do
    v = tonumber(v) or 0
    if v > melhor then melhor, quem = v, i end
  end
  return melhor, quem
end

local function publicarMudanca()
  publicarEstado()
  if M.aoMudar then M.aoMudar() end
end

-- Host em rede: so resolve quando todos os humanos vivos confirmaram (o
-- timer tambem resolve sozinho no fim, mesmo sem confirmacao).
local function todosProntos()
  if not M.partida or not M.leilao then return false end
  for i, j in ipairs(M.partida.jogadores) do
    if not j.isIA and not j.falido and not j.saiu then
      if not (M.leilao.prontos and M.leilao.prontos[i]) then return false end
    end
  end
  return true
end

local function resolverAgora()
  if not M.partida or not M.leilao or M.leilao.resolvido then return end
  -- Nunca corta a roleta: o leilao fica pausado e resolve no fim do hold.
  if M.roleta and M.roleta.mostrar then
    M.resultadoPendente = true
    return
  end
  jogo.resolverLeilao(M.partida)
  M.fase = "resultadoLeilao"
  M.t = duracaoMeta(2.4, 0.5)
  M.resultadoPendente = false
  publicarMudanca()
end

local function ajustarLance(idx, delta)
  if not M.leilao or M.leilao.resolvido then return end
  if M.confirmado and M.rede then return end
  local atual = tonumber(M.leilao.lances[1]) or 0
  if M.rede == "cliente" then
    -- Espelho: atualiza so para desenhar e manda o valor ao host. Nunca
    -- mexe no motor local (o cliente nao e autoridade do leilao).
    local saldo = M.partida.jogadores[1].saldo or 0
    local novo = math.max(0, math.min(saldo, atual + delta))
    M.leilao.lances[1] = novo
    if M.aoLance then M.aoLance(novo) end
    som.tocar("clique")
    return
  end
  jogo.definirLance(M.partida, 1, nil, atual + delta)
  publicarMudanca()
  som.tocar("clique")
end

local function confirmarLeilao()
  if not M.partida or not M.leilao or M.leilao.resolvido then return end
  if M.rede == "cliente" then
    if M.confirmado then return end
    M.confirmado = true
    if M.aoConfirmar then M.aoConfirmar() end
    som.tocar("clique")
    return
  end
  if M.rede == "host" then
    -- O host tambem espera os clientes; cada um confirma o proprio lance.
    M.confirmado = true
    M.leilao.prontos = M.leilao.prontos or {}
    M.leilao.prontos[1] = true
    if todosProntos() then resolverAgora() else publicarMudanca() end
    som.tocar("clique")
    return
  end
  resolverAgora()
  som.tocar("clique")
end

-- Host: lance vindo de um cliente (assento real do motor).
function M.receberLance(assento, valor)
  if M.rede ~= "host" or not M.partida or not M.leilao then return false end
  if M.leilao.resolvido then return false end
  if not jogo.definirLance(M.partida, assento, nil, tonumber(valor) or 0) then
    return false
  end
  publicarMudanca()
  return true
end

-- Host: cliente confirmou o lance; resolve quando todos confirmaram.
function M.receberConfirmacao(assento)
  if M.rede ~= "host" or not M.partida or not M.leilao then return false end
  if M.leilao.resolvido then return false end
  M.leilao.prontos = M.leilao.prontos or {}
  M.leilao.prontos[assento] = true
  if todosProntos() then resolverAgora() else publicarMudanca() end
  return true
end

-- Cliente: aplica o leilao/fase que veio no snapshot, sem reiniciar a roleta
-- e sem resolver nada localmente.
function M.aplicarRede(partida, snap)
  if M.rede ~= "cliente" or not partida then return end
  M.partida = partida
  M.leilao = partida.leilao
  M.bannerT = partida.curingaGlobal and 4.5 or 0
  if tonumber(snap.metaT) then M.t = math.max(0, tonumber(snap.metaT)) end
  local resolvido = partida.leilao and partida.leilao.resolvido
  if snap.metaFase == "resultadoLeilao" or resolvido then
    if M.roleta and M.roleta.mostrar then
      M.resultadoPendente = true
    else
      M.fase = "resultadoLeilao"
    end
  end
end

local function iniciarLojinha()
  jogo.iniciarLojinha(M.partida)
  M.lojinha = M.partida.lojinha
  M.fase = "lojinha"
  M.t = duracaoMeta(jogo.LOJINHA_SEGUNDOS)
  publicarMudanca()
end

-- 4o evento do Deus Mercado: fusao de 2..5 cartas em uma Super Carta.
local function iniciarFusao()
  jogo.iniciarFusao(M.partida)
  jogo.iaFusao(M.partida)
  M.fusaoSel = {}
  M.fase = "fusao"
  M.t = duracaoMeta(jogo.LOJINHA_SEGUNDOS)
  publicarMudanca()
end

local function alternarFusao(uid)
  local sel = M.fusaoSel or {}
  for i, u in ipairs(sel) do
    if u == uid then
      table.remove(sel, i)
      M.fusaoSel = sel
      som.tocar("clique")
      return
    end
  end
  if #sel >= jogo.FUSAO_MAX then return end
  sel[#sel + 1] = uid
  M.fusaoSel = sel
  som.tocar("clique")
end

local function confirmarFusao()
  local sel = M.fusaoSel or {}
  if #sel < jogo.FUSAO_MIN or #sel > jogo.FUSAO_MAX then return end
  local super = jogo.executarFusao(M.partida, 1, sel)
  if not super then return end
  M.fusaoResultado = super
  M.fase = "fusaoResultado"
  M.t = duracaoMeta(2.4, 0.5)
  publicarMudanca()
  som.tocar("guardar")
end

function M.atualizar(dt)
  if not M.fase then return end
  if M.bannerT and M.bannerT > 0 then
    M.bannerT = math.max(0, M.bannerT - dt)
  end

  -- Atualiza roleta do curinga global (gira, para no sorteado e segura o
  -- resultado por um instante antes de liberar o leilao).
  if M.roleta and M.roleta.mostrar then
    local r = M.roleta
    if r.ativa then
      r.t = r.t + dt
      local progresso = math.min(1, r.t / r.dur)
      -- Ease-out cúbico: começa rápido, desacelera suavemente.
      local eased = 1 - (1 - progresso) ^ 3
      r.angulo = eased * r.anguloFinal
      if progresso >= 1 then
        r.ativa = false
        r.parada = true
        r.angulo = r.anguloFinal -- garante o encaixe exato na carta
        r.holdT = r.hold
        som.tocar("clique")
      end
    else
      r.holdT = r.holdT - dt
      if r.holdT <= 0 then M.roleta = nil end
    end
  end

  -- Resolucao adiada (confirmou durante a roleta): espera o hold acabar.
  if M.resultadoPendente and not (M.roleta and M.roleta.mostrar) then
    if M.rede == "cliente" then
      M.resultadoPendente = false
      M.fase = "resultadoLeilao"
      M.t = duracaoMeta(2.4, 0.5)
    elseif M.leilao and M.leilao.resolvido then
      M.resultadoPendente = false
      M.fase = "resultadoLeilao"
    else
      resolverAgora()
    end
  end

  if M.fase == "leilao" then
    -- Pausa o leilao enquanto a roleta aparece: o jogador sempre ve a
    -- animacao inteira (inclusive no modo teste, onde M.t e curto).
    if not (M.roleta and M.roleta.mostrar) then
      M.t = M.t - dt
      if M.t <= 0 then
        if M.rede == "cliente" then
          -- Quem resolve e o host; o cliente so congela o visor.
          M.t = 0
        else
          som.tocar("clique")
          resolverAgora()
        end
      end
    end
  elseif M.fase == "resultadoLeilao" then
    M.t = M.t - dt
    if M.t <= 0 then
      if M.rede == "host" then
        -- Rede: lojinha/fusao ficam fora do escopo; volta direto para a mesa.
        M.fechar()
      elseif not M.rede then
        iniciarLojinha()
      else
        -- Cliente: espera o snapshot com metaFase = nil.
        M.t = 0
      end
    end
  elseif M.fase == "lojinha" then
    M.t = M.t - dt
    if M.t <= 0 then iniciarFusao() end
  elseif M.fase == "fusao" then
    M.t = M.t - dt
    if M.t <= 0 then M.fechar() end
  elseif M.fase == "fusaoResultado" then
    M.t = M.t - dt
    if M.t <= 0 then M.fechar() end
  end
  publicarEstado()
end

function M.clicado(x, y)
  for i = #M.rects, 1, -1 do
    local r = M.rects[i]
    if dentro(x, y, r) then
      if r.tipo == "menos" then
        ajustarLance(r.idx, -100)
      elseif r.tipo == "mais" then
        ajustarLance(r.idx, 100)
      elseif r.tipo == "confirmar" then
        confirmarLeilao()
      elseif r.tipo == "resultado" then
        -- Rede: o host encerra o evento e avisa os clientes; lojinha/fusao
        -- nao rodam no multiplayer por enquanto.
        if M.rede == "host" then
          M.fechar()
        elseif not M.rede then
          iniciarLojinha()
        end
      elseif r.tipo == "comprar" then
        if not M.rede and jogo.comprarLojinha(M.partida, 1, r.uid) then
          som.tocar("guardar")
        end
      elseif r.tipo == "fusaoCard" then
        if not M.rede then alternarFusao(r.uid) end
      elseif r.tipo == "fusaoOk" then
        if not M.rede then confirmarFusao() end
      elseif r.tipo == "concluir" then
        if not M.rede then M.fechar() end
      end
      return true
    end
  end
  return false
end

-- ============================================================
-- DESENHO
-- ============================================================

local function desenharCarta(carta, x, y, w, h)
  if carta then
    ui.carta(carta, x, y, w, h, { preencherArte = true })
  else
    ui.caixaTracejada(x, y, w, h, ui.E(6), ui.hex "#1E1E32", 0.5,
      ui.hex "#777777", 0.8, ui.E(2), ui.E(5), ui.E(4))
  end
end

local function desenharBotao(texto, x, y, w, h, tipo, idx, uid, cor)
  local r = { x = x, y = y, w = w, h = h, tipo = tipo, idx = idx, uid = uid }
  M.rects[#M.rects + 1] = r
  local fundo = cor or ui.hex "#1C2238"
  local borda = hovered(r) and ui.C.OURO or ui.hex "#7A5C29"
  ui.botao(texto, x, y, w, h, fundo, borda, 16)
end

local function desenharTimer()
  local txt = tostring(math.max(0, math.ceil(M.t))) .. "s"
  local cor = (M.t <= 5) and ui.C.FALHA or ui.C.OURO
  ui.txt(txt, VW - ui.E(150), ui.E(24), 28, cor, "right", ui.E(130))
end

-- Visor de Curingas (V7): o global atual + os 2 ultimos ja utilizados.
local function desenharBannerCuringa()
  local cg = M.partida and M.partida.curingaGlobal
  if not cg or not cg.carta then return end
  local c = cg.carta
  local w = ui.E(600)
  local x = (VW - w) / 2
  local y = ui.E(70)
  ui.caixa(x, y, w, ui.E(54), ui.E(10), ui.hex "#120B20",
    ui.C.CORINGA, ui.E(2), 0.92)
  ui.txtCabe(ui.tr("CURINGA GLOBAL:") .. " " .. c.nome, x + ui.E(10), y + ui.E(8),
    18, w - ui.E(20), ui.C.OURO, "center", 12)
  ui.txtCabe(c.efeitoTexto or c.descricao or "", x + ui.E(10), y + ui.E(30),
    12, w - ui.E(20), ui.C.TEXTO2, "center", 9)

  local hist = M.partida.curingaHistorico or {}
  if #hist > 0 then
    local tw, th = ui.E(44), ui.E(62)
    local hx = x - #hist * (tw + ui.E(8)) - ui.E(16)
    if hx > ui.E(60) then
      ui.txt("USADOS:", hx - ui.E(6), y + ui.E(20), 11, ui.C.TEXTO3,
        "right", ui.E(58))
      for k, hc in ipairs(hist) do
        ui.carta(hc, hx + (k - 1) * (tw + ui.E(8)), y - ui.E(5), tw, th,
          { preencherArte = true })
      end
    end
  end
end

local function desenharRoletaCuringa()
  local r = M.roleta
  if not r or not r.mostrar then return end

  local n = #r.itens
  local cx, cy = VW / 2, VH / 2 + ui.E(10)
  local raio = ui.E(138)
  local passo = 2 * math.pi / n
  local cw, ch = ui.E(68), ui.E(98)

  -- Fundo escuro semi-transparente cobrindo a tela.
  love.graphics.setColor(0, 0, 0, 0.82)
  ui.preencherTela(VW, VH)

  -- Titulo centralizado de verdade (printf usa x e largura; x = 0).
  ui.txt("DEUS MERCADO SORTEIA O CURINGA GLOBAL",
    0, ui.E(6), 22, ui.C.OURO, "center", VW)

  -- A mao fica ATRAS das cartas: o dedo termina no centro da carta sorteada,
  -- e a propria carta cobre a ponta, como se a mao estivesse apontando.
  local mao = arte.img("deus_mao")
  if mao then
    local iw, ih = mao:getDimensions()
    local escala = ui.E(140) / ih
    local omx, omy = iw * MAO_PIVO_X, ih * MAO_PIVO_Y -- centro do punho
    love.graphics.push()
    love.graphics.translate(cx + ui.E(4), cy + ui.E(4))
    love.graphics.rotate(r.angulo)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.draw(mao, 0, 0, 0, escala, escala, omx, omy)
    love.graphics.pop()
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(r.angulo)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mao, 0, 0, 0, escala, escala, omx, omy)
    love.graphics.pop()
  end

  -- Cartas fixas em volta do punho. A mao gira por tras delas e para
  -- apontando para a sorteada; o nome nao e desenhado, a arte fala por si.
  for i = 1, n do
    local carta = CARTA_POR_ID[r.itens[i]]
    if carta then
      local ang = -math.pi / 2 + (i - 1) * passo
      local px = cx + math.cos(ang) * raio
      local py = cy + math.sin(ang) * raio
      local vencedora = r.parada and i == r.indiceFinal
      local escala = 1
      if vencedora then
        escala = 1.05 + 0.02 * (0.5 + 0.5 * math.sin(love.timer.getTime() * 7))
      end
      ui.carta(carta, px - cw / 2, py - ch / 2, cw, ch, {
        destaque = vencedora and ui.C.OURO or nil,
        destaqueAlfa = 0.18,
        escala = escala,
      })
    end
  end

  -- Texto inferior: instrucao durante o giro, resultado quando para.
  local textoY = VH - ui.E(48)
  if r.parada then
    ui.txt("CURINGA GLOBAL SORTEADO",
      0, textoY, 20, ui.C.OURO, "center", VW)
    ui.txt("A MAO DO DEUS MERCADO APONTOU PARA A CARTA",
      0, textoY + ui.E(26), 13, ui.C.TEXTO2, "center", VW)
  else
    ui.txt("A MAO DO DEUS MERCADO ESTA ESCOLHENDO...",
      0, VH - ui.E(42), 18, ui.C.OURO, "center", VW)
  end
end

-- ============================================================
-- LEILAO: layout por zonas em unidades virtuais (1280x720).
-- Nao usa ui.E: cartas e paineis crescem a partir da zona disponivel.
-- Textos sem acento, como no resto do jogo.
-- ============================================================
local LP = { ref = nil, refRes = nil }   -- estado de animacao (so desenho)
local RAZAO_CARTA = 236 / 330

local function setCor(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or 1)
end

local function suave(a, b, k, dt)
  local d = b - a
  if math.abs(d) < 0.5 then return b end
  return a + d * math.min(1, k * dt)
end

local function easeOut(t)
  t = math.max(0, math.min(1, t))
  return 1 - (1 - t) ^ 3
end

function LP.zonas()
  local m = 24
  local corpoY = 130
  local corpoH = VH - corpoY - m
  local cartasW = math.floor((VW - m * 2) * 0.56)
  return {
    topo   = { x = m, y = 14, w = VW - m * 2, h = 44 },
    barra  = { x = m, y = 62, w = VW - m * 2, h = 5 },
    faixa  = { x = m, y = 76, w = VW - m * 2, h = 40 },
    cartas = { x = m, y = corpoY, w = cartasW, h = corpoH },
    lance  = { x = m + cartasW + 20, y = corpoY,
               w = VW - m - (m + cartasW + 20), h = corpoH },
  }
end

function LP.fundo()
  -- Reforca o escurecimento (o M.desenhar ja aplica 0.93): some o "fantasma"
  -- do HUD e dos paineis atras do leilao.
  love.graphics.setColor(0.02, 0.02, 0.06, 0.75)
  ui.preencherTela(VW, VH)
  local mao = arte.img("deus_mao")
  if mao then
    local iw, ih = mao:getDimensions()
    local esc = (VH * 0.9) / ih
    love.graphics.setColor(1, 1, 1, 0.05)
    love.graphics.draw(mao, VW / 2, VH / 2, 0, esc, esc, iw / 2, ih / 2)
  end
  for i = 1, 8 do   -- vinheta nas bordas
    local d = i * 14
    love.graphics.setColor(0, 0, 0, 0.06)
    love.graphics.rectangle("fill", 0, 0, VW, d)
    love.graphics.rectangle("fill", 0, VH - d, VW, d)
    love.graphics.rectangle("fill", 0, 0, d, VH)
    love.graphics.rectangle("fill", VW - d, 0, d, VH)
  end
end

function LP.topo(z)
  local tp = z.topo
  local saldo = M.partida.jogadores[1].saldo
  ui.caixa(tp.x, tp.y + 6, 210, 32, 6, ui.hex "#12162B", ui.hex "#7A5C29",
    1, 0.95)
  ui.txt(ui.tr("Seu saldo:"), tp.x + 10, tp.y + 15, 12, ui.C.TEXTO3, "left", 80)
  ui.txt("R$ " .. tostring(saldo), tp.x + 86, tp.y + 12, 16, ui.C.SUCESSO,
    "left", 120)

  ui.txt("LEILAO DO DEUS MERCADO", 2, tp.y + 6, 28, { 0, 0, 0, 0.6 }, "center", VW)
  ui.txt("LEILAO DO DEUS MERCADO", 0, tp.y + 4, 28, ui.C.OURO, "center", VW)

  -- Timer em anel + barra fina que esvazia.
  local total = math.max(0.1, duracaoMeta(jogo.LEILAO_SEGUNDOS))
  local frac = math.max(0, math.min(1, M.t / total))
  local urgente = M.t <= 5
  local pulso = urgente and (0.6 + 0.4 * math.sin(love.timer.getTime() * 10)) or 1
  local cor = urgente and ui.C.FALHA or ui.C.OURO
  local rx, ry = tp.x + tp.w - 24, tp.y + 22
  love.graphics.setLineWidth(5)
  love.graphics.setColor(0.16, 0.17, 0.25, 1)
  love.graphics.circle("line", rx, ry, 22)
  setCor(cor, pulso)
  if frac > 0 then
    love.graphics.arc("line", "open", rx, ry, 22, -math.pi / 2,
      -math.pi / 2 + 2 * math.pi * frac, 32)
  end
  love.graphics.setLineWidth(1)
  ui.txt(tostring(math.max(0, math.ceil(M.t))), rx - 22, ry - 9, 18, cor,
    "center", 44)

  local b = z.barra
  ui.caixa(b.x, b.y, b.w, b.h, 2, ui.hex "#1A1A2E", nil, 0)
  if frac > 0 then
    setCor(cor, pulso)
    love.graphics.rectangle("fill", b.x, b.y, b.w * frac, b.h, 2, 2)
  end
end

function LP.faixaCuringa(f)
  local cg = M.partida and M.partida.curingaGlobal
  if not cg or not cg.carta then return end
  local c = cg.carta
  ui.caixa(f.x, f.y, f.w, f.h, 8, ui.hex "#120B20", ui.C.CORINGA, 2, 0.95)
  ui.txt(ui.tr("CURINGA GLOBAL"), f.x + 14, f.y + 13, 13, ui.C.OURO, "left", 150)
  ui.txtCabe(c.nome, f.x + 170, f.y + 10, 17, 300, ui.C.CREME, "left", 12)
  ui.txtCabe(c.efeitoTexto or c.descricao or "", f.x + 480, f.y + 14, 12,
    f.w - 480 - 14, ui.C.TEXTO3, "left", 9)
end

function LP.produto(zc, t)
  local cartasP = M.leilao.cartas or {}
  local n = math.max(1, #cartasP)
  local gap = 20
  local fitaH, nomeH, pedH = 22, 26, 24
  local zonaH = zc.h - fitaH - 8 - nomeH - pedH - 16
  local ch = math.min(zonaH, 420)
  local cw = ch * RAZAO_CARTA
  if cw * n + gap * (n - 1) > zc.w - 20 then
    cw = (zc.w - 20 - gap * (n - 1)) / n
    ch = cw / RAZAO_CARTA
  end
  local blocoH = fitaH + 8 + ch + nomeH + pedH
  local y0 = zc.y + (zc.h - blocoH) / 2
  local cx = zc.x + zc.w / 2
  local totalW = cw * n + gap * (n - 1)
  local x0 = cx - totalW / 2
  local cardY = y0 + fitaH + 8

  -- Holofote dourado atras das cartas.
  for i = 0, 6 do
    local k = 1 - i / 8
    love.graphics.setColor(0.95, 0.68, 0.2, 0.04)
    love.graphics.ellipse("fill", cx, cardY + ch * 0.75, totalW * 0.75 * k,
      ch * 0.62 * k)
  end

  -- Fita: CARTA UNICA / KIT DE N CARTAS.
  local rotulo = M.leilao.kit
    and (ui.tr("KIT DE") .. " " .. n .. " " .. ui.tr("CARTAS"))
    or ui.tr("CARTA UNICA")
  local fw = 170
  ui.caixa(cx - fw / 2, y0, fw, fitaH, 11, ui.C.CORINGA, ui.C.OURO, 1, 0.95)
  ui.txt(rotulo, cx - fw / 2, y0 + 5, 12, ui.C.CREME, "center", fw)

  for k, carta in ipairs(cartasP) do
    local x = x0 + (k - 1) * (cw + gap)
    local y = cardY + math.sin(t * 2 + k) * 3          -- flutuando
    setCor(ui.C.OURO, 0.35 + 0.25 * math.sin(t * 3 + k)) -- brilho pulsando
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x - 4, y - 4, cw + 8, ch + 8, 8, 8)
    love.graphics.setLineWidth(1)
    desenharCarta(carta, x, y, cw, ch)
    ui.txtCabe(carta.nome, x, cardY + ch + 8, 15, cw, ui.C.OURO, "center", 10)
  end

  -- Pedestal.
  local py = cardY + ch + nomeH + 12
  love.graphics.setColor(0.48, 0.36, 0.16, 0.75)
  love.graphics.ellipse("fill", cx, py, totalW * 0.62, 9)
  love.graphics.setColor(1, 0.84, 0.3, 0.5)
  love.graphics.ellipse("line", cx, py, totalW * 0.62, 9)
end

function LP.painelLance(zl, dt)
  local melhor, quem = maiorLance()
  local lance = totalLanceHumano()
  local saldo = M.partida.jogadores[1].saldo

  -- Estado de animacao (reinicia a cada leilao novo).
  if LP.ref ~= M.leilao then
    LP.ref = M.leilao
    LP.vis, LP.ultMelhor, LP.ultQuem = melhor, melhor, quem
    LP.flash, LP.superado, LP.hold, LP.rep = 0, 0, 0, 0
    LP.nomeSuperador = nil
  end
  if melhor > LP.ultMelhor then
    LP.flash = 0.6
    if quem ~= 1 and LP.ultQuem == 1 then
      LP.superado = 2.0
      LP.nomeSuperador = quem and M.partida.jogadores[quem]
        and M.partida.jogadores[quem].nome or nil
    end
  end
  LP.ultMelhor, LP.ultQuem = melhor, quem
  LP.vis = suave(LP.vis or melhor, melhor, 10, dt)
  LP.flash = math.max(0, LP.flash - dt)
  LP.superado = math.max(0, LP.superado - dt)

  local pw, ph = zl.w, 420
  local px, py = zl.x, zl.y + (zl.h - ph) / 2
  local fl = LP.flash > 0 and (LP.flash / 0.6) or 0
  local alerta = LP.superado > 0
  ui.caixa(px, py, pw, ph, 10, ui.hex "#080D1C",
    alerta and ui.C.FALHA or ui.hex "#7A5C29", 2 + fl * 3, 0.97)
  ui.arestas(px, py, pw, ph, 10, ui.C.OURO, 2)

  local ix, iw = px + 24, pw - 48

  -- 1) MAIOR LANCE
  ui.txt(ui.tr("MAIOR LANCE"), ix, py + 20, 13, ui.C.TEXTO3, "left", iw)
  ui.txt("R$ " .. tostring(math.floor(LP.vis + 0.5)), ix, py + 40, 46,
    fl > 0 and ui.C.CREME or ui.C.OURO, "left", iw)
  local textoNome, corNome
  if alerta then
    textoNome = "SUPERADO" .. (LP.nomeSuperador and (" POR " .. LP.nomeSuperador) or "") .. "!"
    corNome = ui.C.FALHA
  elseif quem == 1 then
    textoNome, corNome = "VOCE ESTA NA FRENTE", ui.C.SUCESSO
  elseif quem and M.partida.jogadores[quem] then
    textoNome, corNome = M.partida.jogadores[quem].nome, ui.C.TEXTO
  else
    textoNome, corNome = "NINGUEM AINDA", ui.C.TEXTO3
  end
  ui.txtCabe(textoNome, ix, py + 100, 18, iw, corNome, "left", 12)

  love.graphics.setColor(0.17, 0.19, 0.29, 1)
  love.graphics.rectangle("fill", ix, py + 140, iw, 2)

  -- 2) SEU LANCE
  ui.txt(ui.tr("SEU LANCE"), ix, py + 156, 13, ui.C.TEXTO3, "left", iw)
  local by, bw, bh = py + 180, 96, 56
  desenharBotao("-100", ix, by, bw, bh, "menos")
  desenharBotao("+100", ix + iw - bw, by, bw, bh, "mais")
  local excede = lance > saldo
  ui.txtCabe("R$ " .. tostring(lance), ix + bw + 8, by + 10, 32,
    iw - bw * 2 - 16, excede and ui.C.FALHA or ui.C.CREME, "center", 18)

  local barY = by + bh + 16
  ui.caixa(ix, barY, iw, 10, 4, ui.hex "#12162B", ui.C.TEXTO3, 1)
  local frac = saldo > 0 and math.min(1, lance / saldo) or 0
  if frac > 0 then
    ui.caixa(ix + 1, barY + 1, (iw - 2) * frac, 8, 3,
      excede and ui.C.FALHA or ui.C.SUCESSO, nil, 0)
  end
  ui.txt(excede and "LANCE MAIOR QUE O SALDO"
    or (ui.tr("SALDO") .. " R$ " .. tostring(saldo)),
    ix, barY + 16, 13, excede and ui.C.FALHA or ui.C.TEXTO2, "left", iw)
  ui.txt("MULTIPLOS DE R$ 100  -  SEGURE PARA REPETIR", ix, barY + 40, 11,
    ui.C.TEXTO3, "left", iw)

  -- 3) CONFIRMAR
  local rotulo = M.confirmado and "AGUARDANDO..." or "CONFIRMAR LANCE"
  desenharBotao(rotulo, ix, py + ph - 80, iw, 60, "confirmar", nil, nil,
    M.confirmado and ui.hex "#3A3F55" or ui.C.VERDE)

  -- Segurar -100 / +100 repete o lance.
  local alvo = nil
  for _, r in ipairs(M.rects) do
    if (r.tipo == "menos" or r.tipo == "mais") and hovered(r) then alvo = r end
  end
  if alvo and love.mouse.isDown(1) and not M.confirmado and not MODO_TESTE then
    LP.hold = LP.hold + dt
    if LP.hold > 0.45 then
      LP.rep = LP.rep + dt
      while LP.rep >= 0.08 do
        LP.rep = LP.rep - 0.08
        ajustarLance(alvo.idx, alvo.tipo == "menos" and -100 or 100)
      end
    end
  else
    LP.hold, LP.rep = 0, 0
  end
end

local function desenharLeilao()
  -- Roleta do curinga global ativa: desenha so ela.
  if M.roleta and M.roleta.mostrar then
    desenharRoletaCuringa()
    return
  end
  local dt = math.min(love.timer.getDelta(), 0.05)
  local t = love.timer.getTime()
  local z = LP.zonas()
  LP.fundo()
  LP.topo(z)
  LP.faixaCuringa(z.faixa)
  LP.produto(z.cartas, t)
  LP.painelLance(z.lance, dt)
end

-- ============================================================
-- RESULTADO DO LEILAO
-- ============================================================
function LP.fagulhas(px, py, pw, ph, t)
  for i = 1, 16 do
    local x = px + 12 + (i * 73) % (pw - 24)
    local y = py + ph - ((t * 40 + i * 37) % ph)
    love.graphics.setColor(1, 0.84, 0.3, 0.45)
    love.graphics.rectangle("fill", x, y, 3, 3)
  end
end

local function desenharResultadoLeilao()
  local dt = math.min(love.timer.getDelta(), 0.05)
  local t = love.timer.getTime()
  if LP.refRes ~= M.leilao then LP.refRes, LP.tRes = M.leilao, 0 end
  LP.tRes = (LP.tRes or 0) + dt

  LP.fundo()
  local r = (M.leilao.resultados or {})[1]
  local venc = r and r.vencedor
  local jv = venc and M.partida.jogadores[venc]
  local euVenci = venc == 1

  ui.txt("RESULTADO DO LEILAO", 2, 34, 28, { 0, 0, 0, 0.6 }, "center", VW)
  ui.txt("RESULTADO DO LEILAO", 0, 32, 28, ui.C.OURO, "center", VW)

  local pw, ph = 700, 420
  local px, py = (VW - pw) / 2, 90
  local corPainel = venc and ui.C.OURO or ui.hex "#5A5F78"
  ui.caixa(px, py, pw, ph, 12, ui.hex "#0F1322", corPainel, 2, 0.97)
  ui.arestas(px, py, pw, ph, 12, corPainel, 2)
  if euVenci then LP.fagulhas(px, py, pw, ph, t) end

  -- Fita no topo do painel.
  local fw = 180
  local rotuloFita = euVenci and "VOCE VENCEU" or (venc and "VENCEDOR" or "SEM VENCEDOR")
  ui.caixa(px + pw / 2 - fw / 2, py - 12, fw, 24, 12,
    euVenci and ui.C.OURO or (venc and ui.C.CORINGA or ui.hex "#3A3F55"),
    corPainel, 1, 1)
  ui.txt(rotuloFita, px + pw / 2 - fw / 2, py - 6, 13,
    euVenci and ui.hex "#10121F" or ui.C.CREME, "center", fw)

  if r then
    -- Cartas do produto, entrando uma a uma.
    local cartasP = r.cartas or {}
    local n = math.max(1, #cartasP)
    local gapC = 16
    local th = 200
    local tw = th * RAZAO_CARTA
    local totalW = tw * n + gapC * (n - 1)
    local x0 = px + (pw - totalW) / 2
    local cy0 = py + 36
    for k, carta in ipairs(cartasP) do
      local q = easeOut((LP.tRes - 0.15 * (k - 1)) / 0.45)
      local x = x0 + (k - 1) * (tw + gapC)
      local y = cy0 + (1 - q) * 24
      if venc then
        setCor(ui.C.OURO, (0.3 + 0.25 * math.sin(t * 3 + k)) * q)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 4, y - 4, tw + 8, th + 8, 8, 8)
        love.graphics.setLineWidth(1)
      end
      ui.carta(carta, x, y, tw, th, { preencherArte = true })
      -- "Fade-in" por cima da carta e escurecimento se ninguem levou.
      love.graphics.setColor(0.06, 0.08, 0.14, (1 - q) + (venc and 0 or 0.45) * q)
      love.graphics.rectangle("fill", x, y, tw, th, 6, 6)
    end

    local yy = cy0 + th + 26
    local textoVenc, corVenc
    if euVenci then
      textoVenc, corVenc = "VOCE LEVOU!", ui.C.SUCESSO
    elseif jv then
      textoVenc, corVenc = jv.nome .. " LEVOU", ui.C.TEXTO
    else
      textoVenc, corVenc = "NINGUEM LEVOU", ui.C.TEXTO2
    end
    ui.txtCabe(textoVenc, px + 24, yy, 30, pw - 48, corVenc, "center", 18)
    yy = yy + 42
    if venc then
      ui.txt("PAGOU R$ " .. tostring(r.valor or 0), px, yy, 24, ui.C.OURO,
        "center", pw)
      yy = yy + 34
      local sub = euVenci
        and (ui.tr("SALDO") .. " R$ " .. tostring(M.partida.jogadores[1].saldo))
        or "LEVOU O PRODUTO INTEIRO"
      ui.txt(sub, px, yy, 14, ui.C.TEXTO3, "center", pw)
    else
      ui.txt("NINGUEM LANCOU O SUFICIENTE", px, yy, 16, ui.C.TEXTO3, "center", pw)
    end
  end

  -- Barra de tempo na base do painel.
  local total = math.max(0.1, duracaoMeta(2.4, 0.5))
  local frac = math.max(0, math.min(1, M.t / total))
  ui.caixa(px + 24, py + ph - 22, pw - 48, 5, 2, ui.hex "#1A1A2E", nil, 0)
  setCor(ui.C.OURO, 0.9)
  love.graphics.rectangle("fill", px + 24, py + ph - 22, (pw - 48) * frac, 5, 2, 2)

  ui.txt(M.rede and "VOLTANDO PARA A MESA..." or "A LOJINHA ABRE EM INSTANTES...",
    0, py + ph + 18, 16, ui.C.TEXTO2, "center", VW)
  local piscar = 0.5 + 0.5 * math.sin(t * 4)
  ui.txt("CLIQUE PARA CONTINUAR", 0, py + ph + 44, 12, ui.C.TEXTO3, "center",
    VW, 0.4 + 0.5 * piscar)

  -- Clicar em qualquer lugar pula (mantem o comportamento antigo).
  M.rects[#M.rects + 1] = { x = 0, y = 0, w = VW, h = VH, tipo = "resultado" }
end

local function desenharLojinha()
  ui.txt("LOJINHA DO DEUS MERCADO", 0, ui.E(22), 30, ui.C.OURO,
    "center", VW)
  ui.txt(ui.tr("Seu saldo:") .. " R$ " .. tostring(M.partida.jogadores[1].saldo),
    ui.E(28), ui.E(28), 16, ui.C.TEXTO2)
  desenharTimer()

  local cw, ch = ui.E(216), ui.E(300)
  local inicio = (VW - (cw * 3 + ui.E(24) * 2)) / 2
  local y = ui.E(136)
  for k, item in ipairs(M.lojinha.cartas) do
    local x = inicio + (k - 1) * (cw + ui.E(24))
    desenharCarta(item.carta, x, y, cw, ch)
    ui.txtCabe(item.carta.nome, x, y + ch + ui.E(6), 15, cw,
      ui.C.OURO, "center", 9)
    ui.txt("R$ " .. item.preco, x, y + ch + ui.E(28), 18,
      item.preco <= M.partida.jogadores[1].saldo and ui.C.CREME
        or ui.C.FALHA, "center", cw)
    if item.vendida then
      local quem = item.comprador and M.partida.jogadores[item.comprador].nome
        or "?"
      ui.txtCabe(ui.tr("VENDIDA:") .. " " .. quem, x, y + ch + ui.E(58), 13,
        cw, ui.C.TEXTO3, "center", 9)
    else
      desenharBotao("COMPRAR", x + ui.E(28), y + ch + ui.E(54),
        cw - ui.E(56), ui.E(38), "comprar", k, item.carta.uid, ui.C.VERDE)
    end
  end
  desenharBotao("CONCLUIR", VW / 2 - ui.E(130), VH - ui.E(108),
    ui.E(260), ui.E(52), "concluir", nil, nil, ui.C.VERMELHO)
end

-- 4o evento: FUSAO. O jogador escolhe 2..5 cartas da mao ou do banco
-- (Area Segura) e troca por uma Super Carta.
local function desenharFusao()
  ui.txt("FUSAO DE CARTAS", 0, ui.E(22), 30, ui.C.OURO, "center", VW)
  ui.txt(ui.tr("Selecione de") .. " " .. tostring(jogo.FUSAO_MIN) .. " - " ..
    tostring(jogo.FUSAO_MAX) .. " " ..
    ui.tr("cartas (mao ou banco) para criar uma SUPER CARTA"),
    0, ui.E(60), 16, ui.C.TEXTO2, "center", VW)
  desenharTimer()

  local j = M.partida.jogadores[1]
  local cw, ch, gap = ui.E(84), ui.E(126), ui.E(9)
  local sel = M.fusaoSel or {}

  local function linha(lista, y, rotulo)
    if not lista or #lista == 0 then
      ui.txt(rotulo .. ui.tr(": (vazio)"), ui.E(28), y, 14, ui.C.TEXTO3)
      return y + ui.E(40)
    end
    ui.txt(rotulo .. " (" .. #lista .. ")", ui.E(28), y - ui.E(22), 13,
      ui.C.OURO)
    local totalW = #lista * cw + (#lista - 1) * gap
    local x0 = math.max(ui.E(28), (VW - totalW) / 2)
    for k, c in ipairs(lista) do
      local x = x0 + (k - 1) * (cw + gap)
      local marcada = false
      for _, u in ipairs(sel) do
        if u == c.uid then marcada = true break end
      end
      ui.carta(c, x, y, cw, ch, { preencherArte = true })
      if marcada then
        ui.caixa(x - ui.E(3), y - ui.E(3), cw + ui.E(6), ch + ui.E(6),
          ui.E(6), nil, ui.C.OURO, ui.E(3))
        ui.txtCabe("*", x, y - ui.E(20), 18, cw, ui.C.OURO, "center", 16)
      end
      M.rects[#M.rects + 1] = { x = x, y = y, w = cw, h = ch,
        tipo = "fusaoCard", uid = c.uid }
    end
    return y + ch + ui.E(38)
  end

  local y1 = linha(j.mao, ui.E(110), "MAO")
  local y2 = linha(j.areaSegura, y1, "BANCO")

  ui.txt(ui.tr("CARTAS SELECIONADAS:") .. " " .. #sel .. " / " .. tostring(jogo.FUSAO_MAX),
    0, math.max(y2, VH - ui.E(150)), 18, #sel >= jogo.FUSAO_MIN
      and ui.C.SUCESSO or ui.C.TEXTO2, "center", VW)

  local ok = #sel >= jogo.FUSAO_MIN and #sel <= jogo.FUSAO_MAX
  desenharBotao("FUSIONAR", VW / 2 - ui.E(330), VH - ui.E(104),
    ui.E(250), ui.E(52), "fusaoOk", nil, nil, ok and ui.C.VERDE
      or ui.hex "#2A3050")
  desenharBotao("PULAR", VW / 2 + ui.E(80), VH - ui.E(104),
    ui.E(250), ui.E(52), "concluir", nil, nil, ui.C.VERMELHO)
end

local function desenharFusaoResultado()
  ui.txt("SUPER CARTA CRIADA!", 0, ui.E(60), 32, ui.C.OURO, "center", VW)
  desenharTimer()
  local c = M.fusaoResultado
  if c then
    local cw, ch = ui.E(280), ui.E(410)
    local x = (VW - cw) / 2
    local y = ui.E(130)
    ui.carta(c, x, y, cw, ch, { preencherArte = true })
    ui.txtCabe(c.nome, 0, y + ch + ui.E(12), 24, VW, ui.C.OURO, "center", 20)
    ui.txtCabe(c.efeitoTexto or "", 0, y + ch + ui.E(46), 15, VW,
      ui.C.TEXTO2, "center", 14)
  end
  M.rects[#M.rects + 1] = { x = 0, y = 0, w = VW, h = VH, tipo = "concluir" }
end

function M.desenhar()
  if not M.fase then return end
  love.graphics.setColor(0.02, 0.02, 0.06, 0.93)
  ui.preencherTela(VW, VH)
  M.rects = {}
  if M.fase == "leilao" then
    desenharLeilao()
  elseif M.fase == "resultadoLeilao" then
    desenharResultadoLeilao()
  elseif M.fase == "lojinha" then
    desenharLojinha()
  elseif M.fase == "fusao" then
    desenharFusao()
  elseif M.fase == "fusaoResultado" then
    desenharFusaoResultado()
  end
end

-- ============================================================
-- VISOR DE CURINGAS NA MESA (manual V7 3.1 / 5.5.4)
-- Exibe o efeito do Curinga Global em vigor + as 2 ultimas cartas usadas.
-- ============================================================
function M.desenharVisor(partida, vw, vh)
  if not partida then return end
  local cg = partida.curingaGlobal
  local hist = partida.curingaHistorico or {}
  if not cg and #hist == 0 then return end
  vw, vh = vw or VW, vh or VH
  local w, h = ui.E(228), ui.E(86)
  local x = vw - ui.E(12) - w
  local y = math.floor(vh * 0.40)
  ui.caixa(x, y, w, h, ui.E(8), ui.hex "#120B20", ui.C.CURINGA,
    ui.E(1.5), 0.9)
  ui.txt("VISOR DE CURINGAS", x + ui.E(8), y + ui.E(5), ui.E(9),
    ui.C.OURO, "left", w - ui.E(16))
  if cg and cg.carta then
    ui.txtCabe(cg.carta.nome, x + ui.E(8), y + ui.E(19), ui.E(11),
      w - ui.E(16), ui.C.CREME, "left", ui.E(9))
    ui.txtCabe(cg.carta.efeitoTexto or cg.carta.descricao or "",
      x + ui.E(8), y + ui.E(33), ui.E(8), w - ui.E(16) - ui.E(96),
      ui.C.TEXTO2, "left", ui.E(7))
  end
  if #hist > 0 then
    ui.txt("ANTERIORES", x + w - ui.E(86), y + ui.E(19), ui.E(7),
      ui.C.TEXTO3, "center", ui.E(78))
    local tw, th, gap = ui.E(22), ui.E(31), ui.E(4)
    local hx = x + w - ui.E(8) - #hist * tw - (#hist - 1) * gap
    local hy = y + h - th - ui.E(6)
    for k, hc in ipairs(hist) do
      ui.carta(hc, hx + (k - 1) * (tw + gap), hy, tw, th,
        { preencherArte = true })
    end
  end
end

-- Visor compacto encostado na placa de turno (substitui o visor lateral).
function M.desenharVisorCompacto(partida, x, y, w, h)
  if not partida then return end
  local cg = partida.curingaGlobal
  local hist = partida.curingaHistorico or {}
  local pad = 10
  ui.caixa(x, y, w, h, ui.E(6), ui.hex "#120B20", ui.C.CORINGA, 1.5, 0.94)

  -- Coluna direita: LUCRO (livro-caixa)
  local colW = 104
  local cx = x + w - colW - pad
  love.graphics.setColor(0.24, 0.16, 0.35, 1)
  love.graphics.rectangle("fill", cx - 8, y + 6, 1, h - 12)
  local j = partida.jogadores and partida.jogadores[1]
  if j then
    local lucro = (j.saldo or 0) - jogo.SALDO_INICIAL
    ui.txt(ui.tr("LUCRO"), cx, y + 5, 10, ui.C.TEXTO3, "right", colW)
    ui.txtCabe(string.format("%sR$ %d", lucro >= 0 and "+" or "-",
      math.abs(lucro)), cx, y + 21, 16,
      colW, lucro >= 0 and ui.C.SUCESSO or ui.C.FALHA, "right", 10)
  end

  -- Coluna esquerda: CURINGA + nome + cartas ja usadas
  local tw, th = ui.E(13), ui.E(18)
  local histW = #hist * (tw + 3)
  local leftW = cx - 12 - (x + pad) - histW - (histW > 0 and 6 or 0)
  ui.txt("CURINGA", x + pad, y + 5, 10, ui.C.OURO, "left", 90)
  if cg and cg.carta then
    ui.txtCabe(cg.carta.nome, x + pad, y + 21, 15, leftW, ui.C.CREME,
      "left", 10)
  else
    ui.txt("NENHUM ATIVO", x + pad, y + 23, 12, ui.C.TEXTO3, "left", leftW)
  end
  local hx = cx - 12 - histW
  for k, hc in ipairs(hist) do
    ui.carta(hc, hx + (k - 1) * (tw + 3), y + (h - th) / 2, tw, th,
      { preencherArte = true })
  end
end

-- ============================================================
-- PILHA DE DEFESA
-- A pilha fica acima dos slots da Area Segura do jogador (main.lua calcula
-- px/py). As antigas pilhas de Jogadas/Curinga nao sao mais desenhadas na mesa:
-- os dados continuam na partida, so a vitrine visual foi removida.
-- ============================================================

function M.desenharPilhas(partida, vw, vh, px, py)
  if not partida or not partida.jogadores or not partida.jogadores[1] then
    return
  end
  vw, vh = vw or VW, vh or VH
  local j = partida.jogadores[1]
  local w, h = ui.E(46), ui.E(64)
  local x0 = px or ui.E(10)
  local y0 = py or (vh - ui.E(12) - h)

  local def = j.defesas and j.defesas[1]
  ui.txt(ui.tr("DEFESA"), x0 - ui.E(2), y0 - ui.E(14), 10, ui.C.OURO,
    "center", w + ui.E(4), 0.85)
  if def and def.carta then
    ui.carta(def.carta, x0, y0, w, h, { preencherArte = true })
    local n = j.defesas and #j.defesas or 0
    if n > 1 then
      ui.txt(tostring(n), x0, y0 + h - ui.E(14), 10,
        ui.C.CREME, "center", w)
    end
  else
    ui.caixaTracejada(x0, y0, w, h, ui.E(6), ui.hex "#1E1E32", 0.35,
      ui.hex "#777777", 0.65, ui.E(1.5), ui.E(4), ui.E(3))
  end
end

return M
