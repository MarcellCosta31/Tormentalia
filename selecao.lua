-- Tela MODO UM JOGADOR: SELECAO DE CICLOS com as ilhas do caminho (Ciclo I
-- - O REINO ESQUECIDO e Ciclo 2 - A EFICIENCIA, folheadas pelas setas
-- laterais) e a roda de inimigos que sobe ao clicar numa ilha (estilo stage
-- select): um circulo por inimigo do ciclo, o primeiro da fila nasce
-- liberado e cada vitoria destrava o proximo ate o SOBERANO (o ultimo
-- circulo, marcado por `soberano` na fila); o clique num destravado fora do
-- centro so centraliza, e o clique no centralizado (ou a roda do mouse)
-- abre o duelo - revanche livre nos ja derrotados. A dificuldade da IA por
-- inimigo vai junto em dueloAtual() (espera/jogar/guarda crescentes ate o
--chefe). Cada ciclo tem a sua fila (Ciclo I: 7 nos ate Adam Smith; Ciclo 2:
-- 6 nos ate Frederick Taylor) e o seu progresso salvo. Selecao: fundo
-- desertico, placa do titulo, ilha em foco (pulsando), setas de folhear e
-- saldo no canto superior.
local ui = require "ui"
local arte = require "arte"
local dinheiro = require "dinheiro"

local S = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"

local VW, VH = 1280, 720
local CX = 640

local COR_TITULO = ui.hex "#F7D488"
local COR_BORDA = ui.hex "#E8C55A"
local COR_ROTULO = { 0.92, 0.87, 0.72 }
local COR_BLOQ = { 0.58, 0.6, 0.66 }
-- Acento dos inimigos "elite" (prata fria por fora da moldura dourada).
local COR_PRATA = ui.hex "#A8C0D8"

-- Topo: botao voltar (icone nas duas vistas) + placa do titulo.
local VOLTAR = { x = 26, y = 26, w = 44, h = 41 }
-- Hitbox do voltar NA SELECAO: icone + a palavra VOLTAR (alvo de toque
-- largo no mobile). Na selecao devolve 'voltar' (menu); com a roda
-- aberta recolhe os circulos.
local VOLTAR_SEL = { x = 22, y = 14, w = 182, h = 62 }

-- Placa superior "SELECAO DE CICLOS" (2256x332, titulo embutido na arte).
local PLACA = { x = 390, y = 8, w = 500, h = 74 }

-- Ilhas do caminho, na ordem em que as setas laterais folheiam (a placa
-- com o nome do ciclo ja vem pintada na arte), cada uma com a sua fila de
-- inimigos e os seus saves. A dificuldade da IA sobe a cada no: reacao mais
-- rapida, mais jogadas, escolhas melhores e mais guarda - o SOBERANO (o
-- ultimo da fila, `soberano`) joga no nivel cheio. `dialogo` marca o no que
-- abre a conversa antes da VS (hoje so o Adam, no Ciclo I).
local CICLOS = {
  {
    nome = "O REINO ESQUECIDO", arte = "sel_ilha_1",
    prog = "ciclo1_progresso", chefe = "ciclo1_chefe",
    inimigos = {
      { idx = 1, nome = "Consumidor Desesperado", avatar = "inimigo_5", estilo = "oportunista",
        espera = 6, chanceJogar = 0.5, chanceMelhor = 0.4, guarda = 0.1 },
      { idx = 2, nome = "Funcionario Condenado", avatar = "inimigo_1", estilo = "agressivo",
        espera = 5.5, chanceJogar = 0.6, chanceMelhor = 0.5, guarda = 0.2 },
      { idx = 3, nome = "Trabalhador sem Rosto", avatar = "inimigo_3", estilo = "defensivo",
        espera = 5, chanceJogar = 0.7, chanceMelhor = 0.6, guarda = 0.3 },
      { idx = 4, nome = "Criatura Papel", avatar = "inimigo_2", estilo = "caotico",
        espera = 4.5, chanceJogar = 0.8, chanceMelhor = 0.7, guarda = 0.4 },
      { idx = 5, nome = "Fiscal", avatar = "inimigo_4", estilo = "agressivo", elite = true,
        espera = 4, chanceJogar = 0.85, chanceMelhor = 0.75, guarda = 0.5 },
      { idx = 6, nome = "Subordinado Corrompido", avatar = "inimigo_6", estilo = "oportunista",
        elite = true, espera = 3.5, chanceJogar = 0.9, chanceMelhor = 0.8,
        guarda = 0.6 },
      { idx = 7, nome = "Adam Smith", avatar = "inimigo_7", estilo = "caotico", soberano = true,
        dialogo = true, espera = 3, chanceJogar = 1, chanceMelhor = 1,
        guarda = 0.7 },
    },
  },
  {
    nome = "A EFICIENCIA", arte = "sel_ilha_2",
    prog = "ciclo2_progresso", chefe = "ciclo2_chefe",
    inimigos = {
      { idx = 1, nome = "Operario Desgastado", avatar = "inimigo2_1", estilo = "defensivo",
        espera = 4.6, chanceJogar = 0.7, chanceMelhor = 0.6, guarda = 0.35 },
      { idx = 2, nome = "Fiscal de Produtividade", avatar = "inimigo2_2", estilo = "agressivo",
        espera = 4.2, chanceJogar = 0.78, chanceMelhor = 0.68,
        guarda = 0.45 },
      { idx = 3, nome = "Esteira Faminta", avatar = "inimigo2_3", estilo = "oportunista",
        espera = 3.8, chanceJogar = 0.85, chanceMelhor = 0.75,
        guarda = 0.55 },
      { idx = 4, nome = "Relogio Fiscal", avatar = "inimigo2_4", estilo = "defensivo",
        elite = true, espera = 3.4, chanceJogar = 0.9, chanceMelhor = 0.85,
        guarda = 0.62 },
      { idx = 5, nome = "Capataz da Meta Impossivel", avatar = "inimigo2_5", estilo = "agressivo",
        elite = true, espera = 3.1, chanceJogar = 0.95, chanceMelhor = 0.9,
        guarda = 0.7 },
      { idx = 6, nome = "Frederick Taylor", avatar = "inimigo2_6", estilo = "oportunista",
        soberano = true, espera = 2.7, chanceJogar = 1, chanceMelhor = 1,
        guarda = 0.8 },
    },
  },
}

