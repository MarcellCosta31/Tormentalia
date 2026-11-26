-- vs.lua — Tela de VS antes de cada duelo do Ciclo 1: o jogador a
-- esquerda e o inimigo a direita entram deslizando, as letras VS batem
-- no meio com flash, tremor de camera, onda de choque e faiscas, e a
-- cena encerra so ou no clique (antes do impacto o clique salta para
-- ele; depois dele sai na hora). O aoFim recebido no iniciar() abre o
-- duelo de verdade no main. Pose grande so quando o avatar do perfil e
-- o 7 (cinza); nos demais avatares vale o retrato emoldurado. Texto
-- ASCII puro: a fonte VCR do jogo nao tem acento.
--
-- Etapa 3 (game feel): antecipacao + overshoot na entrada, hit-stop e
-- trauma no impacto, corte diagonal, flash branco nos sprites (shader
-- com fallback), aberracao cromatica no "VS", respiracao idle, linhas
-- de velocidade, brasas ambientes, placas escalonadas, som em camadas e
-- liberacao de recursos no encerrar().
local ui = require "ui"
local arte = require "arte"
local som = require "som"
local fx = require "fx"
local anim = require "anim"

local V = {}

local VW, VH = 1280, 720
local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"

-- Cronograma da cena (segundos desde o iniciar()).
local T_FADE = 0.3      -- fundo e escurecimento entram
local T_ENTRA = 0.5     -- deslize das poses das bordas para o lugar
local T_ESPERA = 0.78   -- respiro antes do impacto do VS
local DUR_FLASH = 0.22  -- flash branco do impacto
local DUR_ONDA = 0.55   -- onda de choque (dois aneis)
local DUR_CORTE = 0.30  -- corte diagonal do impacto
-- JOGO_VS_SEG prolonga a cena para gravacoes do trailer; sem a variavel
-- o fluxo normal continua saindo sozinho em 2.9s.
local T_FIM = tonumber(os.getenv("JOGO_VS_SEG")) or 2.9
local FADE_SAIDA = 0.35

-- Altura da arte de cada pose em relacao a imagem 1920x1920: os PNGs
-- "cintura" dos inimigos terminam em ~0.62 (vazio embaixo), o do Adam
-- sangra ate a borda de baixo (1.0) e o cinza do jogador termina em
-- ~0.90. Cortar na fracao certa mostra o personagem COMPLETO sem
-- flutuar. A fracao segue o AVATAR do inimigo (a arte viaja com ele na
-- fila), nao a posicao.
local FRAC_CINZA = 0.9
-- As poses 64 ja vem cortadas na caixa do conteudo (arte/64/vs), entao a
-- fracao de corte e o arquivo inteiro.
local FRAC_INIMIGO = 1.0
local FRAC_ADAM = 1.0
local AVATAR_ADAM = "inimigo_7"

local function fracInimigo(avatar)
  if avatar == AVATAR_ADAM then return FRAC_ADAM end
  return FRAC_INIMIGO
end

-- Shader de branqueamento dos sprites no impacto. Compilado sob pcall:
-- se o driver recusar, o efeito some sem quebrar a cena (fallback).
local shaderBranco = nil

local function obterShaderBranco()
  if shaderBranco ~= nil then return shaderBranco or nil end
  if MODO_TESTE then
    shaderBranco = false
    return nil
  end
  local codigo = [[
extern number u_alfa;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 c = Texel(tex, tc);
  return vec4(1.0, 1.0, 1.0, c.a * u_alfa);
}
]]
  local ok, sh = pcall(love.graphics.newShader, codigo)
  shaderBranco = (ok and sh) and sh or false
  if shaderBranco then return shaderBranco end
  return nil
end

local function liberarShader()
  if shaderBranco and shaderBranco ~= false and shaderBranco.release then
    pcall(function() shaderBranco:release() end)
  end
  shaderBranco = nil
end

local st = nil

