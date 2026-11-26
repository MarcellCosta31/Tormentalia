-- Tutorial de primeiro acesso: a mao do Deus Mercado apresenta as regras
-- (tipos de carta, Area Segura, slot de Defesa, Satisfacao e Produtividade),
-- depois acompanha um duelo simulado contra a IA e garante a vitoria.
-- So roda uma vez: marca tutorial_concluido.txt no diretorio de save.
local ui = require "ui"
local arte = require "arte"
local cartas = require "cartas"
local jogo = require "jogo"

local O = {}

local VW, VH = 1280, 720
local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local ARQ = "tutorial_concluido.txt"

local OURO = ui.hex "#FFD54F"
local OURO_SUAVE = ui.hex "#FFE9A6"
local ROSA = ui.hex "#FF5FD2"
local TXT = ui.hex "#D8DCEC"
local FUNDO = ui.hex "#08060E"
local PAINEL = ui.hex "#10152A"
local BORDA = ui.hex "#7A5C29"
local SOMBRA = { 0, 0, 0, 0.35 }

-- Mesma paleta ja usada nas barras reais de Satisfacao/Produtividade do HUD,
-- pra a previa do tutorial ja "ensaiar" a cara que o jogador vai ver depois.
local BARRA_MOLDURA = ui.hex "#3b3b40"
local BARRA_PRETO = ui.hex "#020002"
local BARRA_VAZIO = ui.hex "#201810"
local BARRA_DOURADO = ui.hex "#f7b53a"
local BARRA_DOURADO_CL = ui.hex "#ffe08a"
local BARRA_VERDE = ui.hex "#4b8a3a"
local BARRA_VERMELHO = ui.hex "#d92a1e"
local BARRA_CREME = ui.hex "#f4dfae"

-- Capturas reais do jogo (recortadas de partidas) para as ilustracoes.
local fotosReais = {}
local function fotoReal(nome)
  if fotosReais[nome] == nil then
    local ok, img = pcall(love.graphics.newImage, "arte/tutorial/" .. nome)
    fotosReais[nome] = ok and img or false
  end
  return fotosReais[nome] or nil
end

local ordem = { "intro", "turno", "cartas", "area", "defesa", "barras" }

-- Uma carta real de cada classe para a licao dos tipos.
local TIPOS_ARTE = {
  { nome = "ACAO", id = 23 },
  { nome = "EFEITO", id = 2 },
  { nome = "DEFESA", id = 8 },
  { nome = "CURINGA", id = 51 },
}

local LICOES = {
  intro = {
    titulo = "O DEUS MERCADO",
    linhas = {
      "Eu sou o Deus Mercado - e vou te ensinar a sobreviver aqui.",
      "Toda empresa comeca com R$ 2.000, 7 cartas e 10 turnos.",
      "Quem terminar com mais dinheiro vence. Simples assim.",
      "Preste atencao: o mercado nao perdoa quem joga sem saber.",
    },
  },
  turno = {
    titulo = "PAINEL DE TURNO",
    linhas = {
      "Este e o painel de turno: mostra de quem e a vez e em qual rodada voce esta.",
      "A partida tem 10 turnos. O numero mostra quantos se passaram ate agora.",
      "JOGADAS mostra quantas cartas voce ainda pode jogar neste turno.",
      "PARA A ESQUERDA e o sentido da vez. PASSAR encerra o seu turno.",
    },
  },
  cartas = {
    titulo = "TIPOS DE CARTA",
    linhas = {
      "ACAO move dinheiro: voce ganha, rouba ou derruba o saldo de alguem.",
      "EFEITO mexe com a mesa: mao, chances, turnos e satisfacao.",
      "DEFESA protege o seu caixa. Curinga muda as regras para todo mundo.",
      "Cartas da mesma classe em sequencia formam uma cadeia e dao jogadas extras.",
    },
  },
  area = {
    titulo = "AREA SEGURA",
    linhas = {
      "Aqui embaixo ficam os 3 slots da AREA SEGURA.",
      "Guardar uma carta nao gasta a sua quota de 2 cartas por turno.",
      "Voce pode jogar uma carta guardada ate fora do seu turno, como reacao.",
      "Use isso para segurar uma defesa ate o momento certo.",
    },
  },
  defesa = {
    titulo = "SLOT DE DEFESA",
    linhas = {
      "O slot de DEFESA guarda uma unica carta de protecao.",
      "Ela dura 2 turnos e bloqueia um ataque direcionado a voce.",
      "Uma defesa nova substitui a antiga, que vai para o descarte.",
      "Nem toda carta ruim precisa de defesa: as vezes vale mais atacar.",
    },
  },
  barras = {
    titulo = "SATISFACAO E PRODUTIVIDADE",
    linhas = {
      "A SATISFACAO vai de 0 a 200. Em 0 voce entra em greve e perde o turno.",
      "Em 200, suas proximas 2 cartas tem efeitos dobrados.",
      "A PRODUTIVIDADE multiplica a renda de cada rodada.",
      "Cuide das duas: equipe um time feliz e uma empresa produtiva.",
    },
  },
}