-- Ilha em foco (1920x1920 quadrada, com a placa do nome ja pintada):
-- centrada na tela, no lugar da antiga grade.
local ILHA = { x = 385, y = 99, w = 510, h = 510 }

-- Setas laterais: o sprite e um quadrado 1920x1920 com a seta ocupando
-- ~1/3 da largura no centro — 140px reproduz a medida do mockup (seta
-- visivel de ~50x77 nos centros x=62/1218, y=324). HIT_* e a area
-- clicavel/de toque em volta de cada sprite (mesmo centro da arte); nas
-- pontas do caminho a seta correspondente fica apagada.
local SETA_TAM = 140
local SETA_ESQ = { x = -8, y = 254 }
local SETA_DIR = { x = 1148, y = 254 }
local HIT_ESQ = { x = 2, y = 264, w = 120, h = 120 }
local HIT_DIR = { x = 1158, y = 264, w = 120, h = 120 }

-- Saldo no canto superior direito (moeda + valor formato 9.306).
local SALDO_DIR = 1246
local SALDO_CY = 44
local SALDO_TAM = 28

-- Roda de inimigos do ciclo em foco: um circulo por no, que sobem da base
-- quando a ilha e clicada (estilo stage select). CIRC_ESP = distancia entre
-- vizinhos; CIRC_Y = linha do central; a queda quadrada empurra os
-- laterais para baixo; CIRC_TAM = diametro do central (vizinhos encolhem
-- 1/(1+0.18*d)).
local CIRC_TAM = 212
local CIRC_ESP = 180
local CIRC_Y = 546
local CIRC_QUEDA = 20

-- Estado da tela: selecao de ciclos (ilha) ou roda de inimigos aberta.
local vista = "ciclos"
-- Indice da ilha em foco na selecao (1 = Ciclo I, 2 = Ciclo 2): as setas
-- laterais folheiam e o clique na ilha abre a roda do ciclo.
local cicloSel = 1
-- 0..1 da animacao da roda: sobe ao clicar na ilha, desce no ESC/voltar.
local circT = 0
local sel = nil
local prog = 0
-- Cartao centralizado (alvoSel) e posicao animada do carrossel (selVis).
local alvoSel = 1
local selVis = 1
-- O chefe so revela o retrato depois de enfrentado ao menos uma vez.
local chefe = false

-- Fila de inimigos do ciclo em foco (a roda, a VS e o duelo leem daqui).
local function fila()
  return CICLOS[cicloSel].inimigos
end

-- Quantos nos tem o ciclo em foco (o ultimo da fila e o SOBERANO).
local function totalNos()
  return #CICLOS[cicloSel].inimigos
end

-- Progresso por ciclo: no jogo, cada ciclo tem o seu save (ciclo1_*,
-- ciclo2_*); em MODO_TESTE o disco nao e tocado e a memoria (zerada no
-- iniciar) faz o papel do save.
local progMem = {}
local chefeMem = {}