-- Faiscas do impacto: { x, y, vx, vy, vida, cor }.
local function novasFaiscas()
  local ps = {}
  for i = 1, 26 do
    local ang = love.math.random() * math.pi * 2
    local vel = 200 + love.math.random() * 430
    ps[i] = {
      x = VW / 2,
      y = VH * 0.42,
      vx = math.cos(ang) * vel,
      vy = math.sin(ang) * vel * 0.65,
      vida = 0.45 + love.math.random() * 0.4,
      cor = love.math.random() < 0.5 and { 1, 0.84, 0.31 }
        or { 1, 1, 1 },
    }
  end
  return ps
end

-- Brasas ambientes: sobem devagar, piscam e voltam por baixo. Paleta
-- Tormentalia (ouro, vinho, branco luminoso), sem confete colorido.
local function novasBrasas()
  local cores = {
    { 1.00, 0.84, 0.31 },   -- ouro
    { 0.68, 0.16, 0.18 },   -- vinho/vermelho
    { 0.95, 0.93, 0.88 },   -- branco luminoso
  }
  local bs = {}
  for i = 1, 26 do
    bs[i] = {
      x = love.math.random() * VW,
      y = love.math.random() * VH,
      vy = ui.E(9) + love.math.random() * ui.E(24),
      tam = math.max(1, math.floor(ui.E(1))),
      cor = cores[love.math.random(#cores)],
      alfa = 0.18 + love.math.random() * 0.42,
      fase = love.math.random() * math.pi * 2,
      velPisca = 1.4 + love.math.random() * 2.4,
    }
  end
  return bs
end

-- Linhas de velocidade horizontais (entrada e estouro do impacto).
local function novasLinhas()
  local ls = {}
  for i = 1, 16 do
    ls[i] = {
      y = love.math.random() * VH,
      lado = (i % 2 == 0) and 1 or -1,
      vel = 520 + love.math.random() * 900,
      comp = ui.E(30) + love.math.random() * ui.E(110),
      off = love.math.random(),
      cor = (i % 3 == 0) and { 1, 0.84, 0.31 } or { 1, 1, 1 },
    }
  end
  return ls
end

local function encerrar()
  arte.liberarVS()
  liberarShader()
  st = nil
end

-- Impacto do VS: hit-stop + trauma + flash + linha de corte + onda +
-- faiscas + som em camadas. O clique antes do instante natural salta
-- direto para aqui.
local function dispararImpacto()
  if not st or st.bateu then return end
  st.bateu = true
  st.t = T_ESPERA
  fx.hitstop(0.06)
  fx.bater(0.9)
  st.flash = DUR_FLASH
  st.onda = DUR_ONDA
  st.corte = DUR_CORTE
  st.faiscas = novasFaiscas()
  som.tocar("turno", 0.70)   -- corpo/baixo
  som.tocar("clique", 0.42)  -- estalo agudo
end

-- Termina a cena na hora e dispara o aoFim (mesmo caminho do fim
-- natural). Exposto para testes e para o boot de captura pularem a
-- animacao sem depender do relogio.
function V.pular()
  if not st then return false end
  local fn = st.aoFim
  encerrar()
  if fn then fn() end
  return true
end

-- opcoes: { nomeJog, avatarJog (id "1".."8" ou da loja), nomeInimigo,
-- avatarInimigo (chave do avatar, ex. "inimigo_5" - a arte do inimigo
-- viaja com ele na fila, nao com a posicao), inimigoIdx (legado: monta
-- o avatarInimigo quando ausente), aoFim }.
function V.iniciar(opcoes)
  opcoes = opcoes or {}
  arte.carregarVS()
  obterShaderBranco()
  local idxLeg = tonumber(opcoes.inimigoIdx) or 1
  st = {
    t = 0,
    bateu = false,
    flash = 0,
    onda = 0,
    corte = 0,
    saida = 0,
    faiscas = nil,
    brasas = novasBrasas(),
    linhas = novasLinhas(),
    nomeJog = opcoes.nomeJog or "JOGADOR",
    avatarJog = tostring(opcoes.avatarJog or "1"),
    nomeInimigo = opcoes.nomeInimigo or "INIMIGO",
    avatarInimigo = tostring(opcoes.avatarInimigo or ("inimigo_" .. idxLeg)),
    aoFim = opcoes.aoFim,
  }
  -- Whoosh de entrada (camada leve; some sozinha se o som nao existir).
  som.tocar("passar", 0.32)
end

function V.ativo()
  return st ~= nil
end

-- Avatar do inimigo em cena (a suite confere que a arte segue o
-- inimigo e nao a posicao na fila).
function V.avatarInimigo()
  if not st then return nil end
  return st.avatarInimigo
end

function V.atualizar(dt)
  if not st then return end
  -- Saida em andamento: so conta o fade e encerra no fim dele.
  if st.saida > 0 then
    st.saida = st.saida + dt
    if st.saida >= FADE_SAIDA then
      local fn = st.aoFim
      encerrar()
      if fn then fn() end
    end
    return
  end
  st.t = st.t + dt
  if not st.bateu and st.t >= T_ESPERA then
    dispararImpacto()
  end
  if st.flash > 0 then st.flash = math.max(0, st.flash - dt) end
  if st.onda > 0 then st.onda = math.max(0, st.onda - dt) end
  if st.corte > 0 then st.corte = math.max(0, st.corte - dt) end
  if st.faiscas then
    for _, p in ipairs(st.faiscas) do
      p.vida = p.vida - dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.vy = p.vy + 520 * dt
    end
  end
  -- Brasas: sobem e renascem por baixo ao sair da tela.
  if st.brasas then
    for _, b in ipairs(st.brasas) do
      b.y = b.y - b.vy * dt
      if b.y < -ui.E(10) then
        b.y = VH + ui.E(10)
        b.x = love.math.random() * VW
      end
    end
  end
  if st.t >= T_FIM then
    st.saida = 0.0001
  end
end

-- Um clique: antes do impacto salta para ele; depois dele comeca o fade
-- de saida; com a saida em andamento encerra na hora.
function V.clique()
  if not st then return false end
  if st.saida > 0 then
    return V.pular()
  end
  if not st.bateu then
    dispararImpacto()
    return true
  end
  st.saida = 0.0001
  return true
end

-- Pose cortada na fracao `frac` da imagem 1920x1920 (so o vazio de
-- baixo sai), ancorada na base e centralizada em cx. Cabe na altura
-- disponivel e tambem respeita a largura maxima (nao invade o VS do meio).
-- `escExtra` permite respiracao/entrada; `dy` desloca a base;
-- `branco` (0..1) desenha o flash branco do sprite via shader.
local function pose(img, frac, cx, baseY, largMax, altMax, alfa,
    escExtra, dy, branco)
  if not img then return end
  local iw, ih = img:getDimensions()
  local sw, sh = iw, ih * frac
  local esc = math.min(largMax / sw, altMax / sh) * (escExtra or 1)
  local dw, dh = sw * esc, sh * esc
  local quad = love.graphics.newQuad(0, 0, sw, sh, iw, ih)
  local px = math.floor(cx - dw / 2)
  local py = math.floor(baseY + (dy or 0) - dh)
  love.graphics.setColor(1, 1, 1, alfa or 1)
  love.graphics.draw(img, quad, px, py, 0, esc, esc)
  -- Flash branco por cima do proprio sprite (fade com o impacto).
  if branco and branco > 0.01 then
    local sh = obterShaderBranco()
    if sh then
      love.graphics.setShader(sh)
      sh:send("u_alfa", branco)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(img, quad, px, py, 0, esc, esc)
      love.graphics.setShader()
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
end

-- Retrato emoldurado (avatares simples dos demais perfis).
local function retrato(img, cx, baseY, larg, alt, alfa, escExtra, dy, branco)
  if not img then return end
  local k = escExtra or 1
  local w, h = larg * k, alt * k
  local x, y = cx - w / 2, baseY + (dy or 0) - h
  ui.caixa(x, y, w, h, 8, ui.C.AVATAR_BOX, ui.C.OURO, 2,
    0.97 * alfa, alfa)
  ui.imagemCover(img, x + ui.E(4), y + ui.E(4), w - ui.E(8),
    h - ui.E(8), alfa)
  if branco and branco > 0.01 then
    love.graphics.setColor(1, 1, 1, branco)
    love.graphics.rectangle("fill", x + ui.E(4), y + ui.E(4),
      w - ui.E(8), h - ui.E(8), 6, 6)
  end
end

-- Placa de nome embaixo de cada lado.
local function placa(nome, cx, y, larg, alfa)
  local alt = ui.alturaTexto(ui.E(15)) + ui.E(14)
  local x = cx - larg / 2
  ui.caixa(x, y, larg, alt, 6, { 0, 0, 0 }, ui.C.OURO, 1.5,
    0.62 * alfa, 0.85 * alfa)
  ui.txt(nome, x, y + ui.E(7), ui.E(15), ui.C.CREME, "center", larg, alfa)
end

local function desenharBrasas(a)
  if not st.brasas then return end
  for _, b in ipairs(st.brasas) do
    local pisca = 0.5 + 0.5 * math.sin(st.t * b.velPisca + b.fase)
    local alfa = b.alfa * pisca * a
    if alfa > 0.01 then
      love.graphics.setColor(b.cor[1], b.cor[2], b.cor[3], alfa)
      love.graphics.rectangle("fill", math.floor(b.x), math.floor(b.y),
        b.tam, b.tam)
    end
  end
end

-- Linhas de velocidade: entram com as poses e estouram no impacto.
local function desenharLinhas(a)
  if not st.linhas then return end
  local env = 0
  if st.t < T_ENTRA then
    env = st.t / T_ENTRA
  elseif st.bateu then
    local q = math.max(0, 1 - math.max(0, st.t - T_ESPERA) / 0.5)
    env = q
  end
  if env <= 0.02 then return end
  local span = VW * 0.62
  for _, L in ipairs(st.linhas) do
    local p = ((st.t * L.vel + L.off * span) % span) / span
    local x = VW / 2 + L.lado * (VW * 0.16 + p * span)
    local comp = L.comp * (0.35 + 0.65 * (1 - p))
    local alfa = env * (1 - p) * 0.32 * a
    if alfa > 0.01 then
      love.graphics.setColor(L.cor[1], L.cor[2], L.cor[3], alfa)
      love.graphics.rectangle("fill", math.floor(x), math.floor(L.y),
        math.floor(comp), 2)
    end
  end
end

-- Corte diagonal do impacto: banda dourada com nucleo branco varrendo
-- o centro (comprimento cresce rapido, some no fim).
local function desenharCorte(a)
  if not st.corte or st.corte <= 0 then return end
  local q = 1 - st.corte / DUR_CORTE
  local env = 1 - q
  local cx, cy = VW / 2, VH * 0.42
  local L = (VW * 1.5) * math.min(1, q * 1.7)
  local amp = math.max(1, math.floor(ui.E(5) * env) + 1)
  love.graphics.push()
  love.graphics.translate(cx, math.floor(cy + ui.E(8)))
  love.graphics.rotate(-0.5)
  love.graphics.setColor(1, 0.84, 0.31, 0.32 * env * a)
  love.graphics.rectangle("fill", -L / 2, -amp * 2, L, amp * 4)
  love.graphics.setColor(1, 1, 1, 0.9 * env * a)
  love.graphics.rectangle("fill", -L / 2, -amp / 2, L, amp)
  love.graphics.pop()
end

function V.desenhar()
  if not st then return end
  local a = math.min(1, st.t / T_FADE)
  if st.saida > 0 then
    a = 1 - math.min(1, st.saida / FADE_SAIDA)
  end

  -- Tremor de camera do impacto (via fx: trauma decai e desvia inteiros).
  local sx, sy = fx.offset()
  love.graphics.push()
  love.graphics.translate(sx, sy)

  -- Fundo: escritorio do perfil cobrindo a tela (opaco) sob um
  -- escurecimento forte — o mapa da selecao nao pode vazar atras.
  ui.imagemCover(arte.img("perfil_fundo"), 0, 0, VW, VH, a)
  love.graphics.setColor(0.02, 0.02, 0.06, 0.58 * a)
  ui.preencherTela(VW, VH)

  -- Atmosfera: brasas subindo + linhas de velocidade (atras das poses).
  desenharBrasas(a)
  desenharLinhas(a)

  -- Entrada: as poses deslizam das bordas. Back-out (overshoot) + um
  -- "wind-up" que puxa um pouco para fora nos primeiros 0.14s.
  local q = math.min(1, st.t / T_ENTRA)
  local e = anim.saidaExcesso(q, 1.25)
  local wind = math.max(0, 1 - st.t / 0.14)
  local offP = math.floor((1 - e) * -VW * 0.5 - wind * ui.E(24))
  local offI = math.floor((1 - e) * VW * 0.5 + wind * ui.E(24))
  -- Entrada tambem cresce de leve (0.94 -> 1) na primeira metade.
  local escEnt = 0.94 + 0.06 * math.min(1, q * 1.5)

  -- Respiracao idle: leve subida/descida com escala minima.
  local respP = math.sin(st.t * 2.3)
  local respI = math.sin(st.t * 2.3 + 0.7)
  local dyP = math.floor(respP * ui.E(2))
  local dyI = math.floor(respI * ui.E(2))
  local escP = escEnt * (1 + respP * 0.008)
  local escI = escEnt * (1 + respI * 0.008)

  local baseY = VH - ui.E(86)
  local cxP = math.floor(VW * 0.27 + offP)
  local cxI = math.floor(VW * 0.73 + offI)
  local larg = VW * 0.44
  local alt = VH - ui.E(130)

  -- Flash branco dos sprites no impacto (0..1).
  local branco = (st.flash > 0) and (st.flash / DUR_FLASH) * 0.85 or 0

  -- Jogador: pose grande so no avatar 7 (cinza); demais = retrato.
  local poseJ = st.avatarJog == "7" and arte.vs("vs_jogador_cinza") or nil
  if poseJ then
    pose(poseJ, FRAC_CINZA, cxP, baseY, larg, alt, a, escP, dyP, branco)
  else
    retrato(arte.avatar(st.avatarJog), cxP, baseY, ui.E(300),
      ui.E(360), a, escP, dyP, branco)
  end

  -- Inimigo: pose inteira (fracao por avatar; fallback no avatar
  -- simples se o PNG grande nao carregar). A arte segue o AVATAR do
  -- inimigo (que viaja com ele na tabela INIMIGOS), nao a posicao.
  local poseI = arte.vs("vs_" .. st.avatarInimigo)
  if poseI then
    pose(poseI, fracInimigo(st.avatarInimigo), cxI, baseY, larg, alt, a,
      escI, dyI, branco)
  else
    retrato(arte.avatar(st.avatarInimigo), cxI, baseY, ui.E(300),
      ui.E(360), a, escI, dyI, branco)
  end

  -- Placas de nome escalonadas (jogador entra antes do inimigo), com
  -- um leve deslize de baixo para cima.
  local qJ = math.min(1, math.max(0, (st.t - T_ENTRA * 0.35) / 0.32))
  qJ = 1 - (1 - qJ) * (1 - qJ)
  local qI = math.min(1, math.max(0, (st.t - T_ENTRA * 0.62) / 0.32))
  qI = 1 - (1 - qI) * (1 - qI)
  placa(st.nomeJog, VW * 0.27,
    VH - ui.E(64) + math.floor((1 - qJ) * ui.E(14)),
    ui.E(300), qJ * a)
  placa(st.nomeInimigo, VW * 0.73,
    VH - ui.E(64) + math.floor((1 - qI) * ui.E(14)),
    ui.E(300), qI * a)

  -- Corte diagonal por cima das poses (o "golpe" do VS).
  desenharCorte(a)

  -- Letras VS no meio: entram em escala 3x -> 1x e batem no impacto
  -- (contorno escuro por fora, miolo dourado). No impacto ganham
  -- aberracao cromatica (vinho/azul deslocados) e um punch de escala.
  local cx, cy = VW / 2, VH * 0.42
  local escalaVS = 1
  local ab = 0
  if not st.bateu then
    local qv = math.min(1, st.t / T_ESPERA)
    escalaVS = 3.2 - 2.2 * (qv * qv)
  else
    escalaVS = 1 + 0.10 * (st.flash / DUR_FLASH)
    cy = cy + math.floor(math.sin(st.t * 3) * ui.E(2))
    ab = math.max(0, 1 - math.max(0, st.t - T_ESPERA) / 0.22)
  end
  local tamVS = ui.E(120)
  local txtVS = "VS"
  love.graphics.setFont(arte.fonte(tamVS))
  local fVS = love.graphics.getFont()
  local largVS, altVS = fVS:getWidth(txtVS), fVS:getHeight()
  local baseX = cx - largVS / 2
  local baseYtxt = cy - altVS / 2
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(escalaVS, escalaVS)
  love.graphics.translate(-cx, -cy)

  -- Contorno escuro.
  love.graphics.setColor(0, 0, 0, 0.88 * a)
  local o = ui.E(3)
  for dx = -o, o, o do
    for dy = -o, o, o do
      if dx ~= 0 or dy ~= 0 then
        love.graphics.print(txtVS, baseX + dx, baseYtxt + dy)
      end
    end
  end
  -- Aberracao cromatica: vinho a esquerda, azul profundo a direita.
  local dAb = math.floor(ab * ui.E(7))
  if dAb > 0 then
    love.graphics.setColor(0.80, 0.16, 0.16, 0.72 * ab * a)
    love.graphics.print(txtVS, baseX - dAb, baseYtxt)
    love.graphics.setColor(0.11, 0.28, 0.60, 0.72 * ab * a)
    love.graphics.print(txtVS, baseX + dAb, baseYtxt)
  end
  -- Miolo dourado.
  love.graphics.setColor(1, 0.84, 0.31, a)
  love.graphics.print(txtVS, baseX, baseYtxt)
  love.graphics.pop()

  -- Onda de choque do impacto (dois aneis dourados expandindo).
  if st.onda > 0 then
    local qo = 1 - st.onda / DUR_ONDA
    local r = ui.E(46) + qo * ui.E(390)
    love.graphics.setColor(1, 0.84, 0.31, (1 - qo) * 0.75 * a)
    love.graphics.setLineWidth(ui.E(5) * (1 - qo) + 1)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.circle("line", cx, cy, r * 0.7)
    love.graphics.setLineWidth(1)
  end

  -- Faiscas do impacto (gravidade puxa para baixo ate sumirem).
  if st.faiscas then
    for _, p in ipairs(st.faiscas) do
      if p.vida > 0 then
        local alfaF = math.min(1, p.vida * 2.4) * a
        love.graphics.setColor(p.cor[1], p.cor[2], p.cor[3], alfaF)
        local s = ui.E(3) + p.vida * ui.E(5)
        love.graphics.rectangle("fill", math.floor(p.x - s / 2),
          math.floor(p.y - s / 2), math.floor(s), math.floor(s))
      end
    end
  end

  -- Flash branco do impacto por cima de tudo.
  if st.flash > 0 then
    love.graphics.setColor(1, 1, 1, (st.flash / DUR_FLASH) * 0.85)
    ui.preencherTela(VW, VH)
  end

  -- Legenda pos-impacto e dica de avanco (pisca), no rodape.
  local tamH = ui.E(12)
  if st.bateu then
    local aCap = math.min(1, (st.t - T_ESPERA) / 0.22)
    local pisca = 0.6 + 0.4 * math.sin(st.t * 5)
    ui.txt("QUE COMECE A LUTA", cx - ui.E(220), cy + ui.E(86), tamH,
      ui.C.CREME, "center", ui.E(440), aCap * pisca * a)
  end
  local dica = "TOQUE PARA CONTINUAR >>"
  local dicaPisca = 0.5 + 0.5 * math.sin(st.t * 4.5)
  ui.txt(dica, cx - ui.larguraTexto(dica, tamH) / 2, VH - ui.E(30),
    tamH, ui.C.TEXTO2, nil, nil, dicaPisca * a)

  love.graphics.pop()
end

function V.limpar()
  encerrar()
end

return V
