-- Regras da partida em rede (Fase 2): o host e o unico dono do motor; os
-- clientes enviam intencoes (JOGAR/GUARDAR/USAR_AREA/PASSAR) e recebem
-- snapshots rotacionados — o proprio jogador sempre na posicao 1, igual ao
-- duelo local, para o desenho existente funcionar sem trocar indices.
-- Tudo aqui e puro (sem sockets, sem UI): os testes cobrem serializacao e
-- aplicacao de acoes direto.
local jogo = require "jogo"

local M = {}

-- Display local (1 = baixo/proprio) -> assento real do motor, no cliente.
function M.paraEng(n, meuAssento, localIdx)
  return (meuAssento + localIdx - 2) % n + 1
end

-- Inversa: assento real do motor -> display local. O cliente recebe o
-- EMOJI com o assento GLOBAL do host (ex.: seat 1 = anfitriao), mas o
-- desenho e por indice local (1 = proprio painel; no cliente o quadro fica
-- espelhado). Sem essa conversao o emoji do host caia no painel de baixo
-- do cliente. Com meuAssento = 1 (o proprio host) a funcao e identidade.
function M.paraLocal(n, meuAssento, assentoGlobal)
  local l = (assentoGlobal - meuAssento + 1) % n
  return l == 0 and n or l
end

local function cartasOcultas(n)
  local t = {}
  for _ = 1, n do t[#t + 1] = { oculta = true } end
  return t
end

local function serializarJogador(j, ehEu)
  return {
    nome = j.nome, avatar = j.avatar, saldo = j.saldo,
    falido = j.falido, protegido = j.protegido,
    -- Saiu da partida (desconectou): o cliente tira da arena, mas o seat
    -- continua existindo no jogo do host.
    saiu = j.saiu and true or nil,
    -- efeitos vao junto: o cliente calcula duracaoTurno do proprio relogio.
    efeitos = j.efeitos or {},
    -- Chain System: o cliente desenha a quota efetiva e a cadeia do turno.
    chainClasse = j.chainClasse,
    chainBonus = j.chainBonus or 0,
    satisfacao = j.satisfacao,
    produtividade = j.produtividade,
    bonusSatisfacao = j.bonusSatisfacao or 0,
    -- Fase 3: a placa de turno do cliente pinta "IA" de verdade (o host
    -- distingue turno de humano remoto x IA preenchida).
    isIA = j.isIA and true or false,
    mao = ehEu and j.mao or cartasOcultas(#j.mao),
    -- Area Segura com 3 slots: o cliente precisa da CONTAGEM (verso por
    -- carta guardada), nao so de "tem/não tem".
    areaSegura = ehEu and j.areaSegura or cartasOcultas(#j.areaSegura),
    -- Pilhas novas do manual (visual do cliente). O leilao e o Curinga
    -- global viajam no snapshot; lojinha/fusao continuam fora da rede.
    defesas = j.defesas or {},
    pilhaJogadas = j.pilhaJogadas or {},
    pilhaCuringa = j.pilhaCuringa or {},
    receitas = j.receitas or 0,
    despesas = j.despesas or 0,
    extrato = j.extrato or {},
  }
end

-- Leilao rotacionado para o destinatario: lances/vencedor saem no indice
-- local (1 = proprio jogador), como o resto do snapshot. O cliente nunca
-- resolve o leilao; so desenha e manda o lance para o host.
local function serializarLeilao(l, alvo, n)
  if not l then return nil end
  local lances = {}
  for k = 1, n do
    lances[k] = (l.lances and l.lances[(alvo + k - 2) % n + 1]) or 0
  end
  local resultados = {}
  for i, r in ipairs(l.resultados or {}) do
    local rr = { cartas = r.cartas, valor = r.valor, maior = r.maior }
    if r.vencedor then
      rr.vencedor = ((r.vencedor - alvo) % n) + 1
    end
    resultados[i] = rr
  end
  return {
    rodada = l.rodada, cartas = l.cartas, kit = l.kit,
    lances = lances, resultados = resultados,
    tempo = l.tempo, resolvido = l.resolvido,
    maior = l.maior,
    -- Espelho do vencedor no proprio leilao (o main usa resultados[1],
    -- mas manter os dois consistentes evita divergencia no cliente).
    vencedor = l.vencedor and (((l.vencedor - alvo) % n) + 1) or nil,
  }
end

-- Snapshot para o destinatario `alvo`: `jogadores[1]` e o proprio alvo (mao
-- completa); os demais sao versos (so a contagem importa). `tempo` =
-- { duracao, restante } do relogio do host.
function M.serializar(p, alvo, tempo)
  local n = #p.jogadores
  local jogadores = {}
  for k = 1, n do
    local orig = p.jogadores[(alvo + k - 2) % n + 1]
    jogadores[k] = serializarJogador(orig, k == 1)
  end
  local log = {}
  local ini = math.max(1, #p.log - 29)
  for i = ini, #p.log do log[#log + 1] = p.log[i] end
  local venc = nil
  if p.vencedor then
    venc = p.vencedor.empate and { empate = true } or { nome = p.vencedor.nome }
  end
  return {
    n = n,
    jogadores = jogadores,
    -- Arena escolhida pelo host na sala (nil = madeira padrao): o fundo e
    -- puramente cosmetico, mas os dois lados precisam desenhar o mesmo.
    arena = p.arena,
    pilhaDescarte = p.pilhaDescarte,
    pilhaCuringa = p.pilhaCuringa or {},
    turno = p.turno, maxTurnos = p.maxTurnos,
    -- Inversa da rotacao de jogadores: a posicao `k` que mostre o seat `o`
    -- e k = (o - alvo) mod n + 1 — a fomula simetrica (alvo + o - 2) so
    -- funciona para n = 2.
    vez = ((p.vez - alvo) % n) + 1,
    jogadasTurno = p.jogadasTurno,
    fim = p.fim, motivo = p.motivo, vencedor = venc,
    evento = p.evento,
    -- Habilidade de avatar (marx redistribuiu): o cliente mostra o popup.
    habilidade = p.habilidade,
    -- Evento de saida (quem saiu e em qual sequencia): dispara o aviso
    -- no canto superior direito do cliente.
    saida = p.saida,
    -- Meta-evento em rede: o host e a autoridade do leilao/roleta; o
    -- cliente recebe o leilao ja rotacionado e a fase/tempo correntes.
    curingaGlobal = p.curingaGlobal,
    curingaHistorico = p.curingaHistorico,
    leilao = serializarLeilao(p.leilao, alvo, n),
    metaFase = p.metaFase, metaT = p.metaT, metaRodada = p.metaRodada,
    log = log,
    tempo = tempo,
  }
end

-- Monta a copia local (cliente) a partir do snapshot ja rotacionado. O
-- vencedor volta a ser referencia do proprio jogador para o overlay de fim
-- (dadosFim compara `v == partida.jogadores[1]`).
function M.montar(snap)
  local jogadores = {}
  for k, jd in ipairs(snap.jogadores or {}) do
    jogadores[k] = {
      nome = jd.nome, avatar = jd.avatar, saldo = jd.saldo or 0,
      falido = jd.falido, protegido = jd.protegido,
      efeitos = jd.efeitos or {},
      chainClasse = jd.chainClasse,
      chainBonus = jd.chainBonus or 0,
      satisfacao = jd.satisfacao or 100,
      produtividade = jd.produtividade or 0,
      bonusSatisfacao = jd.bonusSatisfacao or 0,
      mao = jd.mao or {}, areaSegura = jd.areaSegura or {},
      isIA = jd.isIA == true, usouFundoEmergencia = false,
      status = jd.falido and "ELIMINADO" or "ATIVO",
      saiu = jd.saiu and true or nil,
      defesas = jd.defesas or {},
      pilhaJogadas = jd.pilhaJogadas or {},
      pilhaCuringa = jd.pilhaCuringa or {},
      cartasTurno = {},
      comboCartas = {},
      receitas = jd.receitas or 0,
      despesas = jd.despesas or 0,
      extrato = jd.extrato or {},
    }
  end
  local p = {
    jogadores = jogadores,
    -- Arena do host (nil = madeira padrao) para o fundo da mesa.
    arena = snap.arena,
    pilhaDescarte = snap.pilhaDescarte or {},
    pilhaCuringa = snap.pilhaCuringa or {},
    turno = snap.turno or 1, maxTurnos = snap.maxTurnos or 10,
    vez = snap.vez or 1, jogadasTurno = snap.jogadasTurno or 0,
    fim = snap.fim, motivo = snap.motivo, vencedor = nil,
    evento = snap.evento, habilidade = snap.habilidade, log = snap.log or {},
    saida = snap.saida,
    -- Leilao/roleta sincronizados pelo host. O curinga ja vem aplicado nos
    -- efeitos/pilhas de cada jogador; aqui vai so o visor + o produto.
    curingaGlobal = snap.curingaGlobal,
    curingaHistorico = snap.curingaHistorico or {},
    leilao = snap.leilao,
    metaFase = snap.metaFase, metaT = snap.metaT, metaRodada = snap.metaRodada,
    metaPendente = nil,
  }
  if snap.vencedor then
    if snap.vencedor.empate then
      p.vencedor = { empate = true }
    else
      for _, j in ipairs(jogadores) do
        if j.nome == snap.vencedor.nome then p.vencedor = j break end
      end
      p.vencedor = p.vencedor or jogadores[1]
    end
  end
  return p
end

local function entrada(res)
  return {
    carta = res.carta,
    sucesso = res.sucesso,
    chance = tostring(math.floor(((res.chance or 1) * 100) + 0.5)) .. "%",
  }
end

local function uidNaMao(j, uid)
  for _, c in ipairs(j.mao) do
    if c.uid == uid then return c end
  end
  return nil
end

-- Aplica uma acao autoritativamente no motor do host. Devolve
-- { ok, entradas?, motivo? }: `entradas` no formato do banner de resultado
-- (para o host enviar CARTA_JOGADA e o cliente mostrar o mesmo zoom).
-- Regras espelham o duelo local: JOGAR encerra o turno apenas quando a
-- quota de CARTAS_POR_TURNO acaba (1 carta mantem a vez); PASSAR encerra
-- na hora; GUARDAR e USAR_AREA nao; USAR_AREA vale ate fora do turno.
function M.aplicarAcao(p, assento, msg)
  if not p or p.fim then return { ok = false, motivo = "fim" } end
  local j = p.jogadores[assento]
  if not j or type(msg) ~= "table" then return { ok = false, motivo = "assento" } end
  local tipo = msg.tipo

  if tipo == "JOGAR" then
    if p.vez ~= assento then return { ok = false, motivo = "vez" } end
    if j.falido then return { ok = false, motivo = "falido" } end
    local uids = msg.uids
    local restante = jogo.jogadasRestantes(p, assento)
    if type(uids) ~= "table" or #uids == 0
        or restante <= 0 or #uids > restante then
      return { ok = false, motivo = "quantidade" }
    end
    local cartas = {}
    for _, uid in ipairs(uids) do
      local c = uidNaMao(j, uid)
      if not c then return { ok = false, motivo = "uid" } end
      for _, ja in ipairs(cartas) do
        if ja.uid == uid then return { ok = false, motivo = "duplicado" } end
      end
      cartas[#cartas + 1] = c
    end
    local entradas = {}
    for _, carta in ipairs(cartas) do
      for i, m in ipairs(j.mao) do
        if m.uid == carta.uid then table.remove(j.mao, i) break end
      end
      local opts = {}
      -- Escolha manual de defesa do alvo (janela Quick Counter): o host
      -- repassa a permissao para o motor usar SOMENTE a defesa armada.
      if type(msg.defesaDe) == "table" then
        opts.defesaDe = msg.defesaDe
      end
      -- Alvo por carta (mapa uid -> {tipo, idx}) enviado pelo cliente na
      -- Etapa 9; fallback no alvo unico (numero) para mensagens antigas.
      local alvosMapa = type(msg.alvos) == "table" and msg.alvos or nil
      if alvosMapa and alvosMapa[carta.uid]
          and type(alvosMapa[carta.uid].idx) == "number" then
        opts.alvoIdx = alvosMapa[carta.uid].idx
      elseif type(msg.alvo) == "number" then
        opts.alvoIdx = msg.alvo
      end
      if type(msg.roubo) == "table" and msg.roubo[carta.uid] then
        opts.roubarUids = msg.roubo[carta.uid]
      end
      local res = jogo.aplicarCarta(p, assento, carta, opts)
      entradas[#entradas + 1] = entrada(res)
      if p.fim then break end
    end
    -- Cada JOGAR pode conter 1 carta (fluxo de clique por area) ou uma leva
    -- de ate 2. O turno so encerra quando a quota do turno acabou; com 1
    -- carta o jogador continua no turno para jogar a 2a.
    if not p.fim and (p.jogadasTurno or 0) >= jogo.quotaTurno(p, assento) then
      jogo.encerrarVez(p)
    end
    return { ok = true, entradas = entradas }
  end

  if tipo == "GUARDAR" then
    if p.vez ~= assento then return { ok = false, motivo = "vez" } end
    if j.falido then return { ok = false, motivo = "falido" } end
    if not msg.uid then return { ok = false, motivo = "uid" } end
    if not jogo.colocarAreaSegura(p, assento, msg.uid) then
      return { ok = false, motivo = "area" }
    end
    return { ok = true }
  end

  -- Armar defesa no Slot de Defesa: organizacao do proprio turno, nao gasta
  -- quota, nao rola dado e nao encerra a vez.
  if tipo == "ARMAR_DEFESA" then
    if p.vez ~= assento then return { ok = false, motivo = "vez" } end
    if j.falido then return { ok = false, motivo = "falido" } end
    if not msg.uid then return { ok = false, motivo = "uid" } end
    if not jogo.armarDefesa(p, assento, msg.uid) then
      return { ok = false, motivo = "defesa" }
    end
    return { ok = true }
  end

  if tipo == "PASSAR" then
    if p.vez ~= assento then return { ok = false, motivo = "vez" } end
    jogo.passar(p, assento)
    return { ok = true }
  end

  if tipo == "USAR_AREA" then
    if not msg.uid then return { ok = false, motivo = "uid" } end
    local res = jogo.jogarAreaSegura(p, assento, msg.uid)
    if not res then return { ok = false, motivo = "area" } end
    return { ok = true, entradas = { entrada(res) } }
  end

  return { ok = false, motivo = "tipo" }
end

return M