local function arqProg(i)
  return CICLOS[i].prog
end

local function arqChefe(i)
  return CICLOS[i].chefe
end

-- Losango (quadrado girado 45 graus) com a cor corrente.
local function diamante(x, y, lado)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rotate(math.rad(45))
  love.graphics.rectangle("fill", -lado / 2, -lado / 2, lado, lado, 1, 1, 2)
  love.graphics.pop()
end

local function carregarProg(i)
  i = i or cicloSel
  if MODO_TESTE then return progMem[i] or 0 end
  local dados = love.filesystem.read(arqProg(i))
  local n = tonumber(dados)
  if n and n >= 0 and n <= #CICLOS[i].inimigos then
    return math.floor(n)
  end
  return 0
end

local function salvarProg()
  progMem[cicloSel] = prog
  if MODO_TESTE then return end
  pcall(love.filesystem.write, arqProg(cicloSel), tostring(prog))
end

local function carregarChefe(i)
  i = i or cicloSel
  if MODO_TESTE then return chefeMem[i] == true end
  return love.filesystem.read(arqChefe(i)) == "1"
end

local function salvarChefe()
  chefeMem[cicloSel] = true
  if MODO_TESTE then return end
  pcall(love.filesystem.write, arqChefe(cicloSel), "1")
end