local DICAS = {
  "Selecione uma carta da mao e clique em JOGAR. Voce tem 2 jogadas por turno.",
  "Jogue cartas da mesma classe em sequencia para ganhar jogadas extras.",
  "Guarde uma carta na AREA SEGURA - isso nao gasta sua quota.",
  "Uma DEFESA no slot protege seu caixa por 2 turnos.",
  "Observe SAT (0 a 200) e PROD: as duas mexem na sua renda.",
  "Vamos la. Eu estou aqui para ajudar - e nao vou deixar voce perder.",
}

local fase = "intro"
local linha = 1
local tempo = 0
local emBatalha = false
local dica = 1
local dicaTempo = 0
local finalizado = false

local function porCima(x, y, r)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function O.precisa()
  if MODO_TESTE then return false end
  local ok, dados = pcall(love.filesystem.read, ARQ)
  return not (ok and dados and dados:match("1"))
end

function O.iniciar()
  fase = "intro"
  linha = 1
  tempo = 0
  emBatalha = false
  dica = 1
  dicaTempo = 0
  finalizado = false
end

-- Util para capturas/testes: abre direto uma licao especifica.
function O.definirFase(nome)
  if LICOES[nome] then
    fase = nome
    linha = 1
  end
end

function O.marcarConcluido()
  finalizado = true
  if not MODO_TESTE then pcall(love.filesystem.write, ARQ, "1") end
end

function O.finalizado() return finalizado end
function O.emBatalha() return emBatalha end

function O.ativarBatalha()
  emBatalha = true
  fase = "batalha"
  dica = 1
  dicaTempo = 0
end

function O.avancar()
  if fase == "vitoria" or fase == "final" then
    O.marcarConcluido()
    return "menu"
  end
  if fase == "batalha" then return nil end

  local lic = LICOES[fase]
  if not lic then return nil end
  if linha < #lic.linhas then
    linha = linha + 1
    return "falha"
  end
  for i, nome in ipairs(ordem) do
    if nome == fase then
      if i < #ordem then
        fase = ordem[i + 1]
        linha = 1
        return "falha"
      end
      return "batalha"
    end
  end
  return nil
end

function O.clicado(x, y)
  if fase == "batalha" then return nil end
  if fase == "vitoria" then return O.avancar() end
  -- qualquer toque na tela avanca a fala
  if x >= 0 and x <= VW and y >= 0 and y <= VH then return O.avancar() end
  return nil
end

function O.tecla(key)
  if key == "return" or key == "kpenter" or key == "space" then
    return O.avancar()
  end
  if key == "escape" then
    O.marcarConcluido()
    return "menu"
  end
  return nil
end

