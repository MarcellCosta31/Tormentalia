local jogo = require "jogo"
local cartas = require "cartas"
local anim = require "anim"
local perfilMod = require "perfil"
local arenaMenu = require "arena_menu"
local json = require "json"
local rede = require "rede"
local descoberta = require "descoberta"
local multiplayer = require "multiplayer"
local partidaRede = require "partidaRede"
local inventario = require "inventario"
local dinheiro = require "dinheiro"
local arte = require "arte"
local selecao = require "selecao"
local dialogo = require "dialogo"
local ui = require "ui"
local layout = require "layout"

local T = {}

local total, falhas = 0, 0

local function check(cond, msg)
  total = total + 1
  if not cond then
    falhas = falhas + 1
    print("[FALHOU] " .. msg)
  end
end

local function cartaTeste(overrides)
  local c = {
    id = 900, nome = "Carta Teste", tipo = "ACAO",
    subtitulo = "", descricao = "teste", efeitoTexto = "teste",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 10, alteracaoSaldoFalha = 0,
    dinheiroEm = "invocador", efeito = nil,
    uid = "900-1", uidNum = 900,
  }
  for k, v in pairs(overrides or {}) do c[k] = v end
  return c
end

-- Aplica a carta e zera a quota de cartas do turno (simula o fim de turno
-- sem disparar evento/compra; testes de quota usam aplicarCarta direto).
local function jogar(p, indice, carta)
  local res = jogo.aplicarCarta(p, indice, carta)
  p.jogadasTurno = 0
  return res
end

-- O LÖVE só decodifica PNG/JPG/BMP/TGA. Assets vindos do RN podem ser WebP
-- renomeado como .png (assinatura "RIFF"), que carrega em branco no tutorial.
local function varrerImagens(dir, achados)
  for _, nome in ipairs(love.filesystem.getDirectoryItems(dir)) do
    local caminho = dir .. "/" .. nome
    if love.filesystem.getInfo(caminho, "directory") then
      varrerImagens(caminho, achados)
    elseif nome:lower():match("%.png$") or nome:lower():match("%.jpe?g$") then
      local cab = love.filesystem.read(caminho, 4) or ""
      table.insert(achados, {
        caminho = caminho,
        ok = cab == "\137PNG" or cab:sub(1, 3) == "\255\216\255",
      })
    end
  end
end

