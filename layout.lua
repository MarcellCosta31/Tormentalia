-- layout.lua — geometria e desenho da arena com 3+ jogadores.
-- So layout/desenho: nenhuma regra do jogo e alterada aqui.
-- main.lua guarda este modulo em ui._layout (o chunk dele esta no limite de
-- 200 locals do LuaJIT).

local ui = require "ui"
local arte = require "arte"
local jogo = require "jogo"

local M = { debug = false }

local VW, VH = 1280, 720

-- Cache de geometria: assentos() e chamada varias vezes por frame.
local cacheN, cacheW, cacheH, cacheSeats = nil, nil, nil, nil

local function corHex(s, fallback)
  return ui.hex(s or fallback or "#FFD54F")
end

local function dentro(ax, ay, aw, ah, ob)
  return ax < ob.x + ob.w and ax + aw > ob.x
     and ay < ob.y + ob.h and ay + ah > ob.y
end

-- Largura/altura do painel de um oponente. A largura nunca passa de 210 e
-- dimensiona conforme a quantidade de oponentes (minimo 3 para o calculo).
function M.tamanhoPainel(n, W)
  W = W or VW
  n = math.max(tonumber(n) or 3, 3)
  local w = math.min(210, W * 0.85 / n)   -- era 270
  return { w = w, h = w * 0.64 }          -- era w * 1.05
end

-- Regioes reservadas do HUD (placa de turno + visor) e menu.
-- Nenhum painel de oponente pode invadi-las.
function M.obstaculos(W, H)
  W, H = W or VW, H or VH
  local menuL = 16 + ui.E(36) + 6
  return {
    { x = 12, y = 28, w = 318, h = 140, id = "HUD" },
    { x = W - menuL, y = 12, w = menuL - 8, h = ui.E(36) + 12, id = "MENU" },
  }
end

-- Disposicao dos oponentes em arco na metade superior. Formula base:
-- cx=W/2, cy=H*0.52, rx=W*0.40, ry=H*0.36; t=i/(n+1), a=pi*(1-t).
-- Depois vem o clamp: reduces a largura ate caber no menor intervalo entre
-- assentos, empurra para baixo para nao cobrir HUD/menu e limita a
-- faixa da mao do jogador local.
function M.assentos(n, W, H)
  W, H = W or VW, H or VH
  n = tonumber(n) or 3
  if n <= 0 then return {} end
  if cacheN == n and cacheW == W and cacheH == H then return cacheSeats end

  local base = M.tamanhoPainel(n, W)
  local seats = {}
  if n >= 5 then
    -- Com 6/7 oponentes o arco deixava painéis em alturas muito diferentes
    -- (dois bem embaixo nas pontas). Ferradura simétrica: colunas alinhadas
    -- nas laterais e uma fileira curta no topo, sempre longe da arena central.
    local pw, ph = 160, 102
    local gapTopo = 16
    -- No maximo duas linhas por lateral: o excedente vai para a fileira
    -- do topo, que fica livre acima da arena e do slot de DEFESA.
    local lados = math.min(2, math.floor(n / 2))
    local qtdTopo = n - lados * 2
    local primeiroTopo = math.floor((n - qtdTopo) / 2) + 1
    local topo = {}
    for j = 0, qtdTopo - 1 do topo[j + 1] = primeiroTopo + j end
    local topoX = math.floor((W - (qtdTopo * pw + (qtdTopo - 1) * gapTopo)) / 2)
    for j, idx in ipairs(topo) do
      local x = topoX + (j - 1) * (pw + gapTopo)
      seats[idx] = { cx = x + pw / 2, cy = 86 + ph / 2,
        w = pw, h = ph, indice = idx }
    end
    local xEsq, xDir = 44, W - 44 - pw
    for k = 0, lados - 1 do
      local y = 196 + k * (ph + 10)
      local ie, id = 1 + k, n - k
      seats[ie] = { cx = xEsq + pw / 2, cy = y + ph / 2,
        w = pw, h = ph, indice = ie }
      seats[id] = { cx = xDir + pw / 2, cy = y + ph / 2,
        w = pw, h = ph, indice = id }
    end
  else
    local cx, cy = W / 2, H * 0.52
    local rx, ry = W * 0.40, H * 0.36
    for i = 1, n do
      local t = i / (n + 1)
      local a = math.pi * (1 - t)
      seats[i] = {
        cx = cx + rx * math.cos(a), cy = cy - ry * math.sin(a),
        w = base.w, h = base.h, indice = i,
      }
    end
  end

  -- Nao deixa painel vizinho se sobrepor horizontalmente. Na ferradura as
  -- colunas ja tem largura fixa e espacamento, entao so vale para o arco.
  if n > 1 and n < 5 then
    local minGap = math.huge
    for i = 1, n - 1 do
      minGap = math.min(minGap, math.abs(seats[i + 1].cx - seats[i].cx))
    end
    local maxW = math.max(110, minGap - 10)
    if base.w > maxW then
      local k = maxW / base.w
      for i = 1, n do
        seats[i].w = maxW
        seats[i].h = base.h * k
      end
    end
  end

  local margin = 8
  local handTop = H - ui.E(12) - ui.E(64) - ui.E(22) - ui.E(16)
  local obst = M.obstaculos(W, H)
  for _, s in ipairs(seats) do
    local hw, hh = s.w / 2, s.h / 2
    s.cx = math.max(margin + hw, math.min(W - margin - hw, s.cx))
    s.cy = math.max(margin + hh, s.cy)
    -- Empurra para baixo (mantem o arco) ate nao invadir cada regiao.
    for _, ob in ipairs(obst) do
      local guard = 0
      while dentro(s.cx - hw, s.cy - hh, s.w, s.h, ob) and guard < 60 do
        s.cy = s.cy + 6
        guard = guard + 1
      end
    end
    if s.cy + hh > handTop then s.cy = handTop - hh end
    s.cy = math.max(margin + hh, s.cy)
  end

  -- Assentos espelhados ficam na mesma altura (o HUD so empurra o da esquerda).
  for i = 1, math.floor(n / 2) do
    local j = n + 1 - i
    local cy = math.max(seats[i].cy, seats[j].cy)
    seats[i].cy, seats[j].cy = cy, cy
  end

  -- Retangulos derivados (usados para ancorar elementos e no debug F3).
  for _, s in ipairs(seats) do
    local pad = 12
    s.x, s.y = s.cx - s.w / 2, s.cy - s.h / 2
    s.topo = { x = s.x, y = s.y, w = s.w, h = s.h * 0.16 }
    s.cabecalho = { x = s.x + pad, y = s.y + pad,
      w = s.w - pad * 2, h = s.h * 0.34 }
    local largBarras = (s.w - pad * 2 - 6) / 2
    local yBarras = s.y + s.h * 0.54
    s.sat = { x = s.x + pad, y = yBarras, w = largBarras, h = 14 }
    s.prod = { x = s.sat.x + largBarras + 6, y = yBarras,
      w = largBarras, h = 14 }
    local rh = s.h * 0.24
    s.rodape = { x = s.x + pad, y = s.y + s.h - rh - 6,
      w = s.w - pad * 2, h = rh }
    s.esquerda = { x = s.x, y = s.y, w = s.w * 0.5, h = s.h }
    s.direita = { x = s.cx, y = s.y, w = s.w * 0.5, h = s.h }
    s.baixo = { x = s.x, y = s.cy, w = s.w, h = s.h * 0.5 }
  end

  cacheN, cacheW, cacheH, cacheSeats = n, W, H, seats
  return seats
end

-- Raio da arena central: reduz conforme o numero de oponentes e mantem
-- pelo menos 24 px de folga em relacao a qualquer painel.
function M.arena(n, W, H, cx, cy)
  W, H = W or VW, H or VH
  cx, cy = cx or W / 2, cy or math.floor(H * 0.48)
  local r = math.min(ui.E(140) / 2, ui.E(120) / 2)
  for _, s in ipairs(M.assentos(n, W, H)) do
    local dx = math.max(s.x - cx, 0, cx - (s.x + s.w))
    local dy = math.max(s.y - cy, 0, cy - (s.y + s.h))
    r = math.min(r, math.sqrt(dx * dx + dy * dy) - 24)
  end
  return { cx = cx, cy = cy, r = math.max(r, ui.E(22)) }
end

-- ---------------------------------------------------------------------------
-- PAINEL DO OPONENTE (modo = "completo" | "compacto"; por enquanto os dois
-- usam o desenho completo — o compacto ficara para uma proxima iteracao).
-- ---------------------------------------------------------------------------

local function desenharEscudo(x, y, s, cor)
  love.graphics.setColor(cor[1], cor[2], cor[3], 1)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line", {
    x, y - s / 2, x + s / 2, y - s / 4, x + s / 2, y + s / 4,
    x, y + s / 2, x - s / 2, y + s / 4, x - s / 2, y - s / 4,
  })
  love.graphics.setLineWidth(1)
end

local function desenharCadeado(x, y, s, cor)
  love.graphics.setColor(cor[1], cor[2], cor[3], 1)
  love.graphics.setLineWidth(2)
  love.graphics.arc("line", "open", x, y - s * 0.08, s * 0.28,
    math.pi, 2 * math.pi, 12)
  love.graphics.rectangle("line", x - s * 0.38, y - s * 0.08,
    s * 0.76, s * 0.60, 2, 2)
  love.graphics.setLineWidth(1)
end

local function avatarCircular(img, cx, cy, d, cor)
  love.graphics.setColor(28 / 255, 34 / 255, 56 / 255, 1)
  love.graphics.circle("fill", cx, cy, d / 2)
  if img then
    love.graphics.stencil(function()
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("fill", cx, cy, d / 2)
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)
    ui.imagemContain(img, cx - d / 2, cy - d / 2, d, d)
    love.graphics.setStencilTest()
  end
  love.graphics.setLineWidth(3)
  love.graphics.setColor(cor[1], cor[2], cor[3], 1)
  love.graphics.circle("line", cx, cy, d / 2)
  love.graphics.setLineWidth(1)
end

function M.painelOponente(opts)
  local s = opts.seat
  if not s then return end
  local x, y, w, h = s.x, s.y, s.w, s.h
  local cor = corHex(opts.cor, "#FFD54F")
  local pad = 12
  local escala = w / 230

  -- Fundo azul-escuro/preto, borda de 3 px na cor do jogador, cantos dourados.
  ui.caixa(x, y, w, h, ui.E(8), ui.hex "#080D1C", cor, 3, 0.96)
  ui.arestas(x, y, w, h, ui.E(8), ui.C.OURO, 2)

  -- Etiqueta TURNO na borda superior, somente no jogador da vez.
  if opts.vez then
    local lw, lh = 62, 19
    local lx, ly = s.cx - lw / 2, y - lh / 2
    ui.caixa(lx, ly, lw, lh, 5, cor, ui.hex "#1B4D1E", 1)
    ui.txt("TURNO", lx, ly + 3, 12, ui.hex "#10121F", "center", lw)
  end

  -- 1) Cabecalho: avatar circular a esquerda, nome e saldo a direita.
  local d = math.min(56, w * 0.26)
  local ax, ay = x + pad + d / 2, y + pad + d / 2
  avatarCircular(opts.avatar, ax, ay, d, cor)

  local tx = x + pad + d + 10
  local tw = w - (tx - x) - pad
  ui.txtCabe(opts.nome or "JOGADOR", tx, y + pad + 2, 16, tw, cor, "left", 10)
  local valorY = y + pad + d * 0.55
  if opts.ocultarSaldo then
    ui.txt("R$", tx, valorY + 3, 11, ui.C.TEXTO3, "left", 28)
    ui.txt("??", tx + 26, valorY, 18, ui.C.TEXTO3, "left", tw - 26)
  else
    ui.txt("R$", tx, valorY + 3, 11, ui.C.TEXTO3, "left", 28)
    ui.txt(tostring(opts.saldo or 0), tx + 26, valorY, 18, ui.C.SUCESSO,
      "left", tw - 26)
  end

  -- 2) Barras SAT (0..200) e PROD (-100%..+100%) lado a lado, com texto.
  local sat = math.max(0, math.min(200, tonumber(opts.satisfacao) or 100))
  local b = s.sat
  ui.caixa(b.x, b.y, b.w, b.h, 5, ui.hex "#12162B", ui.C.TEXTO3, 1)
  if sat > 0 then
    ui.caixa(b.x + 1, b.y + 1, math.max(0, (b.w - 2) * sat / 200), b.h - 2,
      4, cor, nil, 0)
  end
  local txtSat = opts.greve and "GREVE!" or ("SAT " .. math.floor(sat))
  ui.txtCabe(txtSat, b.x + 4, b.y + 1, 11, b.w - 8, ui.hex "#F0F3FF",
    "left", 8)

  local pb = s.prod
  if pb then
    local prod = math.max(-1, math.min(1, tonumber(opts.produtividade) or 0))
    ui.caixa(pb.x, pb.y, pb.w, pb.h, 5, ui.hex "#12162B", ui.C.TEXTO3, 1)
    local meio = pb.x + pb.w / 2
    if prod >= 0 then
      local larg = (pb.w - 2) * prod / 2
      if larg > 0 then
        ui.caixa(meio, pb.y + 1, larg, pb.h - 2, 4, ui.hex "#3E9B3A", nil, 0)
      end
    else
      local larg = (pb.w - 2) * (-prod) / 2
      if larg > 0 then
        ui.caixa(meio - larg, pb.y + 1, larg, pb.h - 2, 4, ui.hex "#C0392B", nil, 0)
      end
    end
    -- Marcador do neutro (0%) para a barra ficar legível de relance.
    ui.caixa(meio - 0.5, pb.y + 1, 1, pb.h - 2, 0, ui.hex "#8A93B5", nil, 0)
    local sinal = prod > 0 and "+" or ""
    local txtProd = "PROD " .. sinal .. math.floor(prod * 100) .. "%"
    local corProd = prod >= 0 and ui.hex "#8FE388" or ui.hex "#FF8A80"
    ui.txtCabe(txtProd, pb.x + 4, pb.y + 1, 10, pb.w - 8, corProd, "left", 7)
  end

  -- 3) Rodape: UMA carta virada + contador, e dois slots (Defesa/Area).
  local r = s.rodape
  local mw, mh = 22 * escala, 30 * escala
  local my = r.y + (r.h - mh) / 2
  ui.verso(r.x, my, mw, mh, {})
  local nCartas = math.max(1, tonumber(opts.mao) or 0)
  ui.txt("x" .. tostring(nCartas), r.x + mw + 4, my + mh * 0.28, 14,
    ui.C.TEXTO, "left", 40)

  local sw, sh = 28 * escala, 30 * escala
  local gap = 8
  local sx1 = r.x + r.w - sw * 2 - gap
  local sx2 = sx1 + sw + gap
  ui.caixaTracejada(sx1, my, sw, sh, 4, ui.hex "#1E1E32", 0.45,
    ui.C.OURO, 0.85, 1.5, 4, 3)
  ui.caixaTracejada(sx2, my, sw, sh, 4, ui.hex "#1E1E32", 0.45,
    ui.C.OURO, 0.85, 1.5, 4, 3)
  if opts.defesa and opts.defesa.carta then
    ui.carta(opts.defesa.carta, sx1 + 1, my + 1, sw - 2, sh - 2,
      { preencherArte = true })
  else
    desenharEscudo(sx1 + sw / 2, my + sh / 2, sw * 0.62, ui.C.OURO)
  end
  local area = opts.area or {}
  if #area > 0 then
    ui.carta(area[#area], sx2 + 1, my + 1, sw - 2, sh - 2,
      { preencherArte = true })
  else
    desenharCadeado(sx2 + sw / 2, my + sh / 2, sw * 0.62, ui.C.OURO)
  end

  -- Falido: overlay dessaturado por cima de tudo do painel.
  if opts.falido then
    love.graphics.setColor(0.12, 0.12, 0.16, 0.76)
    love.graphics.rectangle("fill", x, y, w, h, ui.E(8))
    ui.txt("FALIU", x, y + h / 2 - 10, 18, ui.C.VERMELHO, "center", w)
  elseif not opts.vez then
    -- Demais painéis levemente escurecidos (sem brilho no painel inteiro).
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.rectangle("fill", x, y, w, h, ui.E(8))
  end
end

-- ---------------------------------------------------------------------------
-- CHIPS E TEXTOS FLUTUANTES (camada separada, desenhada por ultimo)
-- ---------------------------------------------------------------------------

M.filas = {}
M.chips = {}

-- Texto de efeito persistente -> chip curto enquanto durar.
local ROTULOS_EFEITO = {
  RENDA_FIXA = function(e) return "+R$ " .. tostring(e.valor or 0), ui.C.SUCESSO end,
  DANO_PERIODICO = function(e) return "-R$ " .. tostring(e.valor or 0), ui.C.FALHA end,
  PROTECAO_TOTAL = function() return "IMUNE", ui.C.OURO end,
  TEMPO_TURNO = function() return "TEMPO", ui.C.OURO end,
  MOD_PRODUTIVIDADE = function(e)
    return string.format("PROD %+.0f%%", (e.valor or 0) * 100), ui.C.OURO
  end,
  MOD_CHANCE = function(e)
    return string.format("CHANCE %+.0f%%", (e.valor or 0) * 100), ui.C.OURO
  end,
}

function M.definirChips(painel, jogador)
  local lista = {}
  if jogador.greve then
    lista[#lista + 1] = { texto = "GREVE!", cor = ui.C.FALHA }
  end
  for _, e in ipairs(jogador.efeitos or {}) do
    local fn = ROTULOS_EFEITO[e.tipo]
    if fn then
      local texto, cor = fn(e)
      lista[#lista + 1] = { texto = texto, cor = cor }
    end
  end
  M.chips[painel] = lista
end

function M.addFlutuante(painel, texto, cor)
  if not painel or not texto then return end
  local fila = M.filas[painel] or {}
  fila[#fila + 1] = {
    texto = texto, cor = cor or ui.C.OURO,
    t = 0, dur = 1.2, sube = 30,
  }
  M.filas[painel] = fila
end

function M.atualizar(dt)
  for _, fila in pairs(M.filas) do
    for i = #fila, 1, -1 do
      fila[i].t = fila[i].t + dt
      if fila[i].t >= fila[i].dur then table.remove(fila, i) end
    end
  end
end

function M.limpar()
  M.filas, M.chips = {}, {}
end

local function textoContorno(texto, x, y, tam, cor, alfa)
  love.graphics.setLineWidth(1)
  for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
    ui.txt(texto, x + d[1], y + d[2], tam, { 0, 0, 0, 0.85 * alfa })
  end
  ui.txt(texto, x, y, tam, cor, nil, nil, alfa)
end

function M.desenhar(seats)
  local W = VW
  for painel, fila in pairs(M.filas) do
    local s = seats and seats[painel]
    if s then
      for i, item in ipairs(fila) do
        local q = item.t / item.dur
        local alfa = math.max(0, 1 - q)
        local y = s.y - 24 - item.sube * q - (i - 1) * 22
        local x = s.cx
        -- Sem espaco acima (painel do topo): desenha ao lado, nunca sobre o
        -- conteudo do painel.
        if y < 24 then
          x = s.x + s.w + 6
          y = s.y + 10 + (i - 1) * 22
          if x + 120 > W then x = s.x - 120 end
        end
        textoContorno(item.texto, x, y, 14, item.cor, alfa)
      end
    end
  end
  for painel, lista in pairs(M.chips) do
    local s = seats and seats[painel]
    if s and #lista > 0 then
      local cx = s.cx
      local cy = s.y - 10
      if cy < 26 then cy = s.y + s.h + 4 end
      local total = 0
      for _, c in ipairs(lista) do
        total = total + ui.larguraTexto(c.texto, 11) + 12
      end
      local px = cx - total / 2
      for _, c in ipairs(lista) do
        local tw = ui.larguraTexto(c.texto, 11) + 10
        ui.caixa(px, cy, tw, 17, 5, ui.hex "#080D1C", c.cor, 1, 0.92)
        ui.txt(c.texto, px + 5, cy + 3, 11, c.cor, "left", tw)
        px = px + tw + 2
      end
    end
  end
end

-- F3: retangulos de painel, faixas internas e arena.
function M.desenharDebug(seats, arena)
  if not M.debug then return end
  love.graphics.setLineWidth(1)
  for i, s in ipairs(seats or {}) do
    love.graphics.setColor(1, 0.3, 0.3, 0.9)
    love.graphics.rectangle("line", s.x, s.y, s.w, s.h)
    for _, key in ipairs({ "topo", "cabecalho", "sat", "rodape" }) do
      local r = s[key]
      love.graphics.setColor(0.3, 1, 0.4, 0.8)
      love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
    end
    ui.txt("P" .. tostring(i), s.x + 2, s.y + 2, 11, ui.C.OURO)
  end
  if arena then
    love.graphics.setColor(0.3, 0.7, 1, 0.9)
    love.graphics.circle("line", arena.cx, arena.cy, arena.r)
    ui.txt("ARENA r=" .. math.floor(arena.r), arena.cx - 60,
      arena.cy - arena.r - 14, 11, ui.C.OURO)
  end
  love.graphics.setLineWidth(1)
end

return M