-- Saldo formatado com ponto de milhar (mockup: "9.306").
local function milhar(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  if #s <= 3 then return s end
  s = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
  if s:sub(1, 1) == "." then s = s:sub(2) end
  return s
end

-- Saldo do jogador no topo direito (moeda dourada + valor com sombra).
local function desenharSaldo()
  local txt = milhar(dinheiro.valor())
  local larg = ui.larguraTexto(txt, SALDO_TAM)
  local d = 44
  local tx = SALDO_DIR - larg
  ui.imagemContain(arte.img("moeda"), tx - d - 8, SALDO_CY - d / 2, d, d)
  local ty = SALDO_CY - ui.alturaTexto(SALDO_TAM) / 2
  ui.txt(txt, tx + 2, ty + 2, SALDO_TAM, { 0, 0, 0, 0.9 })
  ui.txt(txt, tx, ty, SALDO_TAM, COR_TITULO)
end

-- Botao voltar (icone nas duas vistas; a palavra VOLTAR so na selecao,
-- onde nao ha estandarte do titulo para colidir).
local function desenharVoltar(comTexto)
  local voltar = arte.img("sel_voltar")
  if voltar then
    love.graphics.setColor(1, 1, 1, 1)
    ui.imagemCover(voltar, VOLTAR.x, VOLTAR.y, VOLTAR.w, VOLTAR.h)
  else
    ui.caixa(VOLTAR.x, VOLTAR.y, VOLTAR.w, VOLTAR.h, ui.E(8),
      { 0, 0, 0 }, COR_BORDA, 2, 0.6)
    ui.txt("<", VOLTAR.x, VOLTAR.y + VOLTAR.h * 0.2,
      math.floor(VOLTAR.w * 0.5), COR_TITULO, "center", VOLTAR.w)
  end
  if comTexto then
    local tam = 24
    local tx = VOLTAR.x + 60
    local ty = VOLTAR.y + (VOLTAR.h - ui.alturaTexto(tam)) / 2
    ui.txtEspacado("VOLTAR", tx + 2, ty + 2, tam, { 0, 0, 0, 0.9 }, 2)
    ui.txtEspacado("VOLTAR", tx, ty, tam, COR_TITULO, 2)
  end
end

-- Ponto (virtual) dentro do retangulo r? (hitboxes da selecao)
local function dentroR(r, vx, vy)
  return vx >= r.x and vx <= r.x + r.w and vy >= r.y and vy <= r.y + r.h
end

local function desenharCiclos()
  -- fundo desertico (cover da tela inteira)
  love.graphics.setColor(8 / 255, 6 / 255, 5 / 255, 1)
  ui.preencherTela(VW, VH)
  local fundo = arte.img("ciclos_fundo")
  if fundo then
    ui.imagemCover(fundo, ui.retTelaCheia(VW, VH))
  end

  -- ilha do ciclo em foco (a placa "CICLO I - O REINO ESQUECIDO" /
  -- "CICLO 2 - A EFICIENCIA" vem na arte) o ciclo selecionado no meio
  -- pulsa: respiracao suave de escala (1.00..1.05 no periodo de 1.6s,
  -- pelo relogio do LOVE).
  local t = love.timer.getTime()
  local esc = 1.025 + 0.025 * math.sin(t * math.pi * 2 / 1.6)
  local icx, icy = ILHA.x + ILHA.w / 2, ILHA.y + ILHA.h / 2
  love.graphics.push()
  love.graphics.translate(icx, icy)
  love.graphics.scale(esc)
  love.graphics.translate(-icx, -icy)
  ui.imagemContain(arte.img(CICLOS[cicloSel].arte), ILHA.x, ILHA.y,
    ILHA.w, ILHA.h)
  love.graphics.pop()

  -- placa do titulo no topo + setas laterais (a do lado sem ciclo vizinho
  -- fica apagada: o caminho comeca no Ciclo I e acaba no ultimo)
  ui.imagemCover(arte.img("sel_placa"), PLACA.x, PLACA.y, PLACA.w, PLACA.h)
  ui.imagemCover(arte.img("sel_seta_esq"), SETA_ESQ.x, SETA_ESQ.y,
    SETA_TAM, SETA_TAM, cicloSel > 1 and 1 or 0.3)
  ui.imagemCover(arte.img("sel_seta_dir"), SETA_DIR.x, SETA_DIR.y,
    SETA_TAM, SETA_TAM, cicloSel < #CICLOS and 1 or 0.3)

  -- voltar (icone + texto) e saldo no canto superior direito
  desenharVoltar(true)
  desenharSaldo()
end

-- Escala de um circulo pela distancia ao central: mais perto, maior;
-- fora da faixa visivel, some.
local function escalaCirc(d)
  d = math.abs(d)
  if d > 3.5 then return nil end
  return 1 / (1 + 0.18 * d)
end

-- Centro + raio do circulo do inimigo `e` na posicao animada (selVis).
local function retCirc(e)
  local d = e - selVis
  local esc = escalaCirc(d)
  if not esc then return nil end
  return CX + d * CIRC_ESP, CIRC_Y + d * d * CIRC_QUEDA,
    CIRC_TAM / 2 * esc
end

-- O inimigo `e` ja e acessivel (derrotado ou o proximo da fila)?
local function destravado(e)
  return e <= prog + 1
end

-- Qual circulo esta sob o ponto (o mais central ganha o clique).
local function idxNoPonto(vx, vy)
  local melhor, dMin = nil, 1e9
  for e = 1, totalNos() do
    local cx, cy, r = retCirc(e)
    if cx and (vx - cx) ^ 2 + (vy - cy) ^ 2 <= r * r then
      local d = math.abs(e - selVis)
      if d < dMin then
        melhor, dMin = e, d
      end
    end
  end
  return melhor
end

-- Centraliza a roda no proximo da fila (e poe a animacao em paz).
local function centrarFila()
  alvoSel = math.min(prog + 1, totalNos())
  -- JOGO_MAPA_SEL forca o circulo central nas capturas, sem tocar no save.
  local forc = tonumber(os.getenv("JOGO_MAPA_SEL"))
  if forc and forc >= 1 and forc <= totalNos() then
    alvoSel = math.floor(forc)
  end
  selVis = alvoSel
end

-- Um circulo de inimigo da roda: retrato recortado no disco (stencil) +
-- faixa do nome na base + anel do estado. A subida/descida da roda vem
-- como deslocamento em Y (`subida`), aplicado por quem chama.
local function desenharCirculo(e, hover, subida)
  local inimigo = fila()[e]
  local estado
  if inimigo.idx <= prog then
    estado = "derrotado"
  elseif inimigo.idx == prog + 1 then
    estado = "proximo"
  else
    estado = "bloqueado"
  end
  local prox = estado == "proximo"
  local t = love.timer.getTime()
  local p = prox and (0.5 + 0.5 * math.sin(t * 5)) or 0

  local d = e - selVis
  local esc = escalaCirc(d)
  if not esc then return end
  local cx = CX + d * CIRC_ESP
  local cy = CIRC_Y + d * d * CIRC_QUEDA + subida
  local r = CIRC_TAM / 2 * esc

  -- halo pulsante do proximo / glow do chefe, atras do disco
  if prox then
    love.graphics.setColor(COR_TITULO[1], COR_TITULO[2], COR_TITULO[3],
      0.12 + 0.10 * p)
    love.graphics.circle("fill", cx, cy, r + 9 + 4 * p)
  end
  if inimigo.soberano then
    local g = 0.5 + 0.5 * math.sin(t * 2.3)
    love.graphics.setColor(COR_TITULO[1], COR_TITULO[2], COR_TITULO[3],
      0.07 + 0.06 * g)
    love.graphics.circle("fill", cx, cy, r + 13)
  end

  -- sombra + base escura
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.circle("fill", cx + 4, cy + 6, r)
  love.graphics.setColor(0.05, 0.05, 0.09, 1)
  love.graphics.circle("fill", cx, cy, r)

  -- retrato do inimigo recortado no disco (o soberano so revela a cara
  -- depois de enfrentado ao menos uma vez)
  local oculto = inimigo.soberano == true
    and not (chefe or prog >= totalNos())
  local img
  if oculto then
    img = arte.img("inimigo_bloqueado")
  else
    img = arte.avatar(inimigo.avatar)
  end
  love.graphics.stencil(function()
    love.graphics.circle("fill", cx, cy, r)
  end, "replace", 1)
  love.graphics.setStencilTest("equal", 1)
  if img then
    ui.imagemCover(img, cx - r, cy - r, r * 2, r * 2)
  end

  -- faixa escura com o nome na base do disco (recortada pelo stencil)
  local bandH = r * 0.62
  love.graphics.setColor(0, 0, 0, 0.82)
  love.graphics.rectangle("fill", cx - r, cy + r - bandH, r * 2, bandH)

  -- bloqueado: escurece o retrato
  if estado == "bloqueado" then
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.circle("fill", cx, cy, r)
  end

  -- nome na faixa: o soberano oculto mostra so interrogantes (mesmo
  -- criterio do retrato, via S.rotuloNo).
  local rot = S.rotuloNo(e)
  local corRot = COR_ROTULO
  if estado == "bloqueado" then
    corRot = COR_BLOQ
  elseif prox then
    corRot = COR_TITULO
  end
  local tamN = math.max(10, math.floor(14 * esc + 0.5))
  local bw = r * 1.5
  local yTxt = cy + r - bandH + bandH * 0.16
  ui.textoQuebrado(rot, cx - bw / 2, yTxt, bw, tamN, { 0, 0, 0 },
    "center", 2, 0.85)
  ui.textoQuebrado(rot, cx - bw / 2 - 1, yTxt - 1, bw, tamN, corRot,
    "center", 2)
  love.graphics.setStencilTest()

  -- bloqueado: pendura um cadeado no centro do disco
  if estado == "bloqueado" then
    local mx, my = cx, cy - bandH * 0.45
    local s = esc
    love.graphics.setColor(COR_BLOQ[1], COR_BLOQ[2], COR_BLOQ[3], 0.95)
    love.graphics.setLineWidth(math.max(3, 5 * s))
    love.graphics.arc("line", mx, my - 12 * s, 15 * s, math.pi, 2 * math.pi)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("fill", mx - 22 * s, my - 10 * s, 44 * s,
      34 * s, 4)
    love.graphics.setColor(0.05, 0.04, 0.07)
    love.graphics.circle("fill", mx, my + 4 * s, 5 * s)
    love.graphics.rectangle("fill", mx - 2.5 * s, my + 4 * s, 5 * s, 10 * s)
  end

  -- anel do estado
  if estado == "bloqueado" then
    love.graphics.setColor(COR_BLOQ)
    love.graphics.setLineWidth(math.max(2, 3 * esc))
    love.graphics.circle("line", cx, cy, r - 1)
    love.graphics.setLineWidth(1)
  else
    love.graphics.setColor(COR_BORDA)
    love.graphics.setLineWidth(math.max(2.5, 4 * esc))
    love.graphics.circle("line", cx, cy, r - 1)
    love.graphics.setLineWidth(math.max(1, 1.5 * esc))
    love.graphics.setColor(COR_BORDA[1], COR_BORDA[2], COR_BORDA[3], 0.75)
    love.graphics.circle("line", cx, cy, r - 7 * esc)
    love.graphics.setLineWidth(1)
    if estado == "derrotado" then
      -- marca de concluido: losango dourado no topo do anel
      love.graphics.setColor(COR_TITULO)
      diamante(cx, cy - r, 14 * esc)
    end
  end

  -- elite: acento prata por fora do anel dourado
  if inimigo.elite and estado ~= "bloqueado" then
    love.graphics.setColor(COR_PRATA[1], COR_PRATA[2], COR_PRATA[3], 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, r + 5)
    love.graphics.setLineWidth(1)
    for k = 0, 3 do
      local a = math.rad(45 + k * 90)
      diamante(cx + math.cos(a) * (r + 5), cy + math.sin(a) * (r + 5),
        9 * esc)
    end
  end

  -- hover suave num circulo destravado
  if hover and estado ~= "bloqueado" then
    local hx, hy, hr = retCirc(e)
    if hr and (hover.x - hx) ^ 2 + (hover.y - hy) ^ 2 <= hr * hr then
      love.graphics.setColor(1, 1, 1, 0.08)
      love.graphics.circle("fill", cx, cy, r)
    end
  end

  -- soberano: placa SOBERANO no topo do disco (sem balanca)
  if inimigo.soberano then
    local escP = math.max(0.75, esc)
    local tamC = math.max(9, math.floor(12 * escP + 0.5))
    local bw2 = ui.larguraTexto(ui.tr("SOBERANO"), tamC) + 14 * escP
    local bh2 = tamC + 8
    local bx2, by2 = cx - bw2 / 2, cy - r - 13
    love.graphics.setColor(0.04, 0.04, 0.07, 0.96)
    love.graphics.rectangle("fill", bx2, by2, bw2, bh2, 4)
    love.graphics.setColor(COR_BORDA)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx2 + 1, by2 + 1, bw2 - 2, bh2 - 2, 4)
    love.graphics.setLineWidth(1)
    ui.txt("SOBERANO", bx2, by2 + (bh2 - ui.alturaTexto(tamC)) / 2, tamC,
      COR_TITULO, "center", bw2)
  end

  -- selo PROXIMO na borda superior (o soberano ja tem a placa SOBERANO)
  if prox and not inimigo.soberano then
    local bw3 = 110 * math.max(0.8, esc)
    local by3 = cy - r - 13
    love.graphics.setColor(0.04, 0.04, 0.07, 0.96)
    love.graphics.rectangle("fill", cx - bw3 / 2, by3, bw3, 26, 4)
    love.graphics.setColor(COR_TITULO)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - bw3 / 2 + 1, by3 + 1, bw3 - 2, 24, 4)
    love.graphics.setLineWidth(1)
    ui.txt("PROXIMO", cx - bw3 / 2, by3 + (26 - ui.alturaTexto(13)) / 2,
      13, COR_TITULO, "center", bw3)
  end