local function testarFormatoImagens()
  local achados = {}
  varrerImagens("arte", achados)
  check(#achados > 0, "varredura de arte/ encontrou imagens")
  for _, a in ipairs(achados) do
    if not a.ok then
      check(false, "formato decodificavel pelo LOVE: " .. a.caminho)
    end
  end
  print(string.format("  imagens verificadas: %d", #achados))
end

local function testarBaralho()
  -- Baralho INFINITO: cada compra sorteia uma carta (peso / soma dos pesos)
  -- e devolve uma COPIA nova, sem uid (o motor carimba um uid por partida).
  local a = cartas.comprarCarta()
  local b = cartas.comprarCarta()
  check(a ~= nil and b ~= nil, "comprarCarta devolve carta")
  check(a.uid == nil, "comprarCarta devolve copia sem uid (motor carimba)")
  check(a ~= b, "cada compra devolve uma instancia nova")

  local ids, soma = {}, 0
  for _, c in ipairs(cartas.CARTAS) do
    check(type(c.peso) == "number" and c.peso >= 0
      and c.peso == math.floor(c.peso), c.nome .. " tem peso inteiro >= 0")
    soma = soma + c.peso
    ids[c.id] = true
    -- Toda carta do baralho padrao precisa ter arte carregada (sem cair na
    -- face textual do placeholder).
    if c.peso > 0 then
      check(arte.temArte(c), c.nome .. " do baralho padrao tem arte propria")
    end
  end
  check(soma > 0, "soma dos pesos > 0 (" .. soma .. ")")
  local distintos = 0
  for _ in pairs(ids) do distintos = distintos + 1 end
  check(distintos == 50, "50 cartas no catalogo (" .. distintos .. ")")

  -- Comprar nao mexe no catalogo (o deck e infinito e as cartas sao copias).
  local antes = #cartas.CARTAS
  for _ = 1, 50 do cartas.comprarCarta() end
  check(#cartas.CARTAS == antes, "catalogo intacto depois de comprar")

  local porClasse = cartas.pesosPorClasse()
  check(porClasse.Efeito and porClasse.Acao and porClasse.Defesa
    and porClasse.Curinga, "pesos por classe com as 4 classes")
end

-- Simulacao pedida: 100.000 compras do baralho infinito. Imprime a % real de
-- cada carta e de cada classe e compara com a meta (Efeito 50 / Acao 32 /
-- Defesa 13 / Curinga 5). Se alguma classe passar de 2 pontos da meta, so
-- avisa (os pesos sao escolha de design, nao erro de codigo).
local function testarSorteioPonderado()
  local N = 100000
  local roleta = cartas.roleta()
  local cont = {}
  for _ = 1, N do
    local c = cartas.comprarCarta()
    if c then cont[c.id] = (cont[c.id] or 0) + 1 end
  end

  print("")
  print(string.format("  == Sorteio ponderado: %d compras (peso total %d) ==",
    N, roleta.total))
  local soma = 0
  for _, c in ipairs(cartas.CARTAS) do
    local n = cont[c.id] or 0
    soma = soma + n
    local esp = (c.peso or 0) / roleta.total * 100
    local real = n / N * 100
    print(string.format("  %2d %-34s p%d  esperado %5.2f%%  real %5.2f%%",
      c.id, c.nome, c.peso or 0, esp, real))
    check(math.abs(real - esp) < 1.0,
      c.nome .. " dentro de 1 ponto do peso (" .. string.format("%.2f", real) ..
      "% vs " .. string.format("%.2f", esp) .. "%)")
    if (c.peso or 0) == 0 then
      check(n == 0, c.nome .. " com peso 0 nunca sai")
    end
  end
  check(soma == N, "todas as compras vieram do baralho infinito")

  -- Distribuicao por classe: compara a amostra com o que o PROPRIO catalogo
  -- declara (soma dos pesos de cada classe / peso total). Assim a meta
  -- acompanha a planilha sem precisar de numero fixo desatualizado.
  local pesosClasse, totalPeso = {}, 0
  for _, c in ipairs(cartas.CARTAS) do
    local w = c.peso or 0
    pesosClasse[c.classe] = (pesosClasse[c.classe] or 0) + w
    totalPeso = totalPeso + w
  end
  local porClasse = {}
  for _, c in ipairs(cartas.CARTAS) do
    porClasse[c.classe] = (porClasse[c.classe] or 0) + (cont[c.id] or 0)
  end
  local fora = {}
  print("  -- por classe --")
  for _, classe in ipairs({ "Efeito", "Acao", "Defesa", "Curinga" }) do
    local meta = (pesosClasse[classe] or 0) / totalPeso * 100
    local real = (porClasse[classe] or 0) / soma * 100
    local dif = real - meta
    print(string.format("  %-8s real %5.2f%%  esperado %5.2f%%  (%+.2f)",
      classe, real, meta, dif))
    if math.abs(dif) > 2 then
      fora[#fora + 1] = classe .. " " .. string.format("%+.1f", dif)
    end
  end
  if #fora > 0 then
    print("  AVISO: fora da meta (>2 pontos): " .. table.concat(fora, ", "))
    print("  Sugestao de pesos no bloco SUGESTAO de pesos.lua.")
  else
    print("  Todas as classes dentro de 2 pontos do peso declarado.")
  end
end

local function testarCamposCartas()
  for _, base in ipairs(cartas.CARTAS) do
    local c = cartas.copia(base)
    check(type(c.chance) == "number", c.nome .. " tem chance")
    check(c.chance >= 0 and c.chance <= 1, c.nome .. " chance entre 0 e 1 (" .. tostring(c.chance) .. ")")
    check(c.efeitoTexto ~= nil and c.efeitoTexto ~= "", c.nome .. " tem efeitoTexto")
    check(c.uidNum == base.id, c.nome .. " tem uidNum")
    check(c.descricao ~= nil and c.descricao ~= "", c.nome .. " tem descricao")
    check(c.duracaoTexto ~= nil and c.alvoTexto ~= nil, c.nome .. " tem duracao/alvo")
    check(c.classe ~= nil, c.nome .. " tem classe da planilha")
    if c.polaridade ~= nil then
      check(c.polaridade == "positiva" or c.polaridade == "negativa",
        c.nome .. " polaridade valida (" .. tostring(c.polaridade) .. ")")
    end
  end

  -- Dados especificos: paridade com src/cards/cartasTGA.js
  local nosso = cartas.porId(1)
  check(nosso ~= nil and nosso.efeito.tipo == "DOACAO_PERCENTUAL", "id1 Nosso = doacao percentual")
  check(nosso.chanceSucesso == 1, "Nosso chance 100%")

  local toy = cartas.porId(2)
  check(toy.chanceSucesso == 0.7, "Toyotinho chance 0.7 (" .. tostring(toy.chanceSucesso) .. ")")
  check(toy.alteracaoSaldoBase == 400 and toy.alteracaoSaldoFalha == -400, "Toyotinho +400/-400")
  local copiaToy = cartas.copia(cartas.porId(2))
  check(copiaToy and copiaToy.chance == 0.7, "chance derivada na copia")
  check(copiaToy and copiaToy.uid == nil and copiaToy.uidNum == 2,
    "copia sem uid e com uidNum = id")

  local vig = cartas.porId(4)
  check(vig.efeito.tipo == "ROUBA_CARTAS" and vig.efeito.quantidade == 2, "Roubo de Ideias rouba 2 cartas")

  local noel = cartas.porId(5)
  check(noel.efeito.tipo == "DINHEIRO_ALVO" and noel.efeito.ganhoInvocador == 200, "Noel +200")
  check(noel.efeito.perdaAlvo == 100 and noel.efeito.debuff.valor == -0.1, "Noel -100 / debuff -10%")

  local monstro = cartas.porId(6)
  check(monstro.tipo == "CORINGA", "Monstro e coringa")
  check(monstro.efeito.tipo == "MOD_FALHA" and monstro.efeito.fator == 0.6, "Monstro fator 0.6")

  local psi = cartas.porId(10)
  check(psi.tipo == "PROTECAO" and psi.protegeContra == "EFEITO", "Psicologia protege EFEITO")
  local mao = cartas.porId(12)
  check(mao.tipo == "PROTECAO" and mao.protegeContra == "ACAO", "Mao Visivel protege ACAO")

  local emprest = cartas.porId(11)
  check(emprest.alteracaoSaldoBase == 500 and emprest.efeito.tipo == "DIVIDA_PARCELADA"
    and emprest.efeito.valor == 100 and emprest.efeito.turnos == 5, "Emprestimo 500/5x100")

  local cada = cartas.porId(20)
  check(cada.chanceSucesso == 0.7 and cada.alteracaoSaldoBase == 500
    and cada.alteracaoSaldoFalha == -100, "Cada Um No Seu Quadrado 70% +500/-100")

  local pego = cartas.porId(21)
  check(pego.efeito.tipo == "MOD_CHANCE" and pego.efeito.valor == -0.2
    and pego.efeito.turnos == 2, "Pego no Flagra -20% por 2 turnos")

  local prev = cartas.porId(22)
  check(prev and prev.nome == "Previsao" and prev.classe == "Defesa"
    and prev.tipo == "PROTECAO" and prev.efeito.tipo == "MULT_CHANCE"
    and prev.efeito.fator == 0.5, "Previsao e Defesa de mitigacao x0.5")

  local over = cartas.porId(23)
  check(over.efeito.tipo == "MOD_BONUS_TURNO" and over.efeito.fator == 1.1
    and over.efeito.turnos == 5, "Overclock x1.1 por 5 turnos")

  -- Tipos logicos usados pelo destaque do tutorial (mesma escolha do React)
  check(cartas.porId(1).tipo == "ACAO", "destaque ACAO = id 1")
  check(cartas.porId(25).tipo == "EFEITO", "destaque EFEITO = id 25")
  check(cartas.porId(8).tipo == "PROTECAO",
    "Tempos e Movimentos e Defesa de mitigacao")
  check(cartas.porId(10).tipo == "PROTECAO", "destaque PROTECAO = id 10")
  check(cartas.porId(6).tipo == "CORINGA", "destaque CORINGA = id 6")

  -- Curingas novos (artes em arte/cards/curinga).
  check(#cartas.CARTAS >= 50, "catalogo tem 50 cartas (2 curingas novos)")
  local rot = cartas.porId(50)
  check(rot and rot.nome == "Rotatividade de Mercado"
    and rot.tipo == "CORINGA" and rot.efeito.tipo == "TROCA_MAOS",
    "id50 Rotatividade de Mercado troca as maos")
  local mort = cartas.porId(51)
  check(mort and mort.nome == "Probabilidade Mortal"
    and mort.tipo == "CORINGA" and mort.efeito.tipo == "MORTE_ALEATORIA",
    "id51 Probabilidade Mortal elimina um jogador")
end

local function testarCriarPartida()
  local p = jogo.criarPartida()
  check(#p.jogadores == 2, "partida tem 2 jogadores")
  check(#p.jogadores[1].mao == 7, "mao inicial do jogador = 7")
  check(#p.jogadores[2].mao == 7, "mao inicial da IA = 7")
  check(p.jogadores[1].saldo == 2000, "saldo inicial do jogador = " .. p.jogadores[1].saldo)
  check(p.jogadores[2].saldo == 2000, "saldo inicial da IA = " .. p.jogadores[2].saldo)
  check(p.jogadores[1].extrato[1].categoria == "inicial",
    "extrato comeca com o capital inicial")
  check(jogo.resumoFinanceiro(p.jogadores[1]).lucro == 0,
    "lucro inicial = 0")
  check(#p.jogadores[1].defesas == 0, "Defense Slot comecou vazio")
  check(#p.jogadores[1].pilhaJogadas == 0, "Pilha de Jogadas comecou vazia")
  check(#p.pilhaCuringa == 0, "Pilha de Curinga comecou vazia")
  check(p.vez == 1 or p.vez == 2, "comeca na vez de alguem (" .. p.vez .. ")")
  check(p.turno == 1, "turno inicial = 1")
  check(#p.pilhaDescarte == 0, "descarte comecou vazio")
  check(p.jogadasTurno == 0, "quota de cartas comecou em 0")
  check(#p.log > 0, "log comecou com mensagem")
  check(p.jogadores[1].status == jogo.STATUS.ATIVO, "jogador comeca ATIVO")
  check(p.fim == false, "partida nao comeca no fim")
  check(p.jogadores[1].nome == "JOGADOR_1", "nome do jogador = " .. p.jogadores[1].nome)
  check(p.jogadores[2].nome == "Adam Smith", "nome da IA = " .. p.jogadores[2].nome)
  check(#p.jogadores[1].areaSegura == 0, "area segura comecou vazia")
  check(#p.jogadores[2].areaSegura == 0, "area segura da IA comecou vazia")
end

local function testarSucessoFalha()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]

  -- chance 1 = sucesso garantido
  local antes = j.saldo
  local res = jogar(p, 1, cartaTeste({ chanceSucesso = 1, alteracaoSaldoBase = 10 }))
  check(res.sucesso == true and res.chance == 1, "chance 100% = sucesso")
  check(j.saldo == antes + 10, "sucesso aplica o valor cheio (" .. antes .. " -> " .. j.saldo .. ")")
  check(#p.pilhaDescarte == 1, "carta jogada foi para o descarte")
  check(p.pilhaDescarte[1].uid == "900-1", "descarte guarda a carta jogada")

  -- chance 0 = falha garantida, aplica alteracaoSaldoFalha
  antes = j.saldo
  res = jogar(p, 1, cartaTeste({ chanceSucesso = 0, alteracaoSaldoBase = 10, alteracaoSaldoFalha = -15 }))
  check(res.sucesso == false and res.chance == 0, "chance 0% = falha")
  check(j.saldo == antes - 15, "falha aplica alteracaoSaldoFalha (" .. antes .. " -> " .. j.saldo .. ")")

  -- dinheiro no alvo + divida aleatoria
  local inv, alvo = p.jogadores[1], p.jogadores[2]
  local antesAlvo = alvo.saldo
  res = jogar(p, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "alvo",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "DIVIDA", min = 150, max = 300, alvo = "alvo" },
  }))
  check(res.delta <= -150 and res.delta >= -300,
    "divida entre -150 e -300 (" .. tostring(res.delta) .. ")")
  check(alvo.saldo == antesAlvo + res.delta, "divida descontada do alvo")

  -- dinheiro do invocador com divida parcelada (Emprestimo)
  local antesInv = inv.saldo
  res = jogar(p, 1, cartaTeste({
    chanceSucesso = 1, dinheiroEm = "invocador", alteracaoSaldoBase = 500,
    efeito = { tipo = "DIVIDA_PARCELADA", valor = 100, turnos = 5, alvo = "invocador" },
  }))
  check(inv.saldo == antesInv + 500, "emprestimo creditou 500")
  check(#inv.efeitos == 1 and inv.efeitos[1].tipo == "DIVIDA_PARCELADA", "divida parcelada ativa")
  check(inv.efeitos[1].turnos == 5, "divida parcelada sem +1 (nao e lido no turno)")
  antesInv = inv.saldo
  jogo.processarInicioTurno(p, 1)
  check(inv.saldo == antesInv - 100, "pagou a 1a parcela de 100")
  check(#inv.efeitos == 1, "restam 4 parcelas")
end

local function testarQuotaTurno()
  local p = jogo.criarPartida()
  local vezAntes = p.vez
  local j = p.jogadores[vezAntes]

  local res = jogo.aplicarCarta(p, vezAntes, cartaTeste())
  check(res.consumiuTurno == false, "1a carta nao encerra o turno")
  check(p.jogadasTurno == 1, "quota = 1")

  res = jogo.aplicarCarta(p, vezAntes, cartaTeste())
  check(res.consumiuTurno == true, "2a carta encerra o turno (max 2)")
  check(p.jogadasTurno == 2, "quota = 2")

  -- Fim de turno: completa a mao ate 7 (nao compra so 1).
  for _ = 1, 3 do table.remove(j.mao) end
  local maoAntes = #j.mao
  jogo.encerrarVez(p)
  check(p.jogadasTurno == 0, "quota zerada no fim do turno")
  check(p.vez == (vezAntes == 1 and 2 or 1), "vez avancou")
  check(#j.mao == 7, "quem termina o turno completa a mao = 7 (" .. #j.mao .. ")")
  check(#j.mao == maoAntes + 3, "comprou exatamente o que faltava (3)")
end

local function testarChainSystem()
  local p = jogo.criarPartida()
  p.vez = 1
  local j = p.jogadores[1]

  local r1 = jogo.aplicarCarta(p, 1, cartaTeste({ classe = "Efeito" }))
  check(r1.chain == false, "1a carta inicia a cadeia (sem bonus)")
  check(jogo.quotaTurno(p, 1) == 2, "quota base sem cadeia = 2")

  local r2 = jogo.aplicarCarta(p, 1, cartaTeste({ classe = "Efeito" }))
  check(r2.chain == true, "2a carta da mesma classe entra na cadeia")
  check(j.chainBonus == 1, "cadeia concede 1 jogada extra")
  check(jogo.quotaTurno(p, 1) == 3, "quota com 1 chain = 3")
  check(r2.consumiuTurno == false, "2a carta em cadeia nao encerra o turno")
  check(jogo.jogadasRestantes(p, 1) == 1, "resta 1 jogada bonus")

  local r3 = jogo.aplicarCarta(p, 1, cartaTeste({ classe = "Efeito" }))
  check(r3.chain == true and j.chainBonus == 2, "3a carta concede o 2o bonus")
  check(jogo.quotaTurno(p, 1) == 4, "quota maxima da cadeia = 4")
  check(r3.consumiuTurno == false, "3a carta ainda tem a 4a jogada")

  local r4 = jogo.aplicarCarta(p, 1, cartaTeste({ classe = "Efeito" }))
  check(j.chainBonus == jogo.CHAIN_MAX, "cadeia respeita o teto CHAIN_MAX")
  check(r4.consumiuTurno == true, "4a carta encerra a quota maxima")

  -- Trocar de classe encerra a cadeia e volta a quota base.
  local p2 = jogo.criarPartida()
  p2.vez = 1
  jogo.aplicarCarta(p2, 1, cartaTeste({ classe = "Efeito" }))
  local rm = jogo.aplicarCarta(p2, 1, cartaTeste({ classe = "Acao" }))
  check(rm.chain == false, "classe diferente rompe a cadeia")
  check(p2.jogadores[1].chainBonus == 0, "bonus zerado ao trocar de classe")
  check(rm.consumiuTurno == true, "2a carta sem cadeia encerra o turno")

  -- Carta sem classe nao participa (compatibilidade com cartas antigas).
  local p3 = jogo.criarPartida()
  p3.vez = 1
  local rs = jogo.aplicarCarta(p3, 1, cartaTeste())
  check(rs.chain == false and p3.jogadores[1].chainBonus == 0,
    "carta sem classe nao inicia cadeia")

  -- Inicio do turno zera a cadeia do dono.
  j.chainClasse, j.chainBonus = "Efeito", 2
  jogo.processarInicioTurno(p, 1)
  check(j.chainBonus == 0 and j.chainClasse == nil,
    "processarInicioTurno reseta a cadeia")
end

local function testarQuickCounter()
  local p = jogo.criarPartida()
  p.vez = 2
  local atacante, alvo = p.jogadores[2], p.jogadores[1]
  local def = cartaTeste({
    uid = "def-slot", tipo = "PROTECAO", classe = "Defesa",
    protegeContra = "ACAO", dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
  })
  table.insert(alvo.mao, def)
  local atk = cartaTeste({
    nome = "Ataque", precisaAlvo = true, dinheiroEm = "alvo",
    alteracaoSaldoBase = -50, alteracaoSaldoFalha = 0, classe = "Efeito",
  })

  check(not jogo.podeReagir(p, 1, atk),
    "defesa na mao nao abre a janela (so o slot reage)")
  check(jogo.ameacaContra(p, 1, 2, atk, { alvoIdx = 1 }),
    "carta negativa com alvo no humano e uma ameaca")
  check(not jogo.ameacaContra(p, 2, 2, atk, { alvoIdx = 2 }),
    "carta contra o proprio atacante nao e ameaca")
  local atkTodos = cartaTeste({
    nome = "Ataque em area", precisaAlvo = false, dinheiroEm = "alvo",
    alteracaoSaldoBase = -30, alteracaoSaldoFalha = 0, classe = "Efeito",
    efeito = { alvo = "oponentes" },
  })
  check(jogo.ameacaContra(p, 1, 2, atkTodos),
    "carta negativa sem alvo unico tambem ameaca a mesa")

  -- Armar: sai da mao, entra no slot. Sem quota, sem dado, sem cadeia.
  local rd = jogo.armarDefesa(p, 1, "def-slot")
  local naMao = false
  for _, c in ipairs(alvo.mao) do
    if c.uid == "def-slot" then naMao = true end
  end
  check(rd ~= nil and alvo.protegido == true and not naMao,
    "armar move a defesa da mao para o slot")
  check(p.jogadasTurno == 0 and alvo.chainBonus == 0,
    "armar defesa nao gasta quota nem alimenta a cadeia")
  check(jogo.podeReagir(p, 1, atk), "defesa armada reage a ameaca")
  local opcoes = jogo.reacoesDisponiveis(p, 1, atk)
  check(#opcoes == 1 and opcoes[1].origem == "slot",
    "janela lista somente a defesa armada no slot")

  -- Receber o ataque: dano entra e a defesa CONTINUA armada.
  local antesSaldo = alvo.saldo
  jogo.aplicarCarta(p, 2, atk, { alvoIdx = 1, defesaDe = { [1] = false } })
  check(alvo.saldo == antesSaldo - 50 and alvo.protegido == true,
    "receber o ataque mantem a defesa armada")

  -- Defender: bloqueia e consome a carta do slot.
  antesSaldo = alvo.saldo
  jogo.aplicarCarta(p, 2, atk, { alvoIdx = 1, defesaDe = { [1] = true } })
  check(alvo.saldo == antesSaldo and alvo.protegido == false,
    "defender com a carta do slot bloqueia e consome a defesa")
  check(#alvo.defesas == 0 and not jogo.podeReagir(p, 1, atk),
    "slot vazio apos defender nao abre nova janela")

  -- Area Segura tambem nao defende sozinha: e preciso armar no slot.
  local p2 = jogo.criarPartida()
  p2.vez = 1
  local defArea = cartaTeste({
    uid = "def-area", tipo = "PROTECAO", classe = "Defesa",
    protegeContra = "ACAO", dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
  })
  p2.jogadores[1].areaSegura = { defArea }
  check(not jogo.podeReagir(p2, 1, atk),
    "defesa na Area Segura nao reage sem estar armada")
  check(jogo.jogarAreaSegura(p2, 1, "def-area") ~= nil
      and p2.jogadores[1].protegido == true,
    "usar a Area Segura arma a defesa no slot")
end

local function testarPassivas()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  j.efeitos = {
    { tipo = "RENDA_FIXA", valor = 50, turnos = 3 },
    { tipo = "DANO_PERIODICO", valor = 150, turnos = 2 },
  }
  local antes = j.saldo
  jogo.processarInicioTurno(p, 1)
  check(j.saldo == antes + 50 - 150,
    "inicio do turno aplica renda fixa e dano periodico")
  check(j.efeitos[1].turnos == 2 and j.efeitos[2].turnos == 1,
    "passivas contam um turno por tick")
end

local function testarProtecao()
  local p = jogo.criarPartida()
  local j1 = p.jogadores[1]

  local prot = cartaTeste({
    tipo = "PROTECAO", protegeContra = "ACAO",
    dinheiroEm = "nenhum", alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
  })
  local res = jogar(p, 1, prot)
  check(res.sucesso == true, "protecao tem sucesso garantido")
  check(j1.protegido == true and j1.protegeContra == "ACAO", "protecao ACAO ativa")

  local atk = cartaTeste({
    nome = "Ataque", chanceSucesso = 1, precisaAlvo = true,
    dinheiroEm = "alvo", alteracaoSaldoBase = -50, alteracaoSaldoFalha = 0,
  })
  local antes = j1.saldo
  jogo.aplicarCarta(p, 2, atk)
  check(j1.saldo == antes, "protecao bloqueou o ataque (-50 nao aplicado)")
  check(j1.protegido == false, "protecao consumida ao bloquear")

  -- protecao de outro tipo nao bloqueia (nem e consumida)
  local prot2 = cartaTeste({
    tipo = "PROTECAO", protegeContra = "EFEITO",
    dinheiroEm = "nenhum", alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
  })
  jogar(p, 1, prot2)
  antes = j1.saldo
  jogo.aplicarCarta(p, 2, atk)
  check(j1.saldo == antes - 50, "protecao EFEITO nao bloqueia acao")
  check(j1.protegido == true, "protecao nao consumida por tipo diferente")

  -- Sistemas novos agrupados aqui para nao estourar o limite de upvalues
  -- da funcao principal da suite.
  testarChainSystem()
  testarQuickCounter()
  testarPassivas()
end

local function testarEfeitos()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]

  -- Overclock: o novo MOD_BONUS_TURNO substitui o anterior
  jogo.adicionarEfeito(j, { tipo = "MOD_BONUS_TURNO", fator = 1.1, turnos = 5, alvo = "alvo" })
  jogo.adicionarEfeito(j, { tipo = "MOD_BONUS_TURNO", fator = 1.1, turnos = 5, alvo = "alvo" })
  local qtd = 0
  for _, e in ipairs(j.efeitos) do
    if e.tipo == "MOD_BONUS_TURNO" then qtd = qtd + 1 end
  end
  check(qtd == 1, "overclock substitui o bonus ativo")
  check(j.efeitos[1].turnos == 5, "MOD_BONUS_TURNO sem +1")

  -- MOD_CHANCE guardado com +1 para durar 2 turnos lidos
  j.efeitos = {}
  jogo.adicionarEfeito(j, { tipo = "MOD_CHANCE", valor = -0.1, turnos = 2 })
  check(j.efeitos[1].turnos == 3, "MOD_CHANCE +1 (" .. tostring(j.efeitos[1].turnos) .. ")")

  -- tick do inicio do turno decrementa e expira
  jogo.processarInicioTurno(p, 1)
  check(#j.efeitos == 1 and j.efeitos[1].turnos == 2, "tick 1: 3 -> 2")
  jogo.processarInicioTurno(p, 1)
  check(#j.efeitos == 1 and j.efeitos[1].turnos == 1, "tick 2: 2 -> 1")
  jogo.processarInicioTurno(p, 1)
  check(#j.efeitos == 0, "expira apos 3 ticks (2 turnos lidos)")

  -- MULT_CHANCE (Que Atrevido): proxima carta x0.5, consome 1 uso
  j.efeitos = {}
  jogo.adicionarEfeito(j, { tipo = "MULT_CHANCE", fator = 0.5, usos = 1 })
  local ch = jogo.calcularChance(cartaTeste({ chanceSucesso = 0.8 }), j)
  check(math.abs(ch - 0.4) < 1e-9, "MULT_CHANCE 0.8*0.5 = 0.4 (" .. tostring(ch) .. ")")
  check(#j.efeitos == 0, "MULT_CHANCE consumiu o uso")

  -- CHANCE_FIXA soNegativa (Seiketsu): so age em carta negativa
  j.efeitos = {}
  jogo.adicionarEfeito(j, { tipo = "CHANCE_FIXA", valor = 0.5, usos = 1, soNegativa = true })
  ch = jogo.calcularChance(cartaTeste({ chanceSucesso = 0.8 }), j)
  check(math.abs(ch - 0.8) < 1e-9, "soNegativa ignora carta positiva")
  check(#j.efeitos == 1, "efeito mantido para a carta negativa")
  ch = jogo.calcularChance(cartaTeste({ chanceSucesso = 0.8, alteracaoSaldoBase = -20 }), j)
  check(math.abs(ch - 0.5) < 1e-9, "soNegativa força 50% na negativa")
  check(#j.efeitos == 0, "uso consumido na carta negativa")

  -- MOD_FALHA (Monstro): falha 40% menor
  j.efeitos = {}
  jogo.adicionarEfeito(j, { tipo = "MOD_FALHA", fator = 0.6, turnos = 2 })
  ch = jogo.calcularChance(cartaTeste({ chanceSucesso = 0.5 }), j)
  check(math.abs(ch - 0.7) < 1e-9, "MOD_FALHA 1-(1-0.5)*0.6 = 0.7 (" .. tostring(ch) .. ")")
  check(#j.efeitos == 1, "MOD_FALHA nao e consumido por uso")

  -- MOD_CHANCE negativo (Pego no Flagra no alvo)
  j.efeitos = {}
  jogo.adicionarEfeito(j, { tipo = "MOD_CHANCE", valor = -0.2, turnos = 2 })
  ch = jogo.calcularChance(cartaTeste({ chanceSucesso = 0.8 }), j)
  check(math.abs(ch - 0.6) < 1e-9, "MOD_CHANCE 0.8-0.2 = 0.6")

  -- Curinga id 50: Rotatividade de Mercado gira as maos dos vivos.
  local tm = jogo.criarPartida()
  tm.jogadores[1].mao = { cartaTeste({ nome = "A" }) }
  tm.jogadores[2].mao = { cartaTeste({ nome = "B" }) }
  jogo.aplicarCarta(tm, 1, cartas.porId(50))
  check(tm.jogadores[1].mao[1].nome == "B"
    and tm.jogadores[2].mao[1].nome == "A",
    "Rotatividade de Mercado troca as maos")

  -- Curinga id 51: Probabilidade Mortal zera o saldo de um jogador sorteado.
  local pm = jogo.criarPartida()
  local rnd = love.math.random
  love.math.random = function(a, b)
    if a ~= nil and b == nil then return 2 end
    return rnd(a, b)
  end
  local resPM = jogo.aplicarCarta(pm, 1, cartas.porId(51))
  love.math.random = rnd
  check(pm.jogadores[2].falido == true and pm.jogadores[2].saldo == 0,
    "Probabilidade Mortal elimina o sorteado")
  check(resPM.vitimaIdx == 2,
    "Probabilidade Mortal informa o assento da vitima")
end

local function testarDinheiroAdiado()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  j.saldo = 1000
  j.efeitos = {}
  jogo.adicionarEfeito(j, { tipo = "DINHEIRO_ADIADO", valor = 500, turnos = 1 })
  check(#j.efeitos == 1, "dinheiro adiado registrado")
  jogo.processarInicioTurno(p, 1)
  check(j.saldo == 1500, "creditou +500 no inicio do turno (" .. j.saldo .. ")")
  check(#j.efeitos == 0, "efeito expirou apos creditar")
end

local function testarDoacao()
  local p = jogo.criarPartida()
  local inv, vit = p.jogadores[1], p.jogadores[2]
  local a1, a2 = inv.saldo, vit.saldo
  jogar(p, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "DOACAO_PERCENTUAL", alvo = "alvo" },
  }))
  check(inv.saldo >= a1 and inv.saldo <= a1 + a2, "invocador recebeu entre 0 e todo o saldo")
  if vit.falido then
    check(inv.saldo == a1 + a2, "vitima a zero: doou tudo")
    check(vit.saldo == 0, "vitima falida fica com saldo zero")
  else
    check(inv.saldo + vit.saldo == a1 + a2, "doacao preserva o total")
  end
end

local function testarRouboCartas()
  local p = jogo.criarPartida()
  local m1, m2 = #p.jogadores[1].mao, #p.jogadores[2].mao
  jogar(p, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "ROUBA_CARTAS", quantidade = 2, alvo = "alvo" },
  }))
  check(#p.jogadores[1].mao == m1 + 2, "invocador roubou 2 cartas")
  check(#p.jogadores[2].mao == m2 - 2, "alvo perdeu 2 cartas")
end

-- Roubo AS CEGAS: uids escolhidas pelo jogador (ModalRouboCego).
local function testarRouboEscolhido()
  local p = jogo.criarPartida()
  local inv, alvo = p.jogadores[1], p.jogadores[2]

  local cartaA = cartaTeste({ uid = "alvo-A", uidNum = 911, nome = "Carta A" })
  local cartaB = cartaTeste({ uid = "alvo-B", uidNum = 912, nome = "Carta B" })
  local cartaC = cartaTeste({ uid = "alvo-C", uidNum = 913, nome = "Carta C" })
  alvo.mao = { cartaA, cartaB, cartaC }
  inv.mao = {}

  local res = jogo.aplicarCarta(p, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "ROUBA_CARTAS", quantidade = 2, alvo = "alvo" },
  }), { roubarUids = { "alvo-C", "alvo-A" } })

  check(#inv.mao == 2, "roubo as cegas levou 2 cartas (" .. #inv.mao .. ")")
  check(inv.mao[1] and inv.mao[1].uid == "alvo-C", "1a escolhida foi alvo-C")
  check(inv.mao[2] and inv.mao[2].uid == "alvo-A", "2a escolhida foi alvo-A")
  check(#alvo.mao == 1 and alvo.mao[1].uid == "alvo-B", "so alvo-B ficou no alvo")
  check(res.log:find("as cegas", 1, true) ~= nil, "log marca roubo as cegas")

  -- uid invalido nao consome a cota de quantidade.
  inv.mao = {}
  alvo.mao = { cartaA, cartaB, cartaC }
  jogo.aplicarCarta(p, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "ROUBA_CARTAS", quantidade = 2, alvo = "alvo" },
  }), { roubarUids = { "nao-existe", "alvo-B" } })
  check(#inv.mao == 1 and inv.mao[1].uid == "alvo-B",
    "uid invalido ignorado, alvo-B roubada (" .. #inv.mao .. ")")
end

-- Area Segura (colocarCartaAreaSegura1v1 / jogarCartaAreaSegura1v1).
local function testarAreaSegura()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  local cartaArea = cartaTeste({ uid = "area-1", uidNum = 921, nome = "Carta Area" })
  table.insert(j.mao, cartaArea)
  local uid = cartaArea.uid

  check(jogo.colocarAreaSegura(p, 1, uid) == true, "colocou carta na Area Segura")
  check(#j.mao == 7, "carta saiu da mao (8 -> " .. #j.mao .. ")")
  check(#j.areaSegura == 1, "area segura guarda 1 carta")
  check(j.areaSegura[1].uid == uid, "carta certa na area")
  check(jogo.AREA_SEGURA_MAX == 3, "area segura tem 3 slots")

  -- Cabem 3: a 2a e a 3a entram, a 4a nao.
  local outro = j.mao[1].uid
  check(jogo.colocarAreaSegura(p, 1, outro) == true, "area guarda a 2a carta")
  local terceiro = j.mao[1].uid
  check(jogo.colocarAreaSegura(p, 1, terceiro) == true, "area guarda a 3a carta")
  check(#j.areaSegura == 3, "area segura guarda 3 cartas")
  check(p.jogadasTurno == 0, "guardar 3 cartas no mesmo turno nao consome quota")
  check(jogo.colocarAreaSegura(p, 1, j.mao[1].uid) == false, "area cheia nao guarda a 4a")
  check(#j.areaSegura == 3, "area continua com 3 cartas")
  check(jogo.colocarAreaSegura(p, 1, "uid-invalido") == false, "uid invalido nao guarda")

  -- Jogar da Area Segura: aplica o efeito sem consumir a quota.
  p.jogadasTurno = 1
  local antes = j.saldo
  local res = jogo.jogarAreaSegura(p, 1, uid)
  check(res ~= nil, "jogou carta da Area Segura")
  check(res.sucesso == true and j.saldo == antes + 10, "efeito aplicado (+10)")
  check(res.consumiuTurno == false, "jogada da area nao encerra o turno")
  check(p.jogadasTurno == 1, "quota intacta apos jogar da area (" .. p.jogadasTurno .. ")")
  check(#j.areaSegura == 2, "area perdeu a carta jogada (2 restantes)")
  check(p.pilhaDescarte[#p.pilhaDescarte].uid == uid, "carta da area foi pro descarte")
  check(p.log[#p.log]:find("da Area Segura", 1, true) ~= nil,
    "log marca origem da Area Segura")

  -- As outras duas tambem saem, uma por uma.
  jogo.jogarAreaSegura(p, 1, outro)
  jogo.jogarAreaSegura(p, 1, terceiro)
  check(#j.areaSegura == 0, "area vazia depois de jogar as 3")

  check(jogo.jogarAreaSegura(p, 1, "uid-invalido") == nil, "jogar da area com uid invalido = nil")

  -- A IA guarda (indice 2). Manual V7 4.2: carta so no proprio turno.
  p.vez = 2
  local ia = p.jogadores[2]
  local uidIA = ia.mao[1].uid
  check(jogo.colocarAreaSegura(p, 2, uidIA) == true, "IA guardou na Area Segura")
  check(#ia.areaSegura == 1, "area da IA com 1 carta")
end

local function testarDescartaEPuxa()
  local p = jogo.criarPartida()
  local alvo = p.jogadores[2]
  local maoAntes = #alvo.mao
  local descAntes = #p.pilhaDescarte
  jogar(p, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "DESCARTA_E_PUXA", quantidade = 1, alvo = "alvo" },
  }))
  check(#alvo.mao == maoAntes, "alvo: 1 sai e 1 entra na mao")
  check(#p.pilhaDescarte == descAntes + 2, "descarte +1 da carta jogada +1 da descartada")
end

local function testarPresenteNoel()
  local p = jogo.criarPartida()
  local inv, alvo = p.jogadores[1], p.jogadores[2]
  local a1, a2 = inv.saldo, alvo.saldo
  jogar(p, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = {
      tipo = "DINHEIRO_ALVO", alvo = "alvo",
      ganhoInvocador = 200, perdaAlvo = 100,
      debuff = { tipo = "MOD_CHANCE", valor = -0.1, turnos = 2 },
    },
  }))
  check(inv.saldo == a1 + 200, "invocador +200")
  check(alvo.saldo == a2 - 100, "alvo -100")
  check(#alvo.efeitos == 1 and alvo.efeitos[1].tipo == "MOD_CHANCE", "debuff aplicado ao alvo")
  check(alvo.efeitos[1].turnos == 3, "debuff com +1 (lido no turno)")
end

local function testarEventoDeusMercado()
  -- O evento do Deus Mercado so interfere NO FIM da rodada: quando a vez
  -- passou por todos e vai voltar ao primeiro (wrap N -> 1), antes do turno
  -- virar (ex.: 1 para 2). No meio da rodada nao dispara.
  local p = jogo.criarPartida()
  p.vez = 1 -- a vez inicial e sorteada; fixa para isolar a regra do wrap
  local antes1, antes2 = p.jogadores[1].saldo, p.jogadores[2].saldo
  jogo.encerrarVez(p)
  check(p.evento == nil, "evento NAO dispara no meio da rodada")
  check(p.rendaRodada == nil, "renda tambem so entra no fim da rodada")
  check(p.vez == 2 and p.turno == 1, "vez avancou sem virar o turno")

  jogo.encerrarVez(p)
  check(p.evento ~= nil, "evento dispara no fim da rodada (wrap N->1)")
  check(p.vez == 1 and p.turno == 2, "rodada virou: vez 1 e turno 2")
  check(p.rendaRodada ~= nil and p.rendaRodada.valor == jogo.rendaDaRodada(1),
    "renda da rodada 1 creditada")
  check(p.jogadores[1].saldo == antes1 + p.rendaRodada.valor + p.evento.deltas[1],
    "saldo do jogador = antes + renda + evento")
  check(p.jogadores[2].saldo == antes2 + p.rendaRodada.valor + p.evento.deltas[2],
    "saldo da IA = antes + renda + evento")
  local nomes = { BONANCA = true, CRISE = true, SUBSIDIO = true,
    IMPOSTO = true, VOLATILIDADE = true, ESTIMULO = true }
  check(nomes[p.evento.nome] == true,
    "evento veio da lista variada (" .. tostring(p.evento.nome) .. ")")

  -- Overclock multiplica apenas ganhos positivos; testa com evento forcado.
  local p2 = jogo.criarPartida()
  p2.jogadores[1].efeitos = {
    { tipo = "MOD_BONUS_TURNO", fator = 1.1, turnos = 5, alvo = "alvo" },
  }
  local b1, b2 = p2.jogadores[1].saldo, p2.jogadores[2].saldo
  jogo.eventoDeusMercado(p2, { nome = "BONANCA", tipo = "todos", valor = 100 })
  check(p2.jogadores[1].saldo == b1 + 110, "overclock multiplica ganho (1.1)")
  check(p2.jogadores[2].saldo == b2 + 100, "IA sem bonus recebe o valor cheio")
  b1, b2 = p2.jogadores[1].saldo, p2.jogadores[2].saldo
  jogo.eventoDeusMercado(p2, { nome = "CRISE", tipo = "todos", valor = -100 })
  check(p2.jogadores[1].saldo == b1 - 100 and p2.jogadores[2].saldo == b2 - 100,
    "overclock nao muda perdas")

  -- Em arena com N jogadores o evento dispara no fim do ultimo seat da
  -- rodada (antes do wrap para o seat 1).
  local p3 = jogo.criarPartida({ n = 5 })
  p3.vez = 1
  for i = 1, 4 do
    jogo.encerrarVez(p3)
    check(p3.evento == nil, "arena 5: sem evento no seat " .. i)
  end
  jogo.encerrarVez(p3)
  check(p3.evento ~= nil, "arena 5: evento no fim do 5o seat")
  check(p3.vez == 1 and p3.turno == 2, "arena 5: rodada virou para turno 2")
  check(p3.metaPendente == nil, "rodada 1 nao abre leilao")
end

-- IA na Area Segura: escolher carta para guardar, nao guardar em condicoes
-- invalidas e puxar/jogar a carta guardada sem consumir a quota do turno.
local function testarIAGuardarArea()
  local p = jogo.criarPartida({ n = 4 })
  local ia = p.jogadores[2]
  local uid = jogo.iaGuardarCarta(p, 2)
  check(uid ~= nil, "IA escolhe carta para guardar na Area Segura")
  local naMao = false
  for _, c in ipairs(ia.mao) do
    if c.uid == uid then naMao = true end
  end
  check(naMao, "uid escolhido esta na mao da IA")
  check(#ia.areaSegura == 0, "area segura comecou vazia")

  check(jogo.colocarAreaSegura(p, 2, uid) == true, "IA guardou a carta")
  check(#ia.areaSegura == 1, "area da IA com 1 carta")
  local uid2 = jogo.iaGuardarCarta(p, 2)
  check(uid2 ~= nil, "com 1 carta a IA ainda escolhe outra")
  check(jogo.colocarAreaSegura(p, 2, uid2) == true, "IA guardou a 2a carta")
  local uid3 = jogo.iaGuardarCarta(p, 2)
  check(uid3 ~= nil, "com 2 cartas a IA ainda escolhe a 3a")
  check(jogo.colocarAreaSegura(p, 2, uid3) == true, "IA guardou a 3a carta")
  check(#ia.areaSegura == 3, "area da IA com 3 cartas")
  check(jogo.iaGuardarCarta(p, 2) == nil, "area cheia (3) nao volta a escolher")

  -- Manual V7 4.2: carta so no proprio turno da IA.
  p.vez = 2
  local res = jogo.jogarAreaSegura(p, 2, uid)
  check(res ~= nil, "IA puxou e jogou a carta da Area Segura")
  check(res.consumiuTurno == false, "carta da Area nao consome a quota")
  check(#ia.areaSegura == 2, "area com 2 depois de puxar 1")
  check(#p.pilhaDescarte > 0, "carta da Area foi para o descarte")

  local p2 = jogo.criarPartida({ n = 4 })
  p2.jogadores[2].falido = true
  check(jogo.iaGuardarCarta(p2, 2) == nil, "falido nao guarda")

  local p3 = jogo.criarPartida({ n = 4 })
  p3.jogadores[2].mao = { p3.jogadores[2].mao[1] }
  check(jogo.iaGuardarCarta(p3, 2) == nil, "mao com 1 carta nao guarda")
end

local function testarDuracaoTurno()
  local j = { efeitos = {} }
  -- Manual V7 3.1: turno base de 25 segundos.
  check(jogo.duracaoTurno(j) == 25, "turno base = 25s (V7)")
  j.efeitos = { { tipo = "TEMPO_TURNO", modo = "definir", segundos = 2, turnos = 3 } }
  check(jogo.duracaoTurno(j) == 2, "Sem tempo = 2s")
  j.efeitos = { { tipo = "TEMPO_TURNO", modo = "bonus", segundos = 2, turnos = 2 } }
  check(jogo.duracaoTurno(j) == 27, "Seiso = 25+2 = 27s")
  j.efeitos = {
    { tipo = "TEMPO_TURNO", modo = "definir", segundos = 2 },
    { tipo = "TEMPO_TURNO", modo = "bonus", segundos = 2 },
  }
  check(jogo.duracaoTurno(j) == 2, "definir ignora bonus")
end

local function testarFalencia()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  j.saldo = 10

  local res = jogar(p, 1, cartaTeste({ chanceSucesso = 0, alteracaoSaldoFalha = -100 }))
  check(res.sucesso == false, "falha garantida")
  check(j.usouFundoEmergencia == false, "nao existe mais fundo de emergencia")
  check(j.saldo == 0, "saldo vai a zero (" .. j.saldo .. ")")
  check(j.falido == true, "falencia imediata ao chegar a zero")
  check(j.status == jogo.STATUS.ELIMINADO, "status ELIMINADO (" .. j.status .. ")")

  -- Nao existe saldo negativo: uma nova perda continua em zero.
  jogar(p, 1, cartaTeste({ chanceSucesso = 0, alteracaoSaldoFalha = -300 }))
  check(j.saldo == 0, "saldo nunca fica negativo (" .. j.saldo .. ")")

  jogo.verificarFim(p)
  check(p.fim == true, "partida terminou por eliminacao")
  check(p.vencedor == p.jogadores[2], "IA venceu por eliminacao")
  check(p.motivo == "Vitoria por Eliminacao!", "motivo = " .. tostring(p.motivo))
end

local function testarRendaELivroCaixa()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  local antes = j.saldo

  -- Manual V7 3.1: renda base de R$ 1.000 (+100 por rodada).
  local r1 = jogo.aplicarRendaRodada(p, 1)
  check(r1.valor == 1000, "renda da rodada 1 = 1000 (" .. r1.valor .. ")")
  check(j.saldo == antes + 1000, "renda creditada no saldo")
  check(j.receitas == 1000, "receita registrada no livro-caixa")
  check(j.extrato[#j.extrato].categoria == "renda",
    "extrato marca a categoria renda")
  check(jogo.resumoFinanceiro(j).lucro == 1000, "lucro apos renda = 1000")

  local r2 = jogo.aplicarRendaRodada(p, 3)
  check(r2.valor == 1200, "renda da rodada 3 = 1000 + 2*100 = 1200 (" .. r2.valor .. ")")
  check(jogo.rendaDaRodada(10) == 1900, "renda da rodada 10 = 1900")
  check(j.receitas == 2200, "receitas acumuladas = 2200 (" .. j.receitas .. ")")
  check(jogo.resumoFinanceiro(j).lucro == 2200, "lucro = saldo - capital inicial")

  -- Ruina: perda maior que o saldo zera e registra apenas o valor efetivo.
  local k = p.jogadores[2]
  k.saldo = 50
  jogo.aplicarSaldo(p, k, -200, "teste")
  check(k.saldo == 0 and k.falido, "perda maior que o saldo leva a zero")
  check(k.despesas == 50, "despesa registrada somente ate zero (" .. k.despesas .. ")")
end

local function testarCombinacoes()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  local antes = j.saldo
  j.comboCartas = {
    Seiri = true, Seiton = true, Seiso = true, Seiketsu = true, Shitsuke = true,
  }
  local eventos = jogo.verificarCombos(p)
  check(#eventos == 1 and eventos[1].nome == "5S COMPLETO",
    "5S completo detectado")
  check(j.saldo == antes + 300, "5S completo paga +300")
  check(j.comboCartas and next(j.comboCartas) == nil,
    "cartas do combo resetadas na rodada")
  local depois = j.saldo
  jogo.verificarCombos(p)
  check(j.saldo == depois, "combo nao paga duas vezes na mesma rodada")

  -- Combo incompleto nao paga.
  j.comboCartas = { Seiri = true, Seiton = true }
  antes = j.saldo
  eventos = jogo.verificarCombos(p)
  check(#eventos == 0 and j.saldo == antes, "combo incompleto nao paga")
end

local function testarDefesaDuracao()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  jogar(p, 1, cartaTeste({
    tipo = "PROTECAO", protegeContra = "ACAO",
    dinheiroEm = "nenhum", alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
  }))
  check(#j.defesas == 1 and j.defesas[1].turnos == 2,
    "defesa entra no slot com 2 turnos")

  jogo.processarInicioTurno(p, 1)
  check(#j.defesas == 1 and j.defesas[1].turnos == 1,
    "defesa envelhece para 1 turno")
  jogo.processarInicioTurno(p, 1)
  check(#j.defesas == 0, "defesa expira no segundo tick")
  check(j.protegido == false, "flag de protecao limpa ao expirar")
  check(p.pilhaDescarte[#p.pilhaDescarte].tipo == "PROTECAO",
    "carta de defesa expirada vai para o descarte")

  -- Uma nova defesa substitui a anterior (slot unico).
  jogar(p, 1, cartaTeste({
    tipo = "PROTECAO", protegeContra = "ACAO",
    dinheiroEm = "nenhum", alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
  }))
  local antiga = j.defesas[1].carta
  jogar(p, 1, cartaTeste({
    tipo = "PROTECAO", protegeContra = "EFEITO",
    dinheiroEm = "nenhum", alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
  }))
  check(#j.defesas == 1, "slot de defesa continua unico")
  check(j.defesas[1].carta.protegeContra == "EFEITO",
    "defesa nova ocupa o slot")
  check(p.pilhaDescarte[#p.pilhaDescarte] == antiga,
    "defesa antiga foi para o descarte")

  -- As 5 defesas do catalogo ocupam o slot; cada nova descarta a anterior.
  local j1, j2 = p.jogadores[1], p.jogadores[2]
  for _, id in ipairs({ 8, 10, 12, 22, 13 }) do
    local c = cartas.porId(id)
    check(c.classe == "Defesa" and c.tipo == "PROTECAO",
      "carta " .. id .. " e Defesa")
    jogar(p, 1, c)
    check(#j1.defesas == 1 and j1.defesas[1].carta.id == id,
      "defesa " .. id .. " no slot")
  end

  -- Seiketsu (a ultima instalada) so reage a carta negativa.
  local atkNeg = cartaTeste({ tipo = "ACAO", chanceSucesso = 0.8,
    precisaAlvo = true, dinheiroEm = "alvo", alteracaoSaldoBase = -100,
    alteracaoSaldoFalha = 0 })
  local atkPos = cartaTeste({ tipo = "ACAO", chanceSucesso = 0.8,
    precisaAlvo = true, dinheiroEm = "alvo", alteracaoSaldoBase = 100,
    alteracaoSaldoFalha = 0 })
  check(jogo.mitigacaoPorProtecao(j1, atkNeg) ~= nil,
    "Seiketsu reage a ataque negativo")
  check(jogo.mitigacaoPorProtecao(j1, atkPos) == nil,
    "Seiketsu ignora carta positiva")

  -- Integracao: com chance 80% e dado 0.6, sem mitigacao o ataque acertaria.
  -- Com Tempos e Movimentos no slot a chance cai para 50%: o ataque falha
  -- e a defesa vai para o descarte.
  jogar(p, 1, cartas.porId(8))
  local rnd = love.math.random
  love.math.random = function(a, b)
    if a == nil and b == nil then return 0.6 end
    return rnd(a, b)
  end
  local saldoAntes = j2.saldo
  local res = jogo.aplicarCarta(p, 2, atkNeg)
  love.math.random = rnd
  check(j2.saldo == saldoAntes, "mitigacao derrubou o ataque (saldo intacto)")
  check(res and res.sucesso == false, "dado 0.6 falhou com chance 50%")
  check(#j1.defesas == 0, "defesa mitigadora consumida")
  local foiAoDescarte = false
  for _, c in ipairs(p.pilhaDescarte) do
    if c == cartas.porId(8) then foiAoDescarte = true end
  end
  check(foiAoDescarte, "defesa mitigadora foi para o descarte")

  -- Previsao: mitigacao MULTIPLICATIVA (x0.5), nao fixa em 50%. Um ataque
  -- de 40% cai para 20%: com dado 0.3 ele falha (se fosse CHANCE_FIXA em
  -- 50%, 0.3 < 0.5 acertaria). A defesa e consumida mesmo assim.
  local atkFraco = cartaTeste({ tipo = "EFEITO", chanceSucesso = 0.4,
    precisaAlvo = true, alteracaoSaldoBase = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MOD_CHANCE", valor = -0.1, turnos = 2, alvo = "alvo" } })
  jogar(p, 1, cartas.porId(22))
  love.math.random = function(a, b)
    if a == nil and b == nil then return 0.3 end
    return rnd(a, b)
  end
  local resPrev = jogo.aplicarCarta(p, 2, atkFraco)
  love.math.random = rnd
  check(resPrev and resPrev.sucesso == false,
    "Previsao x0.5: 40% vira 20% e o dado 0.3 falha")
  check(#j1.defesas == 0, "Previsao consumida ao mitigar")
end

local function testarBonusCopia()
  local j = { cartasTurno = {} }
  local c = { id = 7 }
  check(jogo.aplicarBonusCopia(0.4, j, c) == 0.4,
    "primeira copia mantem a chance")
  j.cartasTurno[7] = 1
  check(math.abs(jogo.aplicarBonusCopia(0.4, j, c) - 0.52) < 1e-9,
    "segunda copia: 0.4 * 1.3 = 0.52 (V7: Carta Dobrada +30%)")
  j.cartasTurno[7] = 2
  check(math.abs(jogo.aplicarBonusCopia(0.4, j, c) - 0.52) < 1e-9,
    "terceira copia mantem o maior bonus")
  check(jogo.aplicarBonusCopia(0.9, j, c) == 1,
    "bonus nao passa de 100%")
end

-- ============================================================
-- CORRECOES E MECANICAS NOVAS DO MANUAL V7
-- ============================================================

local function testarConstantesV7()
  check(jogo.TURNO_BASE_SEGUNDOS == 25, "V7: turno base de 25s")
  check(jogo.RENDA_BASE == 1000, "V7: renda base de R$ 1.000")
  check(jogo.BONUS_COPIA == 0.3, "V7: Carta Dobrada da +30%")
  check(jogo.CARTAS_MAX_TOTAL == 10, "V7: maximo de 10 cartas (7 mao + 3 banco)")
  check(jogo.SATISFACAO_INICIAL == 100, "V7: Satisfacao inicial 100")
  check(jogo.SATISFACAO_MIN == 0 and jogo.SATISFACAO_MAX == 200,
    "V7: barra de Satisfacao 0..200")
  check(jogo.SATISFACAO_BONUS_CARTAS == 2, "V7: Satisfacao MAX dobra 2 cartas")
  check(jogo.PRODUTIVIDADE_MIN == -1, "V7: produtividade com piso em -100%")
  check(jogo.FUSAO_MIN == 2 and jogo.FUSAO_MAX == 5, "V7: fusao de 2 a 5 cartas")

  -- 5.5.3: a classe Defesa e o Slot de Defesa - cartas que protegem o dono.
  for _, c in ipairs(cartas.CARTAS) do
    check((c.classe == "Defesa") == (c.tipo == "PROTECAO"),
      c.nome .. ": classe Defesa <=> tipo PROTECAO (" ..
      tostring(c.classe) .. "/" .. tostring(c.tipo) .. ")")
  end
  check(cartas.porId(8).classe == "Defesa",
    "Tempos e Movimentos e Defesa de mitigacao")
  check(cartas.porId(13).classe == "Defesa",
    "Seiketsu e Defesa de mitigacao")
  check(jogo.mitigacaoPorProtecao ~= nil,
    "jogo expoe a regra de mitigacao das defesas")

  -- Super Cartas: catalogo proprio, fora do baralho infinito.
  check(type(cartas.SUPER_CARTAS) == "table" and #cartas.SUPER_CARTAS > 0,
    "catalogo de Super Cartas existe")
  for _, c in ipairs(cartas.SUPER_CARTAS) do
    check(c.classe == "Super" and c.super == true, c.nome .. " e Super Carta")
    check(c.id >= 100, c.nome .. " tem id >= 100 (nao colide com o catalogo)")
    check(c.efeitoTexto ~= nil and c.efeitoTexto ~= "",
      c.nome .. " tem efeitoTexto")
    local noBaralho = false
    for _, b in ipairs(cartas.CARTAS) do
      if b.id == c.id then noBaralho = true end
    end
    check(not noBaralho, c.nome .. " fica fora do baralho infinito")
  end
end

local function testarTetoMao()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  check(jogo.tetoMao(p, j) == 10, "sem banco: teto total de 10 cartas")
  table.insert(j.areaSegura, table.remove(j.mao))
  check(jogo.tetoMao(p, j) == 9, "1 carta no banco: mao vai ate 9")
  while #j.areaSegura < jogo.AREA_SEGURA_MAX do
    table.insert(j.areaSegura, table.remove(j.mao))
  end
  check(jogo.tetoMao(p, j) == jogo.CARTAS_POR_MAO,
    "banco cheio: mao limitada em 7")
  p.eventoMeta = true
  check(jogo.tetoMao(p, j) == math.huge,
    "durante o evento do Deus Mercado o teto e excedido")
  p.eventoMeta = false
  check(jogo.tetoMao(p, j) == jogo.CARTAS_POR_MAO, "fora do evento o teto volta")
end

local function testarTurnoExclusivoDasCartas()
  local p = jogo.criarPartida()
  p.vez = 1
  local j = p.jogadores[1]
  local uid = j.mao[1].uid
  check(jogo.colocarAreaSegura(p, 1, uid) == true, "guarda carta na Area Segura")
  p.vez = 2
  check(jogo.jogarAreaSegura(p, 1, uid) == nil,
    "V7 4.2: fora do turno nao joga da Area Segura")
  check(#j.areaSegura == 1, "carta continua guardada")
  p.vez = 1
  check(jogo.jogarAreaSegura(p, 1, uid) ~= nil,
    "no proprio turno joga da Area Segura")
end

local function testarOcultarSaldos()
  local p = jogo.criarPartida({ n = 3 })
  p.turno = 2
  jogo.processarInicioTurno(p, 3)
  check(p.ocultarSaldos == true,
    "turno imediatamente anterior ao evento esconde os saldos")
  jogo.processarInicioTurno(p, 1)
  check(p.ocultarSaldos == false, "turno normal nao esconde")
  p.turno = 1
  jogo.processarInicioTurno(p, 3)
  check(p.ocultarSaldos == false, "rodada impar nao esconde")
  p.turno = 10
  jogo.processarInicioTurno(p, 3)
  check(p.ocultarSaldos == false, "apos a 10a rodada nao ha evento")
end

local function testarVisorDeCuringas()
  local p = jogo.criarPartida()
  jogo.aplicarCuringaGlobal(p)
  jogo.aplicarCuringaGlobal(p)
  check(#p.curingaHistorico == 1, "visor guarda o Curinga substituido")
  jogo.aplicarCuringaGlobal(p)
  jogo.aplicarCuringaGlobal(p)
  check(#p.curingaHistorico == 2, "visor guarda no maximo 2 anteriores")
  check(p.curingaHistorico[1].uid ~= p.curingaGlobal.carta.uid,
    "o global atual nao entra no proprio historico")
  check(p.curingaHistorico[2].uid ~= p.curingaHistorico[1].uid,
    "historico sem duplicata do mesmo global")
end

local function testarSatisfacao()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  check(j.satisfacao == 100 and (j.bonusSatisfacao or 0) == 0,
    "Satisfacao comeca em 100 sem bonus")

  -- Faixa 0..200.
  jogo.alterarSatisfacao(p, 1, 500)
  check(j.satisfacao == 200, "Satisfacao satura em 200")
  check(j.bonusSatisfacao == 2, "chegar a 200 concede 2 cartas com efeitos dobrados")
  jogo.alterarSatisfacao(p, 1, -9999)
  check(j.satisfacao == 0, "Satisfacao nao desce de 0")
  check(j.greve == true, "Satisfacao 0 coloca em GREVE")

  -- Greve: encerrarVez pula o jogador de greve e limpa a barra.
  local q = jogo.criarPartida({ n = 3 })
  q.vez = 1
  q.jogadores[2].greve = true
  q.jogadores[2].satisfacao = 0
  jogo.encerrarVez(q)
  check(q.jogadores[2].greve == false, "GREVE limpa no turno perdido")
  check(q.jogadores[2].satisfacao == 100,
    "barra volta a 100 ao sair da GREVE")
  check(q.vez == 3, "turno do jogador de GREVE foi pulado (vez foi para o 3)")
end

local function testarSatisfacaoMAX()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  j.satisfacao = 200
  j.bonusSatisfacao = 2

  local antes = j.saldo
  jogar(p, 1, cartaTeste({
    chanceSucesso = 1, dinheiroEm = "invocador", alteracaoSaldoBase = 100,
  }))
  check(j.saldo == antes + 200, "Satisfacao MAX dobra o ganho (100 -> 200)")
  check(j.bonusSatisfacao == 1, "consumiu 1 das 2 cartas")
  check(j.satisfacao == 200, "barra so volta a 100 quando o bonus termina")

  antes = j.saldo
  jogar(p, 1, cartaTeste({
    chanceSucesso = 1, dinheiroEm = "invocador", alteracaoSaldoBase = 100,
  }))
  check(j.saldo == antes + 200, "segunda carta tambem sai com efeito dobrado")
  check(j.bonusSatisfacao == 0, "bonus esgotado")
  check(j.satisfacao == 100, "barra volta a 100 ao consumir as 2 cartas")

  -- A penalidade de FALHA nao e dobrada (so a parte de sucesso).
  j.satisfacao = 200
  j.bonusSatisfacao = 2
  antes = j.saldo
  jogar(p, 1, cartaTeste({
    chanceSucesso = 0, dinheiroEm = "invocador",
    alteracaoSaldoBase = 100, alteracaoSaldoFalha = -30,
  }))
  check(j.saldo == antes - 30, "falha continua com a penalidade cheia (-30)")
end

local function testarProdutividade()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  check(j.produtividade == 0, "produtividade comeca em 0")

  jogo.alterarProdutividade(p, 1, 0.10)
  check(math.abs(j.produtividade - 0.10) < 1e-9, "+10% de produtividade")
  jogo.alterarProdutividade(p, 1, -5)
  check(j.produtividade == -1, "piso em -100% (nao la embaixo)")

  local antes = j.saldo
  local r = jogo.aplicarRendaRodada(p, 1)
  check(r.rendas[1] == 0, "com -100% a renda vira 0")
  check(j.saldo == antes, "nada creditado com produtividade minima")

  j.produtividade = 0.5
  antes = j.saldo
  r = jogo.aplicarRendaRodada(p, 2)
  check(r.rendas[1] == 1650,
    "renda da rodada 2 (1100) com +50% = 1650 (" .. r.rendas[1] .. ")")
  check(j.saldo == antes + 1650, "renda ajustada creditada")

  -- Cartas aplicam Satisfacao/Produtividade declarados na propria carta.
  j.produtividade = 0
  j.satisfacao = 100
  jogar(p, 1, cartaTeste({
    chanceSucesso = 1, dinheiroEm = "invocador", alteracaoSaldoBase = 0,
    satisfacao = { valor = 25, alvo = "invocador" },
    produtividade = { valor = 0.20, alvo = "invocador" },
  }))
  check(j.satisfacao == 125, "carta aplicou +25 de Satisfacao")
  check(math.abs(j.produtividade - 0.20) < 1e-9,
    "carta aplicou +20% de Produtividade")
end

local function testarFusao()
  local p = jogo.criarPartida()
  local j = p.jogadores[1]
  check(#j.mao >= 2, "mao com cartas para fundir")

  local antes = #j.mao
  local uids = { j.mao[1].uid, j.mao[2].uid }
  local super = jogo.executarFusao(p, 1, uids)
  check(super ~= nil, "fusao de 2 cartas cria uma Super Carta")
  check(super.classe == "Super" and super.super == true, "resultado e Super Carta")
  check(super.id >= 100, "Super Carta usa id proprio")
  check(#j.mao == antes - 1, "2 cartas viram 1 na mao")
  check(#p.pilhaDescarte >= 2, "cartas fundidas foram para o descarte")

  check(jogo.executarFusao(p, 1, { j.mao[1].uid }) == nil,
    "1 carta nao funde")
  check(jogo.executarFusao(p, 1, { "uid-x", "uid-y" }) == nil,
    "uid invalido anula a fusao")

  local maoAntes = #j.mao
  local descAntes = #p.pilhaDescarte
  check(jogo.executarFusao(p, 1, { j.mao[1].uid, "uid-x" }) == nil,
    "um uid invalido anula a fusao inteira")
  check(#j.mao == maoAntes and #p.pilhaDescarte == descAntes,
    "nada foi consumido com uid invalido")

  -- Fusao tambem consome cartas do banco (Area Segura).
  local j2 = p.jogadores[2]
  while #j2.areaSegura < 2 do
    table.insert(j2.areaSegura, table.remove(j2.mao))
  end
  local bancos = { j2.areaSegura[1].uid, j2.areaSegura[2].uid }
  local super2 = jogo.executarFusao(p, 2, bancos)
  check(super2 ~= nil, "fusao consome cartas do banco")
  check(#j2.areaSegura == 0, "banco esvaziado pela fusao")

  -- Inventario de Super Cartas: campos obrigatorios.
  for _, c in ipairs(cartas.SUPER_CARTAS) do
    local copia = cartas.copia(c)
    check(type(copia.chance) == "number", c.nome .. " tem chance")
    check(copia.classe == "Super", c.nome .. " mantem a classe Super")
    check(copia.efeito ~= nil, c.nome .. " tem efeito")
  end
end

local function testarLeilao()
  local p = jogo.criarPartida()
  p.jogadores[2].isIA = false -- controla os lances da IA no teste
  local l = jogo.iniciarLeilao(p)
  -- V7 5.7: produto UNICO (1 carta, ou kit de 2/3), com um lance por jogador.
  check(#l.cartas >= 1 and #l.cartas <= 3,
    "leilao oferece um produto de 1 a 3 cartas (" .. #l.cartas .. ")")
  check(l.kit == (#l.cartas > 1), "flag de kit coerente com o produto")
  for _, c in ipairs(l.cartas) do
    check(c.uid ~= nil, "carta do produto tem uid")
    local base = cartas.porId(c.id)
    check(base ~= nil and (base.peso or 0) > 0,
      "leilao so oferece carta do baralho principal: " .. tostring(c.nome))
  end
  check(l.rodada == 1 and not l.resolvido, "leilao da rodada 1 aberto")
  check(p.eventoMeta == true, "durante o evento o teto de 10 cartas e excedivel")
  check(p.curingaGlobal and p.curingaGlobal.carta, "Curinga global sorteado antes do leilao")
  check(#p.pilhaCuringa == 1 and p.pilhaCuringa[1].uid == p.curingaGlobal.carta.uid,
    "Pilha de Curinga mostra o global ativo")

  -- Um lance unico por jogador, em passos de R$ 100.
  check(jogo.definirLance(p, 1, nil, 100) == true, "humano define o lance")
  check(l.lances[1] == 100, "lance do humano = 100")
  jogo.definirLance(p, 1, nil, -50)
  check(l.lances[1] == 0, "lance negativo vira 0")
  jogo.definirLance(p, 1, nil, 100)
  l.lances[2] = 300
  local s1, s2 = p.jogadores[1].saldo, p.jogadores[2].saldo
  local m1, m2 = #p.jogadores[1].mao, #p.jogadores[2].mao
  jogo.resolverLeilao(p)

  check(l.resolvido, "leilao marcado como resolvido")
  check(l.maior == 300 and l.vencedor == 2, "IA venceu com o maior lance")
  check(#l.resultados == 1, "um unico resultado para o produto inteiro")
  check(l.resultados[1].vencedor == 2 and l.resultados[1].valor == 300,
    "IA pagou o lance unico")
  check(#l.resultados[1].cartas == #l.cartas, "resultado leva o produto inteiro")
  check(p.jogadores[1].saldo == s1, "perdedor nao pagou nada")
  check(p.jogadores[2].saldo == s2 - 300, "IA pagou um lance so")
  check(#p.jogadores[2].mao == m2 + #l.cartas,
    "produto inteiro foi para a mao do vencedor")
  check(#p.jogadores[1].mao == m1, "perdedor nao recebeu cartas")
  check(jogo.definirLance(p, 1, nil, 900) == false,
    "nao aceita lance depois de resolvido")

  -- O global seguinte substitui o anterior (e entra no Visor de Curingas).
  local antigo = p.curingaGlobal.carta.uid
  jogo.aplicarCuringaGlobal(p)
  check(p.curingaGlobal.carta.uid ~= antigo,
    "novo Curinga global substitui o anterior")
  check(#p.pilhaCuringa == 1, "pilha global mantem apenas o Curinga ativo")
  check(#p.curingaHistorico == 1 and p.curingaHistorico[1].uid == antigo,
    "visor de Curingas guarda o ultimo usado")
  for _, j in ipairs(p.jogadores) do
    local n = 0
    for _, e in ipairs(j.efeitos) do
      if e.globalCuringa then n = n + 1 end
    end
    check(n <= 1, "no maximo um efeito global por jogador (" .. n .. ")")
  end
end

local function testarLojinha()
  local p = jogo.criarPartida()
  p.jogadores[2].isIA = false
  local loja = jogo.iniciarLojinha(p)
  check(#loja.cartas == 3, "lojinha oferece 3 cartas")
  check(not loja.resolvido, "lojinha aberta")
  local item = loja.cartas[1]
  check(item.preco >= 100 and item.preco <= 500,
    "preco entre 100 e 500 (" .. item.preco .. ")")
  local saldo = p.jogadores[1].saldo
  local mao = #p.jogadores[1].mao
  check(jogo.comprarLojinha(p, 1, item.carta.uid) == true,
    "jogador compra uma carta")
  check(p.jogadores[1].saldo == saldo - item.preco, "preco debitado")
  check(item.vendida and item.comprador == 1, "item marcado como vendido")
  check(#p.jogadores[1].mao == mao + 1, "carta comprada entra na mao")
  check(jogo.comprarLojinha(p, 1, item.carta.uid) == false,
    "item nao pode ser comprado duas vezes")

  jogo.fecharLojinha(p)
  check(loja.resolvido, "lojinha fecha")
end

-- Simulacao all-IA: o assento 1 (normalmente humano) tambem participa dos
-- meta-eventos. O teste troca love.math.random por valores fixos para nao
-- depender de sorte.
local function testarSimulacaoMeta()
  local p = jogo.criarPartida()
  p.simulacao = true
  for _, j in ipairs(p.jogadores) do j.isIA = true end
  local rnd = love.math.random
  love.math.random = function(a, b)
    if a == 0 and b == 8 then return 5 end
    if a == nil and b == nil then return 0.1 end
    return rnd(a, b)
  end

  -- Leilao: random(0, passos) devolve 5 -> lance de 500 do assento 1.
  local l = jogo.iniciarLeilao(p)
  check(l.lances[1] == 500, "sim: assento 1 lanca sozinho (="
    .. tostring(l.lances[1]) .. ")")

  -- Lojinha: a IA do assento 1 compra os itens que couberem no saldo.
  local loja = jogo.iniciarLojinha(p)
  local comprados = 0
  for _, item in ipairs(loja.cartas) do
    if item.comprador == 1 then comprados = comprados + 1 end
  end
  check(comprados > 0, "sim: assento 1 compra na lojinha")

  -- Fusao: a IA do assento 1 funde cartas da propria mao.
  p.jogadores[2].isIA = false
  p.fusao = nil
  jogo.iniciarFusao(p)
  local antes = #p.jogadores[1].mao
  jogo.iaFusao(p)
  local super = false
  for _, c in ipairs(p.jogadores[1].mao) do
    if c.id and c.id >= 100 then super = true end
  end
  check(super and #p.jogadores[1].mao < antes,
    "sim: assento 1 funde e recebe Super Carta")

  love.math.random = rnd
end

local function testarMetaPendente()
  local p = jogo.criarPartida()
  p.vez = 1
  jogo.encerrarVez(p)
  jogo.encerrarVez(p)
  check(p.metaPendente == nil, "rodada 1 nao abre leilao/lojinha")
  p.vez = 1
  jogo.encerrarVez(p)
  jogo.encerrarVez(p)
  check(p.metaPendente == "leilao", "rodada 2 abre leilao")
  check(p.metaRodada == 2, "meta lembra a rodada concluida")
end

local function testarFimPorTempo()
  local p = jogo.criarPartida()
  p.turno = 11
  p.jogadores[1].saldo = 1200
  p.jogadores[2].saldo = 900
  jogo.verificarFim(p)
  check(p.fim == true, "fim apos o turno 11")
  check(p.vencedor == p.jogadores[1], "maior saldo vence")
  check(p.motivo == "Vitoria por Tempo: Maior saldo!", "motivo = " .. tostring(p.motivo))
end

-- Saida em partida: quem ja SAIU e pulado na passagem de turno (e some da
-- arena); falido (eliminado mas na sala) mantem o circuito normal.
local function testarVezPulaSaiu()
  local p = jogo.criarPartida({ n = 4, nomes = { "A", "B", "C", "D" } })
  p.jogadores[2].saiu = true
  p.jogadores[2].falido = true

  p.vez = 1
  jogo.encerrarVez(p)
  check(p.vez == 3, "encerrarVez pula quem saiu (1 -> 3) = " .. tostring(p.vez))

  p.vez = 3
  jogo.encerrarVez(p)
  check(p.vez == 4, "encerrarVez avanca normal (3 -> 4) = " .. tostring(p.vez))

  p.vez = 4
  local turnoAntes = p.turno
  jogo.encerrarVez(p)
  check(p.vez == 1 and p.turno == turnoAntes + 1,
    "wrap com saiu no meio (4 -> 1, turno+1) = " .. tostring(p.vez) ..
    "/" .. tostring(p.turno))

  -- A partir do proprio seat que saiu nao trava nem devolve o mesmo.
  p.vez = 2
  jogo.avancarVez(p)
  check(p.vez == 3, "avancarVez saindo do seat que saiu = " .. tostring(p.vez))

  -- Saida de todos os adversarios: ultimo vivo vence por eliminacao.
  p.jogadores[3].saiu = true
  p.jogadores[3].falido = true
  p.jogadores[4].saiu = true
  p.jogadores[4].falido = true
  jogo.verificarFim(p)
  check(p.fim == true and p.vencedor == p.jogadores[1],
    "adversarios todos saiu -> host vence por eliminacao")
end

-- ARENA N jogadores (ArenaMultiplayer.js): criacao, alvos, fim e IA por vez.
local function testarArenaN()
  local p = jogo.criarPartida({ n = 8 })
  check(#p.jogadores == 8, "arena: partida com 8 jogadores")
  check(p.vez >= 1 and p.vez <= 8, "arena: vez sorteada em 1..8 (" .. p.vez .. ")")
  local okMao, okIA = true, true
  for i, j in ipairs(p.jogadores) do
    if #j.mao ~= 7 then okMao = false end
    if j.isIA ~= (i > 1) then okIA = false end
  end
  check(okMao, "arena: mao inicial de 7 em todos os 8")
  check(okIA, "arena: so o seat 1 e humano (isIA = i > 1)")
  check(p.jogadores[1].nome == "JOGADOR_1", "arena: seat 1 com nome padrao")
  check(p.jogadores[2].nome == "ROBO", "arena: nome do seat 2 = " .. p.jogadores[2].nome)
  check(p.jogadores[8].nome == "RAIO", "arena: nome do seat 8 = " .. p.jogadores[8].nome)
  check(p.jogadores[2].avatar == nil, "arena: avatar so quando informado")

  local pc = jogo.criarPartida({
    n = 3, nomes = { "EU", "A", "B" }, avatares = { "4", "5", "6" },
  })
  check(pc.jogadores[1].nome == "EU" and pc.jogadores[3].nome == "B",
    "arena: nomes customizados")
  check(pc.jogadores[2].avatar == "5" and pc.jogadores[3].avatar == "6",
    "arena: avatares customizados")

  -- sortearAlvo: sempre oponente vivo, nunca o proprio.
  local p3 = jogo.criarPartida({ n = 4 })
  local okSortear, visto = true, {}
  for _ = 1, 60 do
    local a = jogo.sortearAlvo(p3, 1)
    if not a or a == 1 then okSortear = false end
    visto[a] = true
  end
  check(okSortear, "sortearAlvo devolve sempre um oponente")
  check(visto[2] and visto[3] and visto[4], "sortearAlvo cobre todos os oponentes")
  p3.jogadores[2].falido = true
  p3.jogadores[3].falido = true
  p3.jogadores[4].falido = true
  check(jogo.sortearAlvo(p3, 1) == nil, "sortearAlvo nil quando todos faliram")
  -- Seat 2 tambem esta falido, mas o seat 1 continua vivo: alvo valido.
  check(jogo.sortearAlvo(p3, 2) == 1, "sortearAlvo acha o unico vivo restante")

  -- jogadaIA: age na vez indicada e devolve nil para falido/sem mao.
  local p4 = jogo.criarPartida({ n = 5 })
  local idx4 = jogo.jogadaIA(p4, 4)
  check(idx4 ~= nil and idx4 >= 1 and idx4 <= #p4.jogadores[4].mao,
    "jogadaIA do seat 4 devolve indice valido")
  p4.jogadores[3].falido = true
  check(jogo.jogadaIA(p4, 3) == nil, "jogadaIA de falido = nil")

  -- aplicarCarta com alvo aleatorio: nunca a si mesmo nem a falido.
  local p5 = jogo.criarPartida({ n = 6 })
  p5.jogadores[3].falido = true
  local okAlvo, achou = true, {}
  for _ = 1, 60 do
    local a = jogo.sortearAlvo(p5, 1)
    if not a or a == 1 or a == 3 then okAlvo = false end
    achou[a] = true
  end
  check(okAlvo, "alvo vivo exclui self e falido")
  check(achou[2] and achou[4] and achou[5] and achou[6],
    "alvo vivo cobre os 4 oponentes restantes")

  -- aplicarCarta com alvo escolhido pelo jogador (clique na area de alvo):
  -- o indice numerico explicito vale, sem sortear outro oponente.
  local pAlvo = jogo.criarPartida()
  local cAlvo = cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "alvo",
    alteracaoSaldoBase = -100, alteracaoSaldoFalha = 0,
  })
  pAlvo.jogadores[2].saldo = 1000
  local resAlvo = jogo.aplicarCarta(pAlvo, 1, cAlvo, { alvoIdx = 2 })
  check(resAlvo and resAlvo.sucesso, "alvo explicito: carta aplicada")
  check(pAlvo.jogadores[2].saldo == 900,
    "alvo explicito do clique atinge o oponente escolhido")

  -- Area de confirmacao por clique: cartas com alvo usam o tipo; sem alvo
  -- usam o descarte como area generica de "usar carta".
  check(ui.areaDaCarta({ precisaAlvo = true, alvoTexto = "Oponente" }) == "oponente",
    "areaDaCarta: oponente")
  check(ui.areaDaCarta({ precisaAlvo = true, alvoTexto = "Todos" }) == "todos",
    "areaDaCarta: todos")
  check(ui.areaDaCarta({ precisaAlvo = false, alvoTexto = "Voce" }) == "descarte",
    "areaDaCarta: sem alvo usa o descarte")
  check(ui.areaDaCarta(nil) == "descarte", "areaDaCarta: carta nil nao crasha")
  check(ui.alvoTipoNome("descarte") == "USAR CARTA (DESCARTE)",
    "alvoTipoNome: descarte")
  check(ui.alvoIdxDeTipo("descarte") == nil, "alvoIdxDeTipo: descarte sem indice")

  -- Fim por eliminacao com 4 jogadores: o ultimo vivo vence.
  local p6 = jogo.criarPartida({ n = 4 })
  p6.jogadores[2].falido = true
  p6.jogadores[3].falido = true
  p6.jogadores[4].falido = true
  jogo.verificarFim(p6)
  check(p6.fim and p6.vencedor == p6.jogadores[1], "4p: ultimo vivo vence")
  check(p6.motivo == "Vitoria por Eliminacao!", "4p: motivo eliminacao")

  -- Empate geral no modo N.
  local p7 = jogo.criarPartida({ n = 3 })
  p7.jogadores[1].falido = true
  p7.jogadores[2].falido = true
  p7.jogadores[3].falido = true
  jogo.verificarFim(p7)
  check(p7.vencedor.empate == true, "3p: empate quando todos faliram")
  check(p7.motivo == "Empate: Todos faliram!", "3p: motivo empate geral = " .. p7.motivo)

  -- Fim por tempo: maior saldo e empate no topo.
  local p8 = jogo.criarPartida({ n = 4 })
  p8.turno = 11
  p8.jogadores[1].saldo = 900
  p8.jogadores[2].saldo = 1200
  p8.jogadores[3].saldo = 700
  p8.jogadores[4].saldo = 500
  jogo.verificarFim(p8)
  check(p8.vencedor == p8.jogadores[2], "4p: maior saldo vence no tempo")
  check(p8.motivo == "Vitoria por Tempo: Maior saldo!", "4p: motivo tempo")

  local p9 = jogo.criarPartida({ n = 3 })
  p9.turno = 11
  p9.jogadores[1].saldo = 900
  p9.jogadores[2].saldo = 900
  p9.jogadores[3].saldo = 700
  jogo.verificarFim(p9)
  check(p9.vencedor.empate == true, "3p: empate quando o topo empata")
  check(p9.motivo == "Empate: 2 jogadores com mesmo saldo!",
    "3p: motivo empate no topo = " .. p9.motivo)

  -- Layout da arena (so desenho): de 3 a 8 jogadores nao se sobrepoem.
  for _, nOpo in ipairs({ 2, 3, 4, 5, 6, 7 }) do
    local seats = layout.assentos(nOpo, 1280, 720)
    check(#seats == nOpo, "layout: " .. nOpo .. " oponentes posicionados")
    local livre, dentroTela = true, true
    for i, a in ipairs(seats) do
      if a.x < 0 or a.y < 0 or a.x + a.w > 1280 or a.y + a.h > 720 then
        dentroTela = false
      end
      for j = i + 1, #seats do
        local b = seats[j]
        if a.x < b.x + b.w and a.x + a.w > b.x
            and a.y < b.y + b.h and a.y + a.h > b.y then
          livre = false
        end
      end
    end
    check(livre, "layout: painéis nao se sobrepoem com " .. nOpo .. " oponentes")
    check(dentroTela, "layout: painéis dentro da tela com " .. nOpo .. " oponentes")
    local ar = layout.arena(nOpo, 1280, 720)
    check(ar.r > 0 and ar.r <= ui.E(140) / 2,
      "layout: arena reduzida com " .. nOpo .. " oponentes (r=" .. math.floor(ar.r) .. ")")
  end
end

-- Partida completa com N jogadores (IA em todas as seats > 1).
local function rodarPartidaSimuladaN(n)
  local p = jogo.criarPartida({ n = n })
  local passos = 0
  while not p.fim and passos < 2000 do
    passos = passos + 1
    local vez = p.vez
    local j = p.jogadores[vez]
    local escolha = nil

    if j.isIA then
      escolha = jogo.jogadaIA(p, vez)
    else
      if #j.mao > 0 and love.math.random(100) <= 75 then
        escolha = love.math.random(#j.mao)
      end
    end

    if not escolha then
      jogo.passar(p, vez)
    else
      local carta = table.remove(j.mao, escolha)
      local res = jogo.aplicarCarta(p, vez, carta)
      if res.consumiuTurno then
        jogo.encerrarVez(p)
      end
    end
  end
  return p, passos
end

local function testarPartidasCompletasN()
  for _, n in ipairs({ 3, 5, 8 }) do
    for i = 1, 5 do
      local p, passos = rodarPartidaSimuladaN(n)
      check(p.fim, n .. " jogadores: partida " .. i .. " terminou (" .. passos .. " passos)")
      check(p.vencedor ~= nil, n .. "p " .. i .. ": tem vencedor/empate")
      check(p.motivo ~= nil, n .. "p " .. i .. ": tem motivo")
      check(p.vez >= 1 and p.vez <= n, n .. "p " .. i .. ": vez coerente (" .. p.vez .. ")")
      check(p.turno <= 11, n .. "p " .. i .. ": turno coerente (" .. p.turno .. ")")
      local okMao = true
      for _, j in ipairs(p.jogadores) do
        if #j.mao > 9 then okMao = false end
      end
      check(okMao, n .. "p " .. i .. ": mao nunca passa de 9")
    end
  end
end

-- Painel da ARENA (ModalSelecionarJogadores.js): linhas 2..8 e CANCELAR.
local function testarArenaMenu()
  arenaMenu.iniciar()
  check(arenaMenu.clicado(4, 4) == "fechar", "painel ARENA: clique fora fecha")
  local todos = true
  for n = 2, 8 do
    local r = arenaMenu.rectLinha(n)
    if not r or r.w <= 0 or r.h <= 0 then todos = false end
    arenaMenu.iniciar()
    if arenaMenu.clicado(r.x + r.w / 2, r.y + r.h / 2) ~= n then
      todos = false
      print("[FALHOU] painel ARENA: linha " .. n .. " nao devolveu " .. n)
    end
  end
  check(todos, "painel ARENA: as 7 linhas (2..8) respondem ao clique")
  local rc = arenaMenu.rectCancelar()
  check(rc and rc.w > 0 and rc.h > 0, "painel ARENA: CANCELAR existe")
  arenaMenu.iniciar()
  check(arenaMenu.clicado(rc.x + rc.w / 2, rc.y + rc.h / 2) == "fechar",
    "painel ARENA: CANCELAR fecha")

  -- Linhas nao se sobreporem (clique no meio de uma nao pode pegar outra).
  local semSobreposicao = true
  for n = 2, 7 do
    local a, b = arenaMenu.rectLinha(n), arenaMenu.rectLinha(n + 1)
    if a.y + a.h > b.y then semSobreposicao = false end
  end
  check(semSobreposicao, "painel ARENA: linhas sem sobreposicao")
  local r8 = arenaMenu.rectLinha(8)
  local g = arenaMenu.rectCancelar()
  check(r8.y + r8.h <= g.y, "painel ARENA: lista cabe acima do CANCELAR")
end

local function testarAnim()
  anim.limpar()
  local alvo = { x = 0, y = 0 }
  local chamou = false
  anim.tween(alvo, { x = 100 }, 0.5, anim.linear, function() chamou = true end)
  check(anim.ativo(), "tween registrado")
  for _ = 1, 70 do anim.update(1 / 60) end
  check(alvo.x == 100, "tween chegou ao destino (" .. tostring(alvo.x) .. ")")
  check(chamou, "callback do tween chamado")
  check(not anim.ativo(), "tween removido ao terminar")
  anim.limpar()
end

local function rodarPartidaSimulada()
  local p = jogo.criarPartida()
  local passos = 0
  while not p.fim and passos < 800 do
    passos = passos + 1
    local vez = p.vez
    local j = p.jogadores[vez]
    local escolha = nil

    if vez == 2 then
      escolha = jogo.jogadaIA(p)
    else
      if #j.mao > 0 and love.math.random(100) <= 75 then
        escolha = love.math.random(#j.mao)
      end
    end

    if not escolha then
      jogo.passar(p, vez)
    else
      local carta = table.remove(j.mao, escolha)
      local res = jogo.aplicarCarta(p, vez, carta)
      if res.consumiuTurno then
        jogo.encerrarVez(p)
      end
    end
  end
  return p, passos
end

local function testarPartidasCompletas()
  for i = 1, 60 do
    local p, passos = rodarPartidaSimulada()
    check(p.fim, "partida " .. i .. " terminou (" .. passos .. " passos)")
    check(passos < 800, "partida " .. i .. " nao travou")
    if p.fim then
      check(p.vencedor ~= nil, "partida " .. i .. " tem vencedor definido")
      check(p.motivo ~= nil, "partida " .. i .. " tem motivo")
      check(p.turno <= 11, "partida " .. i .. " turno coerente (" .. p.turno .. ")")
      check(p.jogadasTurno >= 0 and p.jogadasTurno < jogo.CARTAS_POR_TURNO,
        "partida " .. i .. " quota apos fim = " .. p.jogadasTurno)
      check(#p.pilhaDescarte > 0, "partida " .. i .. " teve cartas descartadas")
      for _, j in ipairs(p.jogadores) do
        -- Manual V7 4.4: maximo de 10 cartas por jogador (7 mao + 3 banco),
        -- contado sobre o TOTAL. Exceder so vale durante o evento do Deus
        -- Mercado, que nao roda nesta simulacao.
        check(#j.mao + #j.areaSegura <= 10,
          "total de cartas nunca passa de 10 (" ..
          (#j.mao + #j.areaSegura) .. ")")
        check(#j.areaSegura <= jogo.AREA_SEGURA_MAX,
          "banco (Area Segura) com no maximo " .. jogo.AREA_SEGURA_MAX)
        check(j.falido == (j.status == jogo.STATUS.ELIMINADO),
          "status coerente com falencia (" .. j.status .. ")")
      end
    end
  end
end

-- Tela PERFIL (TelaPerfil.js + mockup de 4 abas): nick + avatar + emotes
-- equipados (max 4) numa tela so, com a NAV BAR da esquerda (botoes de arte
-- pronta, verde na aba ativa) trocando RESUMO / AVATARES / EMOTES / CARTAS;
-- maxLength 20 no nick; grade de avatares em 5 colunas e a de emotes em 6.
local function testarPerfil()
  perfilMod.iniciar()
  local pe = perfilMod.estado()
  check(pe.nick == "JOGADOR_1", "perfil nick padrao = " .. pe.nick)
  check(pe.avatarId == "1", "perfil avatar padrao = " .. pe.avatarId)

  -- Emojis: 4 iniciais equipados por padrao (independe de inventario).
  local eq = perfilMod.emojis()
  check(#eq == 4 and eq[1] == 1 and eq[4] == 4,
    "perfil: 4 emojis iniciais equipados = " .. table.concat(eq, ","))
  check(perfilMod.equipado(1) and perfilMod.equipado(4),
    "perfil: iniciais nascem equipados")
  -- Abre no RESUMO e as grades so existem na aba delas.
  check(perfilMod.abaAtual() == "resumo", "perfil abre na aba RESUMO")
  check(perfilMod.rectAvatar(1) == nil and perfilMod.rectEmoji(1) == nil,
    "grades nao aparecem no RESUMO")
  perfilMod.mudarAba("emotes")
  check(perfilMod.abaAtual() == "emotes", "mudarAba('emotes') vai para EMOTES")
  check(perfilMod.rectEmoji(1) and perfilMod.rectEmoji(4).codigo == 4,
    "aba EMOTES: 4 itens na grade")
  check(perfilMod.rectEmoji(5) == nil,
    "aba EMOTES: sem o Marx comprado nao tem 5o item")
  -- Sem Marx comprado, o codigo 5 nao entra nem desequipa os iniciais.
  check(perfilMod.alternarEmoji(5) == false, "emoji 5 fora da grade e recusado")
  check(#perfilMod.emojis() == 4, "recusa do 5 nao mexeu na lista")
  -- Desquipar e re-equipar os iniciais; teto de 4 nunca estoura.
  check(perfilMod.alternarEmoji(1) == true, "desquipar o inicial 1")
  check(not perfilMod.equipado(1), "inicial 1 saiu da lista")
  check(perfilMod.alternarEmoji(1) == true, "re-equipar o inicial 1")
  check(#perfilMod.emojis() == 4, "lista de volta no teto de 4")
  -- Confirmar devolve os emojis junto do nick/avatar.
  local pc0 = perfilMod.confirmar()
  check(type(pc0.emojis) == "table" and #pc0.emojis == 4,
    "confirmar devolve os 4 emojis equipados")
  -- Lista corrompida cai no default; lista vazia (desquipou tudo) fica vazia.
  perfilMod.iniciar({ nick = "X", avatar = "1", emojis = { 99, 1, 1, "z", 2 } })
  local eqSaneado = perfilMod.emojis()
  check(#eqSaneado == 2 and eqSaneado[1] == 1 and eqSaneado[2] == 2,
    "emojis saneados: so possuidos, sem repetir = " .. table.concat(eqSaneado, ","))
  perfilMod.iniciar({ nick = "X", avatar = "1", emojis = {} })
  check(#perfilMod.emojis() == 0, "lista vazia explicita fica vazia")
  perfilMod.iniciar()

  local rC = perfilMod.rectConfirmar()
  check(rC and rC.w > 0 and rC.h > 0, "layout do perfil calculado")
  local rVolt = perfilMod.rectVoltar()
  check(rVolt and rVolt.w > 0 and rVolt.h > 0, "rodape do perfil tem VOLTAR")

  -- NAV BAR: os 4 botoes sao ARTE PRONTA (385x190, com icone e rotulo
  -- embutidos; "_sel" e a verde da aba ativa), entao o retangulo precisa
  -- manter a proporcao do PNG para a arte nao esticar. A nav fica na coluna
  -- da esquerda, a esquerda do conteudo e antes do CONFIRMAR do rodape.
  check(arte.img("btn_perfil_resumo") and arte.img("btn_perfil_avatares")
    and arte.img("btn_perfil_emotes") and arte.img("btn_perfil_cartas"),
    "botoes da nav bar do perfil carregados (versao normal)")
  check(arte.img("btn_perfil_resumo_sel") and arte.img("btn_perfil_cartas_sel"),
    "botoes verdes da aba ativa carregados")
  local rAbas = {}
  local NOMES_ABA = { "resumo", "avatares", "emotes", "cartas" }
  for i, nome in ipairs(NOMES_ABA) do
    rAbas[i] = perfilMod.rectAba(nome)
    check(rAbas[i] and rAbas[i].w > 0 and rAbas[i].h > 0,
      "botao da nav bar '" .. nome .. "' desenhado")
    check(math.abs(rAbas[i].w / rAbas[i].h - 385 / 190) < 0.01,
      "botao '" .. nome .. "' na proporcao da arte (sem esticar)")
  end
  check(rAbas[1].y < rAbas[2].y and rAbas[2].y < rAbas[3].y
    and rAbas[3].y < rAbas[4].y, "abas empilhadas de cima para baixo")
  check(math.abs(rAbas[1].x - rAbas[4].x) < 0.01
    and math.abs(rAbas[1].w - rAbas[4].w) < 0.01,
    "botoes da nav bar alinhados na mesma coluna")
  check(rAbas[1].x < rC.x, "nav bar antes do botao CONFIRMAR")
  check(perfilMod.rectAba("nao_existe") == nil,
    "rectAba de aba desconhecida = nil")
  local abaAntes = perfilMod.abaAtual()
  perfilMod.mudarAba("nao_existe")
  check(perfilMod.abaAtual() == abaAntes,
    "aba desconhecida nao troca a aba atual")

  -- RESUMO: sem as grades e sem a seta de "voltar ao resumo".
  perfilMod.mudarAba("resumo")
  check(perfilMod.abaAtual() == "resumo", "mudarAba('resumo') volta ao RESUMO")
  check(perfilMod.rectVoltarAba() == nil,
    "RESUMO nao mostra a seta de voltar ao resumo")

  -- AVATARES: grade dos 8 base em 6 colunas (item 8 na 2a linha) e a nav
  -- bar a esquerda do conteudo da aba.
  perfilMod.mudarAba("avatares")
  check(perfilMod.rectVoltarAba() ~= nil,
    "abas fora do RESUMO tem a seta de voltar")
  check(perfilMod.rectAvatar(1).x >= rAbas[1].x + rAbas[1].w,
    "nav bar fica a esquerda do conteudo da aba")
  local rI = perfilMod.rectAvatar(8)
  check(rI and rI.y > perfilMod.rectAvatar(6).y,
    "aba AVATARES: item 8 na segunda linha")
  check(perfilMod.rectAvatar(2).x > perfilMod.rectAvatar(1).x
    and math.abs(perfilMod.rectAvatar(2).y - perfilMod.rectAvatar(1).y) < 0.01
    and math.abs(perfilMod.rectAvatar(6).y - perfilMod.rectAvatar(1).y) < 0.01,
    "aba AVATARES: grade em 6 colunas (1..6 na mesma linha)")
  check(perfilMod.rectAvatar(9) == nil, "aba AVATARES: sem comprados sao 8 itens")

  -- FICHA do avatar selecionado, na base da aba: os padroes nao tem
  -- habilidade nem descricao; os da loja trazem as duas (mesmos textos da
  -- loja) e a grade tem de terminar acima dela.
  local rFicha = perfilMod.rectFicha()
  check(rFicha and rFicha.w > 0 and rFicha.h > 0, "aba AVATARES tem a ficha")
  local nAv = 0
  while perfilMod.rectAvatar(nAv + 1) do nAv = nAv + 1 end
  local rUlt = perfilMod.rectAvatar(nAv)
  check(rUlt.y + rUlt.h <= rFicha.y,
    "grade de avatares termina acima da ficha")
  check(rFicha.x >= perfilMod.rectAvatar(1).x
    and rFicha.x + rFicha.w >= rUlt.x + rUlt.w,
    "ficha cobre a largura da grade de avatares")
  perfilMod.selecionar("3")
  local f3 = perfilMod.fichaInfo()
  check(f3.nome == "AVATAR PADRAO" and f3.hab == nil and f3.desc == nil,
    "ficha do avatar padrao sem habilidade e sem descricao")
  inventario.conceder("taylor")
  perfilMod.iniciar()
  perfilMod.mudarAba("avatares")
  perfilMod.selecionar("taylor")
  local ft = perfilMod.fichaInfo()
  check(ft.nome == "FREDERICK TAYLOR" and ft.hab == "+10% DE CHANCE EM ACAO E EFEITO"
    and ft.desc and #ft.desc > 60,
    "ficha do taylor com habilidade e descricao")
  inventario.limpar()
  perfilMod.iniciar()
  perfilMod.mudarAba("avatares")
  check(perfilMod.fichaInfo().nome == "AVATAR PADRAO",
    "sem posse, a ficha volta ao padrao")

  -- EMOTES: grade em 6 colunas dos 4 iniciais.
  perfilMod.mudarAba("emotes")
  local rE1, rE2, rE3, rE4 = perfilMod.rectEmoji(1), perfilMod.rectEmoji(2),
    perfilMod.rectEmoji(3), perfilMod.rectEmoji(4)
  check(rE1 and rE4, "aba EMOTES: grade calculada")
  check(rE2.x > rE1.x and math.abs(rE2.y - rE1.y) < 0.01,
    "emotes em 6 colunas: item 2 a direita do 1")
  check(rE3.x > rE2.x and rE4.x > rE3.x
    and math.abs(rE4.y - rE1.y) < 0.01,
    "emotes em 6 colunas: itens 1..4 na mesma fileira")

  -- CARTAS: so o desenho — sem inventario de cartas ainda, nenhuma grade
  -- clicavel (nem avatares/emotes aparecem aqui).
  perfilMod.mudarAba("cartas")
  check(perfilMod.rectAvatar(1) == nil and perfilMod.rectEmoji(1) == nil,
    "aba CARTAS sem as grades de avatares/emotes")
  check(perfilMod.rectVoltarAba() ~= nil,
    "aba CARTAS tem a seta de voltar ao resumo")

  -- Comprar os emotes da loja so ACRESCENTA itens na aba EMOTES.
  inventario.conceder("karl_marx")
  inventario.conceder("adam_smith")
  perfilMod.iniciar()
  check(perfilMod.abaAtual() == "resumo",
    "reabrir o perfil volta para o RESUMO")
  perfilMod.mudarAba("emotes")
  local rE5, rE6 = perfilMod.rectEmoji(5), perfilMod.rectEmoji(6)
  check(rE5 and rE6 and rE5.codigo == 5 and rE6.codigo == 6,
    "aba EMOTES cresce com os comprados")
  check(rE6.y == rE1.y and rE6.x > rE4.x,
    "6 emotes cabem na fileira de 6 colunas")
  inventario.limpar()
  perfilMod.iniciar()

  perfilMod.digitar("abc")
  check(perfilMod.estado().nick == "JOGADOR_1abc",
    "digitar anexa preservando maiusculas/minusculas = " .. perfilMod.estado().nick)
  perfilMod.digitar("Xy")
  check(perfilMod.estado().nick == "JOGADOR_1abcXy",
    "digitar mistura casos = " .. perfilMod.estado().nick)
  for _ = 1, 40 do perfilMod.digitar("X") end
  check(#perfilMod.estado().nick == 20,
    "nick respeita maxLength 20 = " .. #perfilMod.estado().nick)
  perfilMod.apagar()
  check(#perfilMod.estado().nick == 19, "backspace apaga 1 caractere")

  perfilMod.iniciar({ nick = "", avatar = "9" })
  pe = perfilMod.estado()
  check(pe.nick == "JOGADOR_1", "nick vazio vira padrao = " .. pe.nick)
  check(pe.avatarId == "1", "avatar invalido vira padrao = " .. pe.avatarId)

  perfilMod.selecionar("5")
  check(perfilMod.selecionado() == "5", "selecionar avatar 5")
  perfilMod.selecionar("99")
  check(perfilMod.selecionado() == "1", "avatar inexistente cai no padrao")

  local pc = perfilMod.confirmar()
  check(pc.nick == "JOGADOR_1" and pc.avatar == "1",
    "confirmar devolve {nick, avatar}")
  -- Em MODO_TESTE o disco nao e tocado (preserva o perfil real do usuario).
  check(perfilMod.salvar({ nick = "TESTE", avatar = "5" }) == true,
    "salvar nao lanca excecao")
  local carregado = perfilMod.carregar()
  check(carregado.nick == "JOGADOR_1" and carregado.avatar == "1",
    "carregar padrao em modo teste")
  check(type(carregado.emojis) == "table" and #carregado.emojis == 4,
    "carregar padrao traz os 4 emojis")
end

-- Loja: compra dos avatares Frederick Taylor e Karl Marx (100 cada),
-- recusas (sem saldo / recompra), posse no inventario e a grade do
-- perfil crescendo com a compra. Tudo em memoria (MODO_TESTE nao toca
-- o disco) e restaurado no fim para nao vazar para os demais testes.
local function testarComprasAvatares()
  inventario.limpar()
  dinheiro.carregar()
  local ps = inventario.produtos()
  check(#ps == 3, "loja: tres avatares a venda")
  check(ps[1].id == "taylor" and ps[2].id == "marx" and ps[3].id == "mayo",
    "loja: ordem taylor, marx, mayo")
  check(ps[1].preco == 100 and ps[2].preco == 100 and ps[3].preco == 100,
    "loja: preco 100")
  check(not inventario.temAvatar("taylor"), "inventario: taylor comeca fora")
  check(not inventario.temAvatar("mayo"), "inventario: mayo comeca fora")

  dinheiro.ganhar(150)
  check(inventario.comprar("marx") == true, "compra do Marx autorizada")
  check(dinheiro.valor() == 50, "compra do Marx debitou 100")
  check(inventario.temAvatar("marx"), "Marx ficou no inventario")
  check(inventario.comprar("taylor") == false, "taylor sem saldo e recusado")
  check(dinheiro.valor() == 50, "recusa sem saldo nao mexe no dinheiro")
  dinheiro.ganhar(100)
  check(inventario.comprar("taylor") == true, "compra do Taylor autorizada")
  check(dinheiro.valor() == 50, "compra do Taylor debitou 100")
  check(inventario.comprar("marx") == false, "recompra do Marx e recusada")
  check(dinheiro.valor() == 50, "recompra nao mexe no dinheiro")
  dinheiro.ganhar(100)
  check(inventario.comprar("mayo") == true, "compra do Mayo autorizada")
  check(dinheiro.valor() == 50, "compra do Mayo debitou 100")
  check(inventario.temAvatar("mayo"), "Mayo ficou no inventario")
  check(inventario.comprar("mayo") == false, "recompra do Mayo e recusada")
  check(#inventario.avataresComprados() == 3, "inventario lista os tres")

  -- Grade do perfil (aba AVATARES) cresce com a posse e o comprado vira
  -- equipavel.
  perfilMod.iniciar({ nick = "X", avatar = "1" })
  perfilMod.mudarAba("avatares")
  check(perfilMod.rectAvatar(9) and perfilMod.rectAvatar(10)
    and perfilMod.rectAvatar(11),
    "grade do perfil mostrou os avatares comprados")
  check(perfilMod.rectAvatar(10).y > perfilMod.rectAvatar(4).y,
    "item 10 da grade cai numa linha abaixo")
  perfilMod.selecionar("mayo")
  check(perfilMod.selecionado() == "mayo", "mayo equipavel na grade")
  check(perfilMod.confirmar().avatar == "mayo",
    "confirmar leva o avatar comprado")

  -- Sem posse: cai no padrao e some da grade; restaura o resto da suite.
  inventario.limpar()
  perfilMod.iniciar({ nick = "X", avatar = "taylor" })
  check(perfilMod.selecionado() == "1", "avatar sem posse cai no padrao")
  perfilMod.mudarAba("avatares")
  check(perfilMod.rectAvatar(9) == nil, "grade volta para 8 sem posse")
  dinheiro.carregar()
  perfilMod.iniciar()
end

-- Emojis da loja (Karl Marx piscante, codigo 5; Adam Smith facepalm,
-- codigo 6): catalogo proprio (id NUNCA colide com avatar "marx"), compra
-- por 100 cada, posse via temEmoji e a aba EMOTES do perfil crescendo
-- junto das compras.
local function testarCompraEmojiMarx()
  inventario.limpar()
  dinheiro.carregar()
  local pes = inventario.emojisProdutos()
  check(#pes == 2 and pes[1].id == "karl_marx" and pes[1].codigo == 5
    and pes[2].id == "adam_smith" and pes[2].codigo == 6,
    "loja: emojis karl_marx (5) e adam_smith (6) a venda")
  check(pes[1].preco == 100 and pes[2].preco == 100,
    "loja: os dois emojis custam 100")
  check(not inventario.temEmoji("karl_marx")
    and not inventario.temEmoji("adam_smith"), "emojis comecam fora")
  check(#inventario.emojisComprados() == 0, "lista de emojis comeca vazia")
  -- Busca por codigo (balao/seletor): acha os de loja, ignora os vetoriais.
  check(inventario.emojiPorCodigo(5) and inventario.emojiPorCodigo(5).id
    == "karl_marx" and inventario.emojiPorCodigo(6).id == "adam_smith",
    "emojiPorCodigo acha os sprites pelo codigo")
  check(inventario.emojiPorCodigo(1) == nil
    and inventario.emojiPorCodigo(99) == nil,
    "emojiPorCodigo ignora vetoriais e codigos inventados")

  -- O avatar "marx" e o emoji "karl_marx": posse separada.
  dinheiro.ganhar(250)
  check(inventario.comprar("karl_marx") == true, "compra do emoji autorizada")
  check(dinheiro.valor() == 150, "compra do emoji debitou 100")
  check(inventario.temEmoji("karl_marx"), "emoji ficou no inventario")
  check(inventario.comprar("karl_marx") == false, "recompra do emoji recusada")
  check(dinheiro.valor() == 150, "recompra do emoji nao mexe no dinheiro")
  check(not inventario.temAvatar("marx"),
    "emoji karl_marx nao concede o avatar marx")
  -- Adam Smith: mesma curva de compra (independente do Marx).
  check(inventario.comprar("adam_smith") == true,
    "compra do emoji Adam autorizada")
  check(dinheiro.valor() == 50, "compra do Adam debitou 100")
  check(inventario.temEmoji("adam_smith"), "Adam ficou no inventario")
  check(inventario.comprar("adam_smith") == false, "recompra do Adam recusada")
  check(#inventario.emojisComprados() == 2,
    "lista de emojis comprados com os dois")

  -- Perfil: a aba EMOTES cresce para 6 itens; os dois nascem FORA da lista
  -- equipada (os 4 iniciais ja enchem o teto — troca por toque).
  perfilMod.iniciar({ nick = "X", avatar = "1" })
  perfilMod.mudarAba("emotes")
  local r5 = perfilMod.rectEmoji(5)
  check(r5 and r5.codigo == 5, "aba EMOTES: Marx comprado virou 5o item")
  local r6 = perfilMod.rectEmoji(6)
  check(r6 and r6.codigo == 6, "aba EMOTES: Adam comprado virou 6o item")
  check(not perfilMod.equipado(5) and not perfilMod.equipado(6),
    "comprados nascem fora (teto cheio)")
  check(#perfilMod.emojis() == 4, "teto de 4 equipados mantido")
  -- Desquipar um inicial abre vaga; o Adam entra e sai por toque.
  check(perfilMod.alternarEmoji(1) == true, "desquipar inicial abre vaga")
  check(perfilMod.alternarEmoji(6) == true, "equipar o Adam na vaga")
  check(perfilMod.equipado(6) and #perfilMod.emojis() == 4,
    "Adam equipado com a lista no teto")
  check(perfilMod.alternarEmoji(6) == true, "desquipar o Adam")
  check(not perfilMod.equipado(6), "Adam saiu da lista equipada")
  check(perfilMod.alternarEmoji(6) == true, "re-equipar o Adam")
  check(perfilMod.equipado(6) and #perfilMod.emojis() == 4,
    "lista de volta no teto com o Adam")
  -- O slot e trocavel: abre vaga (tira o Adam) e o Marx entra no lugar.
  check(perfilMod.alternarEmoji(6) == true, "troca: Adam desquipado abre vaga")
  check(perfilMod.alternarEmoji(5) == true, "troca: Marx entra na vaga")
  check(perfilMod.equipado(5) and not perfilMod.equipado(6),
    "troca: Adam saiu, Marx ficou")
  check(#perfilMod.emojis() == 4, "troca: lista intacta no teto")

  -- Demonstracao da aba EMOTES: emoji vetorial nao tem animacao (quadro
  -- nil); o sprite da loja anima em LOOP enquanto esta em foco (o tempo
  -- anda no P.atualizar) e refocar o emoji reinicia do primeiro quadro.
  local durAnim = arte.emojiSpriteDur()
  check(durAnim > 0 and arte.emojiSpriteTotal("karl_marx") > 1,
    "sprite do Marx tem varios quadros")
  check(perfilMod.focarEmoji(5), "focar o Marx na demonstracao")
  check(perfilMod.quadroEmote() == 1, "foco comeca no primeiro quadro")
  perfilMod.atualizar(durAnim * 0.5)
  local qMeio = perfilMod.quadroEmote()
  check(qMeio and qMeio > 1, "a animacao avanca de quadro com o tempo")
  perfilMod.atualizar(durAnim * 0.5)
  check(perfilMod.quadroEmote() == 1,
    "a animacao da a volta e retoma do primeiro quadro")
  perfilMod.atualizar(durAnim * 0.3)
  check(perfilMod.quadroEmote() > 1, "animacao segue rodando em loop")
  perfilMod.focarEmoji(5)
  check(perfilMod.quadroEmote() == 1, "refocar o mesmo emoji reinicia")
  check(perfilMod.focarEmoji(1), "focar um emoji vetorial")
  check(perfilMod.quadroEmote() == nil,
    "emoji vetorial (1..4) nao tem animacao na demonstracao")
  check(perfilMod.focarEmoji(99) == false, "foco recusa codigo fora da grade")

  -- Sem posse: os dois somem da grade e volta pra posse vazia.
  inventario.limpar()
  perfilMod.iniciar({ nick = "X", avatar = "1" })
  perfilMod.mudarAba("emotes")
  check(perfilMod.rectEmoji(5) == nil and perfilMod.rectEmoji(6) == nil,
    "emojis sem posse somem da grade")
  check(#perfilMod.emojis() == 4, "sem posse, so os 4 iniciais equipados")
  dinheiro.carregar()
  perfilMod.iniciar()
end

-- Habilidades dos avatares compraveis: Taylor (+10% de chance em
-- ACAO/EFEITO) e Marx (redistribuicao de R$ 100 no inicio do proprio
-- turno; nao redistribui se o de Marx e o mais rico). Multiplayer: cada
-- marx dispara no seu turno; a habilidade atravessa a serializacao.
local function testarHabilidadesAvatar()
  -- Taylor: boost so em ACAO/EFEITO e so para o portador.
  local pT = jogo.criarPartida()
  pT.jogadores[1].avatar = "taylor"
  local cAcao = { tipo = "ACAO", chanceSucesso = 0.5 }
  check(math.abs(jogo.calcularChance(cAcao, pT.jogadores[1]) - 0.6) < 1e-9,
    "taylor: ACAO com +10% de chance")
  local cEfeito = { tipo = "EFEITO", chanceSucesso = 0.25 }
  check(math.abs(jogo.calcularChance(cEfeito, pT.jogadores[1]) - 0.35) < 1e-9,
    "taylor: EFEITO com +10% de chance")
  local cCoringa = { tipo = "CORINGA", chanceSucesso = 0.5 }
  check(jogo.calcularChance(cCoringa, pT.jogadores[1]) == 0.5,
    "taylor: CORINGA sem boost")
  local cProte = { tipo = "PROTECAO", chanceSucesso = 1 }
  check(jogo.calcularChance(cProte, pT.jogadores[1]) == 1,
    "taylor: PROTECAO intacta")
  local cSem = { tipo = "ACAO", chanceSucesso = 0.5 }
  check(jogo.calcularChance(cSem, pT.jogadores[2]) == 0.5,
    "sem taylor: chance intacta")
  local cAlta = { tipo = "ACAO", chanceSucesso = 1 }
  check(jogo.calcularChance(cAlta, pT.jogadores[1]) == 1,
    "taylor: boost respeita o teto de 100%")

  -- Marx: rico doa 100 ao pobre no inicio do turno do portador.
  local pM = jogo.criarPartida()
  pM.jogadores[1].avatar = "marx"
  pM.jogadores[1].saldo = 500
  pM.jogadores[2].saldo = 1000
  jogo.processarInicioTurno(pM, 1)
  check(pM.jogadores[1].saldo == 600 and pM.jogadores[2].saldo == 900,
    "marx: rico doa R$ 100 ao pobre no inicio do turno")
  check(pM.habilidade and pM.habilidade.tipo == "marx"
    and pM.habilidade.de == 2 and pM.habilidade.para == 1
    and pM.habilidade.valor == 100,
    "marx: habilidade registrada para a UI")

  -- Nao redistribui se o de Marx esta no topo; empate no topo tambem pula.
  local pR = jogo.criarPartida()
  pR.jogadores[1].avatar = "marx"
  pR.jogadores[1].saldo = 1200
  pR.jogadores[2].saldo = 400
  jogo.processarInicioTurno(pR, 1)
  check(pR.jogadores[1].saldo == 1200 and pR.jogadores[2].saldo == 400
    and pR.habilidade == nil, "marx: nao redistribui se ele e o mais rico")
  local pE = jogo.criarPartida()
  pE.jogadores[1].avatar = "marx"
  pE.jogadores[1].saldo = 700
  pE.jogadores[2].saldo = 700
  jogo.processarInicioTurno(pE, 1)
  check(pE.jogadores[1].saldo == 700 and pE.habilidade == nil,
    "marx: empate no topo nao redistribui")

  -- Multiplayer: dois marx; cada um dispara no proprio turno.
  local pN = jogo.criarPartida({ n = 3 })
  pN.jogadores[1].avatar = "marx"
  pN.jogadores[2].avatar = "marx"
  pN.jogadores[1].saldo = 800
  pN.jogadores[2].saldo = 500
  pN.jogadores[3].saldo = 1000
  jogo.processarInicioTurno(pN, 1)
  check(pN.jogadores[3].saldo == 900 and pN.jogadores[2].saldo == 600,
    "marx: no turno do 1o marx, o rico (3) doa ao pobre (2)")
  jogo.processarInicioTurno(pN, 2)
  check(pN.jogadores[3].saldo == 800 and pN.jogadores[2].saldo == 700,
    "marx: o 2o marx redistribui no proprio turno")

  -- Falidos ficam fora da conta (nao doam nem recebem).
  local pF = jogo.criarPartida({ n = 3 })
  pF.jogadores[1].avatar = "marx"
  pF.jogadores[1].saldo = 500
  pF.jogadores[2].saldo = 900
  pF.jogadores[3].saldo = 100
  pF.jogadores[3].falido = true
  jogo.processarInicioTurno(pF, 1)
  check(pF.jogadores[2].saldo == 800 and pF.jogadores[1].saldo == 600
    and pF.jogadores[3].saldo == 100,
    "marx: falido fica fora da redistribuicao")

  -- Rede: habilidade serializada/restaurada pelo snapshot.
  pM.habilidade = { tipo = "marx", de = 2, para = 1, valor = 100 }
  local snap = partidaRede.serializar(pM, 1, nil)
  check(snap.habilidade and snap.habilidade.de == 2 and snap.habilidade.para == 1,
    "marx: habilidade serializada para o cliente")
  local copia = partidaRede.montar(snap)
  check(copia.habilidade and copia.habilidade.valor == 100,
    "marx: habilidade restaurada no cliente")

  -- Mayo: neutraliza carta negativa mirada nele (30%), 1 tentativa por
  -- rodada. MAYO_CHANCE forcado para isolar a logica do RNG.
  local salvY = jogo.MAYO_CHANCE

  local function cNegDinheiro()
    return cartaTeste({
      chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "alvo",
      alteracaoSaldoBase = -100, alteracaoSaldoFalha = 0,
    })
  end

  -- Sucesso garantido (MAYO_CHANCE=1): a perda no alvo nao acontece.
  local pY = jogo.criarPartida()
  pY.jogadores[2].avatar = "mayo"
  pY.jogadores[2].saldo = 1000
  jogo.MAYO_CHANCE = 1.0
  jogar(pY, 1, cNegDinheiro())
  check(pY.jogadores[2].saldo == 1000,
    "mayo: neutralizou a carta negativa (sem perda)")
  check(pY.habilidade and pY.habilidade.tipo == "mayo"
    and pY.habilidade.para == 2,
    "mayo: habilidade registrada para o popup")

  -- Falha garantida (MAYO_CHANCE=0): a perda no alvo acontece.
  local pN = jogo.criarPartida()
  pN.jogadores[2].avatar = "mayo"
  pN.jogadores[2].saldo = 1000
  jogo.MAYO_CHANCE = 0.0
  jogar(pN, 1, cNegDinheiro())
  check(pN.jogadores[2].saldo == 900,
    "mayo: sem neutralizar, o alvo perdeu 100")
  check(pN.habilidade == nil,
    "mayo: sem neutralizacao nao registra habilidade")

  -- Uma vez por rodada: a 2a carta negativa na mesma rodada nao rola.
  local pR = jogo.criarPartida()
  pR.jogadores[2].avatar = "mayo"
  pR.jogadores[2].saldo = 1000
  jogo.MAYO_CHANCE = 1.0
  jogar(pR, 1, cNegDinheiro())
  check(pR.jogadores[2].saldo == 1000,
    "mayo: 1a carta neutralizada na rodada")
  pR.habilidade = nil
  jogar(pR, 1, cNegDinheiro())
  check(pR.jogadores[2].saldo == 900,
    "mayo: 2a carta da mesma rodada passa (1 tentativa/rodada)")

  -- Rodada nova (turno avanca): tenta de novo.
  pR.turno = pR.turno + 1
  pR.habilidade = nil
  jogar(pR, 1, cNegDinheiro())
  check(pR.jogadores[2].saldo == 900,
    "mayo: rodada nova permite neutralizar de novo")

  -- So mira no portador: alvo sem mayo nao neutraliza.
  local pS = jogo.criarPartida()
  pS.jogadores[2].avatar = "taylor"
  pS.jogadores[2].saldo = 1000
  jogo.MAYO_CHANCE = 1.0
  jogar(pS, 1, cNegDinheiro())
  check(pS.jogadores[2].saldo == 900,
    "mayo: alvo sem o avatar nao neutraliza")

  -- Carta positiva nao dispara (so negativa).
  local pP = jogo.criarPartida()
  pP.jogadores[2].avatar = "mayo"
  pP.jogadores[2].saldo = 1000
  jogo.MAYO_CHANCE = 1.0
  jogar(pP, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "alvo",
    alteracaoSaldoBase = 50, alteracaoSaldoFalha = 0,
  }))
  check(pP.jogadores[2].saldo == 1050,
    "mayo: carta positiva no alvo nao e neutralizada")

  -- Caminho de efeito (DOACAO): neutraliza a transferencia inteira.
  local pD = jogo.criarPartida()
  pD.jogadores[1].saldo = 0
  pD.jogadores[2].avatar = "mayo"
  pD.jogadores[2].saldo = 1000
  jogo.MAYO_CHANCE = 1.0
  jogar(pD, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "DOACAO_PERCENTUAL", alvo = "alvo" },
  }))
  check(pD.jogadores[2].saldo == 1000 and pD.jogadores[1].saldo == 0,
    "mayo: doacao percentual neutralizada (vitima e invocador intactos)")

  -- DINHEIRO_ALVO (Presente do Noel): perda do alvo neutralizada, ganho
  -- do invocador preservado.
  local pA = jogo.criarPartida()
  pA.jogadores[1].saldo = 0
  pA.jogadores[2].avatar = "mayo"
  pA.jogadores[2].saldo = 1000
  jogo.MAYO_CHANCE = 1.0
  jogar(pA, 1, cartaTeste({
    chanceSucesso = 1, precisaAlvo = true, dinheiroEm = "nenhum",
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0,
    efeito = { tipo = "DINHEIRO_ALVO", alvo = "alvo",
      ganhoInvocador = 200, perdaAlvo = 100 },
  }))
  check(pA.jogadores[2].saldo == 1000,
    "mayo: presente do Noel, alvo nao perdeu")
  check(pA.jogadores[1].saldo == 200,
    "mayo: presente do Noel, invocador ainda ganhou 200")

  -- Proprio jogador (invocador = mayo) nao dispara ("contra voce").
  local pI = jogo.criarPartida()
  pI.jogadores[1].avatar = "mayo"
  pI.jogadores[1].saldo = 1000
  jogo.MAYO_CHANCE = 1.0
  jogar(pI, 1, cartaTeste({
    chanceSucesso = 1, dinheiroEm = "invocador",
    alteracaoSaldoBase = -100, alteracaoSaldoFalha = 0,
  }))
  check(pI.jogadores[1].saldo == 900,
    "mayo: carta negativa no proprio invocador nao e neutralizada")

  jogo.MAYO_CHANCE = salvY
end

-- JSON do protocolo de rede: roundtrip das formas que a partida usa,
-- escapes, unicode (UTF-8 atravessa sem escape) e rejeicao de invalidos.
local function testarJson()
  local m = { tipo = "JOGAR", uids = { "a-1", "b-2" }, n = 3, ok = true,
    nome = "JOGADOR_2" }
  local texto = json.encode(m)
  local d = json.decode(texto)
  check(d.tipo == "JOGAR", "json roundtrip tipo = " .. tostring(d.tipo))
  check(#d.uids == 2 and d.uids[2] == "b-2", "json roundtrip array de uids")
  check(d.n == 3 and d.ok == true, "json roundtrip numero/booleano")
  check(d.nome == "JOGADOR_2", "json roundtrip string simples")

  check(json.encode({ 1, 2, 3 }) == "[1,2,3]",
    "array codifica como [1,2,3] = " .. json.encode({ 1, 2, 3 }))
  check(json.encode({}) == "[]", "tabela vazia codifica como []")

  local esc = json.decode(json.encode({ s = 'linha\ncom\ttab " \\ ' }))
  check(esc.s == 'linha\ncom\ttab " \\ ', "escapes roundtrip")

  check(json.decode('"\\u00e7"') == string.char(0xC3, 0xA7),
    "escape unicode vira UTF-8")

  local okNull, vNull = pcall(json.decode, "null")
  check(okNull and vNull == nil, "null decodifica como nil sem erro")

  check(json.decode("2.5e2") == 250, "numero cientifico decodifica")

  local aninhado = { sala = { jogadores = {
    { nome = "A", pronto = true }, { nome = "B" } } } }
  local d2 = json.decode(json.encode(aninhado))
  check(d2.sala.jogadores[2].nome == "B", "objeto aninhado roundtrip")
  check(d2.sala.jogadores[1].pronto == true, "booleano dentro de array")

  check(not pcall(json.decode, "{"), "objeto aberto rejeitado")
  check(not pcall(json.decode, "{'a':1}"), "aspas simples rejeitadas")
  check(not pcall(json.decode, "123abc"), "lixo apos numero rejeitado")
  check(not pcall(json.decode, ""), "entrada vazia rejeitada")
  check(not pcall(json.encode, nil), "nil nao codifica")
  check(not pcall(json.encode, math.huge), "infinito nao codifica")
end

-- ENet em localhost: servidor + cliente no mesmo processo (Fase 0 da rede).
local function testarRede()
  check(rede.disponivel, "enet disponivel no LOVE")

  local porta = 49635
  local servidor = rede.novo()
  check(servidor:criarServidor(porta) == true,
    "servidor sobe na porta " .. porta)

  local cliente = rede.novo()
  check(cliente:conectar("127.0.0.1", porta) == true,
    "cliente conecta ao localhost")

  -- Bombeia os dois hosts ate a condicao (ou um limite de tentativas).
  local function bombeear(condicao)
    local vistos = {}
    for _ = 1, 800 do
      servidor:atualizar()
      cliente:atualizar()
      for _, ev in ipairs(servidor:consumirEventos()) do
        vistos[#vistos + 1] = { quem = "servidor", ev = ev }
      end
      for _, ev in ipairs(cliente:consumirEventos()) do
        vistos[#vistos + 1] = { quem = "cliente", ev = ev }
      end
      if condicao and condicao(vistos) then return vistos end
      love.timer.sleep(0.002)
    end
    return vistos
  end

  local function tem(vistos, quem, tipo)
    for _, x in ipairs(vistos) do
      if x.quem == quem and x.ev.tipo == tipo then return x.ev end
    end
    return nil
  end

  local vistos = bombeear(function(v)
    return tem(v, "servidor", "conectado") and tem(v, "cliente", "conectado")
  end)
  check(tem(vistos, "servidor", "conectado") ~= nil,
    "servidor recebe evento conectado")
  check(tem(vistos, "cliente", "conectado") ~= nil,
    "cliente recebe evento conectado")
  local evConect = tem(vistos, "servidor", "conectado")
  local idCliente = evConect and evConect.id
  check(type(idCliente) == "number", "evento conectado traz id do peer")
  check(servidor:quantidadePeers() == 1, "servidor enxerga 1 peer")

  check(cliente:enviarParaServidor({ tipo = "OLA", n = 1 }) == true,
    "cliente envia mensagem")
  vistos = bombeear(function(v) return tem(v, "servidor", "mensagem") end)
  local evMsg = tem(vistos, "servidor", "mensagem")
  check(evMsg and evMsg.msg.tipo == "OLA" and evMsg.msg.n == 1,
    "servidor recebe mensagem JSON decodificada")

  check(servidor:enviar(idCliente, { tipo = "BEM_VINDO" }) == true,
    "servidor responde o peer")
  check(servidor:enviarTodos({ tipo = "TUDO" }) == true, "broadcast do host")
  vistos = bombeear(function(v)
    local n = 0
    for _, x in ipairs(v) do
      if x.quem == "cliente" and x.ev.tipo == "mensagem" then n = n + 1 end
    end
    return n >= 2
  end)
  local tipos = {}
  for _, x in ipairs(vistos) do
    if x.quem == "cliente" and x.ev.tipo == "mensagem" then
      tipos[x.ev.msg.tipo] = true
    end
  end
  check(tipos.BEM_VINDO, "cliente recebe resposta direta")
  check(tipos.TUDO, "cliente recebe broadcast")

  check(servidor:enviarBruto(idCliente, "lixo nao e json") == true,
    "envio bruto aceito")
  vistos = bombeear(function(v)
    return tem(v, "cliente", "mensagem_invalida") ~= nil
  end)
  check(tem(vistos, "cliente", "mensagem_invalida") ~= nil,
    "pacote invalido vira mensagem_invalida")

  check(cliente:desconectar() == true, "cliente pede desconexao")
  vistos = bombeear(function(v)
    return tem(v, "servidor", "desconectado") ~= nil
  end)
  check(tem(vistos, "servidor", "desconectado") ~= nil,
    "servidor ve a desconexao do cliente")
  check(servidor:quantidadePeers() == 0, "peer removido apos desconexao")

  check(type(rede.ipsLocais()) == "table", "ipsLocais devolve tabela")

  cliente:limpar()
  servidor:limpar()
  check(cliente:quantidadePeers() == 0 and servidor:quantidadePeers() == 0,
    "limpar zera os peers")
end

-- Descoberta de salas na rede (Fase 3): host responde o ping UDP do
-- cliente; sem resposta a sala expira. Roda em loopback (alvo 127.0.0.1)
-- para nao depender de placa/broadcast.
local function testarDescoberta()
  local portaDescAntes, alvoAntes = descoberta.PORTA, descoberta.alvo
  descoberta.PORTA = 49639
  descoberta.alvo = "127.0.0.1"

  local hostD = descoberta.novo()
  local consultas = 0
  check(hostD:iniciarHost(function()
    consultas = consultas + 1
    return { nome = "HOST_X", jogadores = 2, max = 8, porta = 49637 }
  end) == true, "descoberta: responder do host sobe na porta " .. descoberta.PORTA)

  local cliD = descoberta.novo()
  check(cliD:iniciarCliente() == true, "descoberta: sonda do cliente sobe")

  local achei
  for _ = 1, 200 do
    hostD:atualizar(0.1, false)
    cliD:atualizar(0.1, true)
    local lista = cliD:listaSalas()
    if #lista > 0 then achei = lista[1] break end
    love.timer.sleep(0.01)
  end
  check(achei ~= nil, "descoberta: ping UDP foi respondido com a sala")
  check(achei and achei.nome == "HOST_X",
    "descoberta: linha mostra o nome do host = " .. tostring(achei and achei.nome))
  check(achei and achei.porta == 49637,
    "descoberta: linha leva a porta de jogo = " .. tostring(achei and achei.porta))
  check(achei and tostring(achei.ip):match("^%d+%.%d+%.%d+%.%d+$") ~= nil,
    "descoberta: IP vem do remetente (IPv4) = " .. tostring(achei and achei.ip))
  check(consultas >= 1, "descoberta: host foi consultado = " .. consultas)
  -- Contadores/status que alimentam a linha de status do lobby.
  check(cliD.pings > 0, "descoberta: pings contabilizados = " .. tostring(cliD.pings))
  check(cliD.respostas > 0,
    "descoberta: respostas contabilizadas = " .. tostring(cliD.respostas))
  check(cliD:sondaStatus() == "OK",
    "descoberta: status da sonda com resposta = " .. cliD:sondaStatus())
  check(descoberta.novo():sondaStatus() == "PARADO",
    "descoberta: sonda nunca ligada = " .. descoberta.novo():sondaStatus())
  -- IP lembrado (unicast extra para rede que filtra broadcast).
  local dLemb = descoberta.novo()
  dLemb:lembrar("192.168.0.10")
  check(dLemb.lembrado == "192.168.0.10",
    "descoberta: guarda IP valido = " .. tostring(dLemb.lembrado))
  dLemb:lembrar("banana")
  check(dLemb.lembrado == "192.168.0.10",
    "descoberta: ignora IP invalido = " .. tostring(dLemb.lembrado))

  -- Varredura unicast da subrede: montada SO no alvo de producao (broadcast).
  -- Os testes rodam com alvo 127.0.0.1 e nao podem pingar a rede real.
  descoberta.alvo = "255.255.255.255"
  local dScan = descoberta.novo()
  check(dScan:iniciarCliente() == true,
    "descoberta: sonda com alvo de producao sobe")
  check(type(dScan.varredura) == "table" and #dScan.varredura > 0,
    "descoberta: varredura /24 da subrede montada = " ..
    tostring(dScan.varredura and #dScan.varredura))
  check(dScan.varreduraI == 1,
    "descoberta: cursor da varredura comeca em 1")
  dScan:parar()
  check(dScan.varredura == nil,
    "descoberta: parar limpa a varredura da subrede")
  descoberta.alvo = "127.0.0.1"

  -- Host some: sem resposta a sala expira da lista (VIDA de poucos segundos).
  hostD:parar()
  for _ = 1, 120 do
    cliD:atualizar(0.1, true)
    love.timer.sleep(0.01)
  end
  check(#cliD:listaSalas() == 0,
    "descoberta: sala expira sem o host = " .. #cliD:listaSalas())
  cliD:parar()

  descoberta.PORTA = portaDescAntes
  descoberta.alvo = alvoAntes
end

-- Arenas dos ciclos (fundo da mesa no duelo do Ciclo I e na partida em
-- rede): carregamento sob demanda, so UMA viva por vez (RAM de celular),
-- nome curto para a linha da sala e faixa valida 1..9.
local function testarArenas()
  check(arte.totalArenas() == 9, "arenas: 9 arenas dos ciclos = "
    .. tostring(arte.totalArenas()))
  check(arte.nomeArena(nil) == "MADEIRA", "arena sem escolha = madeira")
  check(arte.nomeArena(0) == "MADEIRA", "arena 0 = madeira")
  check(arte.nomeArena(1) == "CICLO I", "nome da arena 1 = "
    .. tostring(arte.nomeArena(1)))
  check(arte.nomeArena(9) == "CICLO IX", "nome da arena 9 = "
    .. tostring(arte.nomeArena(9)))
  -- Carrega cada arena sob demanda (valida os 9 PNGs) e prova a faixa.
  for n = 1, arte.totalArenas() do
    check(arte.arena(n) ~= nil, "arena " .. n .. " carrega sob demanda")
  end
  check(arte.arena(0) == nil, "arena 0 = nil (madeira)")
  check(arte.arena(10) == nil, "arena fora de faixa = nil")
  check(arte.arena(nil) == nil, "arena nil nao quebra")
  check(arte.arena("x") == nil, "arena nao numerica = nil")
end

-- Tela MULTIPLAYER (Fase 1): lobby/digitacao de IP e sala real via
-- localhost (host + convidado), cheia (8) e saida.
local function testarMultiplayer()
  -- Fluxo do lobby: digitar IP invalido recusa, voltar sai.
  local l = multiplayer.novo()
  l:iniciar({ nick = "TESTE", avatar = "1" }, 49636)
  local g = l:retangulos()
  check(g.criar ~= nil and g.ip ~= nil, "lobby tem CRIAR SALA e CONECTAR COM IP")
  l:clicado(g.ip.x + 4, g.ip.y + 4)
  check(l:estado().telaInterna == "digitando", "abriu a digitacao de IP")
  l:digitar("9"); l:digitar("9"); l:digitar(".")
  check(l:estado().texto == "99.", "digitar aceita digitos e ponto = "
    .. l:estado().texto)
  l:apagar()
  check(l:estado().texto == "99", "backspace apaga 1 caractere")
  g = l:retangulos()
  l:clicado(g.conectar.x + 4, g.conectar.y + 4)
  check(l:estado().telaInterna == "digitando" and l:estado().statusErro,
    "IP invalido recusa e mostra erro")
  g = l:retangulos()
  l:clicado(g.voltar.x + 4, g.voltar.y + 4)
  check(l:estado().telaInterna == "lobby", "voltar da digitacao ao lobby")
  g = l:retangulos()
  check(l:clicado(g.voltar.x + 4, g.voltar.y + 4) == "menu",
    "voltar do lobby devolve menu")
  l:fechar()

  -- Teclado do celular: no modo digitando o painel SEMPRE sobe para o topo
  -- (sem depender de love.keyboard.isVisible, que nem toda versao/plataforma
  -- tem) — o campo de IP nunca fica atras do teclado software.
  local kd = multiplayer.novo()
  kd:iniciar({ nick = "TC", avatar = "1" }, 49641)
  kd:estado().telaInterna = "digitando"
  local gDigitando = kd:retangulos()
  check(gDigitando.y == 16,
    "campo de IP no topo no modo digitando = " .. tostring(gDigitando.y))
  kd:estado().telaInterna = "lobby"
  local gLobby = kd:retangulos()
  check(gLobby.y > 16, "lobby continua centralizado = " .. tostring(gLobby.y))
  check(gLobby.chat == nil, "lobby (fora da sala) nao tem painel de chat")
  kd:fechar()

  -- Descoberta: a sala do host aparece no lobby do cliente e da para entrar
  -- clicando na linha, sem digitar IP (portas isoladas das demais baterias).
  local portaDescAntes, alvoAntes = descoberta.PORTA, descoberta.alvo
  descoberta.PORTA = 49639
  descoberta.alvo = "127.0.0.1"
  local h2 = multiplayer.novo()
  h2:iniciar({ nick = "HOST_ACHADO", avatar = "1" }, 49640)
  check(h2:criarSala() == true, "descoberta-lobby: host abre sala")
  local c2 = multiplayer.novo()
  c2:iniciar({ nick = "ENTRADA_TOQUE", avatar = "2" }, 49640)
  local achouLinha = false
  for _ = 1, 400 do
    h2:atualizar(0.02)
    c2:atualizar(0.02)
    if #c2:retangulos().salas > 0 then achouLinha = true break end
    love.timer.sleep(0.005)
  end
  check(achouLinha, "descoberta-lobby: sala do host aparece no lobby")
  if achouLinha then
    local r = c2:retangulos().salas[1]
    check(r.sala.nome == "HOST_ACHADO",
      "descoberta-lobby: linha mostra o anfitriao = " .. tostring(r.sala.nome))
    c2:clicado(r.x + r.w / 2, r.y + r.h / 2)
    check(c2:estado().telaInterna == "conectando",
      "clicar na linha conecta sem digitar IP")
    for _ = 1, 800 do
      h2:atualizar(0.002)
      c2:atualizar(0.002)
      if c2:estado().telaInterna == "sala" then break end
      love.timer.sleep(0.002)
    end
    check(c2:estado().telaInterna == "sala",
      "entrou na sala pelo toque na lista = " .. c2:estado().telaInterna)
    check(#h2:estado().jogadores == 2,
      "host enxerga quem entrou por toque = " .. #h2:estado().jogadores)
  end
  c2:fechar()
  h2:sair()
  h2:fechar()
  descoberta.PORTA = portaDescAntes
  descoberta.alvo = alvoAntes

  -- Sala real via localhost.
  local porta = 49636
  local host = multiplayer.novo()
  host:iniciar({ nick = "HOST_PC", avatar = "1" }, porta)
  check(host:criarSala() == true, "host cria sala")
  check(host:estado().telaInterna == "sala", "host vai para a sala")
  check(host:estado().ipSala ~= nil, "sala mostra o IP local")

  local cli = multiplayer.novo()
  cli:iniciar({ nick = "CONVIDADO", avatar = "3" }, porta)
  check(cli:conectar("127.0.0.1") == true, "convidado conecta ao host")

  -- Participantes vivos do bombeio: os extras (cenario do bug de lobby)
  -- entram na lista quando conectam; fechar module e seguro (atualizar
  -- com a conexao ja derrubada so ignora).
  local participantes = { host, cli }
  local function bombeear(condicao)
    for _ = 1, 800 do
      for _, m in ipairs(participantes) do m:atualizar(0.002) end
      if condicao and condicao() then return true end
      love.timer.sleep(0.002)
    end
    return false
  end

  bombeear(function() return cli:estado().telaInterna == "sala" end)
  check(cli:estado().telaInterna == "sala", "convidado entrou na sala")
  check(cli:estado().meuAssento == 2, "assento do convidado = 2")
  check(#host:estado().jogadores == 2, "host enxerga 2 jogadores")
  check(host:estado().jogadores[2].nome == "CONVIDADO",
    "host recebeu o nome do convidado")
  check(cli:estado().jogadores[1].host == true,
    "lista do cliente marca o anfitriao")
  check(cli:estado().jogadores[2].eu == true, "lista do cliente marca eu")

  local gSala = host:retangulos()
  check(host:clicado(gSala.iniciar.x + 4, gSala.iniciar.y + 4) == "iniciar",
    "INICIAR com 2 jogadores devolve iniciar")

  -- PRONTO do convidado propaga para o host.
  cli:alternarPronto()
  check(cli:estado().meuPronto == true, "convidado marcou pronto")
  bombeear(function() return host:estado().jogadores[2].pronto end)
  check(host:estado().jogadores[2].pronto == true,
    "PRONTO do convidado chega ao host")

  -- CHAT DA SALA: os membros escrevem e todos os membros veem. O cliente
  -- manda so o TEXTO; o NOME sai da lista do host (ninguem escolhe o proprio
  -- nome) e a mensagem volta para todos, na ordem do host.
  check(#host:estado().chat == 0 and #cli:estado().chat == 0,
    "chat comeca vazio nos dois lados")
  local gChat = host:retangulos()
  check(gChat.chat ~= nil and gChat.chat.x > gChat.x + gChat.w,
    "painel do chat projeta a DIREITA da sala")
  check(gChat.x >= 0 and gChat.chat.x + gChat.chat.w <= 1280,
    "par sala+chat dentro da tela = " .. string.format("%.0f..%.0f",
      gChat.x, gChat.chat.x + gChat.chat.w))
  check(gChat.chat.campo.y + gChat.chat.campo.h <= gChat.y + gChat.h,
    "campo do chat dentro do painel")
  -- Sem sala nao ha chat: o rascunho e o foco sao da SALA.
  local fora = multiplayer.novo()
  fora:iniciar({ nick = "FORA", avatar = "1" }, porta)
  check(fora:enviarChat() == nil, "sem sala nao ha chat para enviar")
  check(fora:focarChat() == nil, "sem sala o campo do chat nao abre")
  fora:estado().telaInterna = "sala"
  fora:estado().chat = { { nome = "A", texto = "b", cor = "#FFD54F" } }
  fora:estado().chatFoco = true
  fora:sair()
  check(#fora:estado().chat == 0 and fora:estado().chatFoco == false,
    "sair da sala limpa o chat e fecha o campo")
  fora:fechar()

  -- Campo do chat: toque abre (teclado do celular), escrita/backspace no
  -- rascunho local e ENVIAR manda sem fechar o campo.
  host:clicado(gChat.chat.campo.x + 4, gChat.chat.campo.y + 4)
  check(host:estado().chatFoco == true,
    "toque no campo abre o chat para digitar")
  host:digitar("oi")
  check(host:estado().chatTexto == "oi", "digitar monta o rascunho = "
    .. tostring(host:estado().chatTexto))
  host:apagar()
  check(host:estado().chatTexto == "o", "backspace do chat apaga 1 caractere")
  host:digitar("i ai")
  check(host:estado().chatTexto == "oi ai", "digitar continua o rascunho = "
    .. tostring(host:estado().chatTexto))
  local gDig = host:retangulos()
  check(gDig.chatDig == nil,
    "digita no PROPRIO painel do chat (sem tela de digitacao a parte)")
  host:clicado(gChat.chat.enviar.x + 4, gChat.chat.enviar.y + 4)
  check(#host:estado().chat == 1 and host:estado().chatTexto == "",
    "ENVIAR grava e zera o rascunho")
  check(host:estado().chat[1].nome == "HOST_PC"
    and host:estado().chat[1].texto == "oi ai",
    "host assina com o proprio nick = "
    .. tostring(host:estado().chat[1].nome) .. "/"
    .. tostring(host:estado().chat[1].texto))
  check(host:estado().chatFoco == true, "ENVIAR mantem o campo aberto")
  -- Clicar na sala (fora do painel do chat) fecha o campo e nao age sozinho.
  host:clicado(gChat.x + 20, gChat.y + 20)
  check(host:estado().chatFoco == false,
    "clicar na sala fecha o campo do chat")
  host:clicado(10, 10)
  check(host:estado().chatFoco == false, "clicar fora fecha o campo do chat")
  bombeear(function() return #cli:estado().chat == 1 end)
  check(#cli:estado().chat == 1 and cli:estado().chat[1].texto == "oi ai",
    "mensagem do host chega ao cliente = " .. #cli:estado().chat)
  check(#host:estado().chat == 1, "host nao duplica a propria mensagem")

  -- CELULAR com o campo aberto: o PAR sala+chat sobe para o campo (e o
  -- ENVIAR) nao ficarem atras do teclado software. No PC o par fica parado.
  local gAntes = host:retangulos()
  multiplayer.aparelhoMovel = true
  host:focarChat()
  local gMovel = host:retangulos()
  check(gMovel.y < gAntes.y, "celular: par sobe com o campo aberto = "
    .. tostring(gMovel.y) .. " < " .. tostring(gAntes.y))
  check(gMovel.chat.campo.y + gMovel.chat.campo.h <= math.floor(720 * 0.35),
    "celular: campo no TERCO DE CIMA da tela = "
    .. tostring(gMovel.chat.campo.y + gMovel.chat.campo.h))
  check(gMovel.chat.y == gMovel.y and gMovel.chat.h == gAntes.chat.h,
    "celular: chat sobe JUNTO com a sala (mesmo topo e altura)")
  host:desenhar({ x = 0, y = 0 })
  multiplayer.aparelhoMovel = false
  check(host:retangulos().y == gAntes.y,
    "PC: par sala+chat nao sobe com o campo aberto")
  host:desfocarChat()
  multiplayer.aparelhoMovel = nil
  check(host:retangulos().y == gAntes.y, "par volta ao lugar ao fechar o campo")

  -- Cliente escreve: o pacote leva so o texto e o host assina pelo assento.
  cli:focarChat()
  check(cli:estado().chatFoco == true, "campo do chat do cliente em foco")
  cli:digitar("cheguei")
  check(cli:enviarChat() == true, "cliente envia o rascunho do chat")
  bombeear(function()
    return #host:estado().chat == 2 and #cli:estado().chat == 2
  end)
  check(#host:estado().chat == 2, "mensagem do cliente chega ao host = "
    .. #host:estado().chat)
  check(host:estado().chat[2].nome == "CONVIDADO",
    "host assina com o nome que ele conhece = "
    .. tostring(host:estado().chat[2].nome))
  check(cli:estado().chat[2].nome == "CONVIDADO",
    "o autor tambem ve a propria mensagem (eco do host) = "
    .. tostring(cli:estado().chat[2].nome))

  -- Nome forjado no pacote nao vale (quem assina e o host) e remetente fora
  -- da sala e ignorado (nem repassa).
  local idCli = host:estado().jogadores[2].id
  host:processar({ tipo = "mensagem", id = idCli,
    msg = { tipo = "CHAT", nome = "ADMIN", texto = "forjado" } })
  check(host:estado().chat[3].nome == "CONVIDADO",
    "nome no pacote do cliente e ignorado = "
    .. tostring(host:estado().chat[3].nome))
  host:processar({ tipo = "mensagem", id = 777,
    msg = { tipo = "CHAT", texto = "invasor" } })
  check(#host:estado().chat == 3, "chat de quem nao esta na sala e ignorado")

  -- Rascunho vazio/so espacos nao entra e a mensagem e cortada no limite.
  host:estado().chatTexto = "    "
  check(host:enviarChat() == nil, "rascunho so com espacos nao envia")
  check(#host:estado().chat == 3, "nada foi gravado com rascunho vazio")
  cli:estado().chatTexto = string.rep("x", 400)
  check(cli:enviarChat() == true, "mensagem gigante e aceita (cortada)")
  bombeear(function() return #host:estado().chat == 4 end)
  check(#host:estado().chat[4].texto == 140, "mensagem cortada em 140 = "
    .. #host:estado().chat[4].texto)

  -- Desenho: o painel do chat (com o campo em foco e com o rascunho) nao
  -- pode estourar o frame.
  host:desenhar({ x = 0, y = 0 })
  cli:desenhar({ x = 0, y = 0 })
  cli:focarChat()
  cli:digitar("no proprio painel")
  cli:desenhar({ x = 0, y = 0 })
  cli:desfocarChat()
  check(cli:estado().chatFoco == false, "campo do cliente fecha de novo")

  -- Arena da partida em rede: comeca na madeira; o host cicla (madeira ->
  -- I -> ... -> IX -> madeira) e a escolha propaga via SALA. So o host
  -- troca (mesma regra do PREENCHER COM IA).
  check(host:estado().arena == nil, "arena comeca na madeira padrao")
  local gArena = host:retangulos()
  check(gArena.arena ~= nil, "sala do host projeta a linha de arena")
  host:clicado(gArena.arena.x + 4, gArena.arena.y + 4)
  check(host:estado().arena == 1, "1o clique vai para a arena Ciclo I = "
    .. tostring(host:estado().arena))
  bombeear(function() return cli:estado().arena == 1 end)
  check(cli:estado().arena == 1,
    "arena escolhida chega ao cliente via SALA = "
    .. tostring(cli:estado().arena))
  local gArenaCli = cli:retangulos()
  check(gArenaCli.arena ~= nil, "sala do cliente projeta a linha de arena")
  cli:clicado(gArenaCli.arena.x + 4, gArenaCli.arena.y + 4)
  check(cli:estado().arena == 1, "cliente nao altera a arena do host")
  for _ = 2, arte.totalArenas() do
    gArena = host:retangulos()
    host:clicado(gArena.arena.x + 4, gArena.arena.y + 4)
  end
  check(host:estado().arena == arte.totalArenas(),
    "ciclo chega na ultima arena (IX) = " .. tostring(host:estado().arena))
  bombeear(function() return cli:estado().arena == arte.totalArenas() end)
  check(cli:estado().arena == arte.totalArenas(),
    "arena IX chega ao cliente = " .. tostring(cli:estado().arena))
  gArena = host:retangulos()
  host:clicado(gArena.arena.x + 4, gArena.arena.y + 4)
  check(host:estado().arena == nil, "clique alem da IX volta a madeira")
  bombeear(function() return cli:estado().arena == nil end)
  check(arte.nomeArena(host:estado().arena) == "MADEIRA",
    "rotulo da arena volta a madeira")

  -- Fase 3: quantidade de IA e escolha do host (default 0 = so humanos; em
  -- ciclo 0..vagas livres, nunca ultrapassa 8) e o broadcast da SALA leva
  -- a escolha para o cliente (mesma informacao).
  check(host:estado().qtdIA == 0, "quantidade de IA comeca em 0")
  check(host:estado().preencherIA == false, "preencher IA comeca desligado")
  gSala = host:retangulos()
  check(gSala.ia ~= nil, "sala do host tem a linha de IA")
  host:clicado(gSala.ia.x + 4, gSala.ia.y + 4)
  check(host:estado().qtdIA == 1, "1o clique poe 1 IA = "
    .. tostring(host:estado().qtdIA))
  check(host:estado().preencherIA == true, "qtdIA > 0 liga preencherIA")
  bombeear(function() return cli:estado().qtdIA == 1 end)
  check(cli:estado().qtdIA == 1,
    "quantidade de IA chega ao cliente via SALA = "
    .. tostring(cli:estado().qtdIA))
  local gCli = cli:retangulos()
  cli:clicado(gCli.ia.x + 4, gCli.ia.y + 4)
  check(cli:estado().qtdIA == 1, "cliente nao altera a escolha de IA")
  gSala = host:retangulos()
  host:clicado(gSala.ia.x + 4, gSala.ia.y + 4)
  check(host:estado().qtdIA == 2, "segundo clique soma IA = "
    .. tostring(host:estado().qtdIA))
  -- Ciclo fecha em 0: com 2 humanos ha 6 vagas livres (3,4,5,6 e o
  -- quinto clique volta ao zero).
  for _ = 1, 5 do
    gSala = host:retangulos()
    host:clicado(gSala.ia.x + 4, gSala.ia.y + 4)
  end
  check(host:estado().qtdIA == 0, "ciclo da IA fecha em 0 = "
    .. tostring(host:estado().qtdIA))
  check(host:estado().preencherIA == false, "qtdIA 0 desliga preencherIA")
  bombeear(function() return cli:estado().qtdIA == 0 end)
  check(cli:estado().qtdIA == 0, "desligar a IA tambem propaga")

  -- Dificuldade da IA (1 facil, 2 media, 3 dificil): escolha do host
  -- (default media) e broadcast no mesmo formato da arena.
  check(host:estado().dificuldade == 2, "dificuldade comeca em media")
  gSala = host:retangulos()
  check(gSala.dificuldade ~= nil, "sala do host tem a linha de dificuldade")
  host:clicado(gSala.dificuldade.x + 4, gSala.dificuldade.y + 4)
  check(host:estado().dificuldade == 3, "1o clique poe dificuldade dificil = "
    .. tostring(host:estado().dificuldade))
  bombeear(function() return cli:estado().dificuldade == 3 end)
  check(cli:estado().dificuldade == 3,
    "dificuldade chega ao cliente via SALA = "
    .. tostring(cli:estado().dificuldade))
  gCli = cli:retangulos()
  cli:clicado(gCli.dificuldade.x + 4, gCli.dificuldade.y + 4)
  check(cli:estado().dificuldade == 3, "cliente nao altera a dificuldade")
  gSala = host:retangulos()
  host:clicado(gSala.dificuldade.x + 4, gSala.dificuldade.y + 4)
  check(host:estado().dificuldade == 1, "ciclo da dificuldade volta a facil = "
    .. tostring(host:estado().dificuldade))
  bombeear(function() return cli:estado().dificuldade == 1 end)
  check(cli:estado().dificuldade == 1, "ciclo da dificuldade propaga")
  gSala = host:retangulos()
  host:clicado(gSala.dificuldade.x + 4, gSala.dificuldade.y + 4)
  check(host:estado().dificuldade == 2, "dificuldade volta a media")

  -- Saida do convidado limpa a vaga; INICIAR sozinho bloqueia.
  cli:fechar()
  bombeear(function() return #host:estado().jogadores == 1 end)
  check(#host:estado().jogadores == 1, "disconnect remove o convidado")
  local gSala = host:retangulos()
  check(host:clicado(gSala.iniciar.x + 4, gSala.iniciar.y + 4) == nil,
    "INICIAR sozinho nao inicia")
  check(host:estado().status == "AGUARDE MAIS JOGADORES",
    "INICIAR sozinho mostra aviso = " .. tostring(host:estado().status))

  -- Com IA escolhida, o host sozinho tambem pode iniciar: 1 humano + IA
  -- completa a mesa (total >= 2), limitado as vagas livres.
  gSala = host:retangulos()
  host:clicado(gSala.ia.x + 4, gSala.ia.y + 4)
  check(host:estado().qtdIA == 1, "IA com o host sozinho = "
    .. tostring(host:estado().qtdIA))
  gSala = host:retangulos()
  check(host:clicado(gSala.iniciar.x + 4, gSala.iniciar.y + 4) == "iniciar",
    "INICIAR com 1 humano + 1 IA devolve iniciar")
  -- Volta ao zero para nao vazar para os proximos cenarios.
  host:estado().qtdIA = 0
  host:estado().preencherIA = false

  -- BUG DO LOBBY (>=3): quem sai do MEIO renumera os assentos dos demais
  -- (host compacta a lista no lobby). Sem o seuAssento que acompanha a
  -- SALA, o cliente seguinte achava que foi removido e caia fora com
  -- "VOCE SAIU DA SALA" sem ter feito nada.
  local cliA = multiplayer.novo()
  cliA:iniciar({ nick = "CLI_A", avatar = "4" }, porta)
  check(cliA:conectar("127.0.0.1") == true, "lobby: segundo cliente conecta")
  local cliB = multiplayer.novo()
  cliB:iniciar({ nick = "CLI_B2", avatar = "5" }, porta)
  check(cliB:conectar("127.0.0.1") == true, "lobby: terceiro cliente conecta")
  participantes[#participantes + 1] = cliA
  participantes[#participantes + 1] = cliB
  bombeear(function()
    return cliA:estado().telaInterna == "sala"
      and cliB:estado().telaInterna == "sala"
  end)
  check(cliA:estado().meuAssento == 2 and cliB:estado().meuAssento == 3,
    "lobby: assentos 2 e 3 = " .. tostring(cliA:estado().meuAssento)
    .. "/" .. tostring(cliB:estado().meuAssento))
  -- O do meio sai: o 3o e renumerado para 2 e CONTINUA na sala. Espera o
  -- assento NO CLIENTE (o bombeio so sai quando o SALA renumerado chega;
  -- sair so na contagem do host pegaria o estado antigo do cliente).
  cliA:fechar()
  bombeear(function()
    return #host:estado().jogadores == 2
      and cliB:estado().meuAssento == 2
  end)
  check(cliB:estado().telaInterna == "sala",
    "lobby: cliente do meio nao e chutado = " ..
    tostring(cliB:estado().status))
  check(cliB:estado().meuAssento == 2,
    "lobby: meuAssento renumerado 3 -> 2 = " ..
    tostring(cliB:estado().meuAssento))
  check(#host:estado().jogadores == 2
    and host:estado().jogadores[2].nome == "CLI_B2",
    "host enxerga 2 depois da saida do do meio = "
    .. tostring(host:estado().jogadores[2]
      and host:estado().jogadores[2].nome))
  cliB:fechar()
  bombeear(function() return #host:estado().jogadores == 1 end)
  check(#host:estado().jogadores == 1,
    "lobby: terceiro cliente sai e sobra o host")

  -- Sala cheia: 7 sinteticos completam 8; o 9o NAO entra.
  for i = 1, 7 do
    host:processar({ tipo = "mensagem", id = 100 + i,
      msg = { tipo = "ENTRAR", nick = "X" .. i, avatar = "2" } })
  end
  check(#host:estado().jogadores == 8, "sala enche ate 8 = "
    .. #host:estado().jogadores)
  host:processar({ tipo = "mensagem", id = 500,
    msg = { tipo = "ENTRAR", nick = "NOVO", avatar = "2" } })
  check(#host:estado().jogadores == 8, "9o jogador nao entra (sala cheia)")

  -- Painel de limbo (telaInterna "partida"): o cliente travado apos o
  -- INICIADO (sem o primeiro SNAPSHOT ainda) desenha a espera sem erro —
  -- e sem cair no lobby fantasma com botoes.
  local mLimbo = multiplayer.novo()
  mLimbo:iniciar({ nick = "LIMBO", avatar = "2" }, 49642)
  mLimbo:estado().telaInterna = "partida"
  mLimbo:estado().papel = "cliente"
  mLimbo:desenhar({ x = 0, y = 0 })
  check(mLimbo:clicado(100, 100) == nil,
    "limbo ignora clique (nenhuma acao de lobby)")
  mLimbo:fechar()

  host:sair()
  check(host:estado().telaInterna == "lobby" and host:estado().papel == nil,
    "sair da sala volta ao lobby")
end

-- Fase 2: snapshot rotacionado, acoes autoritativas e o protocolo de socket
-- das mensagens de partida (INICIADO/SNAPSHOT/PASSAR).
local function testarPartidaRede()
  -- Display local -> assento do motor (o cliente mora no seat real).
  check(partidaRede.paraEng(2, 2, 2) == 1, "paraEng 1v1: oponente = seat 1")
  check(partidaRede.paraEng(3, 2, 2) == 3, "paraEng mesa: display 2 = seat 3")
  check(partidaRede.paraEng(3, 2, 3) == 1, "paraEng mesa: display 3 = seat 1")

  -- Inversa (usada pelo cliente no EMOJI, que viaja no espaco global).
  check(partidaRede.paraLocal(3, 1, 3) == 3, "paraLocal host: identidade")
  check(partidaRede.paraLocal(2, 2, 1) == 2, "paraLocal 1v1: seat 1 = display 2")
  check(partidaRede.paraLocal(3, 2, 3) == 2, "paraLocal mesa: seat 3 = display 2")
  check(partidaRede.paraLocal(3, 2, 1) == 3, "paraLocal mesa: seat 1 = display 3")
  -- Ida e volta com paraEng cobre todos os tamanhos de mesa e assentos.
  for n = 2, 8 do
    for meu = 1, n do
      for l = 1, n do
        local g = partidaRede.paraEng(n, meu, l)
        check(partidaRede.paraLocal(n, meu, g) == l,
          "paraLocal ida-e-volta n=" .. n .. " meu=" .. meu .. " l=" .. l)
      end
    end
  end

  -- Arena escolhida pelo host sobe no snapshot e volta igual no cliente
  -- (o fundo da mesa e o mesmo dos dois lados; nil = madeira padrao).
  local pArena = jogo.criarPartida({ n = 2, nomes = { "HOST_A", "CLI_A2" } })
  pArena.arena = 5
  local snapArena = partidaRede.serializar(pArena, 2,
    { duracao = 30, restante = 30 })
  check(snapArena.arena == 5, "snapshot leva a arena escolhida = "
    .. tostring(snapArena.arena))
  check(partidaRede.montar(snapArena).arena == 5,
    "montar restaura a arena no cliente")
  pArena.arena = nil
  snapArena = partidaRede.serializar(pArena, 2,
    { duracao = 30, restante = 30 })
  check(snapArena.arena == nil, "snapshot sem arena = madeira padrao")
  check(partidaRede.montar(snapArena).arena == nil,
    "montar sem arena = madeira padrao")

  -- Serializacao em mesa de 3: proprio na posicao 1, maos alheias ocultas
  -- (so a contagem) e vez girada junto com os jogadores.
  local ps = jogo.criarPartida({ n = 3, nomes = { "ALFA", "BETA", "GAMA" } })
  ps.vez = 2
  ps.jogadores[2].chainClasse = "Efeito"
  ps.jogadores[2].chainBonus = 2
  ps.jogadasTurno = 3
  local maoB = ps.jogadores[2].mao
  local maoC = ps.jogadores[3].mao
  local snap = partidaRede.serializar(ps, 2, { duracao = 30, restante = 20 })
  check(snap.jogadores[1].nome == "BETA", "rotacao: BETA na posicao 1 = "
    .. tostring(snap.jogadores[1].nome))
  check(snap.jogadores[2].nome == "GAMA", "rotacao: GAMA na posicao 2")
  check(snap.jogadores[3].nome == "ALFA", "rotacao: ALFA na posicao 3")
  check(snap.jogadores[1].mao[1] and snap.jogadores[1].mao[1].uid == maoB[1].uid,
    "snapshot: mao propria vem completa")
  check(snap.jogadores[2].mao[1] and snap.jogadores[2].mao[1].oculta == true,
    "snapshot: mao do oponente vem oculta")
  check(#snap.jogadores[2].mao == #maoC, "snapshot: contagem da mao oculta = "
    .. #snap.jogadores[2].mao .. " vs " .. #maoC)
  check(snap.vez == 1, "vez girada: BETA (seat 2) vira posicao 1 = "
    .. tostring(snap.vez))
  check(snap.jogadores[1].chainClasse == "Efeito"
    and snap.jogadores[1].chainBonus == 2,
    "snapshot leva classe/bonus da cadeia do proprio jogador")
  check(snap.tempo and snap.tempo.restante == 20, "snapshot leva o relogio")

  -- Montagem do lado do cliente: espelho com vencedor por referencia.
  ps.vencedor = ps.jogadores[3]
  snap = partidaRede.serializar(ps, 2, { duracao = 30, restante = 20 })
  local m = partidaRede.montar(snap)
  check(m.jogadores[1].nome == "BETA" and m.jogadores[2].nome == "GAMA",
    "montar preserva a rotacao")
  check(m.jogadores[1].mao[1] and m.jogadores[1].mao[1].uid == maoB[1].uid,
    "montar: mao propria e a mesma")
  check(m.vez == 1, "montar mantem a vez ja rotacionada")
  check(m.jogadores[1].chainClasse == "Efeito"
    and m.jogadores[1].chainBonus == 2,
    "montar restaura classe/bonus da cadeia")
  check(m.vencedor == m.jogadores[2], "montar: vencedor vira referencia local = "
    .. tostring(m.vencedor and m.vencedor.nome))
  check(m.evento == nil or type(m.evento) == "table", "montar copia o evento")

  -- Leilao/roleta em rede: lances e vencedor saem rotacionados; o cliente
  -- espelha o leilao e o Curinga global sem rodar o motor local.
  ps.leilao = {
    rodada = ps.turno, cartas = { ps.jogadores[1].mao[1] }, kit = false,
    lances = { [1] = 100, [2] = 300, [3] = 200 },
    resultados = { { cartas = {}, vencedor = 2, valor = 300, maior = 300 } },
    tempo = 15, resolvido = true,
  }
  ps.curingaGlobal = { carta = ps.jogadores[1].mao[1], rodada = ps.turno }
  ps.curingaHistorico = { ps.jogadores[2].mao[1] }
  ps.metaFase, ps.metaT, ps.metaRodada = "resultadoLeilao", 1.2, ps.turno
  local snapL = partidaRede.serializar(ps, 2, { duracao = 30, restante = 20 })
  check(snapL.leilao and snapL.leilao.lances[1] == 300,
    "leilao em rede: lance do seat 2 vira display 1 = " ..
    tostring(snapL.leilao and snapL.leilao.lances[1]))
  check(snapL.leilao.lances[2] == 200 and snapL.leilao.lances[3] == 100,
    "leilao em rede: demais lances rotacionados")
  check(snapL.leilao.resultados[1].vencedor == 1,
    "leilao em rede: vencedor rotacionado para o display = " ..
    tostring(snapL.leilao.resultados[1].vencedor))
  check(snapL.curingaGlobal and snapL.curingaGlobal.carta.uid ==
    ps.jogadores[1].mao[1].uid, "curinga global viaja no snapshot")
  check(snapL.metaFase == "resultadoLeilao" and snapL.metaT == 1.2,
    "fase/tempo do meta viajam no snapshot")
  local mL = partidaRede.montar(snapL)
  check(mL.leilao and mL.leilao.lances[1] == 300
    and mL.leilao.resultados[1].vencedor == 1,
    "montar restaura o leilao rotacionado")
  check(mL.curingaGlobal and mL.metaFase == "resultadoLeilao",
    "montar restaura curinga/meta")

  -- Fase 3 (2 a 8): rotacao de 8 lugares para qualquer assento e o isIA
  -- viaja no snapshot (a placa de turno do cliente pinta IA de verdade).
  local p8 = jogo.criarPartida({ n = 8 })
  -- Sala real: host + 1 humano + 6 IAs (criarPartida ja marca i>1 como
  -- IA; so o seat 2 vira humano).
  p8.jogadores[2].isIA = false
  p8.vez = 7
  local snap8 = partidaRede.serializar(p8, 2, { duracao = 30, restante = 30 })
  check(snap8.n == 8, "serializar n=8 devolve n = " .. tostring(snap8.n))
  -- Visto do seat 2: display k = seat k => k=1:2, k=2:3, ...
  check(snap8.jogadores[1].nome == p8.jogadores[2].nome,
    "8p: proprio seat na posicao 1")
  check(snap8.jogadores[2].nome == p8.jogadores[3].nome,
    "8p: seat 3 na posicao 2")
  check(snap8.vez == 6, "8p: vez do seat 7 vista do 2 = 6 = "
    .. tostring(snap8.vez))
  check(snap8.jogadores[1].isIA == false and snap8.jogadores[2].isIA == true,
    "8p: isIA rotaciona junto (2 humano, 3 IA) = "
    .. tostring(snap8.jogadores[1].isIA) .. "/" ..
    tostring(snap8.jogadores[2].isIA))
  local m8 = partidaRede.montar(snap8)
  check(#m8.jogadores == 8, "montar n=8 = " .. #m8.jogadores)
  check(m8.vez == 6, "montar 8p mantem a vez rotacionada")
  check(m8.jogadores[1].isIA == false, "montar 8p: meu seat humano")
  check(m8.jogadores[2].isIA == true,
    "montar 8p: IA serializada = " .. tostring(m8.jogadores[2].isIA))
  check(m8.jogadores[8].isIA == false, "montar 8p: seat 1 na posicao 8")

  -- Fluxo novo: cada JOGAR leva 1 carta (ou ate 2) e o turno so encerra
  -- quando a quota CARTAS_POR_TURNO acaba. A 1a carta mantem a vez.
  -- (encerrarVez depois completa a mao ate 7 — por isso checamos a presenca
  -- do uid jogado, nao o tamanho da mao).
  local p = jogo.criarPartida()
  p.vez = 1
  -- Classes diferentes para este teste olhar SO a quota base da rede: a
  -- cadeia tem cobertura propria abaixo.
  p.jogadores[1].mao[1].classe = "Efeito"
  local uid = p.jogadores[1].mao[1].uid
  local r = partidaRede.aplicarAcao(p, 1, { tipo = "JOGAR", uids = { uid } })
  check(r.ok and r.entradas and #r.entradas == 1, "JOGAR valido devolve entradas")
  local voltou = false
  for _, c in ipairs(p.jogadores[1].mao) do
    if c.uid == uid then voltou = true end
  end
  check(not voltou, "JOGAR tira a carta da mao")
  check(p.vez == 1, "1o JOGAR mantem o turno (vez 1) = " .. tostring(p.vez))
  check(p.jogadasTurno == 1, "1o JOGAR conta 1 carta = " .. tostring(p.jogadasTurno))
  check(r.entradas[1].carta ~= nil and r.entradas[1].sucesso ~= nil,
    "entrada no formato do banner (carta + sucesso + chance)")
  p.jogadores[1].mao[1].classe = "Acao"
  local uid2 = p.jogadores[1].mao[1].uid
  local r2 = partidaRede.aplicarAcao(p, 1, { tipo = "JOGAR", uids = { uid2 } })
  check(r2.ok and r2.entradas and #r2.entradas == 1,
    "2o JOGAR valido devolve entradas")
  check(p.vez == 2, "2o JOGAR encerra o turno (vez 1 -> 2) = " .. tostring(p.vez))

  -- Recusas do JOGAR.
  local p2 = jogo.criarPartida()
  p2.vez = 1
  local maoCheia2 = #p2.jogadores[1].mao
  local u1 = p2.jogadores[1].mao[1].uid
  local u2 = p2.jogadores[1].mao[2].uid
  check(not partidaRede.aplicarAcao(p2, 1,
    { tipo = "JOGAR", uids = { "900-999" } }).ok, "JOGAR com uid desconhecido recusa")
  check(not partidaRede.aplicarAcao(p2, 2,
    { tipo = "JOGAR", uids = { u1 } }).ok, "JOGAR fora da vez recusa")
  check(not partidaRede.aplicarAcao(p2, 1,
    { tipo = "JOGAR", uids = { u1, u1 } }).ok, "JOGAR carta duplicada recusa")
  local u3 = p2.jogadores[1].mao[3].uid
  check(not partidaRede.aplicarAcao(p2, 1,
    { tipo = "JOGAR", uids = { u1, u2, u3 } }).ok, "JOGAR acima da quota recusa")
  check(p2.vez == 1 and #p2.jogadores[1].mao == maoCheia2,
    "recusas nao alteram o estado")

  -- GUARDAR: nao encerra o turno; PASSAR: encerra.
  local p3 = jogo.criarPartida()
  p3.vez = 1
  local maoCheia3 = #p3.jogadores[1].mao
  local uid3 = p3.jogadores[1].mao[1].uid
  local rG = partidaRede.aplicarAcao(p3, 1, { tipo = "GUARDAR", uid = uid3 })
  check(rG.ok and p3.jogadores[1].areaSegura[1] ~= nil, "GUARDAR guarda")
  check(p3.vez == 1 and #p3.jogadores[1].mao == maoCheia3 - 1,
    "GUARDAR NAO encerra o turno")
  check(partidaRede.aplicarAcao(p3, 1,
    { tipo = "GUARDAR", uid = p3.jogadores[1].mao[1].uid }).ok,
    "GUARDAR a 2a carta no mesmo turno")
  check(partidaRede.aplicarAcao(p3, 1,
    { tipo = "GUARDAR", uid = p3.jogadores[1].mao[1].uid }).ok,
    "GUARDAR a 3a carta no mesmo turno")
  check(#p3.jogadores[1].areaSegura == 3 and p3.vez == 1
    and p3.jogadasTurno == 0,
    "3 GUARDAR no mesmo turno nao encerram nem consomem quota")
  local rPE = partidaRede.aplicarAcao(p3, 2, { tipo = "PASSAR" })
  check(not rPE.ok, "PASSAR fora da vez recusa")
  local rP = partidaRede.aplicarAcao(p3, 1, { tipo = "PASSAR" })
  check(rP.ok and p3.vez == 2, "PASSAR encerra o turno")

  -- USAR_AREA: vale ate fora do turno e nao encerra.
  local p4 = jogo.criarPartida()
  p4.vez = 1
  local uid4 = p4.jogadores[1].mao[1].uid
  check(partidaRede.aplicarAcao(p4, 1, { tipo = "GUARDAR", uid = uid4 }).ok,
    "prepara a Area Segura")
  local rU = partidaRede.aplicarAcao(p4, 1, { tipo = "USAR_AREA", uid = uid4 })
  check(rU.ok and rU.entradas and #rU.entradas == 1, "USAR_AREA devolve entradas")
  check(p4.vez == 1, "USAR_AREA nao encerra o turno")
  check(not partidaRede.aplicarAcao(p4, 1,
    { tipo = "USAR_AREA", uid = uid4 }).ok, "USAR_AREA sem carta na area recusa")
  check(not partidaRede.aplicarAcao(p4, 9, { tipo = "PASSAR" }).ok,
    "assento invalido recusa")
  check(not partidaRede.aplicarAcao(p4, 1, { tipo = "OUTRA" }).ok,
    "tipo de mensagem desconhecido recusa")
  p4.fim = true
  check(not partidaRede.aplicarAcao(p4, 1, { tipo = "PASSAR" }).ok,
    "aplicar com partida fim recusa")

  -- Saida em partida: o flag saiu viaja no snapshot (o cliente tira o
  -- slot da arena) junto com falido (regras = eliminado) e o evento de
  -- saida chega ao cliente para o aviso no canto.
  local pS = jogo.criarPartida({ n = 3, nomes = { "H", "A", "B" } })
  pS.jogadores[2].saiu = true
  pS.jogadores[2].falido = true
  pS.saida = { nome = "A", seq = 1 }
  local snapS = partidaRede.serializar(pS, 1, { duracao = 30, restante = 30 })
  check(snapS.jogadores[2].saiu == true, "snapshot leva o flag saiu")
  check(snapS.saida and snapS.saida.nome == "A" and snapS.saida.seq == 1,
    "snapshot leva o evento de saida")
  local pM = partidaRede.montar(snapS)
  check(pM.jogadores[2].saiu == true and pM.jogadores[2].falido == true
    and pM.jogadores[2].status == "ELIMINADO",
    "montar preserva saiu/falido/ELIMINADO")
  check(pM.saida and pM.saida.seq == 1, "montar preserva o evento de saida")

  -- Protocolo de socket: INICIADO host -> cliente, acao cliente -> host,
  -- saida em partida (fila de saidas com seat fixo, SEM renumerar e SEM
  -- encerrar a partida do host) e saida do HOST (o cliente e que encerra).
  local porta = 49637
  local host = multiplayer.novo()
  host:iniciar({ nick = "HOST", avatar = "1" }, porta)
  check(host:criarSala() == true, "partida-rede: host cria sala")
  local cli = multiplayer.novo()
  cli:iniciar({ nick = "CLI", avatar = "2" }, porta)
  check(cli:conectar("127.0.0.1") == true, "partida-rede: cliente conecta")
  -- Terceiro jogador na sala: prova a saida com o seat dos outros FIXO
  -- (sem renumerar, que quebraria os assentos da partida).
  local cli2 = multiplayer.novo()
  cli2:iniciar({ nick = "CLI_B", avatar = "3" }, porta)
  check(cli2:conectar("127.0.0.1") == true,
    "partida-rede: segundo cliente conecta")

  local function bombeear(condicao)
    for _ = 1, 800 do
      host:atualizar(0.002)
      cli:atualizar(0.002)
      cli2:atualizar(0.002)
      if condicao and condicao() then return true end
      love.timer.sleep(0.002)
    end
    return false
  end

  bombeear(function()
    return cli:estado().telaInterna == "sala"
      and cli2:estado().telaInterna == "sala"
  end)
  check(cli:estado().telaInterna == "sala", "partida-rede: cliente na sala")
  check(cli:estado().meuAssento == 2 and cli2:estado().meuAssento == 3,
    "partida-rede: assentos 2 e 3 = " ..
    tostring(cli:estado().meuAssento) .. "/" ..
    tostring(cli2:estado().meuAssento))

  host:marcarPartida(true)
  check(host:emPartida(), "host marca emPartida")
  check(host:enviarPartida(2, { tipo = "INICIADO" }) == true,
    "host envia INICIADO ao assento 2")
  bombeear(function() return #cli:estado().filaPartida > 0 end)
  local fila = cli:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "INICIADO",
    "cliente recebeu INICIADO = " .. tostring(fila[1] and fila[1].msg.tipo))
  check(cli:emPartida() and cli:estado().telaInterna == "partida",
    "INICIADO marca o cliente em partida")
  check(#cli:consumirPartida() == 0, "consumirPartida esvazia a fila")

  -- PEDIR_SNAPSHOT (bootstrap do cliente): enquanto nao aplicar o primeiro
  -- SNAPSHOT o cliente reenvia sozinho a cada ~1s; o host recebe na fila de
  -- partida (o main responde com um SNAPSHOT so para este peer).
  check(cli:estado().sincronizado == false,
    "INICIADO (re)arma a espera de snapshot no cliente")
  bombeear(function() return #host:estado().filaPartida > 0 end)
  fila = host:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "PEDIR_SNAPSHOT",
    "cliente reenvia PEDIR_SNAPSHOT sozinho = " ..
    tostring(fila[1] and fila[1].msg.tipo))
  check(fila[1].id ~= 0,
    "PEDIR_SNAPSHOT identificado pelo id do peer = " ..
    tostring(fila[1] and fila[1].id))
  -- Marcar sincronizado (o main chama ao aplicar o SNAPSHOT) para o
  -- reenvio: 2s de bombeio sem novo pedido na fila do host.
  cli:marcarSincronizado()
  check(cli:estado().sincronizado == true,
    "marcarSincronizado liga a flag de sync")
  for _ = 1, 1000 do
    host:atualizar(0.002)
    cli:atualizar(0.002)
    love.timer.sleep(0.001)
  end
  check(#host:estado().filaPartida == 0,
    "sincronizado: cliente para de pedir snapshot")

  check(cli:enviarParaServidor({ tipo = "PASSAR" }) == true,
    "cliente manda PASSAR")
  bombeear(function() return #host:estado().filaPartida > 0 end)
  fila = host:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "PASSAR",
    "host recebeu a acao do cliente")
  check(fila[1].id ~= 0, "remetente identificado pelo id do peer = "
    .. tostring(fila[1].id))

  -- Leilao em rede: lance/confirmacao do cliente chegam ao host (o main
  -- aplica no leilao autoritativo e reenvia o snapshot rotacionado).
  check(cli:enviarParaServidor({ tipo = "LANCE_LEILAO", valor = 300 }) == true,
    "cliente manda LANCE_LEILAO")
  bombeear(function() return #host:estado().filaPartida > 0 end)
  fila = host:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "LANCE_LEILAO"
    and fila[1].msg.valor == 300,
    "host recebeu o lance do cliente = " ..
    tostring(fila[1] and fila[1].msg.tipo) .. "/" ..
    tostring(fila[1] and fila[1].msg.valor))
  check(cli:enviarParaServidor({ tipo = "CONFIRMAR_LEILAO" }) == true,
    "cliente manda CONFIRMAR_LEILAO")
  bombeear(function() return #host:estado().filaPartida > 0 end)
  fila = host:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "CONFIRMAR_LEILAO",
    "host recebeu a confirmacao do leilao = " ..
    tostring(fila[1] and fila[1].msg.tipo))

  -- Emoji na partida: cliente manda EMOJI e o host recebe na fila de
  -- partida (o main valida o codigo, cria o balao e transmite pra sala).
  check(cli:enviarParaServidor({ tipo = "EMOJI", codigo = 2 }) == true,
    "cliente manda EMOJI")
  bombeear(function() return #host:estado().filaPartida > 0 end)
  fila = host:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "EMOJI"
    and fila[1].msg.codigo == 2,
    "host recebeu o emoji com o codigo = " ..
    tostring(fila[1] and fila[1].msg.tipo) .. "/" ..
    tostring(fila[1] and fila[1].msg.codigo))
  check(fila[1].id ~= 0, "emoji identificado pelo id do peer = " ..
    tostring(fila[1] and fila[1].id))
  -- Codigo 5 (Marx da loja) atravessa a rede igual aos vetoriais.
  check(cli:enviarParaServidor({ tipo = "EMOJI", codigo = 5 }) == true,
    "cliente manda EMOJI codigo 5")
  bombeear(function() return #host:estado().filaPartida > 0 end)
  fila = host:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "EMOJI"
    and fila[1].msg.codigo == 5,
    "host recebeu o emoji do Marx (codigo 5)")
  -- Host -> cliente: o balao chega na fila de partida do cliente.
  check(host:enviarPartida(2,
    { tipo = "EMOJI", assento = 1, codigo = 1 }) == true,
    "host transmite o emoji ao assento 2")
  bombeear(function() return #cli:estado().filaPartida > 0 end)
  fila = cli:consumirPartida()
  check(#fila == 1 and fila[1].msg.tipo == "EMOJI"
    and fila[1].msg.assento == 1,
    "cliente recebeu o emoji do assento 1 = " ..
    tostring(fila[1] and fila[1].msg.assento))

  local okEnv, errEnv = host:enviarPartida(4, { tipo = "SNAPSHOT", p = {} })
  check(okEnv == nil and errEnv ~= nil, "enviarPartida sem peer devolve erro")

  -- Saida em partida: A PARTIDA DO HOST CONTINUA — o que saiu entra na
  -- fila de saidas (seat fixo, sem renumerar os outros) e some da sala.
  cli:fechar()
  bombeear(function() return #host:estado().filaSaios > 0 end)
  local saios = host:consumirSaios()
  check(#saios == 1 and saios[1].assento == 2 and saios[1].nome == "CLI",
    "saida em partida vai para a fila com seat/nome = " ..
    tostring(saios[1] and saios[1].assento) .. "/" ..
    tostring(saios[1] and saios[1].nome))
  check(host:partidaEncerrada() == nil,
    "saida de cliente NAO encerra a partida do host")
  local restantes = host:estado().jogadores
  check(#restantes == 2 and restantes[2].nome == "CLI_B"
    and restantes[2].assento == 3,
    "sem renumeracao em partida: CLI_B continua no seat 3 = " ..
    tostring(restantes[2] and restantes[2].assento))
  check(#host:consumirSaios() == 0, "consumirSaios esvazia a fila")

  -- Host sai: e o cliente em partida que encerra a partida local. O INICIADO
  -- vai para o seat 3 (o CLI ja saiu e fechou): se tivesse renumerado,
  -- esse envio daria erro.
  check(host:enviarPartida(3, { tipo = "INICIADO" }) == true,
    "host envia INICIADO ao assento 3 apos a saida do seat 2")
  bombeear(function() return cli2:estado().telaInterna == "partida" end)
  check(cli2:emPartida(), "INICIADO marca o segundo cliente em partida")
  host:fechar()
  bombeear(function() return cli2:partidaEncerrada() ~= nil end)
  check(cli2:partidaEncerrada() == "DESCONECTADO DO ANFITRIAO",
    "saida do HOST encerra a partida no cliente = " ..
    tostring(cli2:partidaEncerrada()))
  host:sair()
  check(host:estado().filaPartida[1] == nil, "sair limpa a fila de partida")
  check(host:estado().filaSaios[1] == nil, "sair limpa a fila de saidas")
  cli:fechar()
  cli2:fechar()
end

-- Embaralhada de assentos do multiplayer: sortea os assentos 2..total
-- entre os clientes remotos, devolve as cadeiras que viram IA e transmite
-- a SALA com o novo seuAssento de cada um (o fluxo que o cliente ja usa no
-- renumera de saida). O host fica sempre no 1.
local function testarEmbaralharAssentos()
  local m = multiplayer.novo()
  local enviadas = {}
  m.net = {
    enviar = function(_, id, msg)
      enviadas[#enviadas + 1] = { id = id, msg = msg }
      return true
    end,
  }
  m.st.papel = "anfitriao"
  m.st.jogadores = {
    { assento = 1, id = 0, nome = "HOST" },
    { assento = 2, id = 1, nome = "CLI_A" },
    { assento = 3, id = 2, nome = "CLI_B" },
  }

  -- Rand roteirizado (sempre 1): permutacao conhecida, sem aleatoriedade.
  local ia = m:embaralharAssentos(4, function() return 1 end)
  check(m.st.jogadores[1].assento == 1, "embaralhar: host fica no assento 1")
  check(m.st.jogadores[2].assento == 3 and m.st.jogadores[3].assento == 4,
    "embaralhar: clientes nos assentos 3 e 4 = "
    .. tostring(m.st.jogadores[2].assento) .. "/"
    .. tostring(m.st.jogadores[3].assento))
  check(#ia == 1 and ia[1] == 2,
    "embaralhar: IA na cadeira que sobrou = " .. tostring(ia[1]))
  check(#enviadas == 2, "embaralhar: SALA transmitida pros 2 clientes = "
    .. #enviadas)
  local c3, c4 = false, false
  for _, e in ipairs(enviadas) do
    if e.msg.tipo == "SALA" and e.msg.seuAssento == 3 then c3 = true end
    if e.msg.tipo == "SALA" and e.msg.seuAssento == 4 then c4 = true end
  end
  check(c3 and c4, "embaralhar: seuAssento 3 e 4 vieram na SALA")

  -- Rand real (8 lugares, 3 clientes): as propriedades precisam valer para
  -- QUALQUER ordem sorteada — teste nao pode ser flaky.
  for tentativa = 1, 20 do
    local st = {
      { assento = 1, id = 0 },
      { assento = 2, id = 1 },
      { assento = 3, id = 2 },
    }
    m.st.jogadores = st
    local ia8 = m:embaralharAssentos(8)
    local visto = {}
    local ok = true
    for _, j in ipairs(st) do
      if j.assento < 1 or j.assento > 8 or visto[j.assento] then ok = false end
      visto[j.assento] = true
    end
    check(ok and st[1].assento == 1,
      "embaralhar(" .. tentativa .. "): permutacao com host no 1")
    check(#ia8 == 5, "embaralhar(" .. tentativa .. "): 5 IAs = " .. #ia8)
    local okIA = true
    for _, s in ipairs(ia8) do
      if s < 2 or s > 8 or visto[s] then okIA = false end
      visto[s] = true
    end
    local n = 0
    for _ in pairs(visto) do n = n + 1 end
    check(okIA and n == 8,
      "embaralhar(" .. tentativa .. "): IAs nas cadeiras livres = "
      .. #ia8 .. " cobertos " .. n)
  end
end

-- som.lua: contrato da API em MODO_TESTE (tudo no-op, sem audio) — garante
-- que carregar/tocar/mudo existem e nao estouram com love.audio mudo.
local function testarSom()
  local ok, somMod = pcall(require, "som")
  check(ok and type(somMod) == "table", "som: require devolve tabela")
  if not ok then return end
  check(type(somMod.carregar) == "function", "som: carregar existe")
  check(type(somMod.tocar) == "function", "som: tocar existe")
  check(type(somMod.definirMudo) == "function", "som: definirMudo existe")
  check(type(somMod.estaMudo) == "function", "som: estaMudo existe")
  check(type(somMod.musica) == "function", "som: musica existe")
  check(type(somMod.pararMusica) == "function", "som: pararMusica existe")
  somMod.carregar()
  local fM = io.open("sons/menu.wav", "rb")
  check(fM ~= nil, "som: menu.wav existe")
  if fM then fM:close() end
  somMod.musica("menu")
  check(somMod.musicaUltima == "menu", "som: musicaUltima registra menu")
  -- Vento da selecao de ciclos: trilha propria (loop de ambiencia).
  local fV = io.open("sons/vento.wav", "rb")
  check(fV ~= nil, "som: vento.wav existe")
  if fV then fV:close() end
  somMod.musica("vento")
  check(somMod.musicaUltima == "vento", "som: musicaUltima registra vento")
  somMod.pararMusica()
  somMod.tocar("clique")
  somMod.tocar("roleta")
  somMod.tocar("festa")
  somMod.tocar("passo")
  check(somMod.ultimo == "passo", "som: ultimo registra passo")
  local fP = io.open("sons/passo.wav", "rb")
  check(fP ~= nil, "som: passo.wav existe")
  if fP then fP:close() end
  somMod.tocar("psicar")
  check(somMod.ultimo == "psicar", "som: ultimo registra psicar")
  local fPs = io.open("sons/psicar.wav", "rb")
  check(fPs ~= nil, "som: psicar.wav existe")
  if fPs then fPs:close() end
  somMod.tocar("inexistente")
  check(somMod.estaMudo() == false, "som: comeca sem mudo")
  somMod.definirMudo(true)
  check(somMod.estaMudo() == true, "som: mudo liga")
  somMod.tocar("turno")
  somMod.definirMudo(false)
  check(somMod.estaMudo() == false, "som: mudo desliga")

  -- Carregamento da rede: 6s exatos e no-op nos smokes/testes.
  local carga = require "carregamento_rede"
  carga.limpar()
  check(not carga.ativo(), "carregamento: comeca inativo")
  carga.iniciar()
  check(carga.ativo(), "carregamento: iniciar liga a tela")
  carga.atualizar(5.9)
  check(carga.ativo(), "carregamento: continua ativo antes dos 6s")
  carga.atualizar(0.2)
  check(not carga.ativo(), "carregamento: encerra depois dos 6s")
  check(carga.pular(), "carregamento: testes pulam a tela")
end

-- dialogo.lua: animacao do ADAM — boca em loop (neutro -> boca leve ->
-- boca aberta -> boca media -> retorno) so enquanto a fala dele esta
-- sendo digitada, e piscada (neutro -> piscando) parado; quadros
-- carregados ao abrir a cena e descartados ao fechar (~90 MB que nao
-- podem ficar na memoria).
local function testarDialogoAnimacao()
  check(dialogo.quadroAdam() == nil,
    "dialogo: quadro Adam nil com a cena fechada")
  dialogo.iniciar({ nome = "Teste" })
  check(dialogo.ativo(), "dialogo: iniciar abre a cena")
  check(arte.adamDialogo("neutro") ~= nil,
    "dialogo: quadro neutro carregado ao iniciar")
  check(arte.cenarioDialogo() ~= nil,
    "dialogo: cenario carregado ao iniciar")

  -- Fala do jogador em cartaz: Adam parado, alem da pausa cai na piscada.
  check(dialogo.quadroAdam() == "neutro",
    "dialogo: parado comeca no neutro (veio "
      .. tostring(dialogo.quadroAdam()) .. ")")
  dialogo.atualizar(2.1 + 0.05)
  check(dialogo.quadroAdam() == "piscando",
    "dialogo: parado alem da pausa pisca (veio "
      .. tostring(dialogo.quadroAdam()) .. ")")
  dialogo.atualizar(0.15) -- passa da virada do ciclo (2.15 + 0.15 > 2.24)
  check(dialogo.quadroAdam() == "neutro",
    "dialogo: fim da piscada volta ao neutro (veio "
      .. tostring(dialogo.quadroAdam()) .. ")")

  -- Passa para a fala do ADAM (idx 6, "Homens lutando...": 38 chars,
  -- tempo de datilografo de mais de uma volta inteira de boca). Cada par
  -- de cliques sobe uma linha: 1o clique completa, 2o avanca.
  for _ = 1, 10 do dialogo.clique(0, 0) end
  dialogo.atualizar(0.01)
  check(dialogo.quadroAdam() == "neutro",
    "dialogo: boca comeca no neutro (veio "
      .. tostring(dialogo.quadroAdam()) .. ")")
  dialogo.atualizar(0.111)
  check(dialogo.quadroAdam() == "bocaLeve",
    "dialogo: boca 2 = bocaLeve (veio " .. tostring(dialogo.quadroAdam())
      .. ")")
  dialogo.atualizar(0.11)
  check(dialogo.quadroAdam() == "bocaAberta",
    "dialogo: boca 3 = bocaAberta (veio " .. tostring(dialogo.quadroAdam())
      .. ")")
  dialogo.atualizar(0.11)
  check(dialogo.quadroAdam() == "bocaMedia",
    "dialogo: boca 4 = bocaMedia (veio " .. tostring(dialogo.quadroAdam())
      .. ")")
  dialogo.atualizar(0.11)
  check(dialogo.quadroAdam() == "retorno",
    "dialogo: boca 5 = retorno (veio " .. tostring(dialogo.quadroAdam())
      .. ")")
  dialogo.atualizar(0.11)
  check(dialogo.quadroAdam() == "neutro",
    "dialogo: boca loop volta ao neutro (veio "
      .. tostring(dialogo.quadroAdam()) .. ")")

  -- Linha digitada por inteiro: boca para e ele volta a piscar parado.
  dialogo.clique(0, 0)
  dialogo.atualizar(2.1 + 0.05)
  check(dialogo.quadroAdam() == "piscando",
    "dialogo: linha pronta Adam volta a piscar (veio "
      .. tostring(dialogo.quadroAdam()) .. ")")

  dialogo.limpar()
  check(not dialogo.ativo(), "dialogo: limpar fecha a cena")
  check(arte.adamDialogo("neutro") == nil,
    "dialogo: quadros do Adam liberados ao fechar")
  check(arte.adamDialogo("piscando") == nil,
    "dialogo: piscando tambem liberada ao fechar")
  check(arte.cenarioDialogo() == nil,
    "dialogo: cenario liberado ao fechar")
end

-- selecao.lua: caminho das ilhas do modo um jogador. As setas laterais
-- folheiam (Ciclo I -> Ciclo 2 - A EFICIENCIA) e param nas pontas; cada
-- ciclo tem a sua fila (Ciclo I: 7 nos ate o Adam; Ciclo 2: 6 nos ate o
-- Frederick Taylor, o soberano) e o seu save de progresso.
local function testarSelecaoCiclos()
  selecao.iniciar()
  check(selecao.totalCiclos() == 2, "selecao: duas ilhas no caminho")
  check(selecao.cicloAtual() == 1, "selecao: abre na ilha do Ciclo I")
  check(selecao.ciclo().arte == "sel_ilha_1"
    and selecao.ciclo().nome == "O REINO ESQUECIDO"
    and selecao.totalInimigos() == 7,
    "selecao: Ciclo I = reino esquecido com 7 nos")
  check(arte.img("sel_ilha_1") ~= nil and arte.img("sel_ilha_2") ~= nil,
    "selecao: artes das duas ilhas carregadas")
  check(selecao.trocarCiclo(-1) == false and selecao.cicloAtual() == 1,
    "selecao: seta esquerda na primeira ilha nao anda")
  check(selecao.trocarCiclo(0) == false and selecao.cicloAtual() == 1,
    "selecao: passo zero nao navega")
  check(selecao.trocarCiclo(1) == true and selecao.cicloAtual() == 2,
    "selecao: seta direita folheia para o Ciclo 2")
  check(selecao.selecionarCiclo(1) == true and selecao.cicloAtual() == 1,
    "selecao: selecionarCiclo vai direto para a ilha pedida")
  check(selecao.selecionarCiclo(1) == false
    and selecao.selecionarCiclo(9) == false,
    "selecao: selecionarCiclo ignora a mesma ilha e indice fora da faixa")
  selecao.selecionarCiclo(2)
  check(selecao.ciclo().arte == "sel_ilha_2"
    and selecao.ciclo().nome == "A EFICIENCIA"
    and selecao.totalInimigos() == 6,
    "selecao: Ciclo 2 = a eficiencia com 6 nos")

  -- Fila do Ciclo 2 na ordem pedida, com o Taylor como soberano no fim.
  local nomes2 = {
    "Operario Desgastado", "Fiscal de Produtividade", "Esteira Faminta",
    "Relogio Fiscal", "Capataz da Meta Impossivel", "Frederick Taylor",
  }
  local ordemOk, avataresOk = true, true
  for i, nome in ipairs(nomes2) do
    local inim = selecao.inimigo(i)
    if not inim or inim.nome ~= nome then ordemOk = false end
    if not inim or inim.avatar ~= ("inimigo2_" .. i) then avataresOk = false end
  end
  check(ordemOk, "selecao: fila do Ciclo 2 na ordem dos sprites")
  check(avataresOk, "selecao: cada no do Ciclo 2 usa o avatar inimigo2_N")
  check(selecao.inimigo(6).soberano == true
    and selecao.inimigo(6).dialogo == nil,
    "selecao: Taylor e o soberano do Ciclo 2 (sem a conversa do Adam)")
  check(selecao.inimigo(7).nome == "Frederick Taylor",
    "selecao: inimigo(7) no Ciclo 2 cai no ultimo no (6)")
  check(selecao.rotuloNo(6) == "??????"
    and selecao.rotuloNo(5) == "CAPATAZ DA META IMPOSSIVEL",
    "selecao: nome do soberano oculto ate o primeiro enfrentamento")

  -- A ilha do Ciclo 2 abre a roda e o primeiro no ja duela.
  check(selecao.clicado(407, 214) == nil,
    "selecao: clique na ilha do Ciclo 2 nao devolve acao")
  for _ = 1, 40 do selecao.atualizar(1 / 60) end
  check(selecao.clicado(selecao.coordsNo(1)) == "iniciar",
    "selecao: primeiro no do Ciclo 2 abre o duelo")
  check(selecao.dueloAtual() and selecao.dueloAtual().avatar == "inimigo2_1",
    "selecao: dueloAtual aponta o operario do Ciclo 2")
  check(selecao.clicado(selecao.coordsNo(2)) == nil,
    "selecao: segundo no do Ciclo 2 comeca bloqueado")

  -- Progresso separado por ciclo: a vitoria grava no save do ciclo em foco.
  selecao.vitoria()
  check(selecao.progresso() == 1 and selecao.progressoDoCiclo(2) == 1,
    "selecao: vitoria no Ciclo 2 grava o progresso do Ciclo 2")
  check(selecao.progressoDoCiclo(1) == 0,
    "selecao: progresso do Ciclo 2 nao vaza para o Ciclo I")
  selecao.selecionarCiclo(1)
  check(selecao.progresso() == 0,
    "selecao: Ciclo I continua zerado depois do duelo do Ciclo 2")
  selecao.selecionarCiclo(2)
  check(selecao.progresso() == 1,
    "selecao: voltar ao Ciclo 2 mantem o progresso dele")

  -- PROXIMO OPONENTE (botao do painel de vitoria): avanca para o no
  -- seguinte ja liberado e para quando a fila acaba no soberano.
  selecao.iniciar()
  selecao.selecionarCiclo(2)
  check(selecao.temProximo() == false and selecao.proximoNo() == nil,
    "selecao: sem duelo escolhido nao ha proximo oponente")
  selecao.clicado(407, 214)
  for _ = 1, 40 do selecao.atualizar(1 / 60) end
  check(selecao.clicado(selecao.coordsNo(1)) == "iniciar",
    "selecao: no 1 do Ciclo 2 nao abriu para o teste do proximo")
  selecao.vitoria()
  check(selecao.temProximo() == true
    and selecao.proximoNo().nome == "Fiscal de Produtividade",
    "selecao: proximoNo leva ao no 2 do Ciclo 2")
  for _ = 1, 5 do
    selecao.vitoria()
    if selecao.temProximo() then selecao.proximoNo() end
  end
  check(selecao.progresso() == 6 and selecao.temProximo() == false
    and selecao.proximoNo() == nil,
    "selecao: sem proximo oponente depois do soberano (prog="
    .. tostring(selecao.progresso()) .. ")")

  -- O reset das configuracoes apaga o progresso de todos os ciclos.
  selecao.redefinirProgresso()
  check(selecao.progresso() == 0 and selecao.progressoDoCiclo(1) == 0,
    "selecao: reset apaga o progresso de todos os ciclos")

  check(selecao.trocarCiclo(1) == false and selecao.cicloAtual() == 2,
    "selecao: seta direita na ultima ilha nao anda")
  check(selecao.trocarCiclo(-1) == true and selecao.cicloAtual() == 1,
    "selecao: seta esquerda volta para o Ciclo I")
  selecao.iniciar()
  check(selecao.cicloAtual() == 1 and selecao.progresso() == 0,
    "selecao: iniciar volta ao Ciclo I zerado (MODO_TESTE)")

  -- Tela SOBRE (criadores, site reservado e versao).
  local sobre = require "sobre"
  sobre.abrir()
  check(#sobre.CRIADORES == 5, "sobre: 5 criadores")
  check(sobre.CRIADORES[1].nome == "DANIEL VITOR"
    and sobre.CRIADORES[2].nome == "DAVI SOUSA"
    and sobre.CRIADORES[3].nome == "MARCELL COSTA"
    and sobre.CRIADORES[4].nome == "DANILO NUNES"
    and sobre.CRIADORES[5].nome == "KAUA KENNEDY",
    "sobre: Marcell no meio e nomes na ordem pedida")
  check(sobre.CRIADORES[3].papel == "programador, designer, roteirista"
    and sobre.CRIADORES[5].papel == "roteirista", "sobre: papeis")
  check(sobre.CRIADORES[2].fotoAncoraY == 0, "sobre: foto do Davi no topo")
  check(#sobre.RET_CARDS == 5, "sobre: 5 cartoes com retrato")
  check(sobre.VERSAO == "VERSÃO 1.0", "sobre: versao 1.0")
  local rVoltar = sobre.RET_VOLTAR
  check(sobre.clicado(rVoltar.x + 4, rVoltar.y + 4) == "voltar",
    "sobre: botao voltar")
  local rSite = sobre.RET_SITE
  check(sobre.clicado(rSite.x + 4, rSite.y + 4) == "site",
    "sobre: area do site reservada")
  check(sobre.clicado(4, 4) == nil, "sobre: clique fora sem acao")

  -- Tutorial de primeiro acesso: 5 lições, duelo assistido e vitoria.
  local onb = require "onboarding"
  check(onb.precisa() == false, "tutorial: nao dispara em MODO_TESTE")
  onb.iniciar()
  local passos = 0
  local acao = nil
  while passos < 40 do
    acao = onb.avancar()
    passos = passos + 1
    if acao == "batalha" then break end
  end
  check(acao == "batalha", "tutorial: licoes levam ao duelo (" .. passos .. " passos)")
  check(passos == 24, "tutorial: 6 licoes com 4 falas cada")
  onb.ativarBatalha()
  check(onb.emBatalha() == true, "tutorial: duelo assistido ativo")

  local eu = { nome = "JOGADOR_1", saldo = 100, falido = false }
  local ia = { nome = "ADAM", saldo = 5000, falido = false }
  local p = { jogadores = { eu, ia }, fim = true, vencedor = ia, turno = 10,
    maxTurnos = 10, ordemJogadas = {}, registro = {}, log = {} }
  onb.atualizarBatalha(0.016, p)
  check(p.fim == true and p.vencedor == eu and eu.saldo >= 1200,
    "tutorial: mao garante a vitoria do jogador")
  onb.vitoria()
  check(onb.finalizado() == true, "tutorial: vitoria marca como concluido")
end

function T.rodar()
  total, falhas = 0, 0
  print("== Testes do prototipo LOVE ==")

  local sucederam, err = pcall(function()
    testarFormatoImagens()
    testarBaralho()
    testarSorteioPonderado()
    testarCamposCartas()
    testarCriarPartida()
    testarSucessoFalha()
    testarQuotaTurno()
    testarProtecao()
    testarEfeitos()
    testarDinheiroAdiado()
    testarDoacao()
    testarRouboCartas()
    testarRouboEscolhido()
    testarAreaSegura()
    testarDescartaEPuxa()
    testarPresenteNoel()
    testarEventoDeusMercado()
    testarIAGuardarArea()
    testarDuracaoTurno()
    testarFalencia()
    testarRendaELivroCaixa()
    testarCombinacoes()
    testarDefesaDuracao()
    testarBonusCopia()
    testarConstantesV7()
    testarTetoMao()
    testarTurnoExclusivoDasCartas()
    testarOcultarSaldos()
    testarVisorDeCuringas()
    testarSatisfacao()
    testarSatisfacaoMAX()
    testarProdutividade()
    testarFusao()
    testarLeilao()
    testarLojinha()
    testarSimulacaoMeta()
    testarMetaPendente()
    testarFimPorTempo()
    testarVezPulaSaiu()
    testarArenaN()
    testarArenaMenu()
    testarAnim()
    testarPartidasCompletas()
    testarPartidasCompletasN()
    testarPerfil()
    testarComprasAvatares()
    testarCompraEmojiMarx()
    testarHabilidadesAvatar()
    testarJson()
    testarRede()
    testarDescoberta()
    testarArenas()
    testarMultiplayer()
    testarEmbaralharAssentos()
    testarSom()
    testarPartidaRede()
    testarDialogoAnimacao()
    testarSelecaoCiclos()
  end)

  if not sucederam then
    falhas = falhas + 1
    print("[ERRO] excecao: " .. tostring(err))
  end

  print(string.format("Resultado: %d testes, %d falhas", total, falhas))
  return falhas == 0
end

return T
