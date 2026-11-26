local arte = require "arte"
local inv = require "inventario"
local anim = require "anim"
local brilhoCuringa = require "brilho_curinga"
local fundoMenu = require "fundo_menu"
-- Idioma do texto: ui.txt e cia. passam tudo por idioma.tr() (a chave e o
-- portugues original), entao a troca na CONFIGURACOES vale para a tela toda.
local idioma = require "idioma"

local ui = {}

-- Traduz um pedaco de frase montada na mao (prefixo + variavel): a chave e
-- o portugues original, o mesmo criterio do idioma.tr aplicado dentro de
-- ui.txt. Frase inteira e estatica nao precisa chamar - ui.txt ja traduz.
ui.tr = idioma.tr

local K = 1.7
function ui.E(n) return math.floor(n * K + 0.5) end

-- Proporcao natural (largura/altura) da arte de cada carta. As artes
-- antigas sao ~408x612 (~0.667) e as novas de acao 1170x2048 (~0.571).
-- Usada nas cartas fora da mao (zoom, voo, area etc.). Na mao, todas as
-- cartas usam o mesmo tamanho fixo e a arte e esticada para preencher.
function ui.aspectoCarta(carta)
  local img = arte.arte(carta)
  if not img then return 353 / 707 end
  local iw, ih = img:getDimensions()
  if ih <= 0 then return 353 / 707 end
  return iw / ih
end

-- Altura da carta para uma largura dada, respeitando a arte.
function ui.alturaCarta(carta, w)
  return math.floor(w / ui.aspectoCarta(carta) + 0.5)
end

-- Largura da carta para uma altura dada, respeitando a arte.
function ui.larguraCarta(carta, h)
  return math.floor(h * ui.aspectoCarta(carta) + 0.5)
end

local function hex(h)
  return {
    tonumber(h:sub(2, 3), 16) / 255,
    tonumber(h:sub(4, 5), 16) / 255,
    tonumber(h:sub(6, 7), 16) / 255,
  }
end
ui.hex = hex

local C = {
  FUNDO = hex "#0A0A1A",
  PAINEL = hex "#0F1322",
  PAINEL_BORDA = hex "#7A5C29",
  AVATAR_BOX = hex "#1C2238",
  OURO = hex "#FFD54F",
  TEXTO = hex "#F0F3FF",
  TEXTO2 = hex "#AAB0D0",
  TEXTO3 = hex "#7C8AAC",
  CREME = hex "#FFF8E7",
  DESCRICAO = hex "#CFD6E6",
  CORPO_CARTA = hex "#1E1E2E",
  FACE_CARTA = hex "#141A2E",
  VERSO = hex "#1B2035",
  VERSO_BORDA = hex "#FAD02C",
  ACAO = hex "#C62828",
  EFEITO = hex "#1565C0",
  PROTECAO = hex "#2E7D32",
  CORINGA = hex "#6A1B9A",
  VERDE = hex "#2E7D32",
  VERDE_CLARO = hex "#66BB6A",
  AZUL = hex "#1565C0",
  AZUL_CLARO = hex "#42A5F5",
  VERMELHO = hex "#C62828",
  LARANJA = hex "#E65100",
  SUCESSO = hex "#66BB6A",
  FALHA = hex "#EF5350",
  PLACA = hex "#3E2723",
  PLACA_BORDA = hex "#7C4A27",
  SOMBRA_PRETA = { 0, 0, 0 },
}
ui.C = C

local COR_BORDA = { hex "#2196F3", hex "#E53935", hex "#FFB300", hex "#4CAF50", hex "#00ACC1", hex "#9C27B0" }

local COR_TIPO = {
  ACAO = C.ACAO,
  EFEITO = C.EFEITO,
  PROTECAO = C.PROTECAO,
  CORINGA = C.CORINGA,
  MEDIDA = C.ACAO,
  BONUS = C.PROTECAO,
}

function ui.corDoTipo(carta)
  return COR_TIPO[carta and carta.tipo] or C.OURO
end

function ui.corBorda(carta)
  local n = (carta and carta.uidNum) or 0
  return COR_BORDA[(n % #COR_BORDA) + 1]
end

-- Tipo de alvo que a carta exige (ou nil se nao precisa de alvo escolhido):
--   "oponente"   -> clicar no oponente (alvo unico)
--   "todos"      -> clicar no descarte (alvo em todos os oponentes)
--   "voce"       -> clicar no painel proprio
--   "voceOuOponente" -> jogador escolhe: painel proprio ou oponente
--   nil          -> nao precisa de alvo (aplica direto)
function ui.alvoTipoDaCarta(carta)
  if not carta then return nil end
  if carta.precisaAlvo ~= true then return nil end
  local texto = tostring(carta.alvoTexto or "")
  local efAlvo = tostring(carta.efeito and carta.efeito.alvo or "")
  if texto == "Todos" or texto == "Todos oponentes"
      or efAlvo == "oponentes" or efAlvo == "todos" then
    return "todos"
  end
  if texto == "Voce" then return "voce" end
  if texto == "Voce ou Oponente" then return "voceOuOponente" end
  if texto == "Oponente" or efAlvo == "alvo" then return "oponente" end
  return nil
end

-- Area clicavel de confirmacao da carta. Cartas com alvo usam a area do
-- proprio tipo; as demais usam o descarte como area generica de "usar carta".
function ui.areaDaCarta(carta)
  return ui.alvoTipoDaCarta(carta) or "descarte"
end

-- Nome legível da área de alvo para mostrar na tela (ASCII).
function ui.alvoTipoNome(tipo)
  if tipo == "oponente" then return "OPONENTE" end
  if tipo == "todos" then return "DESCARTE (TODOS)" end
  if tipo == "descarte" then return "USAR CARTA (DESCARTE)" end
  if tipo == "voce" then return "SEU PAINEL" end
  if tipo == "voceOuOponente" then return "SEU PAINEL OU OPONENTE" end
  return "ALVO"
end

-- Indice do assento alvo para o jogo.lua (1 = proprio, 2 = oponente).
function ui.alvoIdxDeTipo(tipo)
  if tipo == "oponente" then return 2 end
  if tipo == "voce" then return 1 end
  return nil -- "todos"/"descarte" aplicam sem indice fixo
end

-- Testa se o ponto (x,y) fica dentro do retangulo r (ou {x,y,w,h}).
function ui.dentro(x, y, r)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Testa se o ponto (px,py) fica dentro da carta r (considerando rotacao).
function ui.pontoNaCarta(px, py, r)
  if not r then return false end
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  local dx, dy = px - cx, py - cy
  local c, s = math.cos(-(r.rot or 0)), math.sin(-(r.rot or 0))
  local lx, ly = dx * c - dy * s, dx * s + dy * c
  return math.abs(lx) <= r.w / 2 and math.abs(ly) <= r.h / 2
end

local function pintar(cor, alfa)
  if alfa then
    love.graphics.setColor(cor[1], cor[2], cor[3], alfa)
  else
    love.graphics.setColor(cor[1], cor[2], cor[3], 1)
  end
end
ui.pintar = pintar

-- TEXT ---------------------------------------------------------------------

-- Conta caracteres UTF-8 (o LuaJIT nao tem lib utf8).
local function nChars(texto)
  local n, i = 0, 1
  while i <= #texto do
    local b = texto:byte(i)
    i = i + (b < 0x80 and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4)))
    n = n + 1
  end
  return n
end

function ui.larguraTexto(texto, tam, esp)
  love.graphics.setFont(arte.fonte(tam))
  texto = tostring(texto)
  local w = love.graphics.getFont():getWidth(texto)
  if esp and esp > 0 then w = w + esp * nChars(texto) end
  return w
end

function ui.alturaTexto(tam)
  love.graphics.setFont(arte.fonte(tam))
  return love.graphics.getFont():getHeight()
end

function ui.txt(texto, x, y, tam, cor, alinhar, largura, alfa)
  texto = idioma.tr(texto)
  love.graphics.setFont(arte.fonte(tam))
  pintar(cor or C.TEXTO, alfa)
  if alinhar then
    love.graphics.printf(tostring(texto), x, y, largura, alinhar)
  else
    love.graphics.print(tostring(texto), x, y)
  end
end

-- Texto com letterSpacing (como no React Native): desenha caractere a
-- caractere (iterando por codepoint, nao por byte). Se `largura` for
-- informada, centraliza horizontalmente nela.
function ui.txtEspacado(texto, x, y, tam, cor, esp, largura)
  texto = idioma.tr(texto)
  texto = tostring(texto)
  esp = esp or 0
  cor = cor or C.TEXTO
  love.graphics.setFont(arte.fonte(tam))
  local fonte = love.graphics.getFont()
  local px = x
  if largura then
    px = x + (largura - ui.larguraTexto(texto, tam, esp)) / 2
  end
  local i = 1
  while i <= #texto do
    local b = texto:byte(i)
    local len = b < 0x80 and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4))
    local ch = texto:sub(i, i + len - 1)
    love.graphics.setColor(cor[1], cor[2], cor[3], cor[4] or 1)
    love.graphics.print(ch, px, y)
    px = px + fonte:getWidth(ch) + esp
    i = i + len
  end
end

-- Escreve `texto` cabendo em `largMax`: encolhe a fonte ate `tamMin`
-- e corta com "..." se ainda assim nao couber.
function ui.txtCabe(texto, x, y, tamMax, largMax, cor, alinhar, tamMin, alfa)
  texto = idioma.tr(tostring(texto))
  tamMin = tamMin or 7
  local tam = tamMax
  while tam > tamMin and ui.larguraTexto(texto, tam) > largMax do
    tam = tam - 1
  end
  if ui.larguraTexto(texto, tam) > largMax then
    while #texto > 1 and ui.larguraTexto(texto .. "...", tam) > largMax do
      texto = texto:sub(1, -2)
    end
    texto = texto .. "..."
  end
  ui.txt(texto, x, y, tam, cor, alinhar, alinhar and largMax or nil, alfa)
end

function ui.quebrar(texto, tam, larguraMax)
  local fonte = arte.fonte(tam)
  love.graphics.setFont(fonte)
  local linhas, atual = {}, ""
  for palavra in tostring(texto):gmatch("%S+") do
    local teste = atual == "" and palavra or (atual .. " " .. palavra)
    if fonte:getWidth(teste) > larguraMax and atual ~= "" then
      table.insert(linhas, atual)
      atual = palavra
    else
      atual = teste
    end
  end
  if atual ~= "" then table.insert(linhas, atual) end
  return linhas
end