end

-- A roda de inimigos por cima da selecao: escurece a tela, levanta os
-- circulos da base (estilo stage select) e mostra a dica de uso.
local function desenharCirculos(hover)
  -- pega da curva da subida (desacelera na chegada)
  local p = 1 - (1 - circT) ^ 3
  love.graphics.setColor(0, 0, 0, 0.42 * p)
  ui.preencherTela(VW, VH)
  local subida = (1 - p) * (VH + 170)

  -- circulos de tras para frente (o central por cima dos vizinhos)
  local ordem = {}
  for e = 1, totalNos() do ordem[e] = e end
  table.sort(ordem, function(a, b)
    return math.abs(a - selVis) > math.abs(b - selVis)
  end)
  for _, e in ipairs(ordem) do
    desenharCirculo(e, hover, subida)
  end

  -- dica de uso, so depois da roda pousada
  if circT >= 0.99 then
    ui.txt("TOQUE NUM CIRCULO - NO CENTRO PARA O DUELO",
      0, VH - 26, 14, { 0.92, 0.87, 0.72, 0.85 }, "center", VW)
  end
end

function S.iniciar()
  vista = "ciclos"
  circT = 0
  sel = nil
  cicloSel = 1
  -- MODO_TESTE: o iniciar zera a memoria (o save de verdade nao e tocado).
  progMem = {}
  chefeMem = {}
  prog = carregarProg()
  chefe = carregarChefe()
  centrarFila()
end

function S.irPara() end

-- Poe a ilha `i` (1..totalCiclos) em foco: boot de captura e testes.
-- Devolve true quando mudou de ilha. Cada ilha traz o seu save (progresso e
-- soberano proprios), e sair da roda a fecha.
function S.selecionarCiclo(i)
  i = tonumber(i)
  if not i or i < 1 or i > #CICLOS or i == cicloSel then return false end
  cicloSel = i
  prog = carregarProg()
  chefe = carregarChefe()
  sel = nil
  if vista == "circulos" then
    vista = "ciclos"
    circT = 0
  end
  centrarFila()
  return true
end

-- Folheia a selecao de ilhas (setas laterais): passo -1 volta, +1 avanca.
-- Nas pontas do caminho nao anda e devolve false (a seta fica apagada).
function S.trocarCiclo(passo)
  passo = tonumber(passo)
  if not passo or passo == 0 then return false end
  return S.selecionarCiclo(cicloSel + (passo > 0 and 1 or -1))
end

-- Roda do mouse: folheia a roda de inimigos (so com ela aberta; so ate
-- o proximo da fila - os bloqueados nao entregam spoiler).
function S.rolagem(dy)
  if vista ~= "circulos" or circT < 0.999 or not dy or dy == 0 then return end
  local max = math.min(prog + 1, totalNos())
  local alvo = alvoSel + (dy > 0 and 1 or -1)
  if alvo < 1 then alvo = 1 elseif alvo > max then alvo = max end
  alvoSel = alvo
end