function O.atualizar(dt)
  tempo = tempo + dt
  if fase == "batalha" then
    dicaTempo = dicaTempo + dt
    if dicaTempo >= 9 then
      dicaTempo = 0
      dica = math.min(#DICAS, dica + 1)
    end
  end
end

-- Garante que o jogador venca: a mao corrige o saldo e, se a partida
-- terminar de qualquer outro jeito, decide a vitoria por eliminacao.
function O.atualizarBatalha(dt, p)
  if not p or not p.jogadores or #p.jogadores < 2 then return end
  local eu, ia = p.jogadores[1], p.jogadores[2]
  if not eu or not ia then return end

  if not p.fim then
    if (eu.saldo or 0) < 700 then eu.saldo = 700 end
    if (ia.saldo or 0) > (eu.saldo or 0) + 900 then
      ia.saldo = (eu.saldo or 0) + 900
    end
  else
    if p.vencedor ~= eu then
      p.fim = nil
      p.vencedor = nil
      p.motivo = nil
      eu.falido = false
      eu.saldo = math.max(eu.saldo or 0, 1200)
      ia.falido = true
      ia.saldo = 0
      jogo.verificarFim(p)
    end
  end
end

function O.vitoria()
  fase = "vitoria"
  emBatalha = false
  O.marcarConcluido()
end

-- CantosDecorativos: 4 "L" dourados nos cantos, mesmo vocabulario pixel-art
-- ja usado nas outras telas do jogo (perfil.lua, sobre.lua).
local function cantos(x, y, w, h, cor, tam, offset, lw)
  tam = tam or 10
  offset = offset or 3
  lw = lw or 2
  love.graphics.setLineWidth(lw)
  love.graphics.setColor(cor)
  local function l(px, py, sx, sy)
    love.graphics.line(px, py, px + sx * tam, py)
    love.graphics.line(px, py, px, py + sy * tam)
  end
  l(x - offset, y - offset, 1, 1)
  l(x + w + offset, y - offset, -1, 1)
  l(x - offset, y + h + offset, 1, -1)
  l(x + w + offset, y + h + offset, -1, -1)
  love.graphics.setLineWidth(1)
end

local function diamante(cx, cy, d, cor)
  love.graphics.setColor(cor)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(math.rad(45))
  love.graphics.rectangle("fill", -d / 2, -d / 2, d, d)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1)
end

-- Indicador de progresso das 5 licoes (losango cheio = concluida/atual,
-- contorno = ainda por vir). So faz sentido fora da batalha/vitoria.
local function desenharProgresso(cx, y)
  local indiceAtual = 1
  for i, nome in ipairs(ordem) do
    if nome == fase then indiceAtual = i end
  end
  local passo = 30
  local x0 = cx - (#ordem - 1) * passo / 2
  for i = 1, #ordem do
    local x = x0 + (i - 1) * passo
    if i < indiceAtual then
      diamante(x, y, 9, OURO)
    elseif i == indiceAtual then
      diamante(x, y, 12, OURO_SUAVE)
      love.graphics.setLineWidth(1.5)
      love.graphics.setColor(OURO)
      love.graphics.push()
      love.graphics.translate(x, y)
      love.graphics.rotate(math.rad(45))
      love.graphics.rectangle("line", -8, -8, 16, 16)
      love.graphics.pop()
    else
      love.graphics.setLineWidth(1.5)
      love.graphics.setColor(BORDA)
      love.graphics.push()
      love.graphics.translate(x, y)
      love.graphics.rotate(math.rad(45))
      love.graphics.rectangle("line", -5, -5, 10, 10)
      love.graphics.pop()
    end
  end
  love.graphics.setColor(1, 1, 1)
end

local function desenharMao(x, y, escala)
  local img = arte.img("deus_mao")
  if not img then return end
  local bob = math.sin(tempo * 1.8) * 6
  local iw, ih = img:getDimensions()
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.draw(img, x, y + bob, 0,
    escala * 320 / iw, escala * 320 / ih)
  love.graphics.setColor(1, 1, 1)
end

local function desenharFala(texto, titulo, altura)
  local bx, by, bw, bh = 40, VH - altura - 40, VW - 80, altura
  love.graphics.setColor(SOMBRA)
  love.graphics.rectangle("fill", bx + 4, by + 6, bw, bh, 14, 14)
  ui.caixa(bx, by, bw, bh, 14, PAINEL, BORDA, 2)
  ui.arestas(bx + 6, by + 6, bw - 12, bh - 12, 10, OURO, 2)
  cantos(bx, by, bw, bh, OURO_SUAVE, 14, 4, 2)

  ui.txtEspacado(titulo or "DEUS MERCADO", bx + 26, by + 18, 18, OURO, 2, bw - 52)
  love.graphics.setColor(OURO[1], OURO[2], OURO[3], 0.35)
  love.graphics.rectangle("fill", bx + 26, by + 44, 150, 1)
  diamante(bx + 26 + 150 + 8, by + 44, 5, OURO)

  ui.txt(texto, bx + 26, by + 52, 20, TXT, "left", bw - 52)

  -- pisca suave no aviso de "continuar", pra puxar o olho sem distrair
  local alpha = 0.55 + math.sin(tempo * 3) * 0.25
  ui.txt("TOQUE OU PRESSIONE ENTER PARA CONTINUAR", bx + 26,
    by + bh - 30, 12, { 0.56, 0.58, 0.68, alpha }, "left", bw - 52)
end

local function desenharBarraMock(x, y, w, h, tipo)
  love.graphics.setColor(BARRA_MOLDURA)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(2)
  love.graphics.setColor(BARRA_PRETO)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)

  local pad = 3
  local ix, iy, iw, ih = x + pad, y + pad, w - pad * 2, h - pad * 2
  love.graphics.setColor(BARRA_VAZIO)
  love.graphics.rectangle("fill", ix, iy, iw, ih)

  if tipo == "satisfacao" then
    -- previa em 100/200: metade da barra, com brilho na borda do avanco
    local fillW = iw * 0.5
    love.graphics.setColor(BARRA_DOURADO)
    love.graphics.rectangle("fill", ix, iy, fillW, ih)
    love.graphics.setColor(BARRA_DOURADO_CL)
    love.graphics.rectangle("fill", ix, iy, 3, ih)
    love.graphics.setColor(BARRA_DOURADO_CL)
    love.graphics.rectangle("fill", ix + fillW - 2, iy, 2, ih)
  else
    -- produtividade: centrada em 0%, pode ir pros dois lados
    local meio = ix + iw / 2
    local chunk = iw * 0.1
    love.graphics.setColor(BARRA_VERMELHO)
    love.graphics.rectangle("fill", meio - chunk, iy, chunk, ih)
    love.graphics.setColor(BARRA_VERDE)
    love.graphics.rectangle("fill", meio, iy, chunk, ih)
    love.graphics.setColor(BARRA_CREME)
    love.graphics.rectangle("fill", meio - 1.5, iy - 2, 3, ih + 4)
  end
  love.graphics.setColor(1, 1, 1)