function ui.textoQuebrado(texto, x, y, larguraMax, tam, cor, alinhar, maxLinhas, alfa)
  texto = idioma.tr(texto)
  local fonte = arte.fonte(tam)
  local linhas = ui.quebrar(texto, tam, larguraMax)
  if maxLinhas and #linhas > maxLinhas then
    while #linhas > maxLinhas do table.remove(linhas) end
    local ult = linhas[#linhas]
    linhas[#linhas] = ult:sub(1, math.max(1, #ult - 3)) .. "..."
  end
  love.graphics.setFont(fonte)
  pintar(cor or C.TEXTO, alfa)
  local h = fonte:getHeight()
  for i, linha in ipairs(linhas) do
    if alinhar then
      love.graphics.printf(linha, x, y + (i - 1) * h, larguraMax, alinhar)
    else
      love.graphics.print(linha, x, y + (i - 1) * h)
    end
  end
  return #linhas * h
end

-- FORMAS -------------------------------------------------------------------

function ui.arestas(x, y, w, h, tam, cor, esp)
  tam = tam or 6
  esp = esp or 2
  love.graphics.setLineWidth(esp)
  pintar(cor or C.OURO)
  love.graphics.rectangle("line", x, y, tam, tam)
  love.graphics.rectangle("line", x + w - tam, y, tam, tam)
  love.graphics.rectangle("line", x, y + h - tam, tam, tam)
  love.graphics.rectangle("line", x + w - tam, y + h - tam, tam, tam)
  love.graphics.setLineWidth(1)
end

function ui.caixa(x, y, w, h, raio, corFundo, corBorda, larguraBorda, alfa, alfaBorda)
  if corFundo then
    pintar(corFundo, alfa)
    love.graphics.rectangle("fill", x, y, w, h, raio, raio, 8)
  end
  if corBorda then
    love.graphics.setLineWidth(larguraBorda or 1)
    pintar(corBorda, alfaBorda)
    love.graphics.rectangle("line", x, y, w, h, raio, raio, 8)
    love.graphics.setLineWidth(1)
  end
end

-- Contorno arredondado fechado (amostra os cantos) para traçado tracejado.
local function pontosContorno(x, y, w, h, raio)
  local pts = {}
  local function arco(cx, cy, a0, a1)
    for i = 0, 4 do
      local a = a0 + (a1 - a0) * i / 4
      pts[#pts + 1] = { cx + math.cos(a) * raio, cy + math.sin(a) * raio }
    end
  end
  if raio > 0 then
    arco(x + raio, y + raio, math.pi, math.pi * 1.5)
    arco(x + w - raio, y + raio, math.pi * 1.5, 2 * math.pi)
    arco(x + w - raio, y + h - raio, 0, math.pi / 2)
    arco(x + raio, y + h - raio, math.pi / 2, math.pi)
  else
    pts = { { x, y }, { x + w, y }, { x + w, y + h }, { x, y + h } }
  end
  pts[#pts + 1] = pts[1]
  return pts
end

local function tracejado(pts, seg, gap)
  local ciclo = seg + gap
  local fase = 0
  for i = 1, #pts - 1 do
    local x1, y1 = pts[i][1], pts[i][2]
    local x2, y2 = pts[i + 1][1], pts[i + 1][2]
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
      local ux, uy = dx / len, dy / len
      local pos = 0
      while pos < len do
        local dentro = fase % ciclo
        local passo, pinta
        if dentro < seg then
          passo = math.min(seg - dentro, len - pos)
          pinta = true
        else
          passo = math.min(ciclo - dentro, len - pos)
        end
        if passo < 0.05 then passo = 0.05 end
        local fim = math.min(len, pos + passo)
        if pinta then
          love.graphics.line(x1 + ux * pos, y1 + uy * pos,
            x1 + ux * fim, y1 + uy * fim)
        end
        fase = fase + (fim - pos)
        pos = fim
      end
    end
  end
end

-- Caixa com preenchimento e/ou borda tracejada (slots VAZIA e pilhas vazias
-- da Área Segura/descarte, como no React: dashed 1.5/2dp + bg translucido).
function ui.caixaTracejada(x, y, w, h, raio, corFundo, alfaFundo, corBorda,
                           alfaBorda, larguraBorda, seg, gap)
  if corFundo then
    pintar(corFundo, alfaFundo)
    love.graphics.rectangle("fill", x, y, w, h, raio, raio, 8)
  end
  if corBorda then
    love.graphics.setLineWidth(larguraBorda or 2)
    pintar(corBorda, alfaBorda)
    tracejado(pontosContorno(x, y, w, h, raio), seg or ui.E(5), gap or ui.E(4))
    love.graphics.setLineWidth(1)
  end
end

-- Cover: escala para cobrir todo o retangulo, cortando o excedente (sem
-- distorcer). ancoraX/ancoraY escolhem de onde vem o corte: 0 = so do lado
-- direito/baixo (borda da arte sempre integra), 0.5 = central (padrao),
-- 1 = so da esquerda/cima.
function ui.imagemCover(img, x, y, w, h, alfa, ancoraX, ancoraY)
  if not img then return end
  local iw, ih = img:getDimensions()
  local escala = math.max(w / iw, h / ih)
  local sw, sh = w / escala, h / escala
  local sx = (iw - sw) * (ancoraX or 0.5)
  local sy = (ih - sh) * (ancoraY or 0.5)
  local quad = love.graphics.newQuad(sx, sy, sw, sh, iw, ih)
  love.graphics.setColor(1, 1, 1, alfa or 1)
  love.graphics.draw(img, quad, x, y, 0, escala, escala)
end

function ui.imagemContain(img, x, y, w, h)
  if not img then return end
  local iw, ih = img:getDimensions()
  local escala = math.min(w / iw, h / ih)
  local dw, dh = iw * escala, ih * escala
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, x + (w - dw) / 2, y + (h - dh) / 2, 0, escala, escala)
end

-- Preenche o retangulo inteiro (pode esticar). A mao usa isso nas cartas de
-- acao para manter a proporcao 353x707 sem cortar a arte.
function ui.imagemPreencher(img, x, y, w, h)
  if not img then return end
  local iw, ih = img:getDimensions()
  if iw <= 0 or ih <= 0 then return end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, x, y, 0, w / iw, h / ih)
end

-- Retangulo (coordenadas virtuais) que cobre a tela FISICA inteira, barras
-- do letterbox incluidas — o main publica ui.telaCheia no recalcularEscala.
-- Fundos e overlays de tela cheia usam ele para valer em aparelhos com
-- proporcao diferente de 16:9 (ex.: celular 20:9). Sem a tabela (testes
-- antes do primeiro resize), cai na caixa virtual tradicional (vw x vh).
function ui.retTelaCheia(vw, vh)
  vw, vh = vw or 1280, vh or 720
  local w, h = love.graphics.getDimensions()
  if w <= 0 or h <= 0 then
    local r = ui.telaCheia
    if r then return r.x, r.y, r.w, r.h end
    return 0, 0, vw, vh
  end
  -- Calculado na hora (nao em cache): no Android a superficie pode mudar de
  -- tamanho depois do load sem disparar love.resize, e um retangulo velho
  -- deixa o fundo do menu cortado com barras pretas.
  local e = math.min(w / vw, h / vh)
  return -(w / e - vw) / 2, -(h / e - vh) / 2, w / e, h / e
end

-- Desenha um fundo em coordenadas FISICAS (transform zerado), cobrindo a
-- superficie inteira mesmo quando a escala/letterbox do jogo nao bate com a
-- janela — caso tipico do Android com highdpi.
function ui.fundoTelaCheia(desenhar)
  love.graphics.push("all")
  love.graphics.origin()
  local w, h = love.graphics.getDimensions()
  desenhar(0, 0, w, h)
  love.graphics.pop()
end

-- Preenche a tela fisica inteira com a cor corrente (usa o retangulo de
-- ui.retTelaCheia por baixo dos panos).
function ui.preencherTela(vw, vh)
  local fx, fy, fw, fh = ui.retTelaCheia(vw, vh)
  love.graphics.rectangle("fill", fx, fy, fw, fh)
end

-- corTexto opcional: fundos claros (ex.: PRONTO desligado, branco solido
-- porque o ui.caixa ignora o alfa da cor) precisam de texto escuro para ser
-- legivel; o padrao continua branco.
function ui.botao(texto, x, y, w, h, corFundo, corBorda, tamFonte, corTexto)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill", x + 3, y + 5, w, h, 8, 8, 6)
  ui.caixa(x, y, w, h, 8, corFundo, corBorda, 2)
  love.graphics.setColor(1, 1, 1, 0.14)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h * 0.42, 7, 7, 6)
  ui.txt(texto, x, y + h / 2 - arte.fonte(tamFonte or 20):getHeight() / 2,
    tamFonte or 20, corTexto or { 1, 1, 1 }, "center", w)
end

-- CARTA --------------------------------------------------------------------

local function comRecorte(img, x, y, w, h, raio)
  love.graphics.stencil(function()
    pintar({ 1, 1, 1 })
    love.graphics.rectangle("fill", x, y, w, h, raio, raio, 8)
  end, "replace", 1)
  love.graphics.setStencilTest("equal", 1)
end

function ui.faceMini(carta, x, y, w, h)
  local cor = ui.corDoTipo(carta)
  -- k escala o layout da face (1 na mao, ~2.2 no banner do resultado)
  local k = math.max(0.7, h / ui.E(96))
  local pad = ui.E(3) * k
  local topoH = ui.E(14) * k

  ui.caixa(x, y, w, h, ui.E(4) * k, C.FACE_CARTA, cor, math.max(1, ui.E(1) * k))

  -- barra superior com nome + badge de chance
  love.graphics.setColor(cor[1], cor[2], cor[3], 1)
  love.graphics.rectangle("fill", x + 1, y + 1, w - 2, topoH, ui.E(3), ui.E(3), 6)

  local tamBadge = math.max(7, math.floor(10 * k))
  local badge = tostring(math.floor(((carta.chance or 1) * 100) + 0.5)) .. "%"
  local badgeW = ui.larguraTexto(badge, tamBadge) + ui.E(4) * k
  local badgeX = x + w - badgeW - ui.E(2) * k
  local badgeY = y + ui.E(2) * k

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill", badgeX, badgeY, badgeW, ui.E(11) * k, 3, 3, 4)
  ui.txt(badge, badgeX, badgeY, tamBadge, C.OURO, "center", badgeW)

  local nomeX = x + pad + 2 * k
  ui.txtCabe(carta.nome, nomeX, badgeY, math.max(7, math.floor(11 * k)),
    badgeX - nomeX - ui.E(3) * k, C.CREME, nil, 7)

  -- efeito em destaque
  local efeitoY = y + topoH + ui.E(3) * k
  if carta.efeitoTexto then
    local corEfeito = C.OURO
    if carta.polaridade == "positiva" then corEfeito = C.SUCESSO
    elseif carta.polaridade == "negativa" then corEfeito = C.FALHA end
    ui.txtCabe(carta.efeitoTexto, x + pad, efeitoY, math.max(8, math.floor(13 * k)),
      w - pad * 2, corEfeito, "center", 8)
  end

  -- descricao
  local tamDesc = math.max(7, math.floor(10 * k))
  local fonteDesc = arte.fonte(tamDesc)
  local lh = fonteDesc:getHeight() + 1
  local descY = efeitoY + math.floor(14 * k) + ui.E(3) * k
  local ateY = y + h - ui.E(16) * k
  local maxLinhas = math.max(1, math.floor((ateY - descY) / lh))
  ui.textoQuebrado(carta.descricao or "", x + pad, descY, w - pad * 2,
    tamDesc, C.DESCRICAO, "left", maxLinhas)

  -- rodape: tipo
  ui.txtCabe(carta.tipo, x, y + h - ui.E(11) * k, math.max(7, math.floor(9 * k)),
    w, cor, "center", 7)
end

-- Aba/dobra de canto de página (fold): o canto superior direito dobra pra
-- cima, revelando o verso. f de 0 a 1 — anima com a seleção na mão e fica
-- fixo em 1 na Área Segura.
function ui.dobraCanto(x, y, w, h, f, alfa)
  if not f or f <= 0.02 then return end
  alfa = alfa or 1
  local tam = math.min(f, 1) * math.min(w, h) * 0.3
  if tam < 3 then return end
  local ax, ay = x + w - tam, y
  local bx, by = x + w, y + tam
  local c2x, c2y = x + w - tam, y + tam

  -- buraco onde o canto estava (fundo escuro aparecendo)
  love.graphics.setColor(0, 0, 0, 0.72 * alfa)
  love.graphics.polygon("fill", ax, ay, x + w, y, bx, by)

  -- micro-sombra da aba
  local d = ui.E(1.5)
  love.graphics.setColor(0, 0, 0, 0.4 * alfa)
  love.graphics.polygon("fill", ax + d, ay + d, bx + d, by + d, c2x + d, c2y + d)

  -- aba (verso do papel)
  love.graphics.setColor(0.93, 0.9, 0.82, alfa)
  love.graphics.polygon("fill", ax, ay, bx, by, c2x, c2y)
  love.graphics.setColor(0.55, 0.5, 0.44, alfa)
  love.graphics.setLineWidth(math.max(1, ui.E(1)))
  love.graphics.polygon("line", ax, ay, bx, by, c2x, c2y)
  love.graphics.setLineWidth(1)
end

function ui.carta(carta, x, y, w, h, opts)
  opts = opts or {}
  local raio = ui.E(6)
  local borda = ui.E(3)
  local escala = opts.escala or 1
  -- Curinga "respira" de leve; o brilho de borda entra no mesmo transform.
  if carta.tipo == "CORINGA" then
    escala = escala * brilhoCuringa.respirar(love.timer.getTime(), 0.012)
  end

  if escala ~= 1 then
    love.graphics.push()
    love.graphics.translate(x + w / 2, y + h / 2)
    love.graphics.scale(escala)
    love.graphics.translate(-(x + w / 2), -(y + h / 2))
  end

  -- sombra
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", x + 1, y + ui.E(3), w, h, raio, raio, 8)

  -- brilho da selecao (destaqueAlfa: hover usa um tingimento mais fraco)
  if opts.destaque then
    pintar(opts.destaque, opts.destaqueAlfa or 0.28)
    love.graphics.rectangle("fill", x - ui.E(3), y - ui.E(3), w + ui.E(6), h + ui.E(6),
      raio + 4, raio + 4, 8)
  end

  -- conteudo (arte ou face textual)
  local dentroX, dentroY = x + borda + ui.E(2), y + borda + ui.E(2)
  local dentroW, dentroH = w - (borda + ui.E(2)) * 2, h - (borda + ui.E(2)) * 2
  local raioDentro = math.max(0, raio - borda)

  local img = arte.arte(carta)
  if img then
    -- Sem corpo/recorte atras: as artes novas tem o fundo transparente
    -- (cantos e recortes laterais) e a propria arte define a silhueta.
    -- Desenhar por cima do corpo escuro anularia a transparencia.
    pintar({ 1, 1, 1 })
    if opts.preencherArte then
      ui.imagemPreencher(img, x, y, w, h)
    else
      ui.imagemContain(img, x, y, w, h)
    end
  else
    ui.caixa(x, y, w, h, raio, C.CORPO_CARTA,
      opts.destaque or ui.corBorda(carta), borda)
    ui.faceMini(carta, x + borda, y + borda, w - borda * 2, h - borda * 2)
    ui.caixa(x + borda, y + borda, w - borda * 2, h - borda * 2,
      raioDentro, nil, { 1, 1, 1 }, ui.E(1.5))
  end

  if opts.destaque then
    ui.caixa(x, y, w, h, raio, nil, { 1, 1, 1 }, ui.E(4))
  end

  if opts.dobra then
    ui.dobraCanto(x, y, w, h, opts.dobra)
  end

  -- Brilho de carta rara, desenhado por ultimo para ficar sobre a moldura.
  -- As coordenadas sao as mesmas da carta, entao acompanham o leque da mao.
  if carta.tipo == "CORINGA" then
    brilhoCuringa.desenhar(x, y, w, h, love.timer.getTime(), nil, carta.fase)
  end

  if escala ~= 1 then love.graphics.pop() end
end

-- Carta bloqueada na mão: precisa de alvo mas não há nenhum oponente vivo
-- para recebê-la. Somente feedback visual — não altera regras de jogo.
function ui.cartaBloqueada(carta, partida, idxJogador)
  if not carta or not carta.precisaAlvo then return false end
  if not partida or not partida.jogadores then return false end
  for i, j in ipairs(partida.jogadores) do
    if i ~= idxJogador and not j.falido and not j.saiu then
      return false
    end
  end
  return true
end

function ui.verso(x, y, w, h, opts)
  opts = opts or {}
  local mult = opts.alfa or 1
  local raio = ui.E(5)
  local borda = ui.E(1.5)
  local img = arte.verso()

  love.graphics.setColor(0, 0, 0, 0.45 * mult)
  love.graphics.rectangle("fill", x + 1, y + ui.E(3), w, h, raio, raio, 8)

  ui.caixa(x, y, w, h, raio, C.VERSO, C.VERSO_BORDA, borda, mult, mult)

  if img then
    comRecorte(img, x, y, w, h, raio)
    ui.imagemCover(img, x + borda, y + borda, w - borda * 2, h - borda * 2, mult)
    love.graphics.setStencilTest()
    ui.caixa(x, y, w, h, raio, nil, C.VERSO_BORDA, borda, nil, mult)
  end

  if opts.destaque then
    ui.caixa(x, y, w, h, raio, nil, { 1, 1, 1 }, ui.E(2), nil, mult)
  end

  if opts.dobra then
    ui.dobraCanto(x, y, w, h, opts.dobra, mult)
  end
end

-- Face completa (estilo zoom do React) para o painel de detalhe.
-- `alfa` (padrao 1) aplica a opacidade da animacao do zoom de resultado.
function ui.faceCompleta(carta, x, y, w, h, alfa)
  if not carta then return end
  alfa = alfa or 1
  local cor = ui.corDoTipo(carta)
  local padX = ui.E(7)
  local iw = w - padX * 2

  ui.caixa(x, y, w, h, ui.E(8), C.FACE_CARTA, cor, ui.E(1.5), alfa, alfa)

  local cy = y + ui.E(5)
  love.graphics.setColor(cor[1], cor[2], cor[3], alfa)
  love.graphics.rectangle("fill", x + padX, cy, iw, ui.E(4), 2, 2, 4)
  cy = cy + ui.E(4) + ui.E(5)

  local tamTit = 19
  ui.txtCabe(carta.nome, x + padX, cy, tamTit, iw, C.OURO, nil, 11, alfa)
  cy = cy + tamTit + 9

  if carta.subtitulo and carta.subtitulo ~= "" then
    ui.txtCabe(carta.subtitulo, x + padX, cy, 11, iw, C.TEXTO2, nil, 8, alfa)
    cy = cy + 15
  end

  -- meta: badge do tipo + chance
  local badge = (carta.tipo or "")
  local tamBadge = 11
  local bw = ui.larguraTexto(badge, tamBadge) + ui.E(8)
  ui.caixa(x + padX, cy, bw, ui.E(14), 3, cor, nil, 0, alfa)
  ui.txt(badge, x + padX, cy + ui.E(1), tamBadge, { 1, 1, 1 }, "center", bw, alfa)
  ui.txt("CHANCE " .. tostring(math.floor(((carta.chance or 1) * 100) + 0.5)) .. "%",
    x + padX + bw + ui.E(6), cy + ui.E(2), 12, C.OURO, nil, nil, alfa)
  cy = cy + ui.E(14) + ui.E(3)

  -- alvo
  ui.txtCabe(ui.tr("ALVO:") .. " " .. (carta.alvoTexto or "-"), x + padX, cy, 12, iw, C.TEXTO2, nil, 9, alfa)
  cy = cy + 16

  love.graphics.setColor(cor[1], cor[2], cor[3], 0.35 * alfa)
  love.graphics.rectangle("fill", x + padX, cy, iw, 1)
  cy = cy + ui.E(6)

  -- descricao (ocupa o espaco que sobra entre o topo e a caixa de efeito)
  local altEfeito = ui.E(56)
  local rodapeAlt = 16
  local efeitoY = y + h - ui.E(5) - rodapeAlt - altEfeito - ui.E(4)
  local boxDesc = math.max(ui.E(40), efeitoY - ui.E(6) - (cy + 14))

  ui.txt("DESCRICAO", x + padX, cy, 10, C.TEXTO3, nil, nil, alfa)
  cy = cy + 14
  local lh = arte.fonte(13):getHeight() + 2
  ui.textoQuebrado(carta.descricao or "", x + padX, cy, iw, 13, hex "#E4E9F5", "left",
    math.max(1, math.floor(boxDesc / lh)), alfa)

  -- caixa de efeito
  love.graphics.setColor(C.OURO[1], C.OURO[2], C.OURO[3], 0.08 * alfa)
  love.graphics.rectangle("fill", x + padX, efeitoY, iw, altEfeito, 4, 4, 6)
  ui.caixa(x + padX, efeitoY, iw, altEfeito, 4, nil, hex "#8A7434", 1, nil, alfa)
  ui.txt("EFEITO", x + padX + ui.E(5), efeitoY + ui.E(4), 10, C.TEXTO3, nil, nil, alfa)
  local lhEfeito = arte.fonte(13):getHeight() + 2
  ui.textoQuebrado(carta.efeitoTexto or "-", x + padX + ui.E(5), efeitoY + ui.E(17),
    iw - ui.E(10), 13, hex "#FFE082", "left",
    math.max(1, math.floor((altEfeito - ui.E(20)) / lhEfeito)), alfa)

  -- rodape
  ui.txt("DURACAO", x + padX, y + h - ui.E(5) - rodapeAlt + ui.E(2), 10, C.TEXTO3, nil, nil, alfa)
  ui.txtCabe(carta.duracaoTexto or "-", x + padX, y + h - ui.E(5) - rodapeAlt + ui.E(2),
    12, iw, C.OURO, "right", 9, alfa)
end

-- ZOOM DA CARTA -------------------------------------------------------------
-- CartaZoomModal.js: face 200x280, borda 2.5dp #FFD54F, raio 8dp, cantos
-- ornamentais 8dp offset -2dp e sombra (4,4). Arte => cover; senão face.

function ui.cartaZoom(carta, x, y, w, h)
  if not carta then return end
  local raio = ui.E(8)
  local borda = ui.E(2.5)

  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", x + ui.E(4), y + ui.E(4), w, h, raio, raio, 8)

  local img = arte.arte(carta)
  if img then
    -- Sem corpo/recorte: a arte tem fundo transparente e define a silhueta.
    ui.imagemContain(img, x, y, w, h)
  else
    ui.caixa(x, y, w, h, raio, C.CORPO_CARTA, C.OURO, borda)
    ui.faceCompleta(carta, x + borda, y + borda, w - borda * 2, h - borda * 2)
    ui.caixa(x, y, w, h, raio, nil, C.OURO, borda)
  end

  local ct = ui.E(8)
  local off = ui.E(2)
  love.graphics.setLineWidth(2)
  pintar(C.OURO)
  love.graphics.line(x - off, y - off, x - off + ct, y - off)
  love.graphics.line(x - off, y - off, x - off, y - off + ct)
  love.graphics.line(x + w + off, y - off, x + w + off - ct, y - off)
  love.graphics.line(x + w + off, y - off, x + w + off, y - off + ct)
  love.graphics.line(x - off, y + h + off, x - off + ct, y + h + off)
  love.graphics.line(x - off, y + h + off, x - off, y + h + off - ct)
  love.graphics.line(x + w + off, y + h + off, x + w + off - ct, y + h + off)
  love.graphics.line(x + w + off, y + h + off, x + w + off, y + h + off - ct)
  love.graphics.setLineWidth(1)

  -- Mesmo brilho do Curinga na mao, agora no zoom.
  if carta.tipo == "CORINGA" then
    brilhoCuringa.desenhar(x, y, w, h, love.timer.getTime(), nil, carta.fase)
  end
end

-- PAINEL DE STATUS ---------------------------------------------------------
-- PainelStatus.js + ScoreRoll.js: avatar 28dp com borda de destaque, nome
-- 8dp e linha "SALDO: R$ N" + moeda (cor por limiares >10 / >5). Sem badge
-- de status (o React nunca renderiza InfoJogador na arena).

-- CHIP DE HABILIDADE DE AVATAR ---------------------------------------------
-- Indica no painel/slot quem tem avatar com habilidade (taylor/marx/mayo).
-- cx = centro x; y = topo do chip. Devolve o retangulo (ou nil).

function ui.chipHabilidade(cx, y, hab, tam)
  if hab ~= "taylor" and hab ~= "marx" and hab ~= "mayo" then return nil end
  local txt = hab == "marx" and "MARX R$100"
    or (hab == "mayo" and "MAYO 30%" or "TAYLOR +10%")
  local fs = tam or ui.E(8)
  local w = ui.larguraTexto(txt, fs) + ui.E(8)
  local h = fs + ui.E(4)
  local cor = hab == "marx" and hex "#B71C1C"
    or (hab == "mayo" and hex "#00695C" or hex "#E65100")
  ui.caixa(cx - w / 2, y, w, h, ui.E(3), cor, hex "#FFD54F", ui.E(1))
  ui.txt(txt, cx - w / 2, y + ui.E(2), fs, { 1, 1, 1 }, "center", w)
  return { x = cx - w / 2, y = y, w = w, h = h }
end

-- Barra compacta (texto) de Satisfacao/Produtividade — legado. O duelo agora
-- usa as barras verticais pixel-art de ui.barrasStatus.
function ui.statusJogador(x, y, j)
  if not j then return end
  local w, h = ui.E(168), ui.E(40)
  ui.caixa(x, y, w, h, ui.E(6), C.PAINEL, C.PAINEL_BORDA, ui.E(1.5), 0.94)
  local sat = math.max(0, math.min(200, tonumber(j.satisfacao) or 100))
  local prod = tonumber(j.produtividade) or 0
  local corSat = j.greve and hex "#EF5350"
    or (sat >= 200 and hex "#FFD54F" or hex "#42A5F5")
  ui.txt("SATISFACAO", x + ui.E(6), y + ui.E(3), ui.E(8), C.TEXTO2)
  local valSat = j.greve and "GREVE!" or (math.floor(sat) .. "/200")
  ui.txt(valSat, x + ui.E(6), y + ui.E(3), ui.E(8), corSat,
    "right", w - ui.E(12))
  local bx, by = x + ui.E(6), y + ui.E(15)
  local bw = w - ui.E(12)
  ui.caixa(bx, by, bw, ui.E(6), ui.E(3), hex "#12162B", nil, 0)
  if sat > 0 then
    ui.caixa(bx, by, bw * (sat / 200), ui.E(6), ui.E(3), corSat, nil, 0)
  end
  ui.txt(string.format(ui.tr("PRODUTIVIDADE %+.0f%%"), prod * 100),
    x + ui.E(6), y + ui.E(24), ui.E(8),
    prod >= 0 and C.VERDE_CLARO or C.FALHA)
  if (j.bonusSatisfacao or 0) > 0 then
    ui.txt("MAX x" .. j.bonusSatisfacao, x + ui.E(6), y + ui.E(24),
      ui.E(8), C.OURO, "right", w - ui.E(12))
  end
end

-- Barras verticais pixel-art de Satisfacao (0..200, preenche de baixo para
-- cima) e Produtividade (centrada em 0%, positivo sobe em verde, negativo
-- desce em vermelho). Ficam a ESQUERDA do painel de status no duelo.
-- O conjunto (icone + barra) ocupa exatamente a altura `alt` do painel.

-- Valor EXIBIDO das barras, perseguindo o valor real com easing curto. Fica
-- num cache fraco por jogador: nao entra no snapshot da rede nem gasta local
-- novo no main. Só visual: o jogo continua lendo j.satisfacao/j.produtividade.
local barrasVis = setmetatable({}, { __mode = "k" })

local function animarBarra(j, alvoSat, alvoProd)
  local agora = love.timer.getTime()
  local v = barrasVis[j]
  if not v then
    v = { sat = alvoSat, prod = alvoProd, t = agora }
    barrasVis[j] = v
    return v
  end
  local dt = agora - v.t
  if dt <= 0 then
    dt = 1 / 60
  elseif dt > 0.1 then
    dt = 0.1
  end
  v.t = agora
  local k = 1 - math.exp(-dt * 11)
  v.sat = v.sat + (alvoSat - v.sat) * k
  v.prod = v.prod + (alvoProd - v.prod) * k
  if math.abs(alvoSat - v.sat) < 0.35 then v.sat = alvoSat end
  if math.abs(alvoProd - v.prod) < 0.003 then v.prod = alvoProd end
  return v
end

-- Barras de Satisfacao/Produtividade usando a arte pixel-art nova.
-- Cada PNG e 640x1280 (um quadro por faixa de 10%) com margens transparentes:
-- o recorte util (icone + moldura) fica em x 80..539 e ocupa a altura toda.
local BARRA_ART_X, BARRA_ART_W, BARRA_ART_H = 80, 460, 1280
-- Miolo que enche, em coordenadas relativas ao recorte.
local BARRA_INT_X0, BARRA_INT_X1 = 80 / 460, 400 / 460
local BARRA_INT_Y0, BARRA_INT_Y1 = 340 / 1280, 1220 / 1280
-- Quad recortado por imagem (fraco: some junto com a imagem quando liberada).
local barraQuads = setmetatable({}, { __mode = "k" })

local function larguraBarra(alt)
  alt = alt or ui.E(34)
  return math.max(1, math.floor(alt * BARRA_ART_W / BARRA_ART_H + 0.5))
end

function ui.larguraBarrasStatus(alt)
  return larguraBarra(alt) * 2 + ui.E(2)
end

function ui.barrasStatus(x, y, alt, j)
  if not j then return end
  alt = alt or ui.E(34)
  local bw = larguraBarra(alt)
  local gap = ui.E(2)
  local agora = love.timer.getTime()

  local PRETO = hex "#020002"
  local BASE = hex "#060A10"
  local COR_SAT = hex "#3E9B3A"
  local COR_PROD = hex "#E07A1F"

  local satAlvo = math.max(0, math.min(200, tonumber(j.satisfacao) or 100))
  local prodAlvo = math.max(-1, math.min(1, tonumber(j.produtividade) or 0))
  local vis = animarBarra(j, satAlvo, prodAlvo)
  local sat = math.max(0, math.min(200, vis.sat))
  local prod = math.max(-1, math.min(1, vis.prod))
  local satPct = sat / 2           -- 0..200 -> 0..100
  local prodPct = (prod + 1) * 50  -- -100%..+100% -> 0..100 (neutro = 50)

  local flashSat = j.flashSat and (agora - j.flashSat < 0.6)
  local flashProd = j.flashProd and (agora - j.flashProd < 0.6)

  -- Miolo que enche, em coordenadas de tela.
  local function interior(bx, by)
    local ix = bx + bw * BARRA_INT_X0
    local iy = by + alt * BARRA_INT_Y0
    local iw = bw * (BARRA_INT_X1 - BARRA_INT_X0)
    local ih = alt * (BARRA_INT_Y1 - BARRA_INT_Y0)
    return ix, iy, iw, ih
  end

  local function desenharArte(img, bx, by)
    if not img then return false end
    love.graphics.setColor(1, 1, 1, 1)
    local iw, ih = img:getDimensions()
    local quad = barraQuads[img]
    if not quad and love.graphics.newQuad then
      quad = love.graphics.newQuad(BARRA_ART_X, 0, BARRA_ART_W, BARRA_ART_H,
        iw, ih)
      barraQuads[img] = quad
    end
    if quad then
      love.graphics.draw(img, quad, bx, by, 0,
        bw / BARRA_ART_W, alt / BARRA_ART_H)
    else
      -- Fallback (harness sem Quad): desenha a arte inteira esticada.
      love.graphics.draw(img, bx, by, 0, bw / iw, alt / ih)
    end
    return true
  end

  -- Fallback chapado se a arte faltar: fundo + preenchimento simples.
  local function desenharFundo(bx, by, corFill, pct)
    love.graphics.setColor(BASE[1], BASE[2], BASE[3], 1)
    love.graphics.rectangle("fill", bx, by, bw, alt)
    local ix, iy, iw, ih = interior(bx, by)
    love.graphics.setColor(PRETO[1], PRETO[2], PRETO[3], 1)
    love.graphics.rectangle("fill", ix, iy, iw, ih)
    local fh = math.floor(ih * (pct / 100) + 0.5)
    if fh > 0 then
      love.graphics.setColor(corFill[1], corFill[2], corFill[3], 1)
      love.graphics.rectangle("fill", ix, iy + ih - fh, iw, fh)
    end
  end

  local function brilho(bx, by, ativo, corBrilho)
    if not ativo then return end
    local ix, iy, iw, ih = interior(bx, by)
    local a = 0.28 + 0.28 * math.sin(agora * 20)
    love.graphics.setColor(corBrilho[1], corBrilho[2], corBrilho[3], a)
    love.graphics.rectangle("fill", ix, iy, iw, ih)
  end

  -- ===== SATISFACAO (0..200 -> 0..100 da arte) =====
  local imgSat = arte.barra and arte.barra("sat", satPct) or nil
  if not desenharArte(imgSat, x, y) then
    desenharFundo(x, y, COR_SAT, satPct)
  end
  brilho(x, y, flashSat, { 1, 1, 1 })

  -- ===== PRODUTIVIDADE (neutro em 50%) =====
  local qx = x + bw + gap
  local imgProd = arte.barra and arte.barra("prod", prodPct) or nil
  if not desenharArte(imgProd, qx, y) then
    desenharFundo(qx, y, COR_PROD, prodPct)
  end
  if prod < 0 then
    -- Produtividade negativa (abaixo do neutro): veu vermelho no trecho aceso.
    local ix, iy, iw, ih = interior(qx, y)
    local topo = iy + ih * (1 - prodPct / 100)
    local fundo = iy + ih
    if topo < fundo then
      love.graphics.setColor(0.78, 0.14, 0.12, 0.42)
      love.graphics.rectangle("fill", ix, topo, iw, fundo - topo)
    end
  end
  brilho(qx, y, flashProd, { 1, 0.84, 0.31 })
  -- Marcador do neutro (0%) sobre a moldura.
  local _, iy, _, ih = interior(qx, y)
  love.graphics.setColor(0.98, 0.87, 0.55, 0.9)
  love.graphics.rectangle("fill", qx + bw * BARRA_INT_X0, iy + ih / 2 - 1,
    bw * (BARRA_INT_X1 - BARRA_INT_X0), 2)

  -- Numeros pequenos abaixo das barras: valor exibido de cada medidor.
  local tamNum = ui.E(6)
  local yNum = y + alt + ui.E(2)
  ui.txt(tostring(math.floor(sat + 0.5)), x, yNum, tamNum,
    COR_SAT, "center", bw)
  local sinal = prod > 0 and "+" or ""
  ui.txt(sinal .. math.floor(prod * 100 + 0.5) .. "%", qx, yNum, tamNum,
    COR_PROD, "center", bw)
  love.graphics.setColor(1, 1, 1, 1)
end


function ui.painelStatus(opts)
  local nome = (opts.nome or "JOGADOR"):upper()
  local larg = opts.largura or ui.E(130)
  local alt = ui.E(34)
  local x, y = opts.x, opts.y
  local avatarT = ui.E(28)
  local padX = ui.E(6)

  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", x + 1, y + 2, larg, alt, ui.E(5), ui.E(5), 6)
  ui.caixa(x, y, larg, alt, ui.E(5), C.PAINEL, C.PAINEL_BORDA, ui.E(1.5))

  -- avatar
  local ax, ay = x + padX, y + (alt - avatarT) / 2
  ui.caixa(ax, ay, avatarT, avatarT, ui.E(3), C.AVATAR_BOX,
    opts.corDestaque or ui.hex "#D4AF6A", ui.E(1.5))
  local avatar = arte.avatar(opts.quem)
  if avatar then
    comRecorte(avatar, ax, ay, avatarT, avatarT, ui.E(3))
    ui.imagemCover(avatar, ax + 1, ay + 1, avatarT - 2, avatarT - 2)
    love.graphics.setStencilTest()
  end

  -- coluna: nome (8dp) + ScoreRoll (label 7dp, valor 9dp, moeda 8dp)
  local tx = ax + avatarT + ui.E(6)
  local tamNome = ui.E(8)
  local tamLabel = ui.E(7)
  local tamValor = ui.E(9)
  local altLinha = tamNome + 2 + tamValor
  local cy = y + (alt - altLinha) / 2

  ui.txtCabe(nome, tx, cy, tamNome, x + larg - padX - tx, C.TEXTO, nil, 8)

  local saldo = opts.saldo or 0
  local saldoTxt, corValor
  if opts.ocultarSaldo then
    -- Manual V7 4.4: saldos dos demais ocultos no turno anterior ao evento.
    saldoTxt = "R$ ??"
    corValor = C.TEXTO3
  else
    saldoTxt = "R$ " .. tostring(saldo)
    corValor = saldo > 10 and C.VERDE_CLARO or (saldo > 5 and C.OURO or C.FALHA)
  end
  local sy = cy + tamNome + 2
  local px = tx
  ui.txt(ui.tr("SALDO:"), px, sy + (tamValor - tamLabel) / 2, tamLabel, C.TEXTO2)
  px = px + ui.larguraTexto(ui.tr("SALDO:"), tamLabel) + ui.E(3)
  ui.txt(saldoTxt, px, sy, tamValor, corValor)
  px = px + ui.larguraTexto(saldoTxt, tamValor) + ui.E(2)
  -- moeda (emoji 🪙 não existe na fonte do jogo): círculo dourado com anel.
  local moedaT = ui.E(7)
  local mx, my = px + moedaT / 2, sy + tamValor / 2
  love.graphics.setColor(0.96, 0.77, 0.23, 1)
  love.graphics.circle("fill", mx, my, moedaT / 2)
  love.graphics.setColor(0.72, 0.52, 0.11, 1)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", mx, my, moedaT / 2 - 0.75)
  love.graphics.setLineWidth(1)

  -- ornamentos de canto (CANTO_SIZE 6dp, offset -2dp, borda 2dp, L only)
  local ct = ui.E(6)
  local off = ui.E(2)
  love.graphics.setLineWidth(ui.E(2))
  pintar(C.OURO)
  love.graphics.line(x - off, y - off, x - off + ct, y - off)
  love.graphics.line(x - off, y - off, x - off, y - off + ct)
  love.graphics.line(x + larg + off, y - off, x + larg + off - ct, y - off)
  love.graphics.line(x + larg + off, y - off, x + larg + off, y - off + ct)
  love.graphics.line(x - off, y + alt + off, x - off + ct, y + alt + off)
  love.graphics.line(x - off, y + alt + off, x - off, y + alt + off - ct)
  love.graphics.line(x + larg + off, y + alt + off, x + larg + off - ct, y + alt + off)
  love.graphics.line(x + larg + off, y + alt + off, x + larg + off, y + alt + off - ct)
  love.graphics.setLineWidth(1)

  -- Chip de habilidade de avatar (taylor/marx), no canto superior direito.
  if opts.habilidade then
    ui.chipHabilidade(x + larg - ui.E(22), y - ui.E(5), opts.habilidade, ui.E(7))
  end

  return { x = x, y = y, w = larg, h = alt }
end

-- PLACA DE TURNO -----------------------------------------------------------
-- TurnoIndicador.js: badge "TURNO DE <NOME>" (verde se humano, vermelho se
-- IA), pill amarela "TURNO" + "n / max", chip de fluxo ("PARA A ESQUERDA"), pulso
-- sutil no turno humano e timer so nos ultimos 10s (fade 350ms).

-- Punch de escala quando a vez muda: guarda a ultima chave (nome + turno)
-- e o instante do impacto. Só o desenho usa; nenhuma regra depende disso.
local placaChave, placaPunchT = nil, nil

-- Escala de pulso por carta da mão (cache fraco, chaveado pela tabela da
-- carta): usado para o "pulo" ao selecionar e para o shake de recusa.
-- Nenhum campo novo entra na carta nem no snapshot da rede.
local cartaScale = setmetatable({}, { __mode = "k" })
ui._cartaScale = cartaScale

-- Pulso de seleção: 1 -> 1.10 -> 1.05 (overshoot curto). Chaveado pela
-- tabela da carta; roda no anim.update() do main.
function ui.pulsoSelecao(carta)
  if not carta then return end
  cartaScale[carta] = 1
  carta._esc = 1   -- inicializa antes do tween (senão anim.update faz 1.10 - nil)
  anim.tween(carta, { _esc = 1.10 }, 0.08, anim.saidaExcesso)
  anim.depois(0.08, function()
    if cartaScale[carta] then
      anim.tween(carta, { _esc = 1.05 }, 0.12, anim.entradaCubica)
    end
  end)
end

function ui.placaTurno(opts)
  local x, y = opts.x, opts.y
  local t = opts.tempo
  local alt = ui.E(40) + (t and ui.E(10) or 0)
  local larg = opts.largura or ui.E(150)
  local ehHumano = opts.isHumano

  -- Pulso 1 -> 1.05 em 800ms (so no turno do jogador).
  local agora = love.timer.getTime()
  local escala = 1
  if ehHumano then
    local fase = (agora % 0.8) / 0.8
    escala = 1 + 0.05 * (0.5 - 0.5 * math.cos(fase * 2 * math.pi))
  end
  -- Punch curto (1 -> 1.10 -> 1) na troca de turno. A chave inclui o numero
  -- do turno para o mesmo jogador tambem pulsar quando a rodada vira.
  local chave = tostring(opts.nome or "") .. "|" .. tostring(opts.turno)
  if chave ~= placaChave then
    placaChave = chave
    placaPunchT = agora
  end
  if placaPunchT then
    local q = (agora - placaPunchT) / 0.30
    if q >= 1 then
      placaPunchT = nil
    elseif q > 0 then
      escala = escala + 0.10 * (1 - q) * (1 - q)
    end
  end

  local cx, cy = x + larg / 2, y + alt / 2
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(escala, escala)
  love.graphics.translate(-cx, -cy)

  local pad = ui.E(6)
  local gap = ui.E(5)

  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", x + 1, y + 3, larg, alt, ui.E(6), ui.E(6), 6)
  ui.caixa(x, y, larg, alt, ui.E(6), C.PLACA, C.PLACA_BORDA, ui.E(2))
  if ehHumano then  -- brilho verde sutil na sua vez
    love.graphics.setColor(0.18, 0.49, 0.20, 0.14 + 0.08 * math.sin(agora * 4))
    love.graphics.rectangle("fill", x + 2, y + 2, larg - 4, alt - 4,
      ui.E(5), ui.E(5), 6)
  end

  -- Badge no topo
  local badgeTxt = ui.tr("TURNO DE") .. " " .. (opts.nome or opts.badge or "")
  local badgeH = ui.E(15)
  local badgeW = math.min(math.max(ui.larguraTexto(badgeTxt, 11) + ui.E(14),
    ui.E(72)), larg - ui.E(6))
  local corBadge
  if ehHumano ~= nil then
    corBadge = ehHumano and hex "#2E7D32" or hex "#C62828"
  else
    corBadge = opts.corBadge or C.VERDE
  end
  ui.caixa(x + (larg - badgeW) / 2, y - badgeH / 2, badgeW, badgeH, ui.E(4),
    corBadge, hex "#1B4D1E", ui.E(1))
  ui.txtCabe(badgeTxt, x + (larg - badgeW) / 2 + ui.E(4),
    y - badgeH / 2 + (badgeH - ui.alturaTexto(12)) / 2, 12,
    badgeW - ui.E(8), { 1, 1, 1 }, "center", 8)

  -- Linha 1: pill TURNO + numero grande
  local py = y + ui.E(7)
  local pillW, pillH = ui.E(36), ui.E(12)
  ui.caixa(x + pad, py, pillW, pillH, ui.E(3), hex "#FFD54F",
    hex "#3E2723", ui.E(1))
  ui.txt("TURNO", x + pad, py + (pillH - ui.alturaTexto(11)) / 2, 11,
    hex "#3E2723", "center", pillW)
  local nx = x + pad + pillW + ui.E(5)
  local numTxt = tostring(opts.turno)
  ui.txt(numTxt, nx, py + (pillH - ui.alturaTexto(20)) / 2 - 1, 20, C.TEXTO)
  ui.txt("/ " .. tostring(opts.max),
    nx + ui.larguraTexto(numTxt, 20) + ui.E(3),
    py + (pillH - ui.alturaTexto(13)) / 2 + 1, 13, C.TEXTO3)

  -- Jogadas restantes: bolinhas cheias = ainda pode jogar
  local jg = opts.jogadas
  if jg then
    local q = math.max(1, jg.quota or 1)
    local rest = math.max(0, math.min(q, jg.restantes or 0))
    local r = ui.E(3.5)
    local passoP = r * 2 + ui.E(3)
    local rotY = py + (pillH - ui.alturaTexto(10)) / 2
    if q <= 5 then
      local xr, cyP = x + larg - pad, py + pillH / 2
      for i = 1, q do
        local cxP = xr - r - (q - i) * passoP
        if i <= rest then
          love.graphics.setColor(1, 0.835, 0.31, 1)
          love.graphics.circle("fill", cxP, cyP, r)
        else
          love.graphics.setColor(0.83, 0.71, 0.60, 0.45)
          love.graphics.setLineWidth(2)
          love.graphics.circle("line", cxP, cyP, r - 1)
          love.graphics.setLineWidth(1)
        end
      end
      local largPips = q * passoP - ui.E(3)
      ui.txt("JOGADAS", x + larg - pad - largPips - ui.E(6) - 80, rotY, 10,
        hex "#D3B69A", "right", 80)
    else
      ui.txt("JOGADAS " .. rest .. "/" .. q, x + larg - pad - 120, rotY, 11,
        hex "#D3B69A", "right", 120)
    end
  end

  -- Progresso da partida: um segmento por turno
  local nSeg = tonumber(opts.max) or 0
  if nSeg >= 2 and nSeg <= 14 then
    local sy, sg = py + pillH + ui.E(2), 2
    local sw = (larg - pad * 2 - sg * (nSeg - 1)) / nSeg
    for i = 1, nSeg do
      if i <= (opts.turno or 0) then
        love.graphics.setColor(1, 0.835, 0.31, 1)
      else
        love.graphics.setColor(0.42, 0.29, 0.21, 1)
      end
      love.graphics.rectangle("fill", x + pad + (i - 1) * (sw + sg), sy, sw,
        ui.E(2))
    end
  end

  -- Linha 2: chip de fluxo (com seta) + botao PASSAR
  local fh = ui.E(13)
  local fy = y + ui.E(40) - fh - ui.E(4)
  local totalW = larg - pad * 2
  local fluxoW = opts.passar and math.floor((totalW - gap) * 0.55) or totalW
  local rPassar = nil
  if opts.fluxo then
    ui.caixa(x + pad, fy, fluxoW, fh, ui.E(3), { 0, 0, 0, 0.35 },
      hex "#FFD54F", ui.E(1))
    local my2, ax = fy + fh / 2, x + pad + ui.E(5)
    love.graphics.setColor(1, 0.835, 0.31, 1)
    love.graphics.polygon("fill", ax, my2, ax + 7, my2 - 5, ax + 7, my2 + 5)
    ui.txtCabe(opts.fluxo, x + pad + ui.E(11),
      fy + (fh - ui.alturaTexto(11)) / 2, 11, fluxoW - ui.E(14),
      hex "#FFD54F", "center", 8)
  end
  if opts.passar then
    local pw = totalW - fluxoW - gap
    local px = x + pad + fluxoW + gap
    local ativo = opts.passarAtivo ~= false
    local mx, my = -1, -1
    if opts.mouse then mx, my = opts.mouse() end
    local sobre = ativo and mx >= px and mx <= px + pw
      and my >= fy and my <= fy + fh
    local desce = (sobre and love.mouse.isDown(1)) and 2 or 0
    local fundo, borda, corTxt
    if ativo then
      fundo = sobre and hex "#FFE082" or hex "#FFC107"
      borda, corTxt = hex "#3E2723", hex "#3E2723"
      love.graphics.setColor(0.24, 0.15, 0.14, 1)   -- sombra "grossa"
      love.graphics.rectangle("fill", px, fy + 2, pw, fh, ui.E(3), ui.E(3), 6)
    else
      fundo, borda, corTxt = hex "#4A3A34", hex "#6B5A52", hex "#8A7A72"
    end
    ui.caixa(px, fy + desce, pw, fh, ui.E(3), fundo, borda, ui.E(1))
    if ativo then
      love.graphics.setColor(1, 1, 1, 0.28)
      love.graphics.rectangle("fill", px + 2, fy + desce + 2, pw - 4, fh * 0.4,
        ui.E(2), ui.E(2), 6)
    end
    local iy, ix = fy + desce + fh / 2, px + ui.E(7)   -- icone ">>"
    love.graphics.setColor(corTxt[1], corTxt[2], corTxt[3], 1)
    love.graphics.polygon("fill", ix, iy - 4, ix + 5, iy, ix, iy + 4)
    love.graphics.polygon("fill", ix + 5, iy - 4, ix + 10, iy, ix + 5, iy + 4)
    ui.txt("PASSAR", px + ui.E(10),
      fy + desce + (fh - ui.alturaTexto(13)) / 2, 13, corTxt, "center",
      pw - ui.E(10))
    -- Area de clique um pouco maior que o desenho (toque no celular).
    rPassar = { x = px - 4, y = fy - 6, w = pw + 8, h = fh + 12 }
  end

  -- Cadeia ativa: aparece ao lado da placa (antes ia junto do JOGADAS).
  if opts.cadeia then
    ui.txt(opts.cadeia, x + larg + ui.E(6), y + ui.E(8), 11, C.OURO, "left",
      ui.E(240))
  end

  -- Timer de turno (20s + efeitos TEMPO_TURNO): numero no canto direito da
  -- linha do pill + barra embaixo; aparece so com 10s ou menos (fade 350ms).
  if t then
    local alfa = t.aviso or 0
    if alfa > 0.01 then
      local dur = (t.duracao and t.duracao > 0) and t.duracao or 1
      local razao = math.max(0, math.min(1, t.restante / dur))
      local cor = razao > 0.5 and C.SUCESSO or (razao > 0.25 and C.OURO or C.FALHA)

      local numTxt = tostring(math.ceil(t.restante or 0))
      ui.txt(numTxt, x + larg - ui.E(40), y - ui.E(12), 16, cor, "right",
        ui.E(34), alfa)

      local bx, bw, bh = x + ui.E(6), larg - ui.E(12), ui.E(4)
      local by = y + alt - ui.E(8)
      love.graphics.setColor(0, 0, 0, 0.45 * alfa)
      love.graphics.rectangle("fill", bx, by, bw, bh, bh / 2, bh / 2, 2)
      if razao > 0 then
        love.graphics.setColor(cor[1], cor[2], cor[3], alfa)
        love.graphics.rectangle("fill", bx, by, bw * razao, bh, bh / 2, bh / 2, 2)
      end
    end
  end

  ui.arestas(x, y, larg, alt, ui.E(6), C.OURO, 2)

  -- Visor de curingas encostado na placa (desenhado pelo meta.lua).
  if opts.visor then opts.visor(x, y + alt + ui.E(4), larg, ui.E(30)) end

  love.graphics.pop()
  return { x = x, y = y, w = larg, h = alt, passar = rPassar }
end

-- LOG ----------------------------------------------------------------------

function ui.caixaLog(x, y, w, h, entradas, tamFonte)
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", x, y, w, h, ui.E(6), ui.E(6), 6)
  love.graphics.setLineWidth(1)
  pintar(hex "#555555")
  love.graphics.rectangle("line", x, y, w, h, ui.E(6), ui.E(6), 6)
  love.graphics.setLineWidth(1)

  ui.txt("LOG DE COMBATE", x + ui.E(6), y + ui.E(4), (tamFonte or 13) - 3, hex "#888888")

  local fonte = arte.fonte(tamFonte or 13)
  local lh = fonte:getHeight() + 3
  local maxLinhas = math.floor((h - ui.E(22)) / lh)
  local inicio = math.max(1, #entradas - maxLinhas + 1)

  love.graphics.setFont(fonte)
  local ly = y + ui.E(20)
  for i = inicio, #entradas do
    local e = entradas[i]
    local texto = type(e) == "string" and e or ((e.quem or "") .. ": " .. (e.mensagem or ""))
    local cor = hex "#CCCCCC"
    local m = texto:lower()
    if m:find("falhou") or m:find("eliminado") or m:find("perdeu") or m:find("prejuizo") then
      cor = C.FALHA
    elseif m:find("venceu") or m:find("emergencia") then
      cor = hex "#FFA726"
    elseif m:find("redistribu") then
      cor = hex "#FFD54F"
    elseif m:find("sucesso") or m:find("bonus") or m:find("roubou") then
      cor = C.SUCESSO
    end
    ui.textoQuebrado(texto, x + ui.E(6), ly, w - ui.E(12),
      tamFonte or 13, cor, "left", 1)
    ly = ly + lh
  end
end

-- RESULTADO DA JOGADA ------------------------------------------------------

-- Um item da linha do zoom: carta com selo (carimbo) + titulo/chance abaixo.
local function itemResultado(ent, xCard, yCard, cw, ch, k, alfa, tamTit, tamCh)
  local esc = 0.7 + 0.3 * k
  local aCarta = k * alfa
  local borda = ui.E(2)

  love.graphics.push()
  love.graphics.translate(xCard + cw / 2, yCard + ch / 2)
  love.graphics.scale(esc)
  love.graphics.translate(-(xCard + cw / 2), -(yCard + ch / 2))

  if aCarta > 0.001 then
    -- sombra (shadowOffset 3,4 / opacity 0.7)
    love.graphics.setColor(0, 0, 0, 0.7 * aCarta)
    love.graphics.rectangle("fill", xCard + ui.E(3), yCard + ui.E(4), cw, ch,
      ui.E(8), ui.E(8), 8)

    -- carta: borda creme 2dp, bg #120A1E; arte (cover) ou face completa
    ui.caixa(xCard, yCard, cw, ch, ui.E(8), hex "#120A1E", C.CREME, borda,
      aCarta, aCarta)
    local img = arte.arte(ent.carta)
    if img then
      comRecorte(img, xCard + borda, yCard + borda, cw - borda * 2,
        ch - borda * 2, math.max(1, ui.E(8) - borda))
      ui.imagemCover(img, xCard + borda, yCard + borda,
        cw - borda * 2, ch - borda * 2, aCarta)
      love.graphics.setStencilTest()
      ui.caixa(xCard, yCard, cw, ch, ui.E(8), nil, C.CREME, borda, nil, aCarta)
    else
      ui.faceCompleta(ent.carta, xCard + borda, yCard + borda,
        cw - borda * 2, ch - borda * 2, aCarta)
      ui.caixa(xCard, yCard, cw, ch, ui.E(8), nil, C.CREME, borda, nil, aCarta)
    end

    -- selo SUCESSO/FALHA (padding/borda/radius proporcionais a cw; rotate
    -- -8deg). Dimensões relativas: o painel de resultado usa cartas menores
    -- que o modal original 150x210.
    local seloTxt = ent.sucesso and "SUCESSO" or "FALHA"
    local corSelo = ent.sucesso and C.VERDE_CLARO or C.FALHA
    local tamSelo = math.max(ui.E(9), math.floor(cw * 0.145))
    local espSelo = math.max(ui.E(2), math.floor(tamSelo * 0.15))
    local padSelo = math.max(ui.E(5), math.floor(cw * 0.07))
    local sw = ui.larguraTexto(seloTxt, tamSelo, espSelo) + padSelo * 2
    local sh = ui.alturaTexto(tamSelo) + math.max(ui.E(4), math.floor(cw * 0.04))
    local sx = xCard + (cw - sw) / 2
    local sy = yCard + ch - math.floor(ch * 0.13) - sh

    love.graphics.push()
    love.graphics.translate(sx + sw / 2, sy + sh / 2)
    love.graphics.rotate(math.rad(-8))
    love.graphics.scale(k, k)
    ui.caixa(-sw / 2, -sh / 2, sw, sh, ui.E(6), { 0, 0, 0 }, nil, 0,
      0.72 * aCarta)
    ui.caixa(-sw / 2, -sh / 2, sw, sh, ui.E(6), nil, corSelo, ui.E(3), nil, aCarta)
    ui.txtEspacado(seloTxt, -sw / 2,
      -sh / 2 + (sh - ui.alturaTexto(tamSelo)) / 2, tamSelo,
      { corSelo[1], corSelo[2], corSelo[3], aCarta }, espSelo, sw)
    love.graphics.pop()
  end

  love.graphics.pop()

  -- titulo (13/ls1, #FFF8E7) + chance (12, #B0BEC5), fora da animacao
  local yTit = yCard + ch + ui.E(12)
  ui.txtCabe(ent.carta.nome or "", xCard, yTit, tamTit, cw, C.CREME,
    "center", 10, alfa)
  ui.txt("chance: " .. tostring(ent.chance or "100%"),
    xCard, yTit + ui.alturaTexto(tamTit) + ui.E(4), tamCh, hex "#B0BEC5",
    "center", cw, alfa)
end

-- Painel de SUCESSO/FALHA (ResultadoJogada.js): BLOCO compacto ancorado
-- sobre a mesa central — sem overlay de tela cheia, entao a mao, a placa e
-- os slots continuam visiveis durante a leva. Cartas da linha em escala
-- reduzida (cabem entre os slots de cima e a mao), carimbo -8deg com
-- spring 260ms, fade 0.4s no fim. Devolve o retangulo da placa (os testes
-- garantem que ela nao cobre a mao).
function ui.bannerResultado(estado)
  if not estado or not estado.tempo then return nil end
  local entradas = estado.entradas or {}
  if #entradas == 0 then return nil end
  local alfa = 1
  if estado.tempo > estado.dur - 0.4 then
    alfa = math.max(0, (estado.dur - estado.tempo) / 0.4)
  end

  local vw = estado.vw or 1280
  local vh = estado.vh or 720
  local cx = estado.cx or vw / 2
  local cy = estado.cy or math.floor(vh * 0.37)

  -- Cartas da leva em escala reduzida (largura util maxima da linha).
  local n = #entradas
  local gap = ui.E(16)
  local cw = math.floor((560 - (n - 1) * gap) / n)
  cw = math.max(ui.E(46), math.min(ui.E(72), cw))
  local ch = math.floor(cw * 1.25)
  local tamBanner = ui.E(14)
  local altBanner = ui.alturaTexto(tamBanner)
  local mbBanner = ui.E(6)
  local tamTit = math.max(ui.E(10), math.floor(cw * 0.16))
  local tamCh = math.max(ui.E(9), math.floor(cw * 0.14))
  local altItem = ch + ui.E(8) + ui.alturaTexto(tamTit) + ui.E(4)
    + ui.alturaTexto(tamCh)
  local padX, padY = ui.E(12), ui.E(10)

  local largBloco = n * cw + (n - 1) * gap
  local altBloco = altBanner + mbBanner + altItem
  -- A placa nunca é mais estreita que o título (com letras espaçadas ele
  -- passa dos 150dp do bloco de cartas quando a leva é de uma só).
  local largTitulo = ui.larguraTexto(ui.tr("RESULTADO DA JOGADA"), tamBanner, ui.E(4))
  local pw = math.max(largBloco, largTitulo) + padX * 2
  local ph = altBloco + padY * 2
  local px = math.floor(cx - pw / 2)
  local py = math.floor(cy - ph / 2)

  -- Placa local (antes: overlay full-screen rgba(4,4,10,0.92)).
  ui.caixa(px, py, pw, ph, ui.E(12), { 4 / 255, 4 / 255, 10 / 255 },
    C.CREME, ui.E(2), 0.9 * alfa, 0.45 * alfa)

  -- linha de itens (gap reduzido), bloco centralizado na placa
  ui.txtEspacado("RESULTADO DA JOGADA", px, py + padY, tamBanner,
    { C.CREME[1], C.CREME[2], C.CREME[3], 0.9 * alfa }, ui.E(4), pw)

  -- carimbo (delay 260ms + spring): escala 0.7->1 e opacidade 0->1,
  -- mesmo timing para todos os itens da leva
  local k = math.max(0, math.min(1, (estado.tempo - 0.26) / 0.3))
  k = 1 - (1 - k) ^ 3

  local yCard = py + padY + altBanner + mbBanner
  local x0 = cx - largBloco / 2
  for i = 1, n do
    itemResultado(entradas[i], x0 + (i - 1) * (cw + gap), yCard,
      cw, ch, k, alfa, tamTit, tamCh)
  end
  return { x = px, y = py, w = pw, h = ph }
end

-- SOBREPOSICOES ------------------------------------------------------------

-- Geometria da caixa de fim (overlayFim + cliques em main): caixa central,
-- lista de placares opcional e os botoes. `temProximo` (duelo de ciclo
-- vencido com um no liberado depois) abre a faixa do PROXIMO OPONENTE.
function ui.geomFim(vw, vh, nLin, temProximo)
  nLin = nLin or 0
  local cols = nLin > 4 and 2 or 1
  local porLinha = nLin > 0 and math.ceil(nLin / cols) or 0
  local passo = ui.E(nLin > 4 and 22 or 26)
  local topo = ui.E(112)
  -- A faixa extra do PROXIMO OPONENTE cresce a caixa e a base dos botoes.
  local extra = temProximo and ui.E(30) or 0
  local base = ui.E(130) + extra
  local w = vw * 0.8
  local h = ui.E(318) + extra
  if nLin > 0 then
    h = math.max(h, topo + porLinha * passo + ui.E(10) + base)
  end
  local x = (vw - w) / 2
  local y = (vh - h) / 2
  local g = {
    x = x, y = y, w = w, h = h,
    topo = topo, passo = passo, porLinha = porLinha, cols = cols,
  }
  if temProximo then
    -- Tres botoes: PROXIMO OPONENTE em cima (destaque) e os dois de sempre
    -- lado a lado embaixo (12px de gap entre as faixas).
    g.btnProx = { x = x + w / 2 - ui.E(240), y = y + h - ui.E(116),
      w = ui.E(480), h = ui.E(48) }
    g.btnNovo = { x = x + w / 2 - ui.E(8) - ui.E(280), y = y + h - ui.E(56),
      w = ui.E(280), h = ui.E(42) }
    g.btnMenu = { x = x + w / 2 + ui.E(8), y = y + h - ui.E(56),
      w = ui.E(280), h = ui.E(42) }
  else
    -- Dois botoes empilhados sem se sobrepor: JOGAR NOVAMENTE em cima,
    -- VOLTAR AO MENU embaixo (12px de gap, 14px da borda da caixa).
    g.btnNovo = { x = x + w / 2 - ui.E(150), y = y + h - ui.E(120),
      w = ui.E(300), h = ui.E(50) }
    g.btnMenu = { x = x + w / 2 - ui.E(150), y = y + h - ui.E(58),
      w = ui.E(300), h = ui.E(44) }
  end
  return g
end

-- Abre a VS de um no do ciclo (e, no no com `dialogo`, a conversa antes
-- dela): caminho unico da roda da selecao e do botao PROXIMO OPONENTE do
-- painel de vitoria. `aoFim` recebe o duelo de verdade (iniciarJogo no
-- main); fica em ui pela mesma razao de ui._dlg/ui._vs (teto de locals).
function ui.abrirVS(cfgVS, nomeJog, avatarJog, aoFim)
  local function abrir()
    ui._vs.iniciar({
      nomeJog = nomeJog,
      avatarJog = tostring(avatarJog),
      nomeInimigo = cfgVS and cfgVS.nome or "INIMIGO",
      avatarInimigo = cfgVS and cfgVS.avatar or "inimigo_1",
      aoFim = aoFim,
    })
  end
  if cfgVS and cfgVS.dialogo then
    ui._dlg.iniciar({ nome = nomeJog, aoFim = abrir })
  else
    abrir()
  end
end

-- Animacao de entrada do painel de fim (vitoria/derrota): o tempo corre em
-- love.update enquanto a tela e "fim" (ui._fimT). Sem update (MODO_TESTE)
-- o valor fica nil e o painel nasce pronto, como sempre.
ui.FIM_ANIM = 0.45

-- Escala (k) e deslocamento vertical (yoff) do painel para o tempo atual.
-- Cubico simples SEM estouro de escala: o retrato do Adam embutido no fim
-- fica dentro da tela em qualquer escala de monitor.
function ui.fimAnimacao()
  local t = ui._fimT
  if t == nil or t >= ui.FIM_ANIM then return 1, 0 end
  local q = 1 - t / ui.FIM_ANIM
  local k = 1 - q * q * q
  local yoff = q * q * -ui.E(48)
  return math.max(k, 0.02), yoff
end

-- Depois que o painel assenta, a fala do Adam e escrita letra a letra.
ui.FALSA_ANIM = 1.4
ui.FALSA_VEL = 30  -- letras por segundo

-- (texto visivel, escrevendo?). Sem tempo registrado (MODO_TESTE) devolve
-- a frase completa. A frase do fim e ASCII (a fonte VCR nao renderiza
-- acento): 1 byte = 1 letra — se um dia vir com acento, usar contagem
-- UTF-8 aqui.
function ui.falsaTexto(completo)
  local t = ui._fimT
  if t == nil or t >= ui.FIM_ANIM + ui.FALSA_ANIM then
    return completo, false
  end
  if t <= ui.FIM_ANIM then return "", true end
  local n = math.floor((t - ui.FIM_ANIM) * ui.FALSA_VEL)
  if n <= 0 then return "", true end
  if n >= #completo then return completo, false end
  return completo:sub(1, n), true
end

function ui.overlayFim(caixa)
  local d = caixa.dados or {}
  local res = d.resultado or "empate"
  if not ui._temasFim then
    ui._temasFim = {   -- em ui._ por causa do teto de locals do arquivo
      vitoria = { borda = C.OURO, topo = hex "#3A3210", etiqueta = "VITORIA",
        etqFundo = hex "#2E7D32", etqBorda = hex "#66BB6A", etqTxt = { 1, 1, 1 },
        titulo = C.OURO, sombra = hex "#5A4400", brilho = { 1, 0.84, 0.31 },
        motivo = hex "#CCCCCC" },
      derrota = { borda = hex "#A32D2D", topo = hex "#3A0F12", etiqueta = "DERROTA",
        etqFundo = hex "#5A1015", etqBorda = hex "#A32D2D", etqTxt = hex "#F09595",
        titulo = C.FALHA, sombra = hex "#3A0508", brilho = { 0.94, 0.33, 0.31 },
        motivo = hex "#B8A0A0" },
      empate = { borda = hex "#8C92B8", topo = hex "#1F2438", etiqueta = "EMPATE",
        etqFundo = hex "#2A3050", etqBorda = hex "#8C92B8", etqTxt = hex "#DDE2FF",
        titulo = hex "#DDE2FF", sombra = hex "#10142A", brilho = { 0.55, 0.60, 0.85 },
        motivo = hex "#CCCCCC" },
    }
  end
  local tema = ui._temasFim[res] or ui._temasFim.empate
  local agora = love.timer.getTime()
  local pulso = 0.5 + 0.5 * math.sin(agora * 2)

  -- Fundo escuro + halo colorido (fica parado, fora do transform).
  local fx, fy, fw, fh = ui.retTelaCheia(caixa.larguraVirtual,
    caixa.alturaVirtual)
  love.graphics.setColor(0, 0, 0, 0.88)
  love.graphics.rectangle("fill", fx, fy, fw, fh)
  for i = 0, 7 do
    local k = 1 - i / 8
    love.graphics.setColor(tema.brilho[1], tema.brilho[2], tema.brilho[3], 0.03)
    love.graphics.ellipse("fill", fx + fw / 2, fy + fh / 2, fw * 0.55 * k,
      fh * 0.55 * k)
  end

  local linhas = caixa.placares
  local nLin = linhas and #linhas or 0
  local g = ui.geomFim(caixa.larguraVirtual, caixa.alturaVirtual, nLin,
    caixa.temProximo)
  local x, y, w, h = g.x, g.y, g.w, g.h
  local meio = x + w / 2

  local k, yoff = ui.fimAnimacao()
  local cxm, cym = x + w / 2, y + h / 2
  love.graphics.push()
  love.graphics.translate(cxm, cym + yoff)
  love.graphics.scale(k)
  love.graphics.translate(-cxm, -cym)

  ui.caixa(x, y, w, h, ui.E(12), C.CORPO_CARTA, tema.borda, ui.E(2))

  -- Efeitos recortados pela caixa: degrade tingido, raios e particulas.
  comRecorte(nil, x + 2, y + 2, w - 4, h - 4, ui.E(11))
  local bandas = 16
  local bh = h * 0.55 / bandas
  for i = 0, bandas - 1 do
    love.graphics.setColor(tema.topo[1], tema.topo[2], tema.topo[3],
      0.55 * (1 - i / bandas) ^ 2)
    love.graphics.rectangle("fill", x, y + i * bh, w, bh + 1)
  end
  if res == "vitoria" then
    local rcx, rcy, R = meio, y + ui.E(42), w * 0.9
    for i = 0, 11 do
      local a = agora * 0.15 + i * math.pi / 6
      love.graphics.setColor(1, 0.84, 0.31, 0.06)
      love.graphics.polygon("fill", rcx, rcy,
        rcx + R * math.cos(a - 0.09), rcy + R * math.sin(a - 0.09),
        rcx + R * math.cos(a + 0.09), rcy + R * math.sin(a + 0.09))
    end
    for i = 1, 24 do   -- fagulhas subindo
      local px = x + (i * 97) % w
      local py = y + h - ((agora * (30 + (i % 5) * 8) + i * 53) % h)
      love.graphics.setColor(1, 0.84, 0.31, 0.5)
      love.graphics.rectangle("fill", px, py, 3, 3)
    end
  elseif res == "derrota" then
    for i = 1, 24 do   -- brasas caindo
      local px = x + (i * 97) % w + math.sin(agora + i) * 6
      local py = y + ((agora * (18 + (i % 4) * 6) + i * 61) % h)
      love.graphics.setColor(0.9, 0.3, 0.25, 0.35)
      love.graphics.rectangle("fill", px, py, 3, 3)
    end
  end
  love.graphics.setStencilTest()

  ui.arestas(x + 6, y + 6, w - 12, h - 12, ui.E(8), tema.borda, 2)

  -- Etiqueta (VITORIA / DERROTA / EMPATE)
  local etq = d.etiqueta or tema.etiqueta
  local ew = ui.larguraTexto(etq, 12, 3) + ui.E(16)
  local eh = ui.E(13)
  local ex, ey = meio - ew / 2, y + ui.E(10)
  ui.caixa(ex, ey, ew, eh, ui.E(4), tema.etqFundo, tema.etqBorda, 2)
  ui.txtEspacado(etq, ex, ey + (eh - ui.alturaTexto(12)) / 2, 12,
    tema.etqTxt, 3, ew)

  -- Titulo: sombra + halo pulsante + texto
  local ty = y + ui.E(26)
  ui.txt(caixa.titulo, x, ty + 4, 48,
    { tema.sombra[1], tema.sombra[2], tema.sombra[3] }, "center", w)
  for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do
    ui.txt(caixa.titulo, x + o[1], ty + o[2], 48, tema.brilho, "center", w,
      0.10 + 0.10 * pulso)
  end
  ui.txt(caixa.titulo, x, ty, 48, tema.titulo, "center", w)

  -- Traco ornamental com losango no centro
  local dy = y + ui.E(68)
  local dl = w * 0.165
  love.graphics.setColor(tema.borda[1], tema.borda[2], tema.borda[3], 1)
  love.graphics.setLineWidth(2)
  love.graphics.line(meio - dl, dy, meio - ui.E(11), dy)
  love.graphics.line(meio + ui.E(11), dy, meio + dl, dy)
  love.graphics.rectangle("line", meio - ui.E(6), dy - ui.E(6),
    ui.E(12), ui.E(12))
  love.graphics.setLineWidth(1)

  ui.txt(caixa.motivo, x, y + ui.E(76), 22, tema.motivo, "center", w)

  -- Cartao de jogador do placar (avatar + nome + saldo)
  local function cartao(j, cx0, cy0, cw, ch)
    local venc = j.vencedor
    local alfa = (res == "empate" or venc) and 1 or 0.8
    ui.caixa(cx0, cy0, cw, ch, ui.E(6), venc and tema.topo or hex "#0B0A16",
      venc and tema.borda or hex "#3A3A52", venc and ui.E(2) or 1, alfa)
    local dA = ch - ui.E(8)
    local ax, ay = cx0 + ui.E(7) + dA / 2, cy0 + ch / 2
    love.graphics.setColor(0.11, 0.13, 0.22, 1)
    love.graphics.circle("fill", ax, ay, dA / 2)
    local img = j.avatar and arte.avatar(j.avatar)
    if img then
      love.graphics.stencil(function()
        love.graphics.circle("fill", ax, ay, dA / 2)
      end, "replace", 1)
      love.graphics.setStencilTest("equal", 1)
      love.graphics.setColor(1, 1, 1, alfa)
      ui.imagemCover(img, ax - dA / 2, ay - dA / 2, dA, dA)
      love.graphics.setStencilTest()
    end
    love.graphics.setLineWidth(2)
    pintar(venc and tema.borda or hex "#5A5F78", alfa)
    love.graphics.circle("line", ax, ay, dA / 2)
    love.graphics.setLineWidth(1)

    local nx = ax + dA / 2 + ui.E(8)
    if venc then
      ui.txt(j.nome, nx, cy0 + ui.E(2), 22, C.TEXTO, "left", cw / 2)
      ui.txt("VENCEDOR", nx, cy0 + ch - ui.E(12), 11, tema.titulo, "left", cw / 2)
    else
      ui.txt(j.nome, nx, cy0 + (ch - ui.alturaTexto(22)) / 2, 22,
        hex "#CCCCCC", "left", cw / 2, alfa)
    end
    ui.txt("R$ " .. tostring(j.saldo or 0), cx0,
      cy0 + (ch - ui.alturaTexto(26)) / 2, 26,
      venc and C.OURO or C.TEXTO2, "right", cw - ui.E(10), alfa)
  end

  if nLin == 0 then
    local pw = w * 0.565
    local px = x + (w - pw) / 2
    local ch = ui.E(25)
    local cy0 = y + ui.E(96)
    local a, b = d.jog1, d.jog2
    if a and b then
      if b.vencedor and not a.vencedor then a, b = b, a end   -- vencedor em cima
      cartao(a, px, cy0, pw, ch)
      cartao(b, px, cy0 + ch + ui.E(4), pw, ch)

      -- Barra de proporcao dos saldos + diferenca + turno
      local barY = cy0 + ch * 2 + ui.E(4) + ui.E(5)
      local s1, s2 = math.max(0, a.saldo or 0), math.max(0, b.saldo or 0)
      ui.caixa(px, barY, pw, 8, 4, hex "#1A1A2E", nil, 0)
      if s1 + s2 > 0 then
        local wa = math.floor(pw * s1 / (s1 + s2))
        love.graphics.setColor(0.35, 0.37, 0.47, 1)
        love.graphics.rectangle("fill", px, barY, pw, 8, 4, 4)
        local corA = res == "empate" and hex "#8C92B8" or tema.titulo
        love.graphics.setColor(corA[1], corA[2], corA[3], 1)
        love.graphics.rectangle("fill", px, barY, wa, 8, 4, 4)
      end
      local dif = math.abs((a.saldo or 0) - (b.saldo or 0))
      local txtDif
      if res == "vitoria" then txtDif = "DIFERENCA +R$ " .. dif
      elseif res == "derrota" then txtDif = "FALTARAM R$ " .. dif
      else txtDif = dif == 0 and "SALDOS IGUAIS" or ("DIFERENCA R$ " .. dif) end
      ui.txt(txtDif, px, barY + ui.E(5), 13, C.TEXTO3, "left", pw)
      if d.turno then
        ui.txt("TURNO " .. d.turno .. " / " .. tostring(d.maxTurnos or "?"),
          px, barY + ui.E(5), 13, C.TEXTO3, "right", pw)
      end

      local yExtra = barY + ui.E(5) + ui.E(14)
      if d.moedas and res == "vitoria" then
        local cw2, ch2 = ui.E(78), ui.E(13)
        local cx2 = meio - cw2 / 2
        ui.caixa(cx2, yExtra, cw2, ch2, ui.E(7), hex "#2A2208", C.OURO, 2)
        love.graphics.setColor(C.OURO[1], C.OURO[2], C.OURO[3], 1)
        love.graphics.circle("fill", cx2 + ui.E(9), yExtra + ch2 / 2, ui.E(4))
        ui.txt("+" .. d.moedas .. " MOEDAS", cx2 + ui.E(16),
          yExtra + (ch2 - ui.alturaTexto(13)) / 2, 13, C.OURO)
      elseif res == "derrota" then
        ui.txt("A administracao e a arte de tentar de novo.", x, yExtra, 14,
          tema.motivo, "center", w)
      end
    else
      -- Sem dados dos jogadores: mantem o placar antigo.
      local py = y + g.topo - ui.E(6)
      ui.caixa(px, py, pw, ui.E(65), ui.E(10), hex "#0B0A16", tema.borda, ui.E(2))
      ui.txt(caixa.placar1, px, y + g.topo, 26, C.TEXTO, "center", pw)
      ui.txt(caixa.placar2, px, y + g.topo + ui.E(34), 26, C.TEXTO, "center", pw)
    end
  else
    local largCol = (w - ui.E(40)) / g.cols
    for i, l in ipairs(linhas) do
      local col = math.floor((i - 1) / g.porLinha) + 1
      local row = (i - 1) % g.porLinha + 1
      local lx = x + ui.E(20) + (col - 1) * largCol
      local ly = y + g.topo + (row - 1) * g.passo
      local cor = l.vencedor and C.OURO or C.TEXTO
      ui.txt(l.nome, lx, ly, 20, cor, "left", largCol - ui.E(70))
      ui.txt(l.texto or "", lx, ly, 20, cor, "right",
        largCol - (l.vencedor and ui.E(34) or 0))
      if l.vencedor then
        ui.iconeEspadas(lx + largCol - ui.E(12), ly + ui.E(11), ui.E(16))
      end
    end
  end

  -- Botoes: o principal brilha; VOLTAR AO MENU e secundario discreto.
  local function brilhoBotao(r)
    love.graphics.setColor(tema.brilho[1], tema.brilho[2], tema.brilho[3],
      0.12 + 0.12 * pulso)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", r.x - 3, r.y - 3, r.w + 6, r.h + 6, 10, 10)
    love.graphics.setLineWidth(1)
  end
  if g.btnProx then
    brilhoBotao(g.btnProx)
    ui.botao("PROXIMO OPONENTE", g.btnProx.x, g.btnProx.y, g.btnProx.w,
      g.btnProx.h, C.VERDE, C.VERDE_CLARO, 22)
    ui.botao("JOGAR NOVAMENTE", g.btnNovo.x, g.btnNovo.y, g.btnNovo.w,
      g.btnNovo.h, C.AZUL, C.AZUL_CLARO, 18)
  else
    local corP, corPB, rotP = C.VERDE, C.VERDE_CLARO, "JOGAR NOVAMENTE"
    if res == "derrota" then
      corP, corPB, rotP = hex "#A32D2D", hex "#F09595", "TENTAR DE NOVO"
    elseif res == "empate" then
      corP, corPB = C.AZUL, C.AZUL_CLARO
    end
    brilhoBotao(g.btnNovo)
    ui.botao(rotP, g.btnNovo.x, g.btnNovo.y, g.btnNovo.w, g.btnNovo.h,
      corP, corPB, 22)
  end
  ui.botao("VOLTAR AO MENU", g.btnMenu.x, g.btnMenu.y, g.btnMenu.w,
    g.btnMenu.h, hex "#12121F", hex "#7A5C29", 18, hex "#D3B69A")

  love.graphics.pop()
end

function ui.overlayPausa(caixa)
  love.graphics.setColor(0, 0, 0, 0.6)
  local fx, fy, fw, fh = ui.retTelaCheia(caixa.larguraVirtual,
    caixa.alturaVirtual)
  love.graphics.rectangle("fill", fx, fy, fw, fh)

  local fin = caixa.financeiro
  local w = ui.E(fin and 410 or 360)
  local h = ui.E(fin and 390 or 260)
  local x = (caixa.larguraVirtual - w) / 2
  local y = (caixa.alturaVirtual - h) / 2

  ui.caixa(x, y, w, h, ui.E(12), C.CORPO_CARTA, C.OURO, ui.E(2))
  ui.txt("PAUSA", x, y + ui.E(22), 41, C.OURO, "center", w)

  local by = y + ui.E(100)
  if fin then
    ui.txt("LIVRO-CAIXA (HISTORICO)", x, y + ui.E(66), 14, C.TEXTO2,
      "center", w)
    local function linha(rotulo, valor, cor, yy)
      ui.txt(rotulo, x + ui.E(36), yy, 14, C.TEXTO2)
      ui.txt(valor, x + w - ui.E(36), yy, 14, cor or C.TEXTO, "right",
        ui.E(190))
    end
    linha("RECEITAS", "R$ " .. tostring(fin.receitas or 0), C.VERDE_CLARO,
      y + ui.E(90))
    linha("DESPESAS", "R$ " .. tostring(fin.despesas or 0), C.FALHA,
      y + ui.E(112))
    local lucro = fin.lucro or 0
    linha("LUCRO", (lucro >= 0 and "+" or "-") .. "R$ " ..
      math.abs(lucro), lucro >= 0 and C.SUCESSO or C.FALHA, y + ui.E(134))
    linha("SALDO", "R$ " .. tostring(fin.saldo or 0), C.OURO, y + ui.E(156))

    ui.txt("ULTIMOS MOVIMENTOS", x, y + ui.E(184), 12, C.TEXTO3,
      "center", w)
    local mov = fin.movimentos or {}
    local ini = math.max(1, #mov - 2)
    local yy = y + ui.E(204)
    for i = ini, #mov do
      local m = mov[i]
      local d = tonumber(m.delta) or 0
      local txt = "R" .. tostring(m.rodada or "?") .. " " ..
        tostring(m.categoria or "?") .. "  " ..
        (d >= 0 and "+" or "-") .. "R$ " .. math.abs(d)
      ui.txtCabe(txt, x + ui.E(32), yy, 12, w - ui.E(64),
        d >= 0 and C.VERDE_CLARO or C.FALHA, "left", 9)
      yy = yy + ui.E(18)
    end
    by = y + ui.E(270)
  end

  ui.botao("CONTINUAR", x + w / 2 - ui.E(140), by, ui.E(280), ui.E(48),
    C.VERDE, C.VERDE_CLARO, 22)
  ui.botao("VOLTAR AO MENU", x + w / 2 - ui.E(140), by + ui.E(64),
    ui.E(280), ui.E(48), C.VERMELHO, hex "#FF5252", 20)
end

-- MENU ---------------------------------------------------------------------

local COR_AVATAR = hex "#FFD700"
local FUNDO_FLUT = { 10 / 255, 10 / 255, 26 / 255 }

local function dentroR(x, y, r)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function ui.iconeLivro(cx, cy, s)
  local alt = s * 0.30
  local larg = s * 0.42
  local abertura = s * 0.05
  pintar(C.CREME, 0.95)
  love.graphics.polygon("fill",
    cx - larg, cy - alt + s * 0.07,
    cx - abertura, cy - alt,
    cx - abertura, cy + alt,
    cx - larg, cy + alt - s * 0.07)
  love.graphics.polygon("fill",
    cx + larg, cy - alt + s * 0.07,
    cx + abertura, cy - alt,
    cx + abertura, cy + alt,
    cx + larg, cy + alt - s * 0.07)
  pintar(hex "#9AA0B5", 1)
  love.graphics.rectangle("fill", cx - abertura, cy - alt, abertura * 2, alt * 2)
end

function ui.iconeEspadas(cx, cy, s)
  local a = s * 0.42
  local function espada(px, py, qx, qy)
    local dx, dy = qx - px, qy - py
    local len = math.sqrt(dx * dx + dy * dy)
    dx, dy = dx / len, dy / len
    pintar(hex "#DDE3F2", 1)
    love.graphics.line(px, py, qx, qy)
    local gx, gy = qx - dx * len * 0.18, qy - dy * len * 0.18
    local nx, ny = -dy, dx
    local g = len * 0.15
    pintar(C.OURO, 1)
    love.graphics.line(gx - nx * g, gy - ny * g, gx + nx * g, gy + ny * g)
    love.graphics.circle("fill", qx, qy, len * 0.055)
  end
  love.graphics.setLineWidth(math.max(3, s * 0.10))
  espada(cx + a, cy - a, cx - a * 0.7, cy + a)
  espada(cx - a, cy - a, cx + a * 0.7, cy + a)
  love.graphics.setLineWidth(1)
end

-- Emojis da partida em rede (a fonte VCR nao tem glifos de emoji — mesmo
-- motivo da moeda e do escudo serem desenhados). codigo: 1 feliz, 2 risada,
-- 3 triste, 4 raiva (vetoriais) e 5+ = emojis de sprite da loja (catalogo
-- inventario.emojiPorCodigo; quadro fixo 1 aqui, a animacao do balao e no
-- main). Qualquer outro cai no feliz. alfa (opcional) esmaece o rosto
-- inteiro (fade).
function ui.emoji(codigo, cx, cy, r, alfa)
  if not r or r <= 0 then return end
  codigo = tonumber(codigo) or 1
  alfa = alfa or 1

  -- codigos 5+: sprite do catalogo (desenha quadrado por cima do rosto
  -- redondo; id do sprite = id do produto)
  if codigo >= 5 then
    local prod = inv.emojiPorCodigo(codigo)
    local img = prod and arte.emojiSprite(prod.id, 1)
    if img then
      local d = r * 2
      love.graphics.setColor(1, 1, 1, alfa)
      love.graphics.draw(img, cx - r, cy - r, 0,
        d / img:getWidth(), d / img:getHeight())
      return
    end
    codigo = 1 -- arte faltando: cai no vetor 1
  end

  local escuro = { 0.17, 0.1, 0.05, alfa }

  -- rosto
  love.graphics.setColor(1, 0.83, 0.25, alfa)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0.66, 0.45, 0.05, alfa)
  love.graphics.setLineWidth(math.max(1, r * 0.09))
  love.graphics.circle("line", cx, cy, r)
  love.graphics.setLineWidth(1)

  local olhoY = cy - r * 0.16
  local dx = r * 0.34
  local bocaY = cy + r * 0.34

  local function olhoPontos()
    love.graphics.setColor(escuro)
    love.graphics.circle("fill", cx - dx, olhoY, r * 0.11)
    love.graphics.circle("fill", cx + dx, olhoY, r * 0.11)
  end
  -- Boca em arco: 0..pi atravessa o sul (y pra baixo) = sorriso;
  -- pi..2pi atravessa o norte = bico para cima (frio).
  local function boca(centroY, raio, de, ate)
    love.graphics.setColor(escuro)
    love.graphics.setLineWidth(math.max(1.5, r * 0.10))
    love.graphics.arc("line", cx, centroY, raio, de, ate)
    love.graphics.setLineWidth(1)
  end

  if codigo == 2 then
    -- risada: olhos fechados (arcos virados para cima) + boca aberta
    love.graphics.setColor(escuro)
    love.graphics.setLineWidth(math.max(1.5, r * 0.10))
    for _, s in ipairs({ -1, 1 }) do
      love.graphics.arc("line", cx + s * dx, olhoY + r * 0.12, r * 0.17,
        math.pi + 0.5, 2 * math.pi - 0.5)
    end
    love.graphics.setLineWidth(1)
    love.graphics.arc("fill", cx, cy - r * 0.04, r * 0.44, 0.3, math.pi - 0.3)
    -- linha de dentes no topo da boca aberta
    love.graphics.setColor(1, 1, 1, alfa)
    love.graphics.rectangle("fill", cx - r * 0.40, cy - r * 0.04,
      r * 0.80, r * 0.09)
  elseif codigo == 3 then
    -- triste: olhos pontos + bico para cima + lagrima de um lado
    olhoPontos()
    boca(bocaY + r * 0.40, r * 0.5, math.pi + 0.6, 2 * math.pi - 0.6)
    love.graphics.setColor(0.4, 0.7, 1, alfa)
    love.graphics.circle("fill", cx + dx, olhoY + r * 0.32, r * 0.10)
  elseif codigo == 4 then
    -- raiva: olhos pontos + bico para cima + sobrancelhas firmes
    olhoPontos()
    boca(bocaY + r * 0.40, r * 0.5, math.pi + 0.6, 2 * math.pi - 0.6)
    love.graphics.setColor(escuro)
    love.graphics.setLineWidth(math.max(1.5, r * 0.11))
    love.graphics.line(cx - dx - r * 0.26, olhoY - r * 0.34,
      cx - dx + r * 0.22, olhoY - r * 0.12)
    love.graphics.line(cx + dx + r * 0.26, olhoY - r * 0.34,
      cx + dx - r * 0.22, olhoY - r * 0.12)
    love.graphics.setLineWidth(1)
  else
    -- feliz (padrao): olhos pontos + sorriso
    olhoPontos()
    boca(cy - r * 0.02, r * 0.44, 0.45, math.pi - 0.45)
  end
end

-- Area do perfil no menu (TelaInicial perfilContainer: avatar circular +
-- nick embaixo). Serve pro desenho e pro clique que abre a TelaPerfil.
function ui.rectPerfilMenu(vw, vh)
  local d = vw * 0.08
  return {
    x = vw - vw * 0.04 - d, y = vh * 0.04, w = d,
    h = d + ui.E(6) + ui.alturaTexto(ui.E(12)),
  }
end

-- BBox da barra pintada dentro de cada PNG do menu (canvas 2304x1536).
-- Medido por bbox5.ps1 (alpha > 20): x0, y0, larg, alt da arte opaca.
local BARRAS_MENU = {
  btn_um_jogador = { 84, 552, 2136, 432 },
  btn_multi = { 121, 601, 2254, 456 },
  btn_config = { 220, 556, 1860, 400 },
  btn_sobre = { 188, 544, 1928, 424 },
  btn_sair = { 192, 564, 1916, 404 },
  -- loja.png e quadrada (500x500) com arte opaca 370x376: o retangulo do
  -- botao tambem e quadrado, entao o mapeamento bbox -> ret nao distorce.
  btn_loja = { 65, 63, 370, 376 },
}

-- Alterna o fundo do menu em tempo real (F8 no menu) para comparar o
-- protótipo HTML com o vórtice antigo guardado em fundo_menu_vortex.lua.
function ui.alternarFundoMenu()
  return fundoMenu.alternar()
end

function ui.menu(estado)
  local VW, VH = estado.larguraVirtual, estado.alturaVirtual
  local hover = estado.hover or { x = -999, y = -999 }

  -- Fundo animado (vortice de tinta roxo/laranja/azul) na tela inteira.
  -- Substitui o antigo fundo preto/mesa; cobre tambem as barras do
  -- letterbox em proporcoes fora de 16:9.
  -- Fundo em coordenadas fisicas: cobre a tela toda no celular, independente
  -- da escala virtual do menu.
  ui.fundoTelaCheia(function(fx, fy, fw, fh)
    fundoMenu.desenhar(fx, fy, fw, fh)
  end)

  -- Logo grande (mao + Tormentalia) centralizada no topo, alinhada com o
  -- primeiro botao da coluna; os botoes comecam logo abaixo dela.
  local logo = arte.img("logo_menu")
  local btn1 = estado.itensMenu and estado.itensMenu[1]
  if logo and btn1 then
    local iw, ih = logo:getDimensions()
    local largLogo = btn1.w * 1.65
    local altLogo = largLogo * (ih / iw)
    local xLogo = btn1.x + (btn1.w - largLogo) / 2
    local yLogo = btn1.y - altLogo - ui.E(10)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(logo, xLogo, yLogo, 0, largLogo / iw, altLogo / ih)
  end

  -- botoes principais
  for _, item in ipairs(estado.itensMenu) do
    local img = arte.img(item.chave)
    local hov = dentroR(hover.x, hover.y, item)
    if img then
      local b = BARRAS_MENU[item.chave]
      love.graphics.setColor(1, 1, 1, hov and 0.7 or 1)
      if b then
        -- mapeia a barra pintada sobre o retangulo do item: o canvas tem
        -- padding transparente em volta, entao esticar o PNG inteiro no
        -- retangulo esmagava a arte. Aqui sx/sy quase coincidem e o
        -- texto embutido mantem a proporcao (erro max ~5%).
        local sx = item.w / b[3]
        local sy = item.h / b[4]
        love.graphics.draw(img, item.x - b[1] * sx, item.y - b[2] * sy, 0, sx, sy)
      else
        love.graphics.draw(img, item.x, item.y, 0,
          item.w / img:getWidth(), item.h / img:getHeight())
      end
    else
      ui.botao(item.rotulo, item.x, item.y, item.w, item.h,
        item.cor or C.AZUL, C.OURO, 20)
    end
  end

  -- perfil (canto superior direito; clique abre a TelaPerfil)
  local rp = ui.rectPerfilMenu(VW, VH)
  local d, ax, ay = rp.w, rp.x, rp.y
  local av = arte.avatar("voce")
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.circle("fill", ax + d / 2, ay + d / 2, d / 2 + 2)
  love.graphics.stencil(function()
    pintar({ 1, 1, 1 })
    love.graphics.circle("fill", ax + d / 2, ay + d / 2, d / 2)
  end, "replace", 1)
  love.graphics.setStencilTest("equal", 1)
  ui.imagemContain(av, ax, ay, d, d)
  love.graphics.setStencilTest()
  pintar(COR_AVATAR, 1)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", ax + d / 2, ay + d / 2, d / 2 - 1)
  love.graphics.setLineWidth(1)

  -- dinheiro (moeda + quantidade) imediatamente a esquerda do avatar,
  -- centralizado na vertical do circulo; some se o modulo ainda nao carregou.
  if ui._din then
    local txtDin = tostring(ui._din.valor())
    local tamDin = ui.E(18)
    local altDin = ui.alturaTexto(tamDin)
    local iconeD = ui.E(30)
    local yCDin = ay + d / 2
    local xTxtDin = (ax - ui.E(16)) - ui.larguraTexto(txtDin, tamDin)
    local xIconeDin = xTxtDin - ui.E(8) - iconeD
    ui.txt(txtDin, xTxtDin + 2, yCDin - altDin / 2 + 2, tamDin, { 0, 0, 0 })
    ui.txt(txtDin, xTxtDin, yCDin - altDin / 2, tamDin, C.OURO)
    local moeda = arte.img("moeda")
    if moeda then
      ui.imagemContain(moeda, xIconeDin, yCDin - iconeD / 2, iconeD, iconeD)
    else
      pintar(C.OURO, 1)
      love.graphics.circle("fill", xIconeDin + iconeD / 2, yCDin, iconeD / 2)
    end
  end

  local tamNick = ui.E(12)
  local largNick = d + ui.E(160)
  local xNick = ax + d / 2 - largNick / 2
  local yNick = ay + d + ui.E(6)
  ui.txt(estado.nick or "JOGADOR_1", xNick + 2, yNick + 2, tamNick, { 0, 0, 0 }, "center", largNick)
  ui.txt(estado.nick or "JOGADOR_1", xNick, yNick, tamNick, COR_AVATAR, "center", largNick)

  -- botoes flutuantes (tutorial / arena)
  for _, fl in ipairs(estado.flutuantes) do
    local hov = dentroR(hover.x, hover.y, fl)
    ui.caixa(fl.x, fl.y, fl.w, fl.h, ui.E(12), FUNDO_FLUT, fl.corBorda, 3, 0.9)
    if hov then
      pintar(fl.corBorda, 0.15)
      love.graphics.rectangle("fill", fl.x, fl.y, fl.w, fl.h, ui.E(12), ui.E(12), ui.E(9))
    end
    local cx = fl.x + fl.w / 2
    local iconeY = fl.y + ui.E(10) + fl.iconeTam / 2
    if fl.icone == "livro" then
      ui.iconeLivro(cx, iconeY, fl.iconeTam)
    else
      ui.iconeEspadas(cx, iconeY, fl.iconeTam)
    end
    local yTxt = fl.y + fl.h - ui.E(10) - arte.fonte(fl.tamTexto):getHeight()
    ui.txt(fl.texto, fl.x, yTxt, fl.tamTexto, fl.corTexto, "center", fl.w)
  end
end

-- Tela LOJA: fundo preto, saldo no topo, avatares a venda em cartoes
-- (sprite + nome + preco + botao COMPRAR/COMPRADO) e VOLTAR no canto
-- superior esquerdo (o ESC do main tambem volta).
function ui.rectVoltarLoja(vw, vh)
  -- Retangulo com o aspecto do arte (47x44): o desenho usa imagemContain.
  local w, h = ui.E(48), ui.E(45)
  return { x = ui.E(24), y = ui.E(20), w = w, h = h }
end

-- Tres secoes da loja (abas no topo): AVATARES (com painel de habilidade
-- e teorico), EMOJIS (os 2 sprites compraveis) e PACOTES (vazia por
-- enquanto). A aba ativa vive em ui._lojaAba.
local ABAS_LOJA = {
  { id = "avatares", nome = "AVATARES" },
  { id = "emojis", nome = "EMOJIS" },
  { id = "pacotes", nome = "PACOTES" },
}

-- Retangulos das abas (fonte unica do desenho e do clique do main).
function ui.rectsLojaAbas(vw, vh)
  local w, h, gap = ui.E(140), ui.E(32), ui.E(14)
  local total = #ABAS_LOJA * w + (#ABAS_LOJA - 1) * gap
  local x0 = (vw - total) / 2
  local y = vh * 0.19
  local lista = {}
  for i, ab in ipairs(ABAS_LOJA) do
    lista[i] = { id = ab.id, nome = ab.nome,
      x = x0 + (i - 1) * (w + gap), y = y, w = w, h = h }
  end
  return lista
end

-- Metrika dos cards POR ABA: avatares 115x155 e emojis 160x220 (medidas
-- reais; E() converte). Encolhe se nao couber na largura virtual.
local METRICAS_ABA = {
  avatares = { w = 115, h = 150 },
  emojis = { w = 160, h = 220 },
}

local function metricsLoja(vw, aba, n)
  local m = METRICAS_ABA[aba] or METRICAS_ABA.avatares
  local wCheio, hCheio = ui.E(m.w), ui.E(m.h)
  local gap, margem = ui.E(40), ui.E(30)
  n = math.max(1, n)
  local w = math.min(wCheio,
    math.floor((vw - margem * 2 - (n - 1) * gap) / n))
  local h = math.floor(hCheio * (w / wCheio))
  return w, h, gap
end

-- Geometria dos produtos da ABA ATIVA: fonte unica do desenho e do
-- clique do main. Avatares (tipo "avatar") e emojis (tipo "emoji":
-- sprite do catalogo animado no preview, posse via temEmoji) ficam em
-- abas separadas; PACOTES vem vazia (secao ainda sem conteudo).
function ui.rectsLoja(vw, vh)
  local aba = ui._lojaAba or "avatares"
  local prods = {}
  if aba == "avatares" then
    for _, p in ipairs(inv.produtos()) do
      prods[#prods + 1] = { id = p.id, nome = p.nome, preco = p.preco,
        tipo = "avatar" }
    end
  elseif aba == "emojis" then
    for _, p in ipairs(inv.emojisProdutos()) do
      prods[#prods + 1] = { id = p.id, nome = p.nome, preco = p.preco,
        tipo = "emoji", codigo = p.codigo }
    end
  end
  local w, h, gap = metricsLoja(vw, aba, #prods)
  local total = #prods * w + math.max(0, #prods - 1) * gap
  local x0 = (vw - total) / 2
  local y = vh * 0.285
  local lista = {}
  for i, p in ipairs(prods) do
    local x = x0 + (i - 1) * (w + gap)
    lista[i] = {
      id = p.id, nome = p.nome, preco = p.preco, tipo = p.tipo,
      codigo = p.codigo,
      comprado = p.tipo == "emoji" and inv.temEmoji(p.id)
        or inv.temAvatar(p.id),
      x = x, y = y, w = w, h = h,
      btn = {
        x = x + ui.E(10),
        y = y + h - ui.E(10) - ui.E(28),
        w = w - ui.E(20),
        h = ui.E(28),
      },
    }
  end
  return lista
end

-- Ficha dos avatares a venda (aba AVATARES): habilidade no jogo + um
-- resumo curto do teorico. Textos ASCII — a fonte VCR nao tem acento.
local INFO_AVATAR = {
  taylor = {
    nome = "FREDERICK TAYLOR",
    hab = "+10% DE CHANCE EM ACAO E EFEITO",
    teorico = "PAI DA ADMINISTRACAO CIENTIFICA: CRONOMETROU TAREFAS E ORGANIZOU O TRABALHO EM MOVIMENTOS SIMPLES.",
  },
  marx = {
    nome = "KARL MARX",
    hab = "REDISTRIBUI R$ 100 NO INICIO DO SEU TURNO",
    teorico = "CRITICO DO CAPITALISMO: EM O CAPITAL DESCREVEU A MAIS-VALIA, A RIQUEZA QUE O TRABALHO GERA.",
  },
  mayo = {
    nome = "ELTON MAYO",
    hab = "30% DE CHANCE DE NEUTRALIZAR CARTA NEGATIVA (1 POR RODADA)",
    teorico = "LIDER DAS PESQUISAS DE HAWTHORNE: MOSTROU QUE RELACOES HUMANAS TAMBEM MOVEM A PRODUTIVIDADE.",
  },
}
ui._lojaAba = "avatares"   -- aba ativa da loja (main troca por clique)
ui._lojaAvatarSel = nil    -- avatar selecionado p/ o painel de detalhe

-- Ficha do avatar a venda (nome + habilidade + resumo do teorico): o perfil
-- reusa os MESMOS textos na aba AVATARES (fonte unica, sem duplicar aqui).
function ui.infoAvatar(id)
  return INFO_AVATAR[id]
end

-- Painel de detalhe do avatar selecionado (so na aba AVATARES): faixa
-- sob os cards, com a mesma largura da fileira. nil sem cards.
function ui.rectLojaDetalhe(vw, vh)
  local lista = ui.rectsLoja(vw, vh)
  if #lista == 0 then return nil end
  return {
    x = lista[1].x,
    y = lista[1].y + lista[1].h + ui.E(12),
    w = lista[#lista].x + lista[#lista].w - lista[1].x,
    h = ui.E(80),
  }
end

-- Area do antigo botao MOEDAS +100 (removido da loja). Mantida para os
-- testes conferirem que clicar ali nao altera mais o saldo.
function ui.rectMoedasLoja(vw, vh)
  local w, h = ui.E(170), ui.E(34)
  -- Base: fundo dos cards da aba atual (fallback = altura dos avatares,
  -- usado na PACOTES, que nao tem cards).
  local yBase = vh * 0.285 + ui.E(155)
  for _, pr in ipairs(ui.rectsLoja(vw, vh)) do
    if pr.y + pr.h > yBase then yBase = pr.y + pr.h end
  end
  if (ui._lojaAba or "avatares") == "avatares" then
    yBase = yBase + ui.E(12) + ui.E(80) -- faixa do painel de detalhe
  end
  return {
    x = math.floor(vw / 2 - w / 2),
    y = yBase + ui.E(14),
    w = w, h = h,
  }
end

function ui.loja(estado)
  local VW, VH = estado.larguraVirtual, estado.alturaVirtual
  local hover = estado.hover or { x = -999, y = -999 }

  -- Fundo preto (pedido: tela da loja sem arte de fundo).
  pintar({ 0, 0, 0 })
  ui.preencherTela(VW, VH)

  -- Saldo (moeda + valor) no canto superior direito; some se o modulo
  -- ainda nao carregou (mesmo criterio do menu).
  if ui._din then
    local txtDin = tostring(ui._din.valor())
    local tamD = ui.E(22)
    local altD = ui.alturaTexto(tamD)
    local iconeD = ui.E(26)
    local yCD = ui.E(26) + iconeD / 2
    local xTxtD = VW - ui.E(30) - ui.larguraTexto(txtDin, tamD)
    local xIconeD = xTxtD - ui.E(8) - iconeD
    ui.txt(txtDin, xTxtD + 2, yCD - altD / 2 + 2, tamD, { 0, 0, 0 })
    ui.txt(txtDin, xTxtD, yCD - altD / 2, tamD, C.OURO)
    local moeda = arte.img("moeda")
    if moeda then
      ui.imagemContain(moeda, xIconeD, yCD - iconeD / 2, iconeD, iconeD)
    end
  end

  local tamT = ui.E(48)
  local yT = VH * 0.055
  ui.txt("LOJA", 3, yT + 3, tamT, { 0, 0, 0 }, "center", VW)
  ui.txt("LOJA", 0, yT, tamT, C.OURO, "center", VW)

  -- Feedback da ultima compra no topo (entre o titulo e as abas —
  -- dourado no sucesso, vermelho no erro).
  if ui._lojaMsg then
    local yM = ui.E(6)
    local corM = ui._lojaMsg.ok and C.OURO or C.FALHA
    ui.txt(ui._lojaMsg.texto, 2, yM + 2, ui.E(15), { 0, 0, 0 }, "center", VW)
    ui.txt(ui._lojaMsg.texto, 0, yM, ui.E(15), corM, "center", VW)
  end

  -- Abas das secoes: ativa em dourado (borda + sublinhado), inativa
  -- apagada com brilho no hover.
  local abaAtiva = ui._lojaAba or "avatares"
  for _, ab in ipairs(ui.rectsLojaAbas(VW, VH)) do
    local ativa = ab.id == abaAtiva
    ui.caixa(ab.x, ab.y, ab.w, ab.h, ui.E(8),
      ativa and C.AVATAR_BOX or C.PAINEL,
      ativa and C.OURO or C.PAINEL_BORDA, ativa and 3 or 2)
    ui.txt(ab.nome, ab.x,
      ab.y + (ab.h - ui.alturaTexto(ui.E(15))) / 2,
      ui.E(15), ativa and C.OURO or C.TEXTO3, "center", ab.w)
    if ativa then
      pintar(C.OURO)
      love.graphics.rectangle("fill", ab.x + ui.E(12),
        ab.y + ab.h - ui.E(5), ab.w - ui.E(24), ui.E(2))
    elseif dentroR(hover.x, hover.y, ab) then
      pintar(C.OURO, 0.12)
      love.graphics.rectangle("fill", ab.x, ab.y, ab.w, ab.h, 8, 8, 6)
    end
  end

  -- Cartoes dos produtos da aba ativa.
  for _, pr in ipairs(ui.rectsLoja(VW, VH)) do
    local pad = ui.E(10)
    -- Sprite encolhe quando o card encolhe (muitos produtos na loja),
    -- reservando espaco fixo para nome + preco + botao.
    local espacoBaixo = ui.E(8) + ui.alturaTexto(ui.E(13)) + ui.E(6)
      + ui.alturaTexto(ui.E(16)) + ui.E(28) + ui.E(10)
    local sprW = math.min(pr.w - pad * 2, pr.h - pad - espacoBaixo)
    -- Card do avatar selecionado ganha borda dourada (é o que abriu o
    -- painel de detalhe la embaixo).
    local selAv = pr.tipo == "avatar" and pr.id == ui._lojaAvatarSel
    ui.caixa(pr.x, pr.y, pr.w, pr.h, ui.E(10), C.PAINEL,
      selAv and C.OURO or C.PAINEL_BORDA, selAv and 4 or 3)
    if pr.tipo == "emoji" then
      -- preview do emoji: anima UMA VEZ ao abrir a loja (ancora em
      -- ui._lojaAnimInicio, zerada pelo main ao entrar na tela) e trava
      -- no ultimo quadro — nao repete. Passo = dur total / total de quadros
      -- (arte.emojiSpriteDur); sprite pelo id do produto.
      local nq = arte.emojiSpriteTotal(pr.id)
      local durRitmo = arte.emojiSpriteDur()
      local agora = love.timer.getTime()
      local ini = ui._lojaAnimInicio
      if not ini then
        ini = agora
        ui._lojaAnimInicio = ini
      end
      local quadro = math.min(nq,
        1 + math.floor((agora - ini) / durRitmo * nq))
      local img = arte.emojiSprite(pr.id, quadro)
      local xSpr = pr.x + (pr.w - sprW) / 2 -- centrado se o sprite encolheu
      if img then
        love.graphics.setColor(1, 1, 1, 1)
        ui.imagemContain(img, xSpr, pr.y + pad, sprW, sprW)
      else
        ui.emoji(pr.codigo, pr.x + pr.w / 2, pr.y + pad + sprW / 2,
          sprW * 0.36, 1)
      end
    else
      local av = arte.img("avatar_" .. pr.id)
      if av then
        ui.imagemContain(av, pr.x + (pr.w - sprW) / 2, pr.y + pad,
          sprW, sprW)
      end
    end
    local yNome = pr.y + pad + sprW + ui.E(8)
    -- Nome com a largura INTEIRA do card (nao so a do sprite): evita
    -- truncar nomes longos como FREDERICK TAYLOR em "FREDERIC...".
    ui.txtCabe(pr.nome, pr.x + pad, yNome, ui.E(13), pr.w - pad * 2,
      C.TEXTO, "center", ui.E(9))
    -- Preco: moeda + valor centralizados no cartao.
    local tamP = ui.E(16)
    local altP = ui.alturaTexto(tamP)
    local iconeP = ui.E(20)
    local yP = yNome + ui.alturaTexto(ui.E(13)) + ui.E(6)
    local largP = ui.larguraTexto(tostring(pr.preco), tamP)
    local xG = pr.x + (pr.w - (iconeP + ui.E(6) + largP)) / 2
    ui.txt(tostring(pr.preco), xG + iconeP + ui.E(6), yP, tamP, C.OURO)
    local moedaP = arte.img("moeda")
    if moedaP then
      ui.imagemContain(moedaP, xG, yP + altP / 2 - iconeP / 2, iconeP, iconeP)
    end
    -- Botao COMPRAR (azul com borda dourada) ou COMPRADO (apagado).
    if pr.comprado then
      ui.botao("COMPRADO", pr.btn.x, pr.btn.y, pr.btn.w, pr.btn.h,
        C.AVATAR_BOX, C.TEXTO3, ui.E(13), C.TEXTO3)
    else
      ui.botao("COMPRAR", pr.btn.x, pr.btn.y, pr.btn.w, pr.btn.h,
        C.AZUL, C.OURO, ui.E(14), C.CREME)
      if dentroR(hover.x, hover.y, pr.btn) then
        pintar(C.OURO, 0.16)
        love.graphics.rectangle("fill", pr.btn.x, pr.btn.y, pr.btn.w,
          pr.btn.h, 8, 8, 6)
      end
    end
    -- Card de avatar selecionavel: brilho fraco no hover (dica de que
    -- o clique fora do botao abre o detalhe).
    if pr.tipo == "avatar" and not selAv
        and dentroR(hover.x, hover.y, pr) then
      pintar(C.OURO, 0.08)
      love.graphics.rectangle("fill", pr.x, pr.y, pr.w, pr.h, 10, 10, 8)
    end
  end

  -- Painel do teorico (aba AVATARES): habilidade + resumo do avatar
  -- selecionado; sem selecao, aviso orientando o clique.
  if abaAtiva == "avatares" then
    local rD = ui.rectLojaDetalhe(VW, VH)
    if rD then
      ui.caixa(rD.x, rD.y, rD.w, rD.h, ui.E(10), C.PAINEL,
        C.PAINEL_BORDA, 2)
      local info = ui._lojaAvatarSel and INFO_AVATAR[ui._lojaAvatarSel]
      local pad = ui.E(9)
      if info then
        local largInt = rD.w - pad * 2
        ui.txt(info.nome, rD.x + pad, rD.y + pad, ui.E(15), C.OURO)
        local yH = rD.y + pad + ui.alturaTexto(ui.E(15)) + ui.E(3)
        ui.txtCabe(ui.tr("HABILIDADE:") .. " " .. info.hab, rD.x + pad, yH,
          ui.E(12), largInt, C.TEXTO, nil, ui.E(9))
        local yT2 = yH + ui.alturaTexto(ui.E(12)) + ui.E(3)
        ui.txt(info.teorico, rD.x + pad, yT2, ui.E(11), C.TEXTO2,
          "left", largInt)
      else
        ui.txt("CLIQUE NUM AVATAR PARA VER A HABILIDADE E O TEORICO",
          rD.x, rD.y + (rD.h - ui.alturaTexto(ui.E(13))) / 2,
          ui.E(13), C.TEXTO3, "center", rD.w)
      end
    end
  elseif abaAtiva == "pacotes" then
    -- PACOTES DE CARTAS: secao vazia por enquanto (so o aviso).
    local wP, hP = ui.E(460), ui.E(135)
    local xP, yP = (VW - wP) / 2, VH * 0.285
    ui.caixa(xP, yP, wP, hP, ui.E(12), C.PAINEL, C.PAINEL_BORDA, 2)
    ui.txt("PACOTES DE CARTAS", xP, yP + ui.E(30), ui.E(22), C.OURO,
      "center", wP)
    ui.txt("EM BREVE", xP, yP + ui.E(78), ui.E(15), C.TEXTO3, "center", wP)
  end

  local rV = ui.rectVoltarLoja(VW, VH)
  local imgV = arte.img("sel_voltar")
  if imgV then
    ui.imagemContain(imgV, rV.x, rV.y, rV.w, rV.h)
    if dentroR(hover.x, hover.y, rV) then
      pintar(C.OURO, 0.18)
      love.graphics.rectangle("fill", rV.x, rV.y, rV.w, rV.h, 10, 10, 6)
    end
  else
    ui.botao("VOLTAR", rV.x, rV.y, rV.w, rV.h, C.AZUL, C.OURO, 14)
    if dentroR(hover.x, hover.y, rV) then
      pintar(C.OURO, 0.18)
      love.graphics.rectangle("fill", rV.x, rV.y, rV.w, rV.h, 8, 8, 6)
    end
  end
end

return ui