-- Boot de captura (JOGO_TELA=mapa/ciclo/vs): a roda ja levantada, sem
-- animacao. JOGO_CICLO=1|2 escolhe a ilha (e a fila) antes de abrir.
function S.irParaCirculos()
  local cic = tonumber(os.getenv("JOGO_CICLO"))
  if cic then S.selecionarCiclo(cic) end
  vista = "circulos"
  circT = 1
  centrarFila()
end

-- ESC: com a roda aberta ela desce e volta para a selecao (true); na
-- selecao ja e papel do main.
function S.esc()
  if vista == "circulos" then
    vista = "ciclos"
    return true
  end
  return false
end

function S.atualizar(dt)
  -- animacao da roda: sobe em 0.5s e desce em 0.42s (a vista troca na
  -- hora e o circT acompanha, abrindo e fechando a roda).
  local alvo = (vista == "circulos") and 1 or 0
  if circT < alvo then
    circT = math.min(alvo, circT + dt / 0.5)
  elseif circT > alvo then
    circT = math.max(alvo, circT - dt / 0.42)
  end
  if vista ~= "circulos" then return end
  -- roda deslizando ate o inimigo alvo
  local d = alvoSel - selVis
  if math.abs(d) > 0.003 then
    selVis = selVis + d * math.min(1, dt * 10)
  else
    selVis = alvoSel
  end
end

-- Vitoria do duelo do ciclo: registra o inimigo derrotado (idempotente:
-- so grava quando o proximo da fila cai) no save do ciclo em foco e
-- centraliza a roda no recem-liberado.
function S.vitoria()
  if sel and sel == prog + 1 then
    prog = sel
    salvarProg()
    centrarFila()
  end
end

-- O jogador encostou no soberano (duelo do ultimo no aberto): a partir
-- daqui o retrato dele aparece na roda. Em MODO_TESTE so marca em memoria.
function S.registrarChefe()
  if chefe then return end
  chefe = true
  salvarChefe()
end

-- No seguinte ao selecionado, se ele ja estiver liberado (o botao PROXIMO
-- OPONENTE do painel de vitoria): a fila acaba no soberano e uma revanche
-- no no da frente nao pula para o bloqueado.
local function noSeguinte()
  if not sel then return nil end
  local e = math.min(sel + 1, prog + 1, totalNos())
  if e <= sel then return nil end
  return e
end

-- Ha proximo oponente depois do no selecionado? (libera o botao do painel
-- de vitoria).
function S.temProximo()
  return noSeguinte() ~= nil
end

-- Avanca a selecao para o proximo oponente e devolve a config dele (o main
-- abre a VS/duelo). A roda fica centrada nele, para a volta a selecao.
function S.proximoNo()
  local e = noSeguinte()
  if not e then return nil end
  sel = e
  alvoSel = e
  return fila()[e]
end

-- Reset do progresso (tela de CONFIGURACOES): zera os DERROTADOS e esquece
-- o soberano de TODOS os ciclos (MODO_TESTE so memoria).
function S.redefinirProgresso()
  for i = 1, #CICLOS do
    progMem[i] = 0
    chefeMem[i] = nil
    if not MODO_TESTE then
      pcall(love.filesystem.write, arqProg(i), "0")
      pcall(love.filesystem.write, arqChefe(i), "0")
    end
  end
  prog = 0
  chefe = false
  sel = nil
  alvoSel = 1
  selVis = 1
end

-- Progresso corrente do ciclo em foco (0..totalInimigos DERROTADOS): a
-- suite confere o reset e a separacao dos saves por ciclo.
function S.progresso()
  return prog
end

-- Quantos nos tem o ciclo `i` (ou o em foco): a roda e a VS leem daqui.
function S.totalInimigos(i)
  i = tonumber(i) or cicloSel
  if i < 1 then i = 1 elseif i > #CICLOS then i = #CICLOS end
  return #CICLOS[i].inimigos
end

-- Progresso salvo do ciclo `i` (no em foco vale a memoria do jogo).
function S.progressoDoCiclo(i)
  i = tonumber(i) or cicloSel
  if i < 1 then i = 1 elseif i > #CICLOS then i = #CICLOS end
  if i == cicloSel then return prog end
  return carregarProg(i)
end

-- Ficha do ciclo `i` (1..totalCiclos) ou do que esta em foco na selecao:
-- nome, chave da arte da ilha, saves e a fila de inimigos dele.
function S.ciclo(i)
  i = tonumber(i) or cicloSel
  if i < 1 then i = 1 elseif i > #CICLOS then i = #CICLOS end
  return CICLOS[i]
end

-- Indice da ilha em foco e quantas existem (smoke/testes da navegacao).
function S.cicloAtual() return cicloSel end
function S.totalCiclos() return #CICLOS end