end

function O.desenhar()
  love.graphics.setColor(0, 0, 0, 0.82)
  ui.preencherTela(VW, VH)

  if fase == "vitoria" then
    local px, py, pw, ph = 120, 150, VW - 240, 380
    love.graphics.setColor(SOMBRA)
    love.graphics.rectangle("fill", px + 6, py + 10, pw, ph, 16, 16)
    ui.caixa(px, py, pw, ph, 16, PAINEL, BORDA, 2)
    ui.arestas(px + 6, py + 6, pw - 12, ph - 12, 12, OURO, 2)
    cantos(px, py, pw, ph, OURO_SUAVE, 18, 5, 3)

    local cx = VW / 2
    ui.txtEspacado("VOCE VENCEU!", 120, 196, 42, OURO, 4, VW - 240)
    diamante(cx - 230, 214, 8, OURO)
    diamante(cx + 230, 214, 8, OURO)
    ui.txt("A mao do Deus Mercado cumpriu a promessa: voce aprendeu a jogar e saiu vitorioso.",
      190, 280, 22, TXT, "center", VW - 380)
    ui.txt("O mercado ainda vai te testar muitas vezes. Volte quando quiser.",
      190, 340, 18, ui.hex "#9BA1BD", "center", VW - 380)
    local alpha = 0.7 + math.sin(tempo * 3) * 0.3
    ui.txt("TOQUE PARA IR AO MENU", 190, 440, 16, { ROSA[1], ROSA[2], ROSA[3], alpha },
      "center", VW - 380)
    desenharMao(VW - 250, 420, 0.7)
    return
  end

  local lic = LICOES[fase]
  if not lic then return end

  -- Lições dos elementos da mesa: arena ampliada ao fundo, mao do Deus
  -- Mercado apontando para o elemento e fala em um dos lados da tela.
  local fundo, alvo = nil, nil
  if fase == "turno" then
    fundo = fotoReal("arena_duplo.png")
    alvo = { x = 12, y = 28, w = 318, h = 105,
      mx = 120, my = 180, fala = "baixo" }
  elseif fase == "area" then
    fundo = fotoReal("arena_duplo.png")
    alvo = { x = 1000, y = 585, w = 260, h = 125,
      mx = 760, my = 560, fala = "topo" }
  elseif fase == "defesa" then
    fundo = fotoReal("arena_duplo.png")
    alvo = { x = 1075, y = 405, w = 150, h = 170,
      mx = 800, my = 480, fala = "topo" }
  elseif fase == "barras" then
    fundo = fotoReal("arena_seis.png")
    alvo = { x = 565, y = 82, w = 170, h = 113,
      mx = 555, my = 250, fala = "baixo" }
  end

  if fundo and alvo then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(fundo, 0, 0, 0, VW / 1280, VH / 720)
    love.graphics.setColor(0, 0, 0, 0.14)
    ui.preencherTela(VW, VH)

    local pulso = 0.55 + math.sin(tempo * 3) * 0.25
    love.graphics.setColor(OURO[1], OURO[2], OURO[3], pulso)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", alvo.x - 6, alvo.y - 6,
      alvo.w + 12, alvo.h + 12, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)

    desenharMao(alvo.mx, alvo.my, 0.75)

    local bx = 40
    local bw = VW - 80
    local by, bh = (alvo.fala == "topo") and 12 or (VH - 132), 120
    love.graphics.setColor(SOMBRA)
    love.graphics.rectangle("fill", bx + 4, by + 6, bw, bh, 14, 14)
    ui.caixa(bx, by, bw, bh, 14, PAINEL, BORDA, 2)
    ui.arestas(bx + 6, by + 6, bw - 12, bh - 12, 10, OURO, 2)
    cantos(bx, by, bw, bh, OURO_SUAVE, 14, 4, 2)
    ui.txtEspacado(lic.titulo, bx + 26, by + 12, 18, OURO, 2, bw - 52)
    ui.txt(lic.linhas[linha], bx + 26, by + 46, 19, TXT, "left", bw - 52)
    ui.txt("TOQUE OU PRESSIONE ENTER PARA CONTINUAR", bx + 26,
      by + bh - 24, 11, ui.hex "#8E93AE", "left", bw - 52)
    return
  end

  local px, py, pw, ph = 40, 70, VW - 80, VH - 240
  love.graphics.setColor(SOMBRA)
  love.graphics.rectangle("fill", px + 4, py + 6, pw, ph, 14, 14)
  ui.caixa(px, py, pw, ph, 14, FUNDO, BORDA, 2)
  cantos(px, py, pw, ph, OURO_SUAVE, 14, 4, 2)

  ui.txtEspacado(lic.titulo, 70, 96, 30, OURO, 3, VW - 140)
  desenharProgresso(VW - 220, 106)

  -- Ilustracao simples do assunto, a esquerda; a mao fica a direita.
  local ix, iy = 80, 190
  love.graphics.setColor(SOMBRA)
  love.graphics.rectangle("fill", ix + 3, iy + 5, 420, 200, 12, 12)
  ui.caixa(ix, iy, 420, 200, 12, ui.hex "#0D1222", BORDA, 2)
  cantos(ix, iy, 420, 200, OURO, 10, 3, 2)

  if fase == "cartas" then
    local cores = { ui.hex "#F6B84A", ROSA, ui.hex "#45D6FF", ui.hex "#B388FF" }
    for i, tipo in ipairs(TIPOS_ARTE) do
      local cx = ix + 30 + (i - 1) * 96
      ui.caixa(cx, iy + 28, 78, 118, 8, PAINEL, cores[i], 2)
      cantos(cx, iy + 28, 78, 118, cores[i], 6, 2, 1.5)
      local base = cartas.porId(tipo.id)
      local img = base and arte.arte(base) or nil
      if img then
        ui.imagemContain(img, cx + 4, iy + 32, 70, 110)
      else
        ui.txt("CARTA", cx, iy + 82, 11, cores[i], "center", 78)
      end
      ui.txt(tipo.nome, cx, iy + 152, 11, cores[i], "center", 78)
    end
  elseif fase == "turno" then
    ui.caixa(ix + 20, iy + 44, 380, 110, 8, PAINEL, OURO, 2)
    ui.txt("TURNO DE JOGADOR_1", ix + 40, iy + 62, 16, OURO, "left", 340)
    ui.txt("1 / 10   JOGADAS  2", ix + 40, iy + 100, 14, TXT, "left", 340)
    ui.txt("PARA A ESQUERDA   PASSAR", ix + 40, iy + 128, 12, TXT, "left", 340)
  elseif fase == "area" then
    for i = 1, 3 do
      local cx = ix + 30 + (i - 1) * 130
      local pulso = (i == 1) and (math.sin(tempo * 2.4) * 0.15 + 0.85) or 1
      ui.caixa(cx, iy + 60, 110, 90, 8, PAINEL, OURO, 2)
      cantos(cx, iy + 60, 110, 90, { OURO_SUAVE[1], OURO_SUAVE[2], OURO_SUAVE[3], pulso }, 8, 2, 1.5)
      ui.txt("SLOT " .. i, cx, iy + 94, 14, OURO, "center", 110)
    end
  elseif fase == "defesa" then
    local pulso = math.sin(tempo * 2.2) * 0.25 + 0.75
    local AZUL = ui.hex "#45D6FF"
    love.graphics.setColor(AZUL[1], AZUL[2], AZUL[3], 0.2 * pulso)
    love.graphics.rectangle("fill", ix + 112, iy + 32, 196, 136, 10, 10)
    ui.caixa(ix + 120, iy + 40, 180, 120, 8, PAINEL, AZUL, 3)
    cantos(ix + 120, iy + 40, 180, 120, AZUL, 10, 3, 2)
    ui.txt("DEFESA", ix + 120, iy + 90, 20, AZUL, "center", 180)
    ui.txt("2 TURNOS", ix + 120, iy + 124, 13, TXT, "center", 180)
  elseif fase == "intro" then
    for i = 1, 3 do
      local cx = ix + 70 + (i - 1) * 95
      local cor = i == 2 and ROSA or OURO
      ui.caixa(cx, iy + 40, 70, 110, 8, PAINEL, cor, 2)
      cantos(cx, iy + 40, 70, 110, cor, 6, 2, 1.5)
      ui.txt("CARTA", cx, iy + 88, 12, OURO, "center", 70)
    end
    diamante(ix + 20, iy + 179, 5, OURO)
    ui.txt("32 CARTAS NO BARALHO", ix + 20, iy + 166, 13, TXT, "center", 380)
    diamante(ix + 400, iy + 179, 5, OURO)
  else
    desenharBarraMock(ix + 24, iy + 36, 370, 28, "satisfacao")
    ui.txt("SATISFACAO 100/200", ix + 30, iy + 44 - 8, 13, TXT, "left", 350)
    desenharBarraMock(ix + 24, iy + 100, 370, 28, "produtividade")
    ui.txt("PRODUTIVIDADE +0%", ix + 30, iy + 108 - 8, 13, TXT, "left", 350)
  end

  desenharMao(VW - 430, 130, 1.1)
  desenharFala(lic.linhas[linha], "DEUS MERCADO", 150)
end

function O.desenharBatalha()
  if not emBatalha then return end
  local bx, by, bw, bh = VW / 2 - 330, 96, 660, 62
  love.graphics.setColor(SOMBRA)
  love.graphics.rectangle("fill", bx + 3, by + 5, bw, bh, 10, 10)
  ui.caixa(bx, by, bw, bh, 10, PAINEL, BORDA, 2)
  cantos(bx, by, bw, bh, OURO_SUAVE, 8, 3, 1.5)

  ui.txt("DEUS MERCADO: " .. DICAS[dica], bx + 14, by + 9, 14, TXT,
    "left", bw - 28)

  -- barrinha de progresso das dicas, no lugar do numero seco "x/6"
  local nDicas = math.min(dica, #DICAS)
  local passo = 10
  local x0 = bx + bw - 14 - (#DICAS - 1) * passo
  for i = 1, #DICAS do
    diamante(x0 + (i - 1) * passo, by + bh - 14, i <= nDicas and 6 or 4,
      i <= nDicas and OURO or BORDA)
  end
  desenharMao(26, VH - 212, 0.55)
end

return O