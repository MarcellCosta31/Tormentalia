local cartas = require "cartas"

-- Motor do duelo: port fiel de src/cards/motorEfeitos.js + src/hooks/useCombat.js
-- (escala 1000, 2 cartas por turno, evento do Deus Mercado no fim do turno).
local J = {}

J.STATUS = {
  ATIVO = "ATIVO",
  EMERGENCIA = "EMERGENCIA",
  ELIMINADO = "ELIMINADO",
}

-- Regras da Tormentalia (manual V7): capital inicial de 2000, turno de 25s,
-- renda de rodada de 1000 progressiva, Carta Dobrada +30%, leilao/lojinha/
-- fusao a cada 2 rodadas, Curinga global e falencia imediata ao chegar a
-- zero (sem fundo de emergencia).
local SALDO_INICIAL = 2000
local SALDO_EMERGENCIA = 0 -- mantido por compatibilidade; nao e mais usado
local MAX_TURNOS = 10
local CARTAS_POR_MAO = 7
local CARTAS_POR_TURNO = 2
-- Cadeia de Cartas (Chain System): se o jogador joga cartas da mesma
-- classe em sequencia, ganha jogadas bonus (maximo CHAIN_MAX extras).
-- A cadeia vale por jogador e e zerada no inicio do turno dele.
local CHAIN_MAX = 2            -- ate 4 cartas no total (2 base + 2 chain)
local CHAIN_CLASSES = {        -- classes que formam chain entre si
  Efeito = "Efeito", Acao = "Acao", Defesa = "Defesa", Curinga = "Curinga",
  Super = "Super",
}
-- Quantas cartas cabem na Area Segura. Era 1: com 3 o jogador pode estocar
-- (e a IA tambem) e usar fora do turno sem gastar a quota.
local AREA_SEGURA_MAX = 1
-- Teto total de cartas (manual 4.4): 7 de mao + 3 de banco = 10. So o
-- evento (leilao/lojinha/fusao) pode exceder esse numero.
local CARTAS_MAX_TOTAL = 10
local TURNO_BASE_SEGUNDOS = 25
local RENDA_BASE = 1000
local RENDA_INCREMENTO = 100
local LEILAO_INTERVALO = 2
local LEILAO_SEGUNDOS = 15
local LOJINHA_SEGUNDOS = 15
-- Carta Dobrada (manual 5.2): +30% PROPORTIONAL sobre a chance original.
local BONUS_COPIA = 0.3
local DEFESA_TURNOS = 2
local MAYO_CHANCE = 0.3

-- Barra de Satisfacao (manual 5.3): 0..200, comeca em 100. A 0 o jogador
-- entra em GREVE (perde o turno e a barra volta a 100 no turno seguinte); a
-- 200 ele dobra os efeitos das proximas 2 cartas e volta a 100.
local SATISFACAO_INICIAL = 100
local SATISFACAO_MIN = 0
local SATISFACAO_MAX = 200
local SATISFACAO_BONUS_CARTAS = 2

-- Produtividade (manual 5.4): percentual aplicado sobre a renda da rodada.
-- Piso em -100% (anula a renda); nao ha teto superior.
local PRODUTIVIDADE_MIN = -1

-- Fusao de cartas (manual 5.9): de 2 a 5 cartas (mao ou banco) viram uma
-- Super Carta.
local FUSAO_MIN = 2
local FUSAO_MAX = 5

-- Eventos variados do Deus Mercado. Os valores foram calibrados para a
-- escala de 2000 do manual (antes eram 20/30, pequenos demais).
local EVENTOS_DEUS = {
  { nome = "BONANCA", tipo = "todos", valor = 300 },
  { nome = "CRISE", tipo = "todos", valor = -250 },
  { nome = "SUBSIDIO", tipo = "pobres", valor = 400 },
  { nome = "IMPOSTO", tipo = "ricos", valor = -400 },
  { nome = "VOLATILIDADE", tipo = "aleatorio", min = -300, max = 300 },
  { nome = "ESTIMULO", tipo = "todos", valor = 200 },
}

-- Combinacoes de mercado (manual 6): conjuntos de cartas jogadas na MESMA
-- rodada. A recompensa e creditada no inicio da rodada seguinte, uma vez por
-- combinacao. A lista fica no motor para poder ser exibida no prototipo.
local COMBOS = {
  {
    nome = "5S COMPLETO",
    cartas = { "Seiri", "Seiton", "Seiso", "Seiketsu", "Shitsuke" },
    premio = 300,
  },
  {
    nome = "TRIADE FINANCEIRA",
    cartas = { "Emprestimo", "Nosso", "Cris e Greg Agiotas" },
    premio = 250,
  },
  {
    nome = "MARKETING E PRODUCAO",
    cartas = { "Toyotinho", "Presente do Noel", "Queima de Estoque" },
    premio = 200,
  },
  {
    nome = "CONTROLE E DEFESA",
    cartas = { "Psicologia Industrial", "Mao Visivel", "Tempos e Movimentos" },
    premio = 150,
  },
}

J.SALDO_INICIAL = SALDO_INICIAL
J.MAYO_CHANCE = MAYO_CHANCE
J.SALDO_EMERGENCIA = SALDO_EMERGENCIA
J.CARTAS_POR_TURNO = CARTAS_POR_TURNO
J.CHAIN_MAX = CHAIN_MAX
J.CHAIN_CLASSES = CHAIN_CLASSES
J.CARTAS_POR_MAO = CARTAS_POR_MAO
J.AREA_SEGURA_MAX = AREA_SEGURA_MAX
J.TURNO_BASE_SEGUNDOS = TURNO_BASE_SEGUNDOS
J.MAX_TURNOS = MAX_TURNOS
J.RENDA_BASE = RENDA_BASE
J.RENDA_INCREMENTO = RENDA_INCREMENTO
J.LEILAO_INTERVALO = LEILAO_INTERVALO
J.LEILAO_SEGUNDOS = LEILAO_SEGUNDOS
J.LOJINHA_SEGUNDOS = LOJINHA_SEGUNDOS
J.BONUS_COPIA = BONUS_COPIA
J.DEFESA_TURNOS = DEFESA_TURNOS
J.COMBOS = COMBOS
J.EVENTOS_DEUS = EVENTOS_DEUS
J.CARTAS_MAX_TOTAL = CARTAS_MAX_TOTAL
J.SATISFACAO_INICIAL = SATISFACAO_INICIAL
J.SATISFACAO_MIN = SATISFACAO_MIN
J.SATISFACAO_MAX = SATISFACAO_MAX
J.SATISFACAO_BONUS_CARTAS = SATISFACAO_BONUS_CARTAS
J.PRODUTIVIDADE_MIN = PRODUTIVIDADE_MIN
J.FUSAO_MIN = FUSAO_MIN
J.FUSAO_MAX = FUSAO_MAX

local function registrar(p, msg)
  table.insert(p.log, msg)
  while #p.log > 60 do table.remove(p.log, 1) end
end
J.registrar = registrar

local function copiar(t)
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  return c
end
J.copiar = copiar

local function sincronizarStatus(j)
  if j.falido then
    j.status = J.STATUS.ELIMINADO
  else
    j.status = J.STATUS.ATIVO
  end
end
J.sincronizarStatus = sincronizarStatus

-- ============================================================
-- JOGADORES / PARTIDA
-- ============================================================

-- Chain System: helpers puros usados pelo motor, pela UI e pela rede.
local function resetChain(j)
  if not j then return end
  j.chainClasse = nil
  j.chainBonus = 0
end
J.resetChain = resetChain

-- Quota efetiva do turno: 2 cartas base + bonus de cadeia (max. 2 extras).
-- `idx` e o assento; sem idx usa a vez atual.
function J.quotaTurno(p, idx)
  local j = p and p.jogadores and p.jogadores[idx or p.vez]
  local extra = j and math.max(0, math.min(CHAIN_MAX, j.chainBonus or 0)) or 0
  return CARTAS_POR_TURNO + extra
end

function J.jogadasRestantes(p, idx)
  return math.max(0, J.quotaTurno(p, idx) - ((p and p.jogadasTurno) or 0))
end

-- Atualiza a cadeia depois de uma carta que consome quota. Devolve true se a
-- carta continuou a sequencia e false se ela iniciou/rompeu a cadeia.
local function registrarChain(j, carta)
  local classe = carta and carta.classe
  if not classe or not CHAIN_CLASSES[classe] then
    -- Carta sem classe (cartas de teste antigas) nao entra no combo.
    j.chainClasse = nil
    j.chainBonus = 0
    return false
  end

  local continuou = j.chainClasse == classe
  if continuou then
    if (j.chainBonus or 0) < CHAIN_MAX then
      j.chainBonus = (j.chainBonus or 0) + 1
    end
  else
    -- Trocou de classe: a cadeia anterior termina e a nova comeca do zero.
    j.chainBonus = 0
  end
  j.chainClasse = classe
  return continuou
end

function J.criarJogador(nome, isIA)
  return {
    nome = nome,
    isIA = isIA,
    saldo = SALDO_INICIAL,
    usouFundoEmergencia = false,
    falido = false,
    status = J.STATUS.ATIVO,
    mao = {},
    areaSegura = {},
    protegido = false,
    protegeContra = nil,
    efeitos = {},
    -- Areas novas do manual: defesa ativa, cartas de acao em vigor e
    -- curingas jogados pelo proprio jogador.
    defesas = {},
    pilhaJogadas = {},
    pilhaCuringa = {},
    cartasTurno = {},
    comboCartas = {},
    -- Livro-caixa: receitas/despesas e extrato cronologico. A vitoria
    -- continua sendo por saldo, mas o lucro fica registrado para consulta.
    receitas = 0,
    despesas = 0,
    -- Manual V7 5.3: Barra de Satisfacao 0..200 (com 100) e 5.4:
    -- Produtividade percentual aplicada sobre a renda da rodada.
    satisfacao = SATISFACAO_INICIAL,
    greve = false,
    bonusSatisfacao = 0, -- cartas restantes com efeitos dobrados (max 200)
    produtividade = 0,    -- fracao, ex.: 0.10 = +10%
    -- Chain System: classe da ultima carta jogada neste turno e bonus
    -- acumulado de jogadas extras (maximo CHAIN_MAX).
    chainClasse = nil,
    chainBonus = 0,
    extrato = {
      { delta = SALDO_INICIAL, categoria = "inicial", rodada = 1,
        saldo = SALDO_INICIAL },
    },
  }
end

-- Sorteia UMA carta do baralho infinito e carimba um uid unico da partida
-- (o mesmo id pode sair varias vezes; o uid e que precisa ser unico).
local function novaCarta(p)
  local c = cartas.comprarCarta()
  if not c then return nil end
  p.proxUid = (p.proxUid or 0) + 1
  c.uid = c.id .. "-" .. p.proxUid
  -- Fase propria para o brilho de Curinga (nao sincroniza com as outras).
  -- Derivada do uid para nao consumir o RNG da partida/testes.
  local hash = 0
  for k = 1, #c.uid do
    hash = (hash * 31 + c.uid:byte(k)) % 1000003
  end
  c.fase = (hash % 1000) / 1000
  return c
end
J.novaCarta = novaCarta

-- Compra exatamente `n` cartas do baralho infinito (sem passar de 7 na mao).
-- Efeitos que puxam cartas usam esta; o fim de turno usa J.comprar.
local function comprarCartas(p, j, n)
  local compradas = 0
  for _ = 1, n do
    if #j.mao >= CARTAS_POR_MAO then break end
    local c = novaCarta(p)
    if not c then break end
    table.insert(j.mao, c)
    compradas = compradas + 1
  end
  return compradas
end
J.comprarCartas = comprarCartas

-- Compra de fim de turno: completa a mao ate CARTAS_POR_MAO (7), nao apenas
-- uma carta. Devolve quantas entraram.
function J.comprar(p, j)
  return comprarCartas(p, j, CARTAS_POR_MAO - #j.mao)
end

-- Nomes do modo ARENA (ArenaMultiplayer.js: nomes[i] da inicializacao local).
local NOMES_ARENA = { "JOGADOR_1", "ROBO", "RAPOSA", "DRAGAO", "MASCARA", "LEAO", "LUA", "RAIO" }

-- opts: { n = 2..8, nomes = {...}, avatares = {...} }.
-- Sem opts mantem o duelo classico (JOGADOR_1 x Adam Smith).
function J.criarPartida(opts)
  opts = opts or {}
  local n = math.max(2, math.min(8, tonumber(opts.n) or 2))
  local nomes = opts.nomes
  if not nomes then
    nomes = n == 2 and { "JOGADOR_1", "Adam Smith" } or NOMES_ARENA
  end
  local avatares = opts.avatares or {}
  local lista = {}
  for i = 1, n do
    local j = J.criarJogador(nomes[i] or NOMES_ARENA[i] or ("JOGADOR " .. i), i > 1)
    j.avatar = avatares[i]
    lista[i] = j
  end

  local p = {
    jogadores = lista,
    pilhaDescarte = {},
    -- Pilha global de Curingas: o curinga global ativo substitui o anterior.
    pilhaCuringa = {},
    -- Leilao/lojinha pendentes (a UI em main/meta consome).
    metaPendente = nil,
    metaRodada = nil,
    leilao = nil,
    lojinha = nil,
    curingaGlobal = nil,
    curingaHistorico = {},
    curingaSeq = 0,
    comboEvento = nil,
    rendaRodada = nil,
    -- Uid da proxima carta comprada (baralho infinito: a mesma carta pode
    -- sair varias vezes, entao cada instancia ganha um uid proprio).
    proxUid = 0,
    turno = 1,
    maxTurnos = MAX_TURNOS,
    vez = love.math.random(n),
    jogadasTurno = 0,
    fim = false,
    vencedor = nil,
    motivo = nil,
    evento = nil,
    log = {},
  }

  -- Mao inicial: completa 7 em cada jogador (baralho infinito).
  for _, j in ipairs(p.jogadores) do
    J.comprar(p, j)
  end

  -- Turno 1 tambem passa pelo inicio de turno (habilidade do avatar Marx
  -- vale ja na primeira vez; sem efeitos ativos no comeco o tick e um no-op).
  J.processarInicioTurno(p, p.vez)

  registrar(p, "Comeco! Turno 1 de " .. MAX_TURNOS)
  return p
end

-- ============================================================
-- SALDO / FALENCIA (motorEfeitos.js)
-- ============================================================

local function temFlutuacao(j)
  for _, e in ipairs(j.efeitos) do
    if e.tipo == "RENDA_ALEATORIA" then return true end
  end
  return false
end

-- Manual V2: a partir da SEGUNDA copia da MESMA carta no mesmo turno, a
-- chance aumenta em 50% (multiplicador 1.5). Funcao pura para testes e para
-- o motor aplicar depois dos modificadores de efeitos.
function J.aplicarBonusCopia(chance, j, carta)
  local copias = (j and j.cartasTurno and j.cartasTurno[carta.id]) or 0
  if copias >= 1 then
    return math.min(1, chance * (1 + BONUS_COPIA))
  end
  return chance
end

-- Aplica delta no saldo de `j` (Flutuacao do mercado) e registra no
-- livro-caixa. O manual V2 nao tem fundo de emergencia: ao chegar a zero o
-- jogador vai a FALENCIA imediatamente (saldo fica em zero).
local function aplicarSaldo(p, j, delta, categoria)
  if not delta or delta == 0 then return end
  local valor = delta
  if delta > 0 and temFlutuacao(j) then
    valor = math.floor(love.math.random() * (delta + 1))
  end

  local antes = j.saldo
  local efetivo = valor
  if j.saldo + valor <= 0 then
    efetivo = -j.saldo
    j.saldo = 0
    if not j.falido then
      j.falido = true
      registrar(p, j.nome .. " foi a FALENCIA (saldo zero)!")
    end
  else
    j.saldo = j.saldo + valor
  end

  j.receitas = (j.receitas or 0) + math.max(0, efetivo)
  j.despesas = (j.despesas or 0) + math.max(0, -efetivo)
  j.extrato = j.extrato or {}
  table.insert(j.extrato, {
    delta = efetivo,
    categoria = categoria or "efeito",
    rodada = p and p.turno or 1,
    saldo = j.saldo,
  })
  -- O extrato e historico/estatistica; nao e a condicao de vitoria.
  j.lucro = j.saldo - SALDO_INICIAL
  sincronizarStatus(j)
  return efetivo
end
J.aplicarSaldo = aplicarSaldo

-- ============================================================
-- TEMPO DE TURNO
-- ============================================================

function J.duracaoTurno(j)
  local definido = nil
  for _, e in ipairs(j.efeitos) do
    if e.tipo == "TEMPO_TURNO" and e.modo == "definir" then
      local s = e.segundos or TURNO_BASE_SEGUNDOS
      if not definido or s < definido then definido = s end
    end
  end
  if definido then return math.max(1, definido) end

  local bonus = 0
  for _, e in ipairs(j.efeitos) do
    if e.tipo == "TEMPO_TURNO" and e.modo == "bonus" then
      bonus = bonus + (e.segundos or 0)
    end
  end
  return math.max(1, TURNO_BASE_SEGUNDOS + bonus)
end

-- ============================================================
-- CHANCE (calcularChance)
-- ============================================================

function J.calcularChance(carta, j)
  local chance = carta.chanceSucesso or 1
  local restantes = {}

  for _, e in ipairs(j.efeitos or {}) do
    if e.tipo == "MOD_CHANCE" then
      chance = chance + (e.valor or 0)
      table.insert(restantes, e)
    elseif e.tipo == "MOD_FALHA" then
      -- Reduz a chance de FALHA (fator 0.6 = falha 40% menor).
      chance = 1 - (1 - chance) * (e.fator or 1)
      table.insert(restantes, e)
    elseif e.tipo == "CHANCE_FIXA" then
      if not e.soNegativa or cartas.ehCartaNegativa(carta) then
        chance = e.valor or chance
        local usos = (e.usos or 1) - 1
        if usos > 0 then
          local copia = copiar(e)
          copia.usos = usos
          table.insert(restantes, copia)
        end
      else
        table.insert(restantes, e)
      end
    elseif e.tipo == "MULT_CHANCE" then
      chance = chance * (e.fator or 1)
      local usos = (e.usos or 1) - 1
      if usos > 0 then
        local copia = copiar(e)
        copia.usos = usos
        table.insert(restantes, copia)
      end
    else
      table.insert(restantes, e)
    end
  end

  -- Habilidade do avatar Taylor (prototipo): +10% de chance para cartas de
  -- ACAO/EFEITO jogadas pelo portador. Aplicada antes do clamp final.
  if j.avatar == "taylor" and (carta.tipo == "ACAO" or carta.tipo == "EFEITO") then
    chance = chance + 0.1
  end

  j.efeitos = restantes
  if chance < 0 then chance = 0 elseif chance > 1 then chance = 1 end
  return chance
end

-- ============================================================
-- EFEITOS ATIVOS
-- ============================================================

-- Efeitos lidos DURANTE o turno: como o decremento acontece antes da
-- leitura, guardamos 1 turno a mais para valer `turnos` turnos.
local EFEITOS_LIDOS_NO_TURNO = {
  TEMPO_TURNO = true,
  MOD_CHANCE = true,
  MOD_FALHA = true,
  RENDA_ALEATORIA = true,
}

function J.adicionarEfeito(j, efeito, bonusTurnos)
  local e = copiar(efeito)
  bonusTurnos = bonusTurnos or 0
  if type(e.turnos) == "number" then
    e.turnos = e.turnos + bonusTurnos
    if EFEITOS_LIDOS_NO_TURNO[e.tipo] then e.turnos = e.turnos + 1 end
  end

  local atuais = j.efeitos or {}
  if e.tipo == "MOD_BONUS_TURNO" then
    -- Overclock: o novo bonus substitui o anterior.
    local novos = {}
    for _, x in ipairs(atuais) do
      if x.tipo ~= "MOD_BONUS_TURNO" then table.insert(novos, x) end
    end
    atuais = novos
  end
  table.insert(atuais, e)
  j.efeitos = atuais
end

-- Shitsuke: consome 1 uso e devolve os turnos extras.
function J.consumirProlonga(j)
  local efeitos = j.efeitos or {}
  for i, e in ipairs(efeitos) do
    if e.tipo == "PROLONGA" then
      local usos = (e.usos or 1) - 1
      if usos > 0 then
        e.usos = usos
      else
        table.remove(efeitos, i)
      end
      return e.turnosAdicionais or 0
    end
  end
  return 0
end

-- Defesas podem ser de BLOQUEIO (cancelam a carta atacante) ou de MITIGACAO
-- (Tempos e Movimentos / Seiketsu fixam a chance em 50%; Previsao corta a
-- chance pela metade). O efeito guardado na propria carta define a mitigacao:
-- CHANCE_FIXA (valor) ou MULT_CHANCE (fator).
local function efeitoMitigador(defesa)
  local c = defesa and defesa.carta
  local ef = c and c.efeito
  if not ef then return nil end
  if ef.tipo ~= "CHANCE_FIXA" and ef.tipo ~= "MULT_CHANCE" then return nil end
  return ef
end

-- Devolve o efeito de mitigacao se a defesa ativa do alvo reage a `carta`.
local function mitigacaoPorProtecao(alvo, carta)
  if not alvo or not alvo.protegido then return nil end
  local d = alvo.defesas and alvo.defesas[1]
  local ef = efeitoMitigador(d)
  if not ef then return nil end
  if d.carta.protegeContra and d.carta.protegeContra ~= carta.tipo then
    return nil
  end
  if ef.soNegativa and not cartas.ehCartaNegativa(carta) then return nil end
  if ef.soEfeito and carta.tipo ~= "EFEITO" then return nil end
  return ef
end
J.mitigacaoPorProtecao = mitigacaoPorProtecao

-- A defesa ARMADA so entra em acao se o dono escolheu defender. A janela do
-- Quick Counter grava opts.defesaDe[assento] = true/false; ausente = automatico
-- (IA, simulacao e ataques sem janela). A imunidade temporaria (Atestado) nao
-- depende dessa escolha.
local function defesaPermitida(opts, idx)
  local m = opts and opts.defesaDe
  if not m or m[idx] == nil then return true end
  return m[idx] == true
end

local function bloqueadoPorProtecao(alvo, carta, permitirDefesa)
  -- Atestado Medico (PROTECAO_TOTAL) e uma imunidade temporaria.
  for _, e in ipairs(alvo.efeitos or {}) do
    if e.tipo == "PROTECAO_TOTAL" then return true end
  end
  if permitirDefesa == false then return false end
  if not alvo.protegido then return false end
  -- Defesa mitigadora nao cancela: a chance ja foi ajustada antes do dado.
  if efeitoMitigador(alvo.defesas and alvo.defesas[1]) then return false end
  if not alvo.protegeContra then return true end
  return alvo.protegeContra == carta.tipo
end

-- Move a defesa ativa para o descarte e limpa os flags. O `p` e opcional
-- para chamadas antigas dos testes.
local function removerDefesa(p, alvo)
  if alvo.defesas and #alvo.defesas > 0 then
    local d = table.remove(alvo.defesas, 1)
    if p and d and d.carta then table.insert(p.pilhaDescarte, d.carta) end
  end
end

local function consumirProtecao(alvo, p)
  if alvo.protegido then removerDefesa(p, alvo) end
  alvo.protegido = false
  alvo.protegeContra = nil
end

-- Defesas do manual valem por alguns turnos. O contador e decrementado no
-- inicio do turno do dono; ao zerar, a carta vai para o descarte.
local function atualizarDefesas(p, idx)
  local j = p.jogadores[idx]
  if not j or not j.defesas then return end
  local restantes = {}
  for _, d in ipairs(j.defesas) do
    d.turnos = (d.turnos or 1) - 1
    if d.turnos > 0 then
      table.insert(restantes, d)
    else
      table.insert(p.pilhaDescarte, d.carta)
      if j.protegido then
        j.protegido = false
        j.protegeContra = nil
      end
      registrar(p, "Defesa de " .. j.nome .. " expirou: " .. d.carta.nome)
    end
  end
  j.defesas = restantes
end
J.atualizarDefesas = atualizarDefesas

-- ============================================================
-- Habilidade do avatar Elton Mayo (prototipo)
-- ============================================================
-- Uma vez por rodada (turno), quando um adversario joga carta negativa
-- contra o portador, 30% de chance de neutralizar o efeito negativo. A
-- tentativa (sucesso ou falha) consome a vez da rodada. p.habilidade
-- alimenta o popup da UI (padrao marx). Exportada para os testes.
function J.tentarMayo(p, idxAlvo, idxJog, carta)
  local alvo = p.jogadores[idxAlvo]
  if not alvo or alvo.falido or alvo.saiu or alvo.avatar ~= "mayo" then
    return false
  end
  if idxAlvo == idxJog then return false end
  if not cartas.ehCartaNegativa(carta) then return false end
  if alvo.mayoRodada == p.turno then return false end  -- ja usou nesta rodada
  alvo.mayoRodada = p.turno  -- consome a tentativa (sucesso ou falha)
  if love.math.random() >= J.MAYO_CHANCE then return false end
  p.habilidade = { tipo = "mayo", de = idxJog, para = idxAlvo }
  return true
end

-- ============================================================
-- AUXILIARES DE EFEITO
-- ============================================================

-- Roubo de cartas: aleatorio, ou por uids escolhidas (roubo as cegas da
-- carta Vigarice, igual ao motorEfeitos.js). Teto: mao pode estourar em
-- ate 2 cartas, mas nunca passar de 9.
local function roubarCartas(p, idxAlvo, idxJog, quantidade, uidsEscolhidas)
  local alvo = p.jogadores[idxAlvo]
  local inv = p.jogadores[idxJog]
  local roubadas = 0

  local escolhidas = {}
  if type(uidsEscolhidas) == "table" then
    local visto = {}
    for _, uid in ipairs(uidsEscolhidas) do
      if not visto[uid] then
        visto[uid] = true
        table.insert(escolhidas, uid)
      end
    end
  end

  if #escolhidas > 0 then
    -- Roubo as cegas: o jogador escolheu os uids sem ver as cartas.
    -- uid invalido nao consome a cota de `quantidade`.
    for _, uid in ipairs(escolhidas) do
      if roubadas >= quantidade then break end
      if #inv.mao >= J.tetoMao(p, inv) then break end
      local idx = nil
      for i, c in ipairs(alvo.mao) do
        if c.uid == uid then idx = i break end
      end
      if idx then
        table.insert(inv.mao, table.remove(alvo.mao, idx))
        roubadas = roubadas + 1
      end
    end
    return roubadas, true
  end

  for _ = 1, quantidade do
    if #alvo.mao == 0 then break end
    if #inv.mao >= J.tetoMao(p, inv) then break end
    local de = love.math.random(#alvo.mao)
    table.insert(inv.mao, table.remove(alvo.mao, de))
    roubadas = roubadas + 1
  end
  return roubadas, false
end

local function descartarEPuxar(p, idx, quantidade)
  local j = p.jogadores[idx]
  local descartadas, puxadas = 0, 0
  for _ = 1, quantidade do
    if #j.mao > 0 then
      local de = love.math.random(#j.mao)
      table.insert(p.pilhaDescarte, table.remove(j.mao, de))
      descartadas = descartadas + 1
    end
    -- Baralho infinito: a carta puxada vem de comprarCarta(), nunca de pilha.
    puxadas = puxadas + comprarCartas(p, j, 1)
  end
  return descartadas, puxadas
end

-- "Devolver ao baralho" no baralho INFINITO: as cartas apenas saem da mao
-- (vão para o descarte, que e visual) — nao existe pilha de compra para
-- devolver nem reembaralhar.
local function descartarDaMao(p, idx, quantidade)
  local j = p.jogadores[idx]
  local descartadas = 0
  for _ = 1, quantidade do
    if #j.mao == 0 then break end
    table.insert(p.pilhaDescarte, table.remove(j.mao, love.math.random(#j.mao)))
    descartadas = descartadas + 1
  end
  return descartadas
end

-- ============================================================
-- SATISFACAO E PRODUTIVIDADE (manual V7 5.3 / 5.4)
-- ============================================================

-- Barra de Satisfacao: 0..200 (comeca em 100). Em 0 o jogador entra em
-- GREVE e perde o proximo turno; em 200 ele ganha o beneficio de dobrar os
-- efeitos das proximas duas cartas (a barra volta a 100 ao consumir o bonus).
function J.alterarSatisfacao(p, idx, delta, opts)
  opts = opts or {}
  local j = p.jogadores[idx]
  if not j or j.falido or j.saiu then return 0 end
  local antes = tonumber(j.satisfacao) or SATISFACAO_INICIAL
  local novo
  if opts.setar then
    novo = math.max(SATISFACAO_MIN,
      math.min(SATISFACAO_MAX, tonumber(delta) or 0))
  else
    novo = math.max(SATISFACAO_MIN,
      math.min(SATISFACAO_MAX, antes + (tonumber(delta) or 0)))
  end
  j.satisfacao = novo

  if novo <= SATISFACAO_MIN then
    j.greve = true
  end
  -- So concede o bonus se nao ha um pendente (evita estender o beneficio).
  if novo >= SATISFACAO_MAX and (j.bonusSatisfacao or 0) <= 0 then
    j.bonusSatisfacao = SATISFACAO_BONUS_CARTAS
  end
  if (novo - antes) ~= 0 then
    j.flashSat = love.timer.getTime()
  end
  return novo - antes
end

-- Produtividade: percentual acumulativo aplicado sobre a renda da rodada.
-- Piso em -100% (PRODUTIVIDADE_MIN); nao ha teto superior (manual 5.4).
function J.alterarProdutividade(p, idx, fracao, opts)
  opts = opts or {}
  local j = p.jogadores[idx]
  if not j or j.falido or j.saiu then return 0 end
  local atual = tonumber(j.produtividade) or 0
  local novo
  if opts.setarPositivo then
    novo = math.max(PRODUTIVIDADE_MIN, tonumber(fracao) or 0)
    if novo < 0 then novo = 0 end
  else
    novo = math.max(PRODUTIVIDADE_MIN,
      atual + (tonumber(fracao) or 0))
  end
  j.produtividade = novo
  if (novo - atual) ~= 0 then
    j.flashProd = love.timer.getTime()
  end
  return novo - atual
end

-- Alvos declarados em carta.satisfacao / carta.produtividade.
local function alvosDoCampo(p, campo, idxJog, idxAlvo, temAlvo)
  if not campo then return nil end
  local t = campo.alvo or "invocador"
  local lista = {}
  if t == "invocador" then
    lista = { idxJog }
  elseif t == "alvo" then
    if temAlvo then lista = { idxAlvo } end
  elseif t == "oponentes" then
    for i = 1, #p.jogadores do
      if i ~= idxJog then lista[#lista + 1] = i end
    end
  else
    for i = 1, #p.jogadores do lista[#lista + 1] = i end
  end
  return lista
end

-- Efeitos que dobram no beneficio da Satisfacao MAX. So magnitudes
-- numericas: duracoes, chances e a penalidade de falha ficam iguais.
local TIPOS_EFEITO_DOBRA = {
  RENDA_FIXA = true,
  DANO_PERIODICO = true,
  RENDA_ALVO = true,
  DINHEIRO_ADIADO = true,
  DIVIDA = true,
}

local function dobrarEfeito(efeito)
  if not efeito then return nil end
  local novo = copiar(efeito)
  if TIPOS_EFEITO_DOBRA[novo.tipo] and type(novo.valor) == "number" then
    novo.valor = novo.valor * 2
  end
  local campos = { "ganhoInvocador", "perdaAlvo", "min", "max",
    "quantidade", "segundos", "tempoBonus" }
  for _, campo in ipairs(campos) do
    if type(novo[campo]) == "number" then novo[campo] = novo[campo] * 2 end
  end
  if novo.debuff then novo.debuff = dobrarEfeito(novo.debuff) end
  return novo
end
J.dobrarEfeito = dobrarEfeito

-- Manual V7 5.5.3: as cartas da classe Defesa ocupam o Slot de Defesa
-- (apenas uma ativa por vez) e protegem o proprio dono. O `tipo == "PROTECAO"`
-- continua valendo como marcador estrutural (cartas de teste e defesas).
function J.ehDefesa(c)
  return c ~= nil and (c.classe == "Defesa" or c.tipo == "PROTECAO")
end

-- Manual V7 4.4: maximo de 10 cartas por jogador (7 de mao + 1 de banco).
-- Durante o evento do Deus Mercado (leilao/lojinha/fusao) esse teto pode ser
-- excedido. O teto e sobre o TOTAL: com o banco cheio, a mao fica em 7.
function J.tetoMao(p, j)
  if p and p.eventoMeta then return math.huge end
  local banco = (j and j.areaSegura) and #j.areaSegura or 0
  return math.max(CARTAS_POR_MAO, CARTAS_MAX_TOTAL - banco)
end

-- ============================================================
-- EXECUCAO DE UMA CARTA (executarCarta)
-- ============================================================

local function executarCarta(p, idxJog, idxAlvo, carta, opts)
  opts = opts or {}
  local origem = opts.origem or ""
  local jogadores = p.jogadores
  local j = jogadores[idxJog]
  local extras = {}
  -- Assento sorteado pela Probabilidade Mortal (feedback/animacao no main).
  local vitimaIdx = nil

  -- Beneficio da Satisfacao MAX (manual 5.3): consome 1 das 2 cartas e
  -- dobra os efeitos numericos desta carta. Consumo vale para qualquer
  -- carta utilizada, inclusive Defesa.
  local mult = 1
  if j and (j.bonusSatisfacao or 0) > 0 then
    j.bonusSatisfacao = j.bonusSatisfacao - 1
    mult = 2
    if j.bonusSatisfacao == 0 then
      j.satisfacao = SATISFACAO_INICIAL
    end
    table.insert(extras, "(Satisfacao MAX: efeitos dobrados!)")
  end

  if J.ehDefesa(carta) then
    -- Defesa ativa no slot unico: a nova substitui a anterior (a antiga vai
    -- para o descarte). A duracao padrao e 2 turnos do dono.
    if j.defesas and #j.defesas > 0 then
      for _, d in ipairs(j.defesas) do
        table.insert(p.pilhaDescarte, d.carta)
      end
    end
    j.defesas = { {
      carta = carta,
      turnos = carta.defesaTurnos or DEFESA_TURNOS,
    } }
    j.protegido = true
    j.protegeContra = carta.protegeContra
    local contra = carta.protegeContra and (" contra " .. carta.protegeContra) or ""
    return {
      sucesso = true,
      chance = carta.chanceSucesso or 1,
      delta = 0,
      mensagem = "Protecao ativa" .. contra,
      log = j.nome .. " ativou protecao" .. origem .. ": " .. carta.nome,
      -- Escudo no proprio seat ao ativar a defesa.
      protecao = { idxJog },
    }
  end

  local temAlvo = carta.precisaAlvo and idxAlvo ~= nil and idxAlvo ~= idxJog

  -- Defesas mitigadoras (Tempos e Movimentos / Seiketsu): antes do dado,
  -- forcam a chance da carta atacante a 50%. A defesa e consumida logo
  -- depois, quer o ataque acerte ou erre. O ataque NAO e cancelado.
  local mitigados = {}
  local efMitigacao = nil
  local function registrarMitigacao(alvo, idx)
    if not alvo or idx == idxJog then return end
    if not defesaPermitida(opts, idx) then return end
    local ef = mitigacaoPorProtecao(alvo, carta)
    if not ef then return end
    mitigados[#mitigados + 1] = { alvo = alvo, idx = idx }
    if not efMitigacao then efMitigacao = ef end
  end
  if temAlvo then
    registrarMitigacao(jogadores[idxAlvo], idxAlvo)
  elseif carta.efeito and (carta.efeito.alvo == "todos"
      or carta.efeito.alvo == "oponentes") then
    for i = 1, #jogadores do registrarMitigacao(jogadores[i], i) end
  end
  if efMitigacao then
    table.insert(j.efeitos, 1, {
      tipo = efMitigacao.tipo,
      valor = efMitigacao.valor,
      fator = efMitigacao.fator,
      usos = 1, _defesaTemp = true,
    })
  end

  local chance = J.calcularChance(carta, j)
  -- Manual V2: a partir da SEGUNDA copia da MESMA carta no mesmo turno, a
  -- chance aumenta em 50% (multiplicador 1.5). O contador e por jogador e
  -- zera no inicio do turno dele (processarInicioTurno).
  chance = J.aplicarBonusCopia(chance, j, carta)
  local sucesso = love.math.random() < chance

  -- Dinheiro base (sucesso/falha, ou valor aleatorio da divida).
  -- O beneficio da Satisfacao MAX dobra os efeitos: so a parte de SUCESSO
  -- (a penalidade de falha fica como esta, por ser perda do jogador).
  local delta
  if sucesso then
    delta = (carta.alteracaoSaldoBase or 0) * mult
  else
    delta = carta.alteracaoSaldoFalha or 0
  end
  local efeito = carta.efeito
  if mult == 2 then efeito = dobrarEfeito(carta.efeito) end
  if efeito and efeito.tipo == "DIVIDA" and sucesso then
    -- Igual ao React: min + [0..max-min] (random(n) no Lua e 1-based).
    delta = -(efeito.min + love.math.random(efeito.max - efeito.min + 1) - 1)
  end

  local dinheiroEm = carta.dinheiroEm or (carta.precisaAlvo and "alvo" or "invocador")
  local bloqueado = false
  -- Seats que bloquearam algo com protecao nesta carta (feedback visual).
  local protetores = {}

  if efMitigacao then
    -- calcularChance ja consome o CHANCE_FIXA de 1 uso; a limpeza garante
    -- que nenhum efeito temporario vaze para os proximos turnos.
    for k = #j.efeitos, 1, -1 do
      if j.efeitos[k]._defesaTemp then table.remove(j.efeitos, k) end
    end
    for _, m in ipairs(mitigados) do
      protetores[#protetores + 1] = m.idx
      local rotulo
      if efMitigacao.tipo == "MULT_CHANCE" then
        rotulo = "Chance -" .. math.floor(
          (1 - (efMitigacao.fator or 0.5)) * 100 + 0.5) .. "%"
      else
        rotulo = "Chance "
          .. math.floor((efMitigacao.valor or 0.5) * 100 + 0.5) .. "%"
      end
      table.insert(extras, "(" .. m.alvo.nome .. " mitigou! " .. rotulo .. ")")
      consumirProtecao(m.alvo, p)
    end
  end

  if dinheiroEm ~= "nenhum" and delta ~= 0 then
    if dinheiroEm == "alvo" and temAlvo then
      local alvo = jogadores[idxAlvo]
      if bloqueadoPorProtecao(alvo, carta, defesaPermitida(opts, idxAlvo)) then
        bloqueado = true
        protetores[#protetores + 1] = idxAlvo
        table.insert(extras, "(" .. alvo.nome .. " protegido! Sem efeito)")
        consumirProtecao(alvo, p)
      elseif J.tentarMayo(p, idxAlvo, idxJog, carta) then
        table.insert(extras, "(" .. alvo.nome .. " neutralizou!)")
      else
        aplicarSaldo(p, alvo, delta)
        table.insert(extras, "(" .. alvo.nome .. ": " .. (delta > 0 and "+" or "") .. delta .. ")")
      end
    else
      if j.protegido and delta < 0 and defesaPermitida(opts, idxJog) then
        bloqueado = true
        protetores[#protetores + 1] = idxJog
        table.insert(extras, "(Protegido! Sem perda)")
        consumirProtecao(j, p)
      else
        aplicarSaldo(p, j, delta)
      end
    end
  end

  -- Efeito especial (somente em caso de sucesso).
  if sucesso and efeito and not bloqueado then
    local protegido = false
    local mayoBloq = false
    if efeito.alvo == "alvo" and temAlvo then
      local alvo = jogadores[idxAlvo]
      if bloqueadoPorProtecao(alvo, carta, defesaPermitida(opts, idxAlvo)) then
        protegido = true
        protetores[#protetores + 1] = idxAlvo
        table.insert(extras, "(" .. alvo.nome .. " protegido! Sem efeito)")
        consumirProtecao(alvo, p)
      else
        mayoBloq = J.tentarMayo(p, idxAlvo, idxJog, carta)
        if mayoBloq then
          table.insert(extras, "(" .. alvo.nome .. " neutralizou!)")
        end
      end
    end

    if not protegido then
      local bonusTurnos = 0
      if carta.tipo == "ACAO" then
        bonusTurnos = J.consumirProlonga(j)
      end

      local alvos = {}
      if efeito.alvo == "invocador" then
        alvos = { idxJog }
      elseif efeito.alvo == "alvo" then
        if temAlvo then alvos = { idxAlvo } end
      elseif efeito.alvo == "oponentes" then
        for i = 1, #jogadores do
          if i ~= idxJog then table.insert(alvos, i) end
        end
      else -- todos
        for i = 1, #jogadores do table.insert(alvos, i) end
      end

      local t = efeito.tipo
      if t == "DOACAO_PERCENTUAL" and temAlvo then
        if not mayoBloq then
          local vitima = jogadores[idxAlvo]
          local pct = love.math.random(0, 100)
          local doado = math.floor(math.max(0, vitima.saldo) * (pct / 100) + 0.5)
          aplicarSaldo(p, vitima, -doado)
          aplicarSaldo(p, j, doado)
          table.insert(extras, "doou " .. pct .. "% (" .. doado .. ")")
        end
      elseif t == "DINHEIRO_ALVO" then
        aplicarSaldo(p, j, efeito.ganhoInvocador or 0)
        if temAlvo and not mayoBloq then
          aplicarSaldo(p, jogadores[idxAlvo], -(efeito.perdaAlvo or 0))
          if efeito.debuff then
            J.adicionarEfeito(jogadores[idxAlvo], efeito.debuff, bonusTurnos)
          end
        end
        if mayoBloq then
          table.insert(extras, "(+" .. (efeito.ganhoInvocador or 0) ..
            " / alvo neut.)")
        else
          table.insert(extras, "(+" .. (efeito.ganhoInvocador or 0) ..
            " / alvo -" .. (efeito.perdaAlvo or 0) .. ")")
        end
      elseif t == "ROUBA_CARTAS" and temAlvo then
        if not mayoBloq then
          local roubadas, asCegas = roubarCartas(p, idxAlvo, idxJog,
            efeito.quantidade or 1, opts.roubarUids)
          table.insert(extras, "roubou " .. roubadas .. " carta(s)" ..
            (asCegas and roubadas > 0 and " (as cegas)" or ""))
        end
      elseif t == "DESCARTA_E_PUXA" and temAlvo then
        if not mayoBloq then
          local d, x = descartarEPuxar(p, idxAlvo, efeito.quantidade or 1)
          table.insert(extras, "descartou " .. d .. " e puxou " .. x)
        end
      elseif t == "TROCA_MAO" then
        local devolvidas = descartarDaMao(p, idxJog, efeito.quantidade or 3)
        local novo = copiar(efeito)
        novo.alvo = "invocador"
        J.adicionarEfeito(j, novo, bonusTurnos)
        table.insert(extras, "descartou " .. devolvidas .. " carta(s) da mao")
      elseif t == "TROCA_MAOS" then
        -- Rotatividade de Mercado: as maos dos jogadores vivos giram uma
        -- posicao. Nao mexe em saldo/area/buffs (o antigo TROCA_ESTADO_TOTAL
        -- so registrava um efeito inerte).
        local vivos = {}
        for i, alvo in ipairs(jogadores) do
          if not alvo.falido and not alvo.saiu then vivos[#vivos + 1] = i end
        end
        if #vivos > 1 then
          local maos = {}
          for k, idx in ipairs(vivos) do maos[k] = jogadores[idx].mao end
          for k, idx in ipairs(vivos) do
            jogadores[idx].mao = maos[(k % #vivos) + 1]
          end
          table.insert(extras, "maos trocadas pelo Deus Mercado")
        end
      elseif t == "MORTE_ALEATORIA" then
        -- Probabilidade Mortal: o Deus Mercado sorteia um jogador vivo e
        -- zera o saldo dele (aplicarSaldo ja marca falido e registra o log).
        local vivos = {}
        for i, alvo in ipairs(jogadores) do
          if not alvo.falido and not alvo.saiu then vivos[#vivos + 1] = i end
        end
        if #vivos > 0 then
          vitimaIdx = vivos[love.math.random(#vivos)]
          local vitima = jogadores[vitimaIdx]
          aplicarSaldo(p, vitima, -vitima.saldo)
          table.insert(extras, "(" .. vitima.nome .. " morto pelo Deus Mercado)")
        end
      elseif t == "DIVIDA" then
        -- O dinheiro ja foi aplicado pelo caminho base.
      else
        for _, i in ipairs(alvos) do
          J.adicionarEfeito(jogadores[i], efeito, bonusTurnos)
        end
      end
    end
  end

  -- Barra de Satisfacao e Produtividade (manual V7 5.3/5.4): aplicadas em
  -- caso de sucesso, sobre os alvos declarados na propria carta.
  if sucesso and not bloqueado then
    local campos = {
      { spec = carta.satisfacao, rotulo = "sat" },
      { spec = carta.produtividade, rotulo = "prod" },
    }
    for _, c in ipairs(campos) do
      local lista = alvosDoCampo(p, c.spec, idxJog, idxAlvo, temAlvo)
      if lista then
        local valor = (c.spec.valor or 0) * mult
        local copts = {}
        if c.spec.setar then copts.setar = true end
        if c.spec.setarPositivo then copts.setarPositivo = true end
        for _, i in ipairs(lista) do
          local antesGreve = jogadores[i].greve
          local bloqueou = false
          if i ~= idxJog
              and bloqueadoPorProtecao(jogadores[i], carta,
                defesaPermitida(opts, i)) then
            bloqueou = true
            protetores[#protetores + 1] = i
            consumirProtecao(jogadores[i], p)
            table.insert(extras, "(" .. jogadores[i].nome .. " protegido!)")
          end
          if not bloqueou then
            local real
            if c.rotulo == "sat" then
              real = J.alterarSatisfacao(p, i, valor, copts)
            else
              real = J.alterarProdutividade(p, i, valor, copts)
            end
            if real ~= 0 then
              local txt
              if c.rotulo == "sat" then
                txt = "satisfacao " .. (real > 0 and "+" or "") ..
                  tostring(math.floor(real + (real > 0 and 0.5 or -0.5)))
              else
                txt = "produtividade " .. (real > 0 and "+" or "") ..
                  string.format("%d%%", math.floor(real * 100 +
                    (real > 0 and 0.5 or -0.5)))
              end
              table.insert(extras, jogadores[i].nome .. ": " .. txt)
            end
            if jogadores[i].greve and not antesGreve then
              table.insert(extras, jogadores[i].nome .. " entrou em GREVE!")
            end
          end
        end
      end
    end
  end

  local situacao = sucesso and "com SUCESSO!" or "e FALHOU!"
  local valorTxt = ""
  if dinheiroEm ~= "nenhum" and delta ~= 0 then
    valorTxt = " (" .. (delta > 0 and "+" or "") .. delta .. ")"
  end
  local extrasTxt = #extras > 0 and (" " .. table.concat(extras, " ")) or ""
  local log = j.nome .. " jogou " .. carta.nome .. origem .. " " .. situacao .. valorTxt .. extrasTxt

  local mensagem
  if bloqueado then
    mensagem = "Protegeu!"
  elseif delta > 0 then
    mensagem = "+R$ " .. delta
  elseif delta < 0 then
    mensagem = "-R$ " .. math.abs(delta)
  elseif sucesso then
    mensagem = "Sucesso!"
  else
    mensagem = "Falhou!"
  end

  return {
    sucesso = sucesso,
    chance = chance,
    delta = delta,
    mensagem = mensagem,
    log = log,
    -- Seats protegidos que bloquearam algo (feedback: escudo no alvo).
    protecao = protetores,
    -- Probabilidade Mortal: assento sorteado para a animacao de avanco.
    vitimaIdx = vitimaIdx,
  }
end

-- Carta ja removida da mao pelo chamador (permite animar antes de aplicar).
-- Registra no descarte, executa e devolve { sucesso, chance, consumiuTurno }.
-- opts: { origem = " da Area Segura", roubarUids = {uid...}, semQuota = true }
-- Sorteia um oponente vivo (exclui o proprio jogador). Sem vivos, nil.
function J.sortearAlvo(p, idxJog)
  local vivos = {}
  for i, j in ipairs(p.jogadores) do
    if i ~= idxJog and not j.falido then vivos[#vivos + 1] = i end
  end
  if #vivos == 0 then return nil end
  return vivos[love.math.random(#vivos)]
end

-- Resolve o alvo de uma carta sem executar nada. Usado pelo Quick Counter
-- para saber contra quem a carta vai antes da janela de reacao.
function J.alvoDaCarta(p, indiceJogador, carta, opts)
  opts = opts or {}
  local idxAlvo = opts.alvoIdx
  if carta.precisaAlvo and (not idxAlvo or idxAlvo == indiceJogador) then
    idxAlvo = J.sortearAlvo(p, indiceJogador)
  end
  return idxAlvo
end

function J.aplicarCarta(p, indiceJogador, carta, opts)
  opts = opts or {}
  local idxAlvo = J.alvoDaCarta(p, indiceJogador, carta, opts)

  local j = p.jogadores[indiceJogador]

  -- A protecao fica no Defense Slot ate expirar/ser consumida; as demais
  -- cartas vao para o descarte normal. As pilhas de Jogadas/Curinga sao
  -- espelhos das cartas em vigor, usadas tambem pela UI.
  if not J.ehDefesa(carta) then
    table.insert(p.pilhaDescarte, carta)
  end
  if carta.tipo == "ACAO" or carta.tipo == "EFEITO" then
    table.insert(j.pilhaJogadas, carta)
  elseif carta.tipo == "CORINGA" then
    table.insert(j.pilhaCuringa, carta)
  end

  local res = executarCarta(p, indiceJogador, idxAlvo, carta, opts)
  res.carta = carta
  registrar(p, res.log)

  -- Contador de copias para o bonus de +50% da mesma carta no turno.
  if j then
    j.cartasTurno = j.cartasTurno or {}
    j.cartasTurno[carta.id] = (j.cartasTurno[carta.id] or 0) + 1
    if res.sucesso then
      j.comboCartas = j.comboCartas or {}
      j.comboCartas[carta.nome] = true
    end
  end

  if opts.semQuota then
    -- Jogada da Area Segura/reacao: nao consome a quota do turno
    -- (igual ao React) e nao alimenta a cadeia.
    res.consumiuTurno = false
  else
    if not opts.semChain then
      res.chain = registrarChain(j, carta)
      res.chainBonus = j.chainBonus or 0
      if res.chain and (j.chainBonus or 0) > 0 then
        res.chainTexto = "CADEIA " .. tostring(carta.classe) ..
          " +" .. tostring(j.chainBonus)
      end
    end
    p.jogadasTurno = (p.jogadasTurno or 0) + 1
    res.jogadasTurno = p.jogadasTurno
    res.quotaTurno = J.quotaTurno(p, indiceJogador)
    res.consumiuTurno = p.jogadasTurno >= res.quotaTurno
  end
  return res
end

-- ============================================================
-- AREA SEGURA (useCombat.js: colocarCartaAreaSegura1v1 /
-- jogarCartaAreaSegura1v1)
-- ============================================================

-- Move uma carta da mao para a Area Segura (maximo AREA_SEGURA_MAX = 1).
-- Devolve true se guardou; false se nao (cheia/invalida).
function J.colocarAreaSegura(p, indiceJogador, cartaUid)
  local j = p.jogadores[indiceJogador]
  if not j or #j.areaSegura >= AREA_SEGURA_MAX then return false end
  local idx = nil
  for i, c in ipairs(j.mao) do
    if c.uid == cartaUid then idx = i break end
  end
  if not idx then return false end

  local carta = table.remove(j.mao, idx)
  table.insert(j.areaSegura, carta)
  registrar(p, j.nome .. " colocou " .. carta.nome .. " na Area Segura")
  return true
end

-- Joga uma carta guardada na Area Segura: nao consome quota, nao compra
-- Manual V7 4.2: a utilizacao de cartas (inclusive das guardadas na Area
-- Segura) e exclusiva do proprio turno. Guardar/cartas de organizacao continua
-- valendo a qualquer momento.
function J.jogarAreaSegura(p, indiceJogador, cartaUid)
  local j = p.jogadores[indiceJogador]
  if not j then return nil end
  if p.vez ~= indiceJogador then return nil end
  local idx = nil
  for i, c in ipairs(j.areaSegura) do
    if c.uid == cartaUid then idx = i break end
  end
  if not idx then return nil end

  local carta = table.remove(j.areaSegura, idx)
  return J.aplicarCarta(p, indiceJogador, carta, {
    origem = " da Area Segura",
    semQuota = true,
  })
end

-- Arma uma carta de Defesa no slot unico SEM resolver a carta: nao rola dado,
-- nao gasta a quota do turno e nao alimenta a cadeia. A defesa anterior vai
-- para o descarte. A carta so reage quando o dono escolhe DEFENDER na janela
-- do Quick Counter (opts.defesaDe no ataque).
function J.armarDefesa(p, indiceJogador, cartaUid)
  local j = p and p.jogadores and p.jogadores[indiceJogador]
  if not j or not cartaUid then return nil end
  local pos = nil
  for i, c in ipairs(j.mao or {}) do
    if c.uid == cartaUid then pos = i break end
  end
  if not pos then return nil end
  local carta = j.mao[pos]
  if not J.ehDefesa(carta) then return nil end
  table.remove(j.mao, pos)
  if j.defesas and #j.defesas > 0 then
    for _, d in ipairs(j.defesas) do
      if d.carta then table.insert(p.pilhaDescarte, d.carta) end
    end
  end
  j.defesas = { { carta = carta, turnos = carta.defesaTurnos or DEFESA_TURNOS } }
  j.protegido = true
  j.protegeContra = carta.protegeContra
  registrar(p, j.nome .. " armou defesa no slot: " .. carta.nome)
  return {
    sucesso = true,
    chance = 1,
    delta = 0,
    carta = carta,
    mensagem = "Defesa armada",
    protecao = { indiceJogador },
    consumiuTurno = false,
    log = j.nome .. " armou defesa: " .. carta.nome,
  }
end

-- ============================================================
-- QUICK COUNTER (janela de reacao)
-- ============================================================

-- Uma carta e uma ameaca contra `idxAlvo` quando e negativa e atinge o alvo
-- (seja por alvo unico ou por efeito em oponentes/todos).
function J.ameacaContra(p, idxAlvo, idxAtacante, carta, opts)
  if not p or not carta or not idxAlvo or idxAlvo == idxAtacante then
    return false
  end
  local alvo = p.jogadores[idxAlvo]
  if not alvo or alvo.falido or alvo.saiu then return false end
  local negativa = cartas.ehCartaNegativa(carta)
    or cartas.polaridadeDe(carta) == "negativa"
  if not negativa then return false end

  local ef = carta.efeito
  if carta.precisaAlvo then
    -- O alvo efetivo ja foi resolvido pelo chamador (opts.alvoIdx).
    return opts == nil or opts.alvoIdx == nil or opts.alvoIdx == idxAlvo
  end
  if ef and (ef.alvo == "oponentes" or ef.alvo == "todos") then
    return true
  end
  if carta.satisfacao and carta.satisfacao.alvo == "alvo" then return true end
  if carta.produtividade and carta.produtividade.alvo == "alvo" then return true end
  return false
end

-- A defesa ARMADA no slot reage a esta carta? Bloqueio do tipo certo ou
-- mitigacao aplicavel. Usado para abrir a janela so quando defender resolve.
function J.defesaReageA(alvo, carta)
  local d = alvo and alvo.defesas and alvo.defesas[1]
  if not d or not d.carta or not carta then return false end
  if mitigacaoPorProtecao(alvo, carta) then return true end
  if efeitoMitigador(d) then return false end
  if not alvo.protegido then return false end
  if not alvo.protegeContra then return true end
  return alvo.protegeContra == carta.tipo
end

-- Defesas disponiveis para reagir: SOMENTE a carta armada no Slot de Defesa.
-- Cartas na mao / Area Segura nao defendem: precisam ser armadas antes. Nao
-- altera o estado; o main usa a lista para montar os botoes da janela. Com
-- `carta`, so devolve quando a defesa realmente reage ao ataque.
function J.reacoesDisponiveis(p, idx, carta)
  local j = p and p.jogadores and p.jogadores[idx or p.vez]
  local lista = {}
  if not j or j.falido or j.saiu then return lista end
  local d = j.defesas and j.defesas[1]
  if not d or not d.carta or not J.ehDefesa(d.carta) then return lista end
  if carta and not J.defesaReageA(j, carta) then return lista end
  lista[1] = { carta = d.carta, uid = d.carta.uid, origem = "slot" }
  return lista
end

function J.podeReagir(p, idx, carta)
  return #J.reacoesDisponiveis(p, idx, carta) > 0
end

-- Usa uma defesa durante a janela: nao gasta quota, nao alimenta a cadeia e
-- pode ser puxada da Area Segura mesmo fora do turno do dono. A protecao
-- passa a valer ANTES da carta atacante ser resolvida pelo chamador.
function J.usarReacao(p, idx, uid, origem)
  local j = p and p.jogadores and p.jogadores[idx]
  if not j or not uid then return nil end
  local lista = origem == "area" and j.areaSegura or j.mao
  local pos = nil
  for i, c in ipairs(lista or {}) do
    if c.uid == uid then pos = i break end
  end
  if not pos then return nil end
  local carta = table.remove(lista, pos)
  if not J.ehDefesa(carta) then
    -- Seguranca: so defesas entram na reacao.
    table.insert(lista, pos, carta)
    return nil
  end
  return J.aplicarCarta(p, idx, carta, {
    origem = origem == "area" and " da Area Segura (REACAO)" or " (REACAO)",
    semQuota = true,
    semChain = true,
    reacao = true,
  })
end

-- ============================================================
-- INICIO DE TURNO (processarInicioTurno)
-- ============================================================

-- Habilidade do avatar Marx (prototipo): no inicio do turno de cada
-- portador, o jogador com MAIOR saldo doa MARX_DOACAO ao de MENOR saldo
-- (vivos apenas). Nao acontece se o de Marx esta no topo (unico ou
-- empatado). Em multiplayer varios Marx: cada um dispara no proprio turno.
local MARX_DOACAO = 100
local function habilidadeMarx(p, idx)
  local marx = p.jogadores[idx]
  if not marx or marx.falido or marx.saiu or marx.avatar ~= "marx" then return end
  local ricoI, ricoS, pobreI, pobreS = nil, nil, nil, nil
  for i, j in ipairs(p.jogadores) do
    if not j.falido and not j.saiu then
      if not ricoI or j.saldo > ricoS then ricoI, ricoS = i, j.saldo end
      if not pobreI or j.saldo < pobreS then pobreI, pobreS = i, j.saldo end
    end
  end
  if not ricoI or ricoI == pobreI then return end
  if marx.saldo >= ricoS then return end
  local rico, pobre = p.jogadores[ricoI], p.jogadores[pobreI]
  aplicarSaldo(p, rico, -MARX_DOACAO)
  aplicarSaldo(p, pobre, MARX_DOACAO)
  -- Seq para a UI distinguir gatilhos repetidos (mesmo criterio do evento).
  p.habilidadeSeq = (p.habilidadeSeq or 0) + 1
  p.habilidade = { tipo = "marx", de = ricoI, para = pobreI,
    valor = MARX_DOACAO, seq = p.habilidadeSeq }
  registrar(p, "REDISTRIBUICAO MARX: " .. rico.nome ..
    " doou R$ " .. MARX_DOACAO .. " para " .. pobre.nome)
end
J.habilidadeMarx = habilidadeMarx

function J.processarInicioTurno(p, idx)
  local j = p.jogadores[idx]
  if not j then return end

  -- Manual V7: no turno imediatamente anterior a um evento do Deus Mercado
  -- (rodadas pares, antes da 10a) os saldos dos demais ficam ocultos.
  local ultimo = #p.jogadores
  while ultimo > 1 and p.jogadores[ultimo].saiu do ultimo = ultimo - 1 end
  p.ocultarSaldos = (idx == ultimo)
    and (p.turno % LEILAO_INTERVALO == 0)
    and (p.turno < MAX_TURNOS)
    and not p.eventoMeta

  -- Novo turno do dono: zera o contador de copias, a cadeia e envelhece as
  -- defesas.
  j.cartasTurno = {}
  resetChain(j)
  atualizarDefesas(p, idx)

  habilidadeMarx(p, idx)

  local restantes = {}
  for _, e in ipairs(j.efeitos) do
    local t = e.tipo
    if t == "DINHEIRO_ADIADO" then
      local antes = j.saldo
      aplicarSaldo(p, j, e.valor or 0)
      registrar(p, j.nome .. " recebeu +" .. (j.saldo - antes) .. " (efeito adiado)")
    elseif t == "DIVIDA_PARCELADA" then
      aplicarSaldo(p, j, -(e.valor or 0))
      registrar(p, j.nome .. " pagou " .. (e.valor or 0) .. " de emprestimo")
    elseif t == "RENDA_FIXA" then
      local valor = e.valor or 0
      if valor > 0 then
        aplicarSaldo(p, j, valor, "renda_fixa")
        registrar(p, j.nome .. " recebeu +" .. valor .. " (renda fixa)")
      end
    elseif t == "DANO_PERIODICO" then
      local valor = e.valor or 0
      if valor > 0 then
        aplicarSaldo(p, j, -valor, "dano_periodico")
        registrar(p, j.nome .. " perdeu " .. valor .. " (dano periodico)")
      end
    elseif t == "MAO_ALEATORIA" then
      local qtd = e.quantidade or 3
      local trocadas = 0
      for _ = 1, qtd do
        if #j.mao > 0 then
          -- A carta sai da mao (nao volta pro deck) e uma nova e comprada.
          local pos = love.math.random(#j.mao)
          table.insert(p.pilhaDescarte, table.remove(j.mao, pos))
          if comprarCartas(p, j, 1) > 0 then trocadas = trocadas + 1 end
        end
      end
      if trocadas > 0 then
        registrar(p, j.nome .. " teve " .. trocadas .. " carta(s) substituida(s) (Taylor)")
      end
    elseif t == "TROCA_MAO" then
      -- Puxa `quantidade` cartas e fica com 1 aleatoria.
      local qtd = e.quantidade or 3
      local puxadas = {}
      for _ = 1, qtd do
        local c = novaCarta(p)
        if c then puxadas[#puxadas + 1] = c end
      end
      if #puxadas > 0 then
        local fica = table.remove(puxadas, love.math.random(#puxadas))
        table.insert(j.mao, fica)
        -- As outras puxadas e o excedente da mao saem do jogo (o deck e
        -- infinito: nada volta para a pilha de compra).
        for _, c in ipairs(puxadas) do table.insert(p.pilhaDescarte, c) end
        while #j.mao > CARTAS_POR_MAO do
          table.insert(p.pilhaDescarte, table.remove(j.mao, 1))
        end
        registrar(p, j.nome .. " renovou a mao com Seiri (" .. (#puxadas + 1) .. " cartas)")
      end
    end
    -- TEMPO_TURNO: duracao lida pela UI via duracaoTurno(j).

    if type(e.turnos) == "number" then
      e.turnos = e.turnos - 1
      if e.turnos > 0 then table.insert(restantes, e) end
    else
      table.insert(restantes, e)
    end
  end
  j.efeitos = restantes
end

-- ============================================================
-- RENDA, COMBINACOES E CURINGA GLOBAL (manual V2)
-- ============================================================

function J.rendaDaRodada(rodada)
  rodada = math.max(1, tonumber(rodada) or 1)
  return RENDA_BASE + (rodada - 1) * RENDA_INCREMENTO
end

-- Credita a renda da rodada concluida em todos os jogadores vivos. O extrato
-- registra a categoria "renda" (livro-caixa), sem alterar a regra de vitoria.
-- Manual V7 5.4: cada jogador recebe a renda multiplicada por (1 + produtividade),
-- com piso em 0 (produtividade minima -100%).
function J.aplicarRendaRodada(p, rodada)
  local valor = J.rendaDaRodada(rodada)
  local deltas = {}
  local rendas = {}
  for i, j in ipairs(p.jogadores) do
    deltas[i] = 0
    rendas[i] = 0
    if not j.falido and not j.saiu then
      local prod = math.max(PRODUTIVIDADE_MIN, tonumber(j.produtividade) or 0)
      local bruto = math.floor(valor * (1 + prod) + 0.5)
      if bruto < 0 then bruto = 0 end
      local antes = j.saldo
      aplicarSaldo(p, j, bruto, "renda")
      deltas[i] = j.saldo - antes
      rendas[i] = bruto
    end
  end
  p.rendaRodada = { rodada = rodada, valor = valor, deltas = deltas,
    rendas = rendas }
  local txt = "Renda da rodada " .. rodada .. ":"
  for i, j in ipairs(p.jogadores) do
    if rendas[i] and rendas[i] > 0 then
      local prod = math.max(PRODUTIVIDADE_MIN, tonumber(j.produtividade) or 0)
      txt = txt .. " " .. j.nome .. " +R$ " .. rendas[i]
      if prod ~= 0 then
        txt = txt .. string.format(" (%.0f%%)", prod * 100)
      end
      txt = txt .. ";"
    end
  end
  registrar(p, txt)
  return p.rendaRodada
end

-- Verifica as combinacoes de mercado no fim da rodada. A recompensa entra
-- no inicio da rodada seguinte (aqui, antes do evento), uma vez por combo.
function J.verificarCombos(p)
  local eventos = {}
  for i, j in ipairs(p.jogadores) do
    if not j.falido and not j.saiu then
      for _, combo in ipairs(COMBOS) do
        local completo = true
        for _, nome in ipairs(combo.cartas) do
          if not (j.comboCartas and j.comboCartas[nome]) then
            completo = false
            break
          end
        end
        if completo then
          aplicarSaldo(p, j, combo.premio, "combo")
          eventos[#eventos + 1] = {
            jogador = i, nome = combo.nome, premio = combo.premio,
          }
          registrar(p, "COMBINACAO " .. combo.nome .. ": " .. j.nome ..
            " recebeu +R$ " .. combo.premio)
        end
      end
    end
    j.comboCartas = {}
  end
  p.comboEventos = eventos
  p.comboEvento = eventos[1]
  return eventos
end

-- CURINGA GLOBAL: antes de cada leilao, sorteia um Curinga do catalogo e
-- aplica a todos; o anterior e removido (substituicao, nao acumulo).
function J.aplicarCuringaGlobal(p)
  -- Remove os efeitos marcados como globais da rodada anterior.
  if p.curingaGlobal then
    for _, j in ipairs(p.jogadores) do
      local restantes = {}
      for _, e in ipairs(j.efeitos or {}) do
        if not e.globalCuringa then table.insert(restantes, e) end
      end
      j.efeitos = restantes
    end
  end

  local opcoes = {}
  for _, base in ipairs(cartas.CARTAS) do
    if base.tipo == "CORINGA" and base.efeito then
      local t = base.efeito.tipo
      -- Apenas curingas cujo efeito o motor protótipo ja trata como global.
      if t == "MOD_FALHA" or t == "MAO_ALEATORIA" or t == "RENDA_ALEATORIA" then
        opcoes[#opcoes + 1] = base
      end
    end
  end
  if #opcoes == 0 then return nil end

  local base = opcoes[love.math.random(#opcoes)]
  local carta = J.novaCartaBase(p, base)
  p.curingaSeq = (p.curingaSeq or 0) + 1
  carta.uid = "global-" .. p.curingaSeq .. "-" .. carta.id

  -- Remove o global anterior das pilhas individuais (mantem curingas que o
  -- jogador tenha jogado da mao).
  local antigo = p.curingaGlobal and p.curingaGlobal.carta
  if antigo then
    for _, j in ipairs(p.jogadores) do
      local restantes = {}
      for _, c in ipairs(j.pilhaCuringa or {}) do
        if c.uid ~= antigo.uid then restantes[#restantes + 1] = c end
      end
      j.pilhaCuringa = restantes
    end
  end

  p.curingaGlobal = { carta = carta, rodada = p.turno }
  p.pilhaCuringa = { carta }

  -- Visor de Curingas (V7): global atual + os 2 ultimos ja usados.
  p.curingaHistorico = p.curingaHistorico or {}
  if antigo then
    table.insert(p.curingaHistorico, 1, antigo)
    while #p.curingaHistorico > 2 do
      table.remove(p.curingaHistorico)
    end
  end

  local efeito = copiar(base.efeito)
  efeito.turnos = nil -- vale ate o proximo leilao substituir
  efeito.globalCuringa = true
  for _, j in ipairs(p.jogadores) do
    if not j.falido and not j.saiu then
      J.adicionarEfeito(j, efeito, 0)
      table.insert(j.pilhaCuringa, carta)
    end
  end
  registrar(p, "CURINGA GLOBAL: " .. carta.nome)
  return carta
end

-- ============================================================
-- FIM DE TURNO (fimDeTurno)
-- ============================================================

local function eventoDeusMercado(p, forcado)
  local ev = forcado or EVENTOS_DEUS[love.math.random(#EVENTOS_DEUS)]
  local deltas = {}

  -- Define os alvos especiais de cada evento (pobres/ricos) antes de aplicar.
  local alvoMin, alvoMax = nil, nil
  local menor, maior = nil, nil
  for _, j in ipairs(p.jogadores) do
    if not j.falido and not j.saiu then
      if not menor or j.saldo < menor then menor, alvoMin = j.saldo, j end
      if not maior or j.saldo > maior then maior, alvoMax = j.saldo, j end
    end
  end

  for i, alvo in ipairs(p.jogadores) do
    local d = 0
    if not alvo.falido and not alvo.saiu then
      if ev.tipo == "pobres" then
        if alvo.saldo == menor then d = ev.valor end
      elseif ev.tipo == "ricos" then
        if alvo.saldo == maior then d = ev.valor end
      elseif ev.tipo == "aleatorio" then
        d = math.floor(love.math.random() * (ev.max - ev.min + 1)) + ev.min
      else
        d = ev.valor or 0
      end

      if d > 0 then
        for _, e in ipairs(alvo.efeitos) do
          if e.tipo == "MOD_BONUS_TURNO" and type(e.fator) == "number" then
            d = math.floor(d * e.fator + 0.5)
            break
          end
        end
      end
      aplicarSaldo(p, alvo, d, "evento")
      deltas[i] = d
    else
      deltas[i] = 0
    end
  end

  p.evento = {
    nome = ev.nome,
    tipo = ev.tipo,
    base = ev.valor or 0,
    deltas = deltas,
  }
  registrar(p, "Deus Mercado: " .. ev.nome)
end
J.eventoDeusMercado = eventoDeusMercado

-- ============================================================
-- LEILAO E LOJINHA (manual V2)
-- ============================================================

local function novaCartaBase(p, base)
  local c = cartas.copia(base)
  p.proxUid = (p.proxUid or 0) + 1
  c.uid = c.id .. "-" .. p.proxUid
  -- Fase propria para o brilho de Curinga (nao sincroniza com as outras).
  -- Derivada do uid para nao consumir o RNG da partida/testes.
  local hash = 0
  for k = 1, #c.uid do
    hash = (hash * 31 + c.uid:byte(k)) % 1000003
  end
  c.fase = (hash % 1000) / 1000
  return c
end
J.novaCartaBase = novaCartaBase

local function sortearCartasCatalogo(n)
  local lista, vistos = {}, {}
  local tentativas = 0
  while #lista < n and tentativas < 400 do
    tentativas = tentativas + 1
    local base = cartas.CARTAS[love.math.random(#cartas.CARTAS)]
    if base and not vistos[base.id] then
      vistos[base.id] = true
      lista[#lista + 1] = base
    end
  end
  return lista
end

-- Sorteia o PRODUTO do leilao (manual V7): UMA carta, ou um kit de 2 ou 3
-- cartas. So entram as cartas do BARALHO PRINCIPAL (peso > 0 em pesos.lua,
-- selecao igual a regras/baralho atual.txt). Super Cartas e cartas fora do
-- baralho ficam de fora do leilao, mas continuam no catalogo.
local function sortearProdutoLeilao(p)
  local n = love.math.random() < 0.4 and love.math.random(2, 3) or 1
  local bases, vistos = {}, {}
  local function tentar(base)
    if base and (base.peso or 0) > 0 and not vistos[base.id] then
      vistos[base.id] = true
      bases[#bases + 1] = base
    end
  end
  local function sortearBase()
    tentar(cartas.CARTAS[love.math.random(#cartas.CARTAS)])
  end
  sortearBase()
  local tentativas = 0
  while #bases < n and tentativas < 400 do
    tentativas = tentativas + 1
    sortearBase()
  end
  local lista = {}
  for _, base in ipairs(bases) do
    lista[#lista + 1] = novaCartaBase(p, base)
  end
  return lista
end

local function lancesValidos(p, idx)
  local j = p.jogadores[idx]
  if not j or j.falido then return 0 end
  local lance = p.leilao and p.leilao.lances[idx] or 0
  return math.min(math.max(0, tonumber(lance) or 0), math.max(0, j.saldo))
end

-- Abre o leilao (produto unico: 1 carta ou kit de 2-3) e o Curinga global da
-- rodada. A UI (meta.lua) define o lance do humano; a IA lanca sozinha.
function J.iniciarLeilao(p)
  if p.leilao and p.leilao.resolvido then p.leilao = nil end
  if p.leilao then return p.leilao end
  p.eventoMeta = true -- durante o evento vale exceder o teto de 10 cartas
  J.aplicarCuringaGlobal(p)

  local cartasLeilao = sortearProdutoLeilao(p)

  p.leilao = {
    rodada = p.turno,
    cartas = cartasLeilao,
    kit = #cartasLeilao > 1,
    lances = {}, -- [indiceDoJogador] = UM lance total pelo produto
    resultados = {},
    tempo = LEILAO_SEGUNDOS,
    resolvido = false,
  }
  for i = 1, #p.jogadores do
    p.leilao.lances[i] = 0
  end

  -- IA: um lance unico de 0..800 em passos de 100, limitado ao saldo.
  for i, j in ipairs(p.jogadores) do
    if (i > 1 or p.simulacao) and j.isIA and not j.falido and not j.saiu then
      local passos = math.floor(math.min(math.max(0, j.saldo), 800) / 100)
      p.leilao.lances[i] = love.math.random(0, passos) * 100
    end
  end
  return p.leilao
end

-- Lance unico do jogador pelo produto inteiro. O `uid` e mantido na
-- assinatura por compatibilidade com a UI antiga; hoje o produto e unico.
function J.definirLance(p, idx, uid, valor)
  if not p.leilao or p.leilao.resolvido then return false end
  local j = p.jogadores[idx]
  if not j or j.falido then return false end
  if p.leilao.lances[idx] == nil then return false end
  local maximo = math.max(0, j.saldo)
  p.leilao.lances[idx] = math.max(0, math.min(maximo, tonumber(valor) or 0))
  return true
end

-- Fecha o leilao: UM vencedor leva o produto inteiro (1 carta ou kit de 2-3).
-- Empate resolvido por sorteio aleatorio.
function J.resolverLeilao(p)
  local leilao = p.leilao
  if not leilao or leilao.resolvido then return leilao end
  leilao.resultados = {}

  local melhor, vencedores = 0, {}
  for i, j in ipairs(p.jogadores) do
    if not j.falido and not j.saiu then
      local lance = tonumber(leilao.lances[i]) or 0
      if lance > melhor then
        melhor = lance
        vencedores = { i }
      elseif lance == melhor and lance > 0 then
        vencedores[#vencedores + 1] = i
      end
    end
  end

  local vencedor = nil
  if melhor > 0 and #vencedores > 0 then
    vencedor = vencedores[love.math.random(#vencedores)]
  end

  local pago = 0
  if vencedor then
    local j = p.jogadores[vencedor]
    if j.saldo >= melhor then
      aplicarSaldo(p, j, -melhor, "leilao")
      pago = melhor
      for _, carta in ipairs(leilao.cartas) do
        if #j.mao < J.tetoMao(p, j) then
          table.insert(j.mao, carta)
        else
          table.insert(p.pilhaDescarte, carta)
        end
      end
      local oQue = leilao.kit
        and ("kit de " .. #leilao.cartas .. " cartas")
        or leilao.cartas[1].nome
      registrar(p, j.nome .. " venceu o leilao (" .. oQue ..
        ") por R$ " .. melhor)
    else
      vencedor = nil
    end
  end

  leilao.maior = melhor
  leilao.vencedor = vencedor
  leilao.resultados[1] = {
    cartas = leilao.cartas,
    vencedor = vencedor,
    valor = pago,
    maior = melhor,
  }
  leilao.resolvido = true
  return leilao
end

-- Abre a lojinha (3 cartas, 1 unidade de cada). A IA pode comprar antes do
-- humano; cada item so pode ser vendido uma vez.
function J.iniciarLojinha(p)
  if p.lojinha and p.lojinha.resolvido then p.lojinha = nil end
  if p.lojinha then return p.lojinha end
  p.eventoMeta = true -- durante o evento vale exceder o teto de 10 cartas
  local itens = {}
  for _, base in ipairs(sortearCartasCatalogo(3)) do
    local carta = novaCartaBase(p, base)
    local preco = 100 + love.math.random(0, 6) * 50
    if carta.tipo == "CORINGA" then preco = preco + 100 end
    itens[#itens + 1] = {
      carta = carta, preco = preco, vendida = false, comprador = nil,
    }
  end
  p.lojinha = {
    rodada = p.turno,
    cartas = itens,
    tempo = LOJINHA_SEGUNDOS,
    resolvido = false,
  }

  for i, j in ipairs(p.jogadores) do
    if (i > 1 or p.simulacao) and j.isIA and not j.falido and not j.saiu then
      for _, item in ipairs(itens) do
        if not item.vendida and item.preco <= j.saldo
            and love.math.random() < 0.35 then
          J.comprarLojinha(p, i, item.carta.uid)
        end
      end
    end
  end
  return p.lojinha
end

function J.comprarLojinha(p, idx, uid)
  if not p.lojinha or p.lojinha.resolvido then return false end
  local j = p.jogadores[idx]
  if not j or j.falido or j.saiu then return false end
  for _, item in ipairs(p.lojinha.cartas) do
    if item.carta.uid == uid and not item.vendida then
      if j.saldo < item.preco then return false end
      aplicarSaldo(p, j, -item.preco, "lojinha")
      item.vendida = true
      item.comprador = idx
      if #j.mao < J.tetoMao(p, j) then
        table.insert(j.mao, item.carta)
      else
        table.insert(p.pilhaDescarte, item.carta)
      end
      registrar(p, j.nome .. " comprou " .. item.carta.nome ..
        " na lojinha por R$ " .. item.preco)
      return true
    end
  end
  return false
end

function J.fecharLojinha(p)
  if p.lojinha then p.lojinha.resolvido = true end
  p.eventoMeta = false
end

-- ============================================================
-- FUSAO DE CARTAS -> SUPER CARTA (manual V7 5.9)
-- ============================================================
-- 2..5 cartas da mao ou do banco (Area Segura) viram UMA Super Carta, que
-- entra na mao. Só acontece dentro do evento do Deus Mercado.

function J.iniciarFusao(p)
  p.eventoMeta = true
  if not p.fusao then p.fusao = { escolhidas = {} } end
  return p.fusao
end

function J.limparFusao(p)
  p.fusao = nil
  p.eventoMeta = false
end

-- Troca `uids` (2..5) por uma Super Carta na mao. Devolve a Super Carta ou nil.
function J.executarFusao(p, idx, uids)
  local j = p.jogadores[idx]
  if not j or j.falido or j.saiu then return nil end
  uids = uids or {}
  if #uids < J.FUSAO_MIN or #uids > J.FUSAO_MAX then return nil end

  local escolhidas, vistos = {}, {}
  for _, uid in ipairs(uids) do
    if not vistos[uid] then
      local achada = nil
      for _, c in ipairs(j.mao) do
        if c.uid == uid then achada = { c = c, mao = true } break end
      end
      if not achada then
        for _, c in ipairs(j.areaSegura) do
          if c.uid == uid then achada = { c = c, mao = false } break end
        end
      end
      if achada then
        vistos[uid] = true
        escolhidas[#escolhidas + 1] = achada
      end
    end
  end
  -- uid invalido anula a fusao inteira (ou o numero esta fora de 2..5).
  if #escolhidas ~= #uids then return nil end

  for _, e in ipairs(escolhidas) do
    local lista = e.mao and j.mao or j.areaSegura
    for i, c in ipairs(lista) do
      if c.uid == e.c.uid then
        table.insert(p.pilhaDescarte, table.remove(lista, i))
        break
      end
    end
  end

  local base = cartas.SUPER_CARTAS[love.math.random(#cartas.SUPER_CARTAS)]
  local super = J.novaCartaBase(p, base)
  table.insert(j.mao, super)
  registrar(p, j.nome .. " fundiu " .. #escolhidas ..
    " cartas e criou " .. super.nome)
  return super
end

-- A IA funde sozinha quando o evento abre (metade das vezes, com 2 cartas).
function J.iaFusao(p)
  for i, j in ipairs(p.jogadores) do
    if (i > 1 or p.simulacao) and j.isIA and not j.falido and not j.saiu
        and love.math.random() < 0.5 then
      local uids = {}
      for _, c in ipairs(j.mao) do
        if #uids < J.FUSAO_MAX then uids[#uids + 1] = c.uid end
      end
      if #uids >= J.FUSAO_MIN then J.executarFusao(p, i, uids) end
    end
  end
end

-- Passa a vez para o proximo jogador, pulando quem ja SAIU da partida
-- (desconectou — some da arena e nao recebe turno). Falido continua no
-- circuito normal (o turno dele e repassado). A virada N -> 1 conta o
-- turno. Usado por encerrarVez e pela saida de um jogador no main.
function J.avancarVez(p)
  local n = #p.jogadores
  local giro = 0
  repeat
    if p.vez == n then
      p.turno = p.turno + 1
      if p.turno <= p.maxTurnos then
        registrar(p, "Turno " .. p.turno)
      end
    end
    p.vez = p.vez % n + 1
    giro = giro + 1
  until not p.jogadores[p.vez].saiu or giro >= n
end

function J.encerrarVez(p)
  local idx = p.vez
  local j = p.jogadores[idx]

  -- Quem termina o turno completa a mao ate 7 (baralho infinito).
  J.comprar(p, j)

  -- Fim da rodada: renda progressiva, combinacoes de mercado e evento do
  -- Deus Mercado. Tudo antes de avancar a vez/turno.
  local ultimo = #p.jogadores
  while ultimo > 1 and p.jogadores[ultimo].saiu do ultimo = ultimo - 1 end
  local fimRodada = idx == ultimo
  local rodadaConcluida = p.turno
  if fimRodada then
    J.aplicarRendaRodada(p, rodadaConcluida)
    J.verificarCombos(p)
    eventoDeusMercado(p)
  end

  resetChain(j)
  J.avancarVez(p)
  p.jogadasTurno = 0

  -- Greve (manual V7 5.3): quem esta de Greve perde o turno dele. Os efeitos
  -- continuam correndo no turno perdido e a barra volta a 100 nesse momento.
  -- Nunca anda alem da ultima rodada (o fim e conferido em seguida).
  local giro = 0
  while p.jogadores[p.vez].greve and giro < #p.jogadores
      and p.turno <= p.maxTurnos do
    local idxGreve = p.vez
    local emGreve = p.jogadores[idxGreve]
    J.processarInicioTurno(p, idxGreve)
    emGreve.greve = false
    emGreve.satisfacao = SATISFACAO_INICIAL
    registrar(p, emGreve.nome .. " esta em GREVE e perde o turno")
    J.avancarVez(p)
    p.jogadasTurno = 0
    giro = giro + 1
  end

  -- Tick dos efeitos ativos no inicio do turno de quem vai jogar.
  J.processarInicioTurno(p, p.vez)
  J.verificarFim(p)

  -- Leilao + lojinha a cada 2 rodadas concluidas. O main (meta.lua) pausa a
  -- mesa e conduz os dois eventos; depois chama proximaFase de novo.
  p.metaPendente = nil
  if not p.fim and fimRodada and rodadaConcluida % LEILAO_INTERVALO == 0 then
    p.metaPendente = "leilao"
    p.metaRodada = rodadaConcluida
  end
end

function J.verificarFim(p)
  if p.fim then return end
  local n = #p.jogadores
  local vivos = {}
  for _, j in ipairs(p.jogadores) do
    if not j.falido then vivos[#vivos + 1] = j end
  end

  if #vivos <= 1 then
    p.fim = true
    if #vivos == 0 then
      p.vencedor = { empate = true }
      p.motivo = n == 2 and "Empate: Ambos faliram!" or "Empate: Todos faliram!"
      registrar(p, n == 2 and "Empate: ambos faliram!" or "Empate: todos faliram!")
    else
      p.vencedor = vivos[1]
      p.motivo = "Vitoria por Eliminacao!"
      registrar(p, vivos[1].nome .. " venceu por eliminacao!")
    end
    return
  end

  if p.turno > p.maxTurnos then
    p.fim = true
    -- Maior saldo entre os vivos (ordem estavel por insert).
    local ordem = {}
    for _, j in ipairs(vivos) do ordem[#ordem + 1] = j end
    table.sort(ordem, function(a, b) return a.saldo > b.saldo end)
    local topo = ordem[1]
    local empatados = 0
    for _, j in ipairs(ordem) do
      if j.saldo == topo.saldo then empatados = empatados + 1 end
    end
    if empatados > 1 then
      p.vencedor = { empate = true }
      p.motivo = n == 2 and "Empate: Saldo identico!"
        or ("Empate: " .. empatados .. " jogadores com mesmo saldo!")
      registrar(p, "Fim dos turnos: empate!")
    else
      p.vencedor = topo
      p.motivo = "Vitoria por Tempo: Maior saldo!"
      registrar(p, "Fim dos turnos: " .. topo.nome .. " venceu!")
    end
  end
end

function J.passar(p, indiceJogador)
  local j = p.jogadores[indiceJogador or p.vez]
  if j then registrar(p, j.nome .. " passou a vez") end
  J.encerrarVez(p)
end

-- ============================================================
-- IA
-- ============================================================

-- Personalidades de IA (8.1): cada estilo altera o valor das cartas.
J.ESTILOS_IA = { "agressivo", "defensivo", "oportunista", "caotico" }

function J.definirEstilos(p)
  if not p or not p.jogadores then return end
  for i = 2, #p.jogadores do
    local j = p.jogadores[i]
    if j and j.isIA and not j.estilo then
      j.estilo = J.ESTILOS_IA[(i - 2) % #J.ESTILOS_IA + 1]
    end
  end
end

local function notaCarta(c, ia, p)
  local chance = c.chanceSucesso or 1
  local e = c.efeito
  local t = e and e.tipo
  local nota

  if J.ehDefesa(c) then
    nota = ia.protegido and 15 or 60
  elseif c.dinheiroEm == "invocador" and
      ((c.alteracaoSaldoBase or 0) ~= 0 or (c.alteracaoSaldoFalha or 0) ~= 0) then
    -- Valor esperado do dinheiro para o proprio invocador.
    nota = (c.alteracaoSaldoBase or 0) * chance +
      (c.alteracaoSaldoFalha or 0) * (1 - chance)
  elseif t == "DIVIDA" then
    nota = chance * ((e.min + e.max) / 2) * 0.6
  elseif t == "DOACAO_PERCENTUAL" then
    nota = 120 * chance
  elseif t == "DINHEIRO_ALVO" then
    nota = ((e.ganhoInvocador or 0) - (e.perdaAlvo or 0)) * 0.8 * chance
  elseif t == "ROUBA_CARTAS" then
    nota = 90 * chance
  else
    nota = 45 * chance
  end

  if c.tipo == "CORINGA" then nota = nota + 15 end
  if c.tipo == "EFEITO" then nota = nota + 5 end

  local estilo = ia.estilo
  if estilo == "agressivo" then
    if J.ehDefesa(c) then nota = nota - 45
    elseif cartas.ehCartaNegativa(c) then nota = nota + 25 end
  elseif estilo == "defensivo" then
    if J.ehDefesa(c) then nota = nota + 45
    elseif cartas.ehCartaNegativa(c) then nota = nota - 20 end
  elseif estilo == "oportunista" then
    if c.classe and ia.chainClasse == c.classe then nota = nota + 40 end
    if chance < 0.5 then nota = nota - 30 end
  elseif estilo == "caotico" then
    return love.math.random() * 100
  end

  -- IA que aprende (8.2): contra-ataca o padrao do jogador.
  if p and p.contraEstilo == "agressivo" and c.id == 9 then
    nota = nota + 120  -- Queima de Estoque contra quem guarda defesas
  elseif p and p.contraEstilo == "defensivo" and J.ehDefesa(c) then
    nota = nota + 60   -- protecao contra quem ataca muito
  end

  return nota + love.math.random() * 6
end

-- Escolhe uma carta (indice na mao) para a IA jogar, ou nil para passar.
-- idx: quem joga (padrao: a vez atual — usado pelo driver da IA).
function J.jogadaIA(p, idx)
  local ia = p.jogadores[idx or p.vez]
  if not ia or ia.falido or #ia.mao == 0 then return nil end

  local melhor, melhorNota = nil, -math.huge
  for i, c in ipairs(ia.mao) do
    local nota = notaCarta(c, ia, p)
    if nota > melhorNota then
      melhor, melhorNota = i, nota
    end
  end
  return melhor
end

-- IA: uid da carta da mao para guardar na Area Segura (a de menor valor,
-- porque a Area sera puxada e jogada no proximo turno). Nil se nao da:
-- falido, area cheia (3) ou mao com menos de 2 cartas. Deterministica.
function J.iaGuardarCarta(p, idx)
  local ia = p.jogadores[idx or p.vez]
  if not ia or ia.falido or #ia.areaSegura >= AREA_SEGURA_MAX
      or #ia.mao < 2 then
    return nil
  end
  local pior, piorNota = nil, math.huge
  for i, c in ipairs(ia.mao) do
    local nota = notaCarta(c, ia)
    if nota < piorNota then
      pior, piorNota = i, nota
    end
  end
  return pior and ia.mao[pior].uid or nil
end

function J.descreveVez(p)
  return p.jogadores[p.vez].nome
end

-- Livro-caixa: resumo para a UI/estatisticas. Lucro nao define vitoria.
function J.resumoFinanceiro(j)
  if not j then return nil end
  return {
    inicial = SALDO_INICIAL,
    receitas = j.receitas or 0,
    despesas = j.despesas or 0,
    saldo = j.saldo or 0,
    lucro = (j.saldo or 0) - SALDO_INICIAL,
    movimentos = j.extrato or {},
  }
end

return J