-- Config do inimigo `e` da fila do ciclo em foco (boot de captura da VS e
-- smokes: ordem/nome/arte viajam juntos, sem copia em outro arquivo).
function S.inimigo(e)
  e = tonumber(e) or 1
  local n = totalNos()
  if e < 1 then e = 1 elseif e > n then e = n end
  return fila()[e]
end

-- Rotulo desenhado no disco do inimigo `e`: o nome em caixa alta, ou
-- "??????" enquanto o soberano nao tiver sido enfrentado ao menos uma vez.
function S.rotuloNo(e)
  e = tonumber(e) or 1
  local n = totalNos()
  if e < 1 then e = 1 elseif e > n then e = n end
  local inimigo = fila()[e]
  if inimigo.soberano and not (chefe or prog >= n) then return "??????" end
  return string.upper(inimigo.nome)
end

-- Config do duelo selecionado (nome/avatar/dificuldade da IA) ou nil.
function S.dueloAtual()
  if not sel then return nil end
  return fila()[sel]
end

-- Coordenadas do proximo inimigo da fila (boot de captura JOGO_TELA=
-- ciclo/vs): o centro do circulo alvo - igual a coordsNo do liberado.
function S.coordsProximo()
  local e = math.min(prog + 1, totalNos())
  local d = e - alvoSel
  return CX + d * CIRC_ESP, CIRC_Y + d * d * CIRC_QUEDA
end

-- Coordenadas do circulo do inimigo `e` na posicao alvo: o teste do main
-- usa ela em vez de numeros fixos, para os smokes nao quebrarem.
function S.coordsNo(e)
  e = tonumber(e) or 1
  local n = totalNos()
  if e < 1 then e = 1 elseif e > n then e = n end
  local d = e - alvoSel
  return CX + d * CIRC_ESP, CIRC_Y + d * d * CIRC_QUEDA
end

-- Saldo formatado (exposto para o smoke conferir o formato 9.306).
S.milhar = milhar

function S.desenhar(hover)
  desenharCiclos()
  if circT > 0.001 then
    desenharCirculos(hover)
  end
end

-- Devolve "voltar" (na selecao: volta ao menu), "iniciar" (clique no
-- circulo central: proximo da fila ou revanche de um ja derrotado), nil
-- (roda animando, inimigo bloqueado, clique fora ou no primeiro clique
-- que so centraliza um destravado fora do centro).
function S.clicado(vx, vy)
  if vista == "circulos" then
    -- a roda ainda esta subindo ou descendo: nao responde
    if circT < 0.999 then return nil end
    if vx >= VOLTAR_SEL.x and vx <= VOLTAR_SEL.x + VOLTAR_SEL.w
        and vy >= VOLTAR_SEL.y and vy <= VOLTAR_SEL.y + VOLTAR_SEL.h then
      vista = "ciclos"
      return nil
    end
    local e = idxNoPonto(vx, vy)
    if not e then
      -- clique fora da roda: dentro da ilha, recolhe os circulos
      if vx >= ILHA.x and vx <= ILHA.x + ILHA.w
          and vy >= ILHA.y and vy <= ILHA.y + ILHA.h then
        vista = "ciclos"
      end
      return nil
    end
    if not destravado(e) then
      -- inimigo bloqueado: nao faz nada
      return nil
    end
    -- circulo central com a roda pousada: abre o duelo
    if e == alvoSel and math.abs(e - selVis) < 0.5 then
      sel = e
      return "iniciar"
    end
    -- destravado fora do centro: so centraliza (o proximo clique duela)
    if e ~= alvoSel then
      alvoSel = e
    end
    return nil
  end

  -- selecao de ciclos: voltar (icone + texto), setas (folheiam as ilhas)
  -- e o clique na ilha (abre a roda de inimigos do ciclo em foco).
  if vx >= VOLTAR_SEL.x and vx <= VOLTAR_SEL.x + VOLTAR_SEL.w
      and vy >= VOLTAR_SEL.y and vy <= VOLTAR_SEL.y + VOLTAR_SEL.h then
    return "voltar"
  end
  if dentroR(HIT_ESQ, vx, vy) then
    S.trocarCiclo(-1)
    return nil
  end
  if dentroR(HIT_DIR, vx, vy) then
    S.trocarCiclo(1)
    return nil
  end
  if dentroR(ILHA, vx, vy) then
    -- A ilha abre a roda de inimigos do ciclo em foco (cada ciclo tem a
    -- sua fila; o ultimo no e o soberano).
    if totalNos() > 0 then
      vista = "circulos"
      centrarFila()
    end
  end
  return nil
end

return S
