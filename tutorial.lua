local ui = require "ui"
local arte = require "arte"
local cartas = require "cartas"

local tut = {}

local VW, VH = 1280, 720
local C = ui.C
local OURO = C.OURO
local BRANCO = { 1, 1, 1 }

local COR_CENA = ui.hex "#05050A"
local COR_LEG_FUNDO = { 4 / 255, 4 / 255, 10 / 255 }
local COR_LEG_DICA = ui.hex "#B9B9CF"
local COR_PAINEL = { 3 / 255, 3 / 255, 8 / 255 }
local COR_BOTAO = ui.hex "#0A0A1A"

local DUR_ENTRADA = 0.6
local DUR_OUT = 0.3
local DUR_IN = 0.4
local DUR_FADE = 0.7
local DUR_PORTAL = 2.0
local DUR_PORTAL_LUZ = 1.6
local INTERVALO_TOQUE = 0.5

local P = "PROTAGONISTA"
local G = "GUIA"

local function fl(speaker, text, destaque)
  return { speaker = speaker, text = text, destaque = destaque }
end

local CENAS = {
  {
    id = "SCENE_01",
    titulo = "O ESCRITORIO",
    quadros = {
      {
        id = "SCENE_01_FRAME_01", numero = 1, imgPath = "arte/tutorial/f1.png",
        titulo = "PROTAGONISTA NO ESCRITORIO",
        falas = {
          fl(P, "Eu lutei tanto para conseguir o que tenho hoje..."),
          fl(P, "Passei horas estudando Administracao na universidade."),
          fl(P, "Sem o apoio de ninguem, eu tentei."),
          fl(P, "Eu realmente tentei..."),
        },
      },
      {
        id = "SCENE_01_FRAME_02", numero = 2, imgPath = "arte/tutorial/f2.png",
        titulo = "A JANELA QUEBRADA",
        falas = {
          fl(P, "Mas peixe pequeno nao sobrevive em mar de tubaroes..."),
          fl(P, "E agora..."),
        },
        pausaAntesProximo = 1.5,
      },
      {
        id = "SCENE_01_FRAME_03", numero = 3, imgPath = "arte/tutorial/f3.png",
        titulo = "A CARTA DE DEMISSAO",
        falas = {
          fl(P, "Sinto que o meu sonho chegou ao fim."),
          fl(P, "Eu nao queria desistir..."),
          fl(P, "Mas, no fundo, eu sei que parte disso e culpa minha."),
          fl(P, "Culpa da minha pessima lideranca..."),
        },
      },
      {
        id = "SCENE_01_FRAME_04", numero = 4, imgPath = "arte/tutorial/f4.png",
        titulo = "ELA VOANDO EMBORA",
        falas = {
          fl(P, "Culpa minha por ter sido um pessimo marido."),
          fl(P, "Culpa minha por ter colocado tudo a perder."),
          fl(P, "Parece que tudo que eu tentei construir esta desaparecendo."),
        },
      },
      {
        id = "SCENE_01_FRAME_05", numero = 5, imgPath = "arte/tutorial/f5.png",
        titulo = "O QUADRO DO PAI",
        falas = {
          fl(P, "Desculpa, pai..."),
          fl(P, "Desculpa por ser um fracassado."),
          fl(P, "Eu tentei seguir os seus passos."),
          fl(P, "Mas acho que..."),
          fl(P, "...eu vou dar um fim nisso."),
        },
        pausaAntesProximo = 2.5,
      },
      {
        id = "SCENE_01_FRAME_06", numero = 6, imgPath = "arte/tutorial/f6.png",
        titulo = "A LUZ ATRAS DELE",
        comecarSemCaixa = true,
        falas = { fl(P, "Ha...?") },
      },
      {
        id = "SCENE_01_FRAME_07", numero = 7, imgPath = "arte/tutorial/f7.png",
        titulo = "O PORTAL NO CHAO",
        falas = { fl(P, "O que e isso?!") },
      },
      {
        id = "SCENE_01_FRAME_08", numero = 8, imgPath = "arte/tutorial/f8.png",
        titulo = "SUGADO PELO PORTAL",
        falas = {
          fl(P, "SOCORRO!"),
          fl(P, "ALGUEM ME AJUDA!"),
        },
        transicaoSaida = "portal",
      },
    },
  },
  {
    id = "SCENE_02",
    titulo = "O MUNDO",
    quadros = {
      {
        id = "SCENE_02_FRAME_01", numero = 1, fundo = "ciclico",
        titulo = "UM MUNDO EM RUINAS",
        falas = {
          fl(G, "E ai, cara."),
          fl(G, "Dormiu bem?"),
          fl(P, "Onde estou?"),
          fl(G, "Nem te conto."),
          fl(P, "Eu estou no inferno?"),
          fl(G, "Mais ou menos isso."),
          fl(G, "Seja bem-vindo ao Tormentalia."),
          fl(P, "Tormentalia?"),
          fl(G, "Voce foi condenado por ELE."),
          fl(G, "A ficar aqui em agonia."),
          fl(G, "Parabens."),
          fl(G, "Uhuuu..."),
        },
      },
      {
        id = "SCENE_02_FRAME_02", numero = 2, fundo = "ciclico",
        titulo = "A ESFERA DE LUZ",
        falas = {
          fl(P, "Condenado por quem?"),
          fl(G, "Por ELE."),
          fl(G, "Para alguns, ele e o diabo necessario."),
          fl(G, "Para outros, a propria vida."),
          fl(G, "Para outros, a morte."),
          fl(G, "Para poucos, uma mentira."),
          fl(G, "E para muitos, a verdade."),
          fl(G, "Ninguem sabe exatamente quem ele e."),
          fl(G, "So sabemos que estamos aqui por causa dele."),
        },
      },
      {
        id = "SCENE_02_FRAME_03", numero = 3, fundo = "ciclico",
        titulo = "O GUIA FLUTUA",
        falas = {
          fl(P, "Mas o que ele quer comigo?"),
          fl(G, "O mesmo que quer com todo mundo."),
          fl(G, "Duelo."),
          fl(P, "Duelo?"),
          fl(G, "Voce nao vai sobreviver muito tempo aqui se nao souber duelar."),
          fl(G, "Mas voce parece um cara legal."),
          fl(G, "Entao vou te dar uma coisa para comecar."),
        },
      },
      {
        id = "SCENE_02_FRAME_04", numero = 4, fundo = "ciclico",
        titulo = "O DECK INICIAL",
        falas = {
          fl(G, "Esse e o seu deck inicial."),
          fl(G, "Todo mundo que chega aqui recebe um."),
          fl(G, "Quando uma batalha comeca, as cartas sao embaralhadas e distribuidas entre os jogadores."),
        },
        acaoAoTerminar = "mostrarDeck",
      },
      {
        id = "SCENE_02_FRAME_05", numero = 5, fundo = "ciclico",
        titulo = "AS CARTAS DO JOGO",
        falas = {
          fl(P, "Por que o Karl Marx esta na carta?"),
          fl(G, "Ah..."),
          fl(G, "Esqueci de explicar."),
          fl(G, "Ele fez com que todos os duelos daqui usassem cartas relacionadas a Administracao."),
        },
      },
      {
        id = "SCENE_02_FRAME_06", numero = 6, fundo = "ciclico",
        titulo = "AS CATEGORIAS DE CARTAS",
        falas = {
          fl(G, "Existem diferentes tipos de cartas."),
          fl(G, "As cartas de Acao permitem atacar ou provocar mudancas durante o duelo.", "ACAO"),
          fl(G, "As Medidas alteram situacoes e recursos.", "EFEITO"),
          fl(G, "As Defesas protegem voce dos seus adversarios.", "PROTECAO"),
          fl(G, "E os Coringas possuem efeitos especiais.", "CORINGA"),
          fl(G, "Voce precisa aprender a combinar tudo isso."),
          fl(P, "Estrategia nao e exatamente o meu ponto forte."),
          fl(G, "Mas valendo a sua vida..."),
          fl(G, "...acho que voce consegue tirar leite de pedra."),
          fl(G, "La ele."),
        },
        acaoAoTerminar = "fim",
      },
    },
  },
}

local QUADROS = {}
for cenaIdx, cena in ipairs(CENAS) do
  for qIdx, q in ipairs(cena.quadros) do
    q.cenaIdx = cenaIdx
    q.cenaTitulo = "CENA " .. cenaIdx .. " . " .. cena.titulo
    q.totalNaCena = #cena.quadros
    if not q.numero then q.numero = qIdx end
    QUADROS[#QUADROS + 1] = q
  end
end

local FRASES_INTRO = {
  "Ola peixe pequeno, seja bem vindo.",
  "Essa e a sua historia.",
  "De como voce fez historia,",
}

local ROTULO_DESTAQUE = {
  ACAO = "CARTA DE ACAO",
  EFEITO = "CARTA DE MEDIDA / EFEITO",
  PROTECAO = "CARTA DE PROTECAO",
  CORINGA = "CARTA CORINGA",
}
-- Mesma escolha do React (DestaqueTipos): primeira carta de cada tipo.
local ID_DESTAQUE = { ACAO = 1, EFEITO = 25, PROTECAO = 10, CORINGA = 6 }

local DECK_X, DECK_Y, DECK_W, DECK_H = 533, 145, 214, 290
local DECK_GAP = 10
local FACE_NAT_W, FACE_NAT_H = 306, 415

local function desenharFace(carta, x, y, w, h)
  local s = math.min(w / FACE_NAT_W, h / FACE_NAT_H)
  love.graphics.push()
  love.graphics.translate(x + w / 2, y + h / 2)
  love.graphics.scale(s, s)
  ui.faceCompleta(carta, -FACE_NAT_W / 2, -FACE_NAT_H / 2, FACE_NAT_W, FACE_NAT_H)
  love.graphics.pop()
end

local est = nil
local imgGuia = nil
local baralho = nil
local exemplar = {}
local cacheImg = {}

local function dentro(x, y, r)
  return r ~= nil and x >= r.x and y >= r.y and x <= r.x + r.w and y <= r.y + r.h
end

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function agendar(segundos, fn)
  table.insert(est.timers, { t = segundos, fn = fn })
end

local function garantirBase()
  if not imgGuia then
    local ok, img = pcall(love.graphics.newImage, "arte/tutorial/guia.png")
    if ok and img then
      img:setFilter("linear", "linear")
      imgGuia = img
    end
  end
  if not baralho then
    -- Baralho infinito: o "deck" do tutorial mostra um exemplar de cada
    -- carta do catalogo (antes eram as 3 copias do baralho finito).
    baralho = {}
    for _, c in ipairs(cartas.CARTAS) do
      local copia = cartas.copia(c)
      baralho[#baralho + 1] = copia
      if exemplar[c.id] == nil then exemplar[c.id] = copia end
    end
  end
end

local function carregarImg(indice)
  local q = QUADROS[indice]
  if not q or not q.imgPath then return nil end
  if cacheImg[indice] then return cacheImg[indice] end
  local ok, img = pcall(love.graphics.newImage, q.imgPath)
  if ok and img then
    img:setFilter("linear", "linear")
    cacheImg[indice] = img
    return img
  end
  return nil
end

local function limparImgAte(indice)
  local remover = {}
  for i in pairs(cacheImg) do
    if i < indice then remover[#remover + 1] = i end
  end
  for _, i in ipairs(remover) do
    pcall(function() cacheImg[i]:release() end)
    cacheImg[i] = nil
  end
end

function tut.liberar()
  for i in pairs(cacheImg) do
    pcall(function() cacheImg[i]:release() end)
  end
  cacheImg = {}
end

local function retQuadro()
  local altArea = VH - 128
  local h = altArea - 24
  local w = h * 16 / 9
  if w > VW * 0.94 then
    w = VW * 0.94
    h = w * 9 / 16
  end
  return { x = (VW - w) / 2, y = (altArea - h) / 2, w = w, h = h }
end

local function falaAtual()
  local q = QUADROS[est.indice]
  if not q then return nil end
  if est.falaIdx == nil or est.falaIdx < 1 then return nil end
  return q.falas[clamp(est.falaIdx, 1, #q.falas)]
end

local function alturaLinha(tam)
  local f = arte.fonte(tam)
  local h = f:getHeight()
  local minimo = math.floor(tam * 1.35 + 0.5)
  if h < minimo then return minimo end
  return h
end

local function desenharLinhas(linhas, x, y, tam, cor, hLinha, alfa)
  local f = arte.fonte(tam)
  love.graphics.setFont(f)
  ui.pintar(cor, alfa)
  for i, l in ipairs(linhas) do
    love.graphics.print(l, x, y + (i - 1) * hLinha)
  end
  return #linhas * hLinha
end

local function coverComAlpha(img, x, y, w, h, alfa)
  if not img then return end
  local iw, ih = img:getDimensions()
  local esc = math.max(w / iw, h / ih)
  local sw, sh = w / esc, h / esc
  local sx, sy = (iw - sw) / 2, (ih - sh) / 2
  local quad = love.graphics.newQuad(sx, sy, sw, sh, iw, ih)
  love.graphics.setColor(1, 1, 1, alfa or 1)
  love.graphics.draw(img, quad, x, y, 0, esc, esc)
end

-- CAIXA DE LEGENDA ----------------------------------------------------------

local function retLegenda()
  -- DicaAvulsa do RN: quadro comeca sem caixa; caixa vazia, so o aviso centralizado.
  if est.falaIdx == -1 then
    local tamDica = ui.E(11)
    local alt = ui.E(12) + alturaLinha(tamDica) + ui.E(12)
    return {
      x = 16, y = VH - 18 - alt, w = VW - 32, h = alt,
      linhas = {}, hLinha = alturaLinha(tamDica), texto = "TOQUE PARA CONTINUAR",
      tamSpk = ui.E(14), tamTxt = ui.E(19), tamDica = tamDica,
      padX = ui.E(20), padTop = ui.E(12), padBot = ui.E(12),
      fala = nil, mostraDica = false, soDica = true,
    }
  end

  local f = falaAtual()
  if not f then return nil end
  local texto = f.text

  local x, larg = 16, VW - 32
  local padX, padTop, padBot = ui.E(20), ui.E(14), ui.E(12)
  local tamSpk = ui.E(14)
  local tamTxt = ui.E(19)
  local tamDica = ui.E(11)
  local hLinha = alturaLinha(tamTxt)
  local linhas = ui.quebrar(texto, tamTxt, larg - padX * 2)

  local alt = padTop + padBot + alturaLinha(tamSpk) + ui.E(6) + #linhas * hLinha
  if not est.pausa then
    alt = alt + ui.E(6) + alturaLinha(tamDica)
  end

  return {
    x = x, y = VH - 18 - alt, w = larg, h = alt,
    linhas = linhas, hLinha = hLinha, texto = texto,
    tamSpk = tamSpk, tamTxt = tamTxt, tamDica = tamDica,
    padX = padX, padTop = padTop, padBot = padBot,
    fala = f, mostraDica = not est.pausa, soDica = false,
  }
end

local function desenharLegenda(a)
  local r = retLegenda()
  est.legendaRet = r
  if not r then return end

  ui.caixa(r.x, r.y, r.w, r.h, 8, COR_LEG_FUNDO, nil, 0, 0.82 * a)
  love.graphics.setLineWidth(1)
  ui.pintar(BRANCO, 0.16 * a)
  love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8, 8)
  love.graphics.setLineWidth(1)

  if r.soDica then
    local h = alturaLinha(r.tamDica)
    ui.txt(r.texto, r.x, r.y + (r.h - h) / 2, r.tamDica, COR_LEG_DICA, "center", r.w,
      a * est.piscada)
    return
  end

  local y = r.y + r.padTop
  if r.fala then
    ui.txt(r.fala.speaker, r.x + r.padX, y, r.tamSpk, OURO, nil, nil, a)
    y = y + alturaLinha(r.tamSpk) + ui.E(6)
  end
  desenharLinhas(r.linhas, r.x + r.padX, y, r.tamTxt, BRANCO, r.hLinha, a)

  if r.mostraDica then
    local textoDica = "TOQUE PARA CONTINUAR"
    local yD = r.y + r.h - r.padBot - alturaLinha(r.tamDica)
    local xD = r.x + r.w - r.padX
    local largD = ui.larguraTexto(textoDica, r.tamDica)
    local tri = ui.E(9)
    ui.txt(textoDica, xD - largD - tri - ui.E(6), yD, r.tamDica, COR_LEG_DICA, nil, nil,
      a * est.piscada)
    ui.pintar(COR_LEG_DICA, a * est.piscada)
    local tx = xD - largD - ui.E(6)
    local ty = yD + alturaLinha(r.tamDica) / 2
    love.graphics.polygon("fill", tx, ty - tri / 2, tx, ty + tri / 2, tx + tri, ty)
  end
end

-- SPRITE DO GUIA E FUNDO CICLICO --------------------------------------------

local function corCiclica()
  local u = (est.t % 3.6) / 3.6
  local p = 1 - math.abs(1 - 2 * u)
  local a, b, t
  if p <= 0.5 then
    a, b, t = 0, 45, p / 0.5
  else
    a, b, t = 45, 120, (p - 0.5) / 0.5
  end
  local v = (a + (b - a) * t) / 255
  return v, v, v
end

local function desenharGuia(cx, cy, d, falando)
  if not imgGuia then return end
  local respir = (1 - math.cos(est.t * 2 * math.pi / 3)) / 2
  local opMin = falando and 0.8 or 0.55
  local opMax = falando and 1.0 or 0.95
  local haloOp = lerp(opMin, opMax, respir)
  local esc = 1 + 0.06 * respir
  local trem = falando and math.sin(est.t * 2 * math.pi / 0.14) or 0
  local tx, ty = trem * 3, trem * 2.2
  local escSprite = falando and (1 + 0.05 * math.abs(trem)) or 1

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(esc, esc)
  ui.pintar(BRANCO, 0.16 * haloOp)
  love.graphics.circle("fill", 0, 0, d * 1.15, 64)
  ui.pintar(BRANCO, 0.3 * haloOp)
  love.graphics.circle("fill", 0, 0, d * 0.75, 64)

  love.graphics.push()
  love.graphics.translate(tx, ty)
  love.graphics.scale(escSprite, escSprite)
  local iw, ih = imgGuia:getDimensions()
  local e = math.min(d / iw, d / ih)
  love.graphics.setColor(1, 1, 1, haloOp)
  love.graphics.draw(imgGuia, 0, 0, 0, e, e, iw / 2, ih / 2)
  love.graphics.pop()
  love.graphics.pop()
end

-- DESTAQUE DE TIPOS ----------------------------------------------------------

local function desenharDestaque(a)
  local f = falaAtual()
  if not f or not f.destaque then return end
  local carta = exemplar[ID_DESTAQUE[f.destaque]]
  if not carta then return end

  local w, h = 260, 340
  local r = est.legendaRet
  local baseY = (r and r.y or VH - 140) - 8 - h
  local x = (VW - w) / 2
  local y = baseY
  local entrada = clamp(est.tDestaque / 0.25, 0, 1)
  local alfa = lerp(0.4, 1, entrada) * a

  local rot = ROTULO_DESTAQUE[f.destaque] or f.destaque
  local tamRot = ui.E(13)
  local largRot = ui.E(340)
  ui.txtCabe(rot, (VW - largRot) / 2, y - ui.E(10) - alturaLinha(tamRot), tamRot, largRot,
    OURO, "center", ui.E(9), alfa)

  ui.pintar(OURO, 0.12 * alfa)
  love.graphics.rectangle("fill", x - 7, y - 7, w + 14, h + 14, 8, 8, 8)
  desenharFace(carta, x, y, w, h)
  ui.pintar(OURO, alfa)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x - 7, y - 7, w + 14, h + 14, 8, 8, 8)
  love.graphics.setLineWidth(1)
end

-- PORTAL ---------------------------------------------------------------------

local function desenharPortal()
  if est.transicao ~= "portal" then return end
  love.graphics.setColor(0, 0, 0, 1)
  ui.preencherTela(VW, VH)
  local p = clamp(est.tPortal / DUR_PORTAL_LUZ, 0, 1)
  local esc = lerp(0.3, 75, p)
  local brilho = p <= 0.6 and (p / 0.6) or 1
  ui.pintar(BRANCO, brilho)
  love.graphics.circle("fill", VW / 2, VH / 2, 12 * esc, 64)
end

-- OVERLAY DO DECK -----------------------------------------------------------

local function retDeck()
  return { x = DECK_X, y = DECK_Y, w = DECK_W, h = DECK_H }
end

local function novoDeck(fala)
  local part = {}
  for i = 1, 16 do
    part[i] = {
      ang = (i / 16) * math.pi * 2 + (love.math.random() - 0.5) * 0.4,
      dist = (70 + love.math.random() * 95) * 2,
      tam = 4 + love.math.random() * 5,
      cor = love.math.random() < 0.5 and OURO or { 1, 0.953, 0.769 },
      atraso = love.math.random() * 0.07,
      dur = 0.52 + love.math.random() * 0.22,
    }
  end
  return {
    fala = fala, revelado = false, windup = false, estouro = false,
    tWindup = 0, tEstouro = -1, tFlash = -1, tOnda = -1, tShake = -1, tPart = -1,
    pulso = 0, scroll = 0, tRevel = -1, tBotao = -1,
    cartasT = {}, particulas = part,
  }
end

local function abrirDeck()
  local d = est.deck
  if not d or d.windup or d.estouro or d.revelado then return end
  d.windup = true
  d.tWindup = 0
end

local function atualizarDeck(d, dt)
  d.pulso = d.pulso + dt
  if d.windup then
    d.tWindup = d.tWindup + dt
    if d.tWindup >= 0.2 then
      d.windup = false
      d.estouro = true
      d.tEstouro = 0
      d.tFlash = 0
      d.tOnda = 0
      d.tShake = 0
      d.tPart = 0
    end
  end
  if d.estouro then
    d.tEstouro = d.tEstouro + dt
    if d.tEstouro >= 0.2 then
      d.estouro = false
      d.revelado = true
      d.tRevel = 0
      d.cartasT = {}
    end
  end
  if d.tFlash >= 0 then
    d.tFlash = d.tFlash + dt
    if d.tFlash > 0.42 then d.tFlash = -1 end
  end
  if d.tOnda >= 0 then
    d.tOnda = d.tOnda + dt
    if d.tOnda > 0.7 then d.tOnda = -1 end
  end
  if d.tShake >= 0 then
    d.tShake = d.tShake + dt
    if d.tShake > 0.14 then d.tShake = -1 end
  end
  if d.tPart >= 0 then
    d.tPart = d.tPart + dt
    if d.tPart > 0.9 then d.tPart = -1 end
  end

  if d.revelado then
    d.tRevel = d.tRevel + dt
    for i = 1, #baralho do
      local delay = (i - 1) * 0.03
      if d.tRevel > delay then
        d.cartasT[i] = clamp((d.tRevel - delay) / 0.6, 0, 1)
      end
    end
    local delayBotao = #baralho * 0.03 + 0.12
    if d.tRevel > delayBotao then
      d.tBotao = clamp(d.tBotao + dt / 0.32, 0, 1)
    end
  end
end

local function shakeOffset(t)
  if t == nil or t < 0 then return 0 end
  if t < 0.035 then return 12 * (t / 0.035) end
  if t < 0.070 then return 12 - 24 * ((t - 0.035) / 0.035) end
  if t < 0.105 then return -12 + 18 * ((t - 0.070) / 0.035) end
  if t < 0.140 then return 6 - 6 * ((t - 0.105) / 0.035) end
  return 0
end

local function deckEsc(d)
  if d.windup then
    if d.tWindup < 0.09 then return lerp(1, 0.9, d.tWindup / 0.09) end
    return lerp(0.9, 1.1, (d.tWindup - 0.09) / 0.11)
  end
  if d.estouro then return lerp(1.1, 1.32, clamp(d.tEstouro / 0.2, 0, 1)) end
  return 1
end

local function deckOpacidade(d)
  if d.estouro then return clamp(1 - d.tEstouro / 0.18, 0, 1) end
  return 1
end

local function desenharOnda(d)
  if d.tOnda < 0 then return end
  local p = clamp(d.tOnda / 0.7, 0, 1)
  local alfa = p <= 0.4 and lerp(0.9, 0.35, p / 0.4) or lerp(0.35, 0, (p - 0.4) / 0.6)
  local esc = lerp(0.3, 14, p)
  local cx, cy = VW / 2, DECK_Y + DECK_H / 2
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(esc, esc)
  ui.pintar(OURO, alfa)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", 0, 0, 55, 64)
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

local function desenharFlash(d)
  if d.tFlash < 0 then return end
  local p = clamp(d.tFlash / 0.42, 0, 1)
  local alfa = p <= 0.45 and (p / 0.45) or (1 - (p - 0.45) / 0.55)
  local esc = lerp(0.35, 16, p)
  local cx, cy = VW / 2, DECK_Y + DECK_H / 2
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(esc, esc)
  ui.pintar(BRANCO, alfa)
  love.graphics.circle("fill", 0, 0, 48, 48)
  ui.pintar(OURO, alfa * 0.5)
  love.graphics.circle("fill", 0, 0, 64, 48)
  love.graphics.pop()
end

local function desenharParticulas(d)
  if d.tPart < 0 then return end
  local cx, cy = VW / 2, DECK_Y + DECK_H / 2
  for _, pc in ipairs(d.particulas) do
    local p = (d.tPart - pc.atraso) / pc.dur
    if p > 0 and p < 1 then
      local alfa = p <= 0.15 and (p / 0.15) or (1 - (p - 0.15) / 0.85)
      local dx = math.cos(pc.ang) * pc.dist * p
      local dy = math.sin(pc.ang) * pc.dist * p
      local esc = lerp(0.5, 1.3, p)
      ui.pintar(pc.cor, alfa)
      love.graphics.circle("fill", cx + dx, cy + dy, pc.tam * esc / 2, 12)
    end
  end
end

local function botaoContinuarRect()
  local w, h = ui.E(260), ui.E(36)
  local y = 478
  -- Fica sempre ACIMA da caixa de legenda do overlay (reserva do paddingBottom do RN).
  if est then
    local salvaPausa = est.pausa
    est.pausa = true
    local r = retLegenda()
    est.pausa = salvaPausa
    if r then y = math.min(y, r.y - ui.E(10) - h) end
  end
  return { x = (VW - w) / 2, y = y, w = w, h = h }
end

local function desenharBotaoContinuar(d)
  local r = botaoContinuarRect()
  local t = clamp(d.tBotao, 0, 1)
  if t <= 0 then return end
  ui.caixa(r.x, r.y + (1 - t) * 24, r.w, r.h, 10, COR_BOTAO, OURO, 2, t)
  ui.txt("CONTINUAR >", r.x, r.y + (1 - t) * 24 + (r.h - alturaLinha(ui.E(14))) / 2,
    ui.E(14), OURO, "center", r.w, t)
  est.rectContinuar = r
end

local function desenharDeck(hover)
  local d = est.deck
  if not d then return end

  love.graphics.setColor(COR_PAINEL[1], COR_PAINEL[2], COR_PAINEL[3], 0.96)
  ui.preencherTela(VW, VH)

  local falando = d.fala ~= nil and d.fala.speaker == G
  desenharGuia(VW / 2, 70, ui.E(32), falando)

  love.graphics.push()
  love.graphics.translate(shakeOffset(d.tShake), 0)

  if not d.revelado then
    local r = retDeck()
    local esc = deckEsc(d)
    local alfa = deckOpacidade(d)
    local sobre = dentro(hover.x, hover.y, r)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(esc, esc)
    ui.pintar(OURO, 0.6 * alfa * (sobre and 1 or 0.8))
    love.graphics.rectangle("fill", -(r.w + 28) / 2, -(r.h + 28) / 2, r.w + 28, r.h + 28,
      14, 14, 8)
    ui.verso(-r.w / 2, -r.h / 2, r.w, r.h)
    if alfa < 1 then
      love.graphics.setColor(COR_PAINEL[1], COR_PAINEL[2], COR_PAINEL[3], (1 - alfa) * 0.96)
      love.graphics.rectangle("fill", -r.w / 2, -r.h / 2, r.w, r.h, 6, 6, 8)
    end
    love.graphics.pop()

    desenharParticulas(d)

    if not d.windup and not d.estouro then
      local pulso = lerp(1, 0.35, 1 - math.abs(1 - 2 * ((d.pulso / 1.3) % 1)))
      local tamDica = ui.E(13)
      ui.txt("TOQUE NO DECK PARA ABRIR", r.x, r.y + r.h + ui.E(12), tamDica, OURO,
        "center", r.w, pulso)
    end
  else
    local largCarta = DECK_W
    local total = #baralho
    local maxScroll = math.min(0, VW - 24 - (total * (largCarta + DECK_GAP) - DECK_GAP))
    d.scroll = clamp(d.scroll, maxScroll, 0)
    local baseY = DECK_Y
    for i, carta in ipairs(baralho) do
      local t = d.cartasT[i] or 0
      local x = 12 + d.scroll + (i - 1) * (largCarta + DECK_GAP)
      if t > 0 and x + largCarta > -4 and x < VW + 4 then
        local p = t
        local giro = (i % 2 == 0) and -14 or 14
        local rot = math.rad(giro * (1 - p))
        local dy = lerp(64, 0, 1 - (1 - p) * (1 - p))
        local sobe = 1 + 0.08 * math.sin(math.pi * p)
        local esc = lerp(0.4, 1, 1 - (1 - p) * (1 - p)) * sobe
        local cx = x + largCarta / 2
        local cy = baseY + DECK_H / 2 + dy
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(rot)
        love.graphics.scale(esc, esc)
        desenharFace(carta, -largCarta / 2, -DECK_H / 2, largCarta, DECK_H)
        if p < 1 then
          love.graphics.setColor(COR_PAINEL[1], COR_PAINEL[2], COR_PAINEL[3], (1 - p) * 0.96)
          love.graphics.rectangle("fill", -largCarta / 2, -DECK_H / 2, largCarta, DECK_H, 6, 6, 8)
        end
        love.graphics.pop()
      end
    end
    desenharBotaoContinuar(d)
  end

  love.graphics.pop()

  desenharOnda(d)
  desenharFlash(d)

  if d.fala then
    local salva = est.falaIdx
    local salvaPausa = est.pausa
    est.pausa = true
    local r = retLegenda()
    est.falaIdx = salva
    est.pausa = salvaPausa
    est.legendaRet = r
    if r then
      local y = r.y + r.padTop
      ui.caixa(r.x, r.y, r.w, r.h, 8, COR_LEG_FUNDO, nil, 0, 0.82)
      love.graphics.setLineWidth(1)
      ui.pintar(BRANCO, 0.16)
      love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8, 8)
      love.graphics.setLineWidth(1)
      ui.txt(d.fala.speaker, r.x + r.padX, y, r.tamSpk, OURO)
      y = y + alturaLinha(r.tamSpk) + ui.E(6)
      desenharLinhas(r.linhas, r.x + r.padX, y, r.tamTxt, BRANCO, r.hLinha, 1)
    end
  end
end

-- PAINEL FINAL ---------------------------------------------------------------

local function retFim()
  local w = 640
  return {
    principal = { x = (VW - w) / 2, y = 440, w = w, h = 64 },
    secundario = { x = (VW - w) / 2, y = 522, w = w, h = 56 },
    largura = w,
    larguraDesc = 840,
  }
end

local function desenharFim(hover)
  local r = retFim()
  est.rectsFim = r
  love.graphics.setColor(COR_PAINEL[1], COR_PAINEL[2], COR_PAINEL[3], 0.94)
  ui.preencherTela(VW, VH)

  local tamTit = ui.E(28)
  local yTit = 160
  ui.txt("TUTORIAL CONCLUIDO", (VW - r.largura) / 2, yTit, tamTit, OURO, "center", r.largura)

  local tamFala = ui.E(20)
  local yFala = yTit + alturaLinha(tamTit) + ui.E(17)
  ui.txt("Boa sorte. - GUIA", (VW - r.largura) / 2, yFala, tamFala, BRANCO, "center", r.largura)

  local desc = "O proximo passo e o seu primeiro duelo.\nO sistema de batalha e o mesmo do jogo normal."
  local tamDesc = ui.E(16)
  local hLinha = alturaLinha(tamDesc)
  local y = yFala + alturaLinha(tamFala) + ui.E(28)
  for linha in desc:gmatch("[^\n]+") do
    for _, l in ipairs(ui.quebrar(linha, tamDesc, r.larguraDesc)) do
      ui.txt(l, (VW - r.larguraDesc) / 2, y, tamDesc, C.TEXTO3, "center", r.larguraDesc)
      y = y + hLinha
    end
  end

  local tamPri = ui.E(16)
  local sobrePri = dentro(hover.x, hover.y, r.principal)
  ui.caixa(r.principal.x, r.principal.y, r.principal.w, r.principal.h, 12, COR_BOTAO, OURO, 2,
    sobrePri and 1 or 0.9)
  ui.pintar(OURO, sobrePri and 0.5 or 0.35)
  love.graphics.rectangle("fill", r.principal.x, r.principal.y, r.principal.w, 3, 2, 2, 2)
  ui.txt("COMECAR O PRIMEIRO DUELO", r.principal.x,
    r.principal.y + (r.principal.h - alturaLinha(tamPri)) / 2, tamPri, OURO, "center",
    r.principal.w)

  local tamSec = ui.E(14)
  local sobreSec = dentro(hover.x, hover.y, r.secundario)
  ui.caixa(r.secundario.x, r.secundario.y, r.secundario.w, r.secundario.h, 12, nil,
    ui.hex "#3A3A52", 1)
  ui.txt("VOLTAR AO MENU", r.secundario.x,
    r.secundario.y + (r.secundario.h - alturaLinha(tamSec)) / 2, tamSec,
    sobreSec and BRANCO or C.TEXTO3, "center", r.secundario.w)
end

-- FLUXO ----------------------------------------------------------------------

local function finalizar()
  est.fim = true
  est.rectsFim = retFim()
end

local trocarPara

local function iniciarPortal()
  if est.indice >= #QUADROS then
    finalizar()
    return
  end
  est.transicao = "portal"
  est.tPortal = 0
  est.busy = DUR_PORTAL + DUR_FADE
  carregarImg(est.indice + 1)
  agendar(DUR_PORTAL, function()
    trocarPara(est.indice + 1)
    est.transicao = nil
    est.tPortal = 0
    est.troca = { t = 0, fase = "in", prox = nil }
  end)
end

local function proximoQuadro()
  if est.indice >= #QUADROS then
    finalizar()
    return
  end
  est.busy = DUR_FADE
  est.troca = { t = 0, fase = "out", prox = est.indice + 1 }
  carregarImg(est.indice + 1)
end

trocarPara = function(i)
  est.indice = i
  local q = QUADROS[i]
  est.falaIdx = q.comecarSemCaixa and -1 or 1
  est.tDestaque = 0
  est.preload = 0.3
  carregarImg(i)
  limparImgAte(i)
end

local function finalizarQuadro(q)
  if q.transicaoSaida == "portal" then
    iniciarPortal()
    return
  end
  if q.acaoAoTerminar == "mostrarDeck" then
    est.overlayDeck = true
    est.deck = novoDeck(falaAtual())
    return
  end
  if q.acaoAoTerminar == "fim" then
    finalizar()
    return
  end
  proximoQuadro()
end

local function avancar()
  if not est or est.fase ~= "cena" then return end
  if est.busy > 0 or est.pausa or est.overlayDeck or est.fim or est.transicao then return end
  local q = QUADROS[est.indice]
  local total = #q.falas
  local atual = est.falaIdx
  if atual < total then
    local prox = atual < 0 and 1 or atual + 1
    est.falaIdx = prox
    if prox == total and (q.pausaAntesProximo or 0) > 0 then
      est.pausa = true
      est.pausaT = q.pausaAntesProximo
    end
    return
  end
  finalizarQuadro(q)
end

local function toqueIntro()
  if est.t - est.tUltimoToque < INTERVALO_TOQUE then return end
  est.tUltimoToque = est.t
  if est.fraseIdx >= #FRASES_INTRO then
    est.fase = "cena"
    est.indice = 1
    local q = QUADROS[1]
    est.falaIdx = q.comecarSemCaixa and -1 or 1
    est.tEntrada = 0
    est.troca = nil
    est.opQuadro = 1
    est.tDestaque = 0
    est.preload = 0.3
    carregarImg(1)
    return
  end
  est.fraseIdx = est.fraseIdx + 1
  est.tFrase = 0
end

function tut.concluirDeck()
  if not est or not est.overlayDeck then return end
  est.overlayDeck = false
  est.deck = nil
  proximoQuadro()
end

function tut.clicarDeck()
  abrirDeck()
end

-- PUBLICO --------------------------------------------------------------------

function tut.iniciar(debug)
  tut.liberar()
  garantirBase()
  est = {
    fase = "intro", fraseIdx = 1, tFrase = 0, tUltimoToque = -999,
    t = 0, timers = {}, busy = 0, pausa = false, pausaT = 0,
    indice = 1, falaIdx = 1, opQuadro = 1, tEntrada = DUR_ENTRADA,
    troca = nil, transicao = nil, tPortal = 0, tDestaque = 0,
    overlayDeck = false, deck = nil, fim = false,
    piscada = 1, preload = -1, legendaRet = nil, rectsFim = retFim(),
    rectContinuar = nil, hoverAnt = { x = -999, y = -999 },
  }

  if debug then
    tut.debug(debug)
  end
end

function tut.debug(acao)
  if not est then return end
  local n, fala
  if acao then
    n, fala = acao:match("^quadro(%d+):?(%d*)$")
  end
  n = tonumber(n)
  if n then
    est.fase = "cena"
    est.tFrase = 0
    est.tEntrada = DUR_ENTRADA
    est.busy = 0
    est.pausa = false
    est.pausaT = 0
    est.troca = nil
    est.transicao = nil
    trocarPara(clamp(n, 1, #QUADROS))
    local q = QUADROS[est.indice]
    local nf = tonumber(fala)
    if nf then
      est.falaIdx = clamp(nf, 1, #q.falas)
    else
      est.falaIdx = math.min(1, #q.falas)
      if q.comecarSemCaixa then est.falaIdx = -1 end
    end
    return
  end
  if acao == "frase2" then
    est.fraseIdx = 2
    est.tFrase = DUR_ENTRADA
  elseif acao == "deck" or acao == "deckrev" then
    tut.debug("quadro12")
    local q = QUADROS[est.indice]
    est.falaIdx = #q.falas
    est.overlayDeck = true
    est.deck = novoDeck(falaAtual())
    if acao == "deckrev" then
      est.deck.revelado = true
      est.deck.tRevel = 99
      est.deck.tBotao = 1
      for i = 1, #baralho do est.deck.cartasT[i] = 1 end
    end
  elseif acao == "fim" then
    tut.debug("quadro14")
    est.falaIdx = #QUADROS[14].falas
    finalizar()
  end
end

function tut.update(dt)
  if not est then return end
  est.t = est.t + dt

  local i = 1
  while i <= #est.timers do
    local tm = est.timers[i]
    tm.t = tm.t - dt
    if tm.t <= 0 then
      table.remove(est.timers, i)
      tm.fn()
    else
      i = i + 1
    end
  end

  if est.busy > 0 then est.busy = math.max(0, est.busy - dt) end
  if est.pausa then
    est.pausaT = est.pausaT - dt
    if est.pausaT <= 0 then
      est.pausa = false
      est.pausaT = 0
    end
  end

  local pisc = (est.t % 1.4) / 1.4
  est.piscada = pisc <= 0.5 and lerp(1, 0.3, pisc / 0.5) or lerp(0.3, 1, (pisc - 0.5) / 0.5)

  if est.fase == "intro" then
    if est.tFrase < DUR_ENTRADA then est.tFrase = math.min(DUR_ENTRADA, est.tFrase + dt) end
    return
  end

  if est.tEntrada < DUR_ENTRADA then est.tEntrada = est.tEntrada + dt end

  local f = falaAtual()
  local destaque = f and f.destaque or nil
  if destaque ~= est.destaqueAnt then
    est.destaqueAnt = destaque
    est.tDestaque = 0
  end
  if est.tDestaque < 0.25 then est.tDestaque = est.tDestaque + dt end

  if est.preload >= 0 then
    est.preload = est.preload - dt
    if est.preload < 0 then
      carregarImg(est.indice + 1)
      est.preload = -1
    end
  end

  if est.troca then
    est.troca.t = est.troca.t + dt
    if est.troca.fase == "out" and est.troca.t >= DUR_OUT then
      trocarPara(est.troca.prox)
      est.troca = { t = 0, fase = "in" }
    elseif est.troca.fase == "in" and est.troca.t >= DUR_IN then
      est.troca = nil
    end
  end

  if est.transicao == "portal" then
    est.tPortal = est.tPortal + dt
  end

  local op = 1
  if est.troca then
    if est.troca.fase == "out" then
      op = clamp(1 - est.troca.t / DUR_OUT, 0, 1)
    else
      op = clamp(est.troca.t / DUR_IN, 0, 1)
    end
  elseif est.transicao == "portal" then
    op = clamp(1 - est.tPortal / 0.4, 0, 1)
  end
  est.opQuadro = op

  if est.deck then atualizarDeck(est.deck, dt) end
end

local function desenharIntro()
  local frase = FRASES_INTRO[est.fraseIdx]
  local p = est.tFrase / DUR_ENTRADA
  local alfa = clamp(p, 0, 1)
  local dy = lerp(18, 0, p)
  local tam = ui.E(26)
  local larg = VW - 100
  local x = 50
  local h = alturaLinha(tam)
  local y = (VH - h) / 2 + dy

  for _, off in ipairs({ -3, 3 }) do
    ui.txt(frase, x + off, y, tam, BRANCO, "center", larg, alfa * 0.12)
    ui.txt(frase, x, y + off, tam, BRANCO, "center", larg, alfa * 0.12)
  end
  ui.txt(frase, x, y, tam, BRANCO, "center", larg, alfa)
end

local function desenharCena(hover)
  local q = QUADROS[est.indice]
  local a = est.opQuadro

  if q.fundo == "ciclico" then
    love.graphics.setColor(corCiclica())
    ui.preencherTela(VW, VH)
    if not est.overlayDeck then
      local f = falaAtual()
      desenharGuia(VW / 2, (VH - 128) / 2, math.min(VW, VH) * 0.24,
        f ~= nil and f.speaker == G)
    end
  end

  if q.imgPath and not q.fundo then
    local img = cacheImg[est.indice]
    if img then
      local r = retQuadro()
      local entrada = clamp(est.tEntrada / DUR_ENTRADA, 0, 1)
      local esc = lerp(0.94, 1, entrada)
      local alfaEntrada = entrada
      love.graphics.push()
      love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
      love.graphics.scale(esc, esc)
      coverComAlpha(img, -r.w / 2, -r.h / 2, r.w, r.h, alfaEntrada * a)
      love.graphics.pop()
    end
  end

  est.legendaRet = retLegenda()
  desenharDestaque(a)
  desenharLegenda(a)

  desenharPortal()
end

function tut.desenhar(hover)
  if not est then return end
  hover = hover or { x = -999, y = -999 }

  love.graphics.setColor(COR_CENA)
  ui.preencherTela(VW, VH)

  if est.fase == "intro" then
    desenharIntro()
  else
    desenharCena(hover)
  end

  if est.overlayDeck then desenharDeck(hover) end
  if est.fim then desenharFim(hover) end
end

function tut.clicado(vx, vy)
  if not est then return nil end

  if est.fim then
    local r = est.rectsFim or retFim()
    if dentro(vx, vy, r.principal) then return "jogar" end
    if dentro(vx, vy, r.secundario) then return "menu" end
    return nil
  end

  if est.fase == "intro" then
    toqueIntro()
    return nil
  end

  if est.overlayDeck then
    local d = est.deck
    if not d then return nil end
    if not d.revelado then
      if dentro(vx, vy, retDeck()) then abrirDeck() end
      return nil
    end
    if est.rectContinuar and dentro(vx, vy, est.rectContinuar) then
      tut.concluirDeck()
    end
    return nil
  end

  local r = est.legendaRet or retLegenda()
  if r and dentro(vx, vy, r) then avancar() end
  return nil
end

function tut.tecla(key)
  if not est then return nil end
  if key == "space" or key == "return" then
    if est.fim then return nil end
    if est.fase == "intro" then
      toqueIntro()
      return nil
    end
    if est.overlayDeck then
      if not est.deck.revelado then abrirDeck() end
      return nil
    end
    avancar()
  elseif est.deck and est.deck.revelado then
    if key == "left" then
      est.deck.scroll = math.min(0, est.deck.scroll + DECK_W + DECK_GAP)
    elseif key == "right" then
      est.deck.scroll = est.deck.scroll - (DECK_W + DECK_GAP)
    end
  end
  return nil
end

function tut.rolagem(dx)
  if est and est.deck and est.deck.revelado then
    est.deck.scroll = est.deck.scroll + dx * 160
  end
end

function tut.estado()
  if not est then return {} end
  local d = est.deck
  return {
    fase = est.fase, fraseIdx = est.fraseIdx, indice = est.indice,
    falaIdx = est.falaIdx, fim = est.fim, overlayDeck = est.overlayDeck,
    revelado = d ~= nil and d.revelado, busy = est.busy, pausa = est.pausa,
    total = #QUADROS,
  }
end

tut.retFim = retFim
tut.retDeck = retDeck
tut.retContinuar = botaoContinuarRect
tut.avancar = avancar

return tut
