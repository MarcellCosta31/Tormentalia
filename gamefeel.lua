-- gamefeel.lua — camada visual/sound design de "momento": combo Chain,
-- particulas ambientais, eventos do Deus Mercado, surpresa (slow-mo + flash)
-- e feedback haptic. Nao altera regras: so reage ao que o motor ja informa.
-- Guardado em ui._gf para o main nao ganhar locals (teto do LuaJIT).
local ui = require "ui"
local som = require "som"

local g = {}

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"
local VW, VH = 1280, 720

local OURO = ui.hex "#FFD54F"
local LARANJA = ui.hex "#F6A23C"
local VERMELHO = ui.hex "#FF5A5A"
local BRANCO = { 1, 1, 1 }

local t = 0
local heartT = 0
local cadeias = {}   -- { x, y, n, idade }
local moedas = {}    -- { x, y, vy, idade, valor }
local nuvens = {}    -- { x, y, idade, seat }
local evento = nil   -- { nome, tempo, dur }

local COMPRIMENTO_EVENTO = {
  BONANCA = 3,
  CRISE = 8,       -- ~2 turnos
  VOLATILIDADE = 6,
  SUBSIDIO = 3,
  IMPOSTO = 6,
  ESTIMULO = 3,
}

local function novoTexto(texto, x, y, cor, escala)
  cadeias[#cadeias + 1] = {
    texto = texto, x = x, y = y, cor = cor,
    idade = 0, dur = 1.1, escala = escala or 1,
  }
end

-- Chain System: texto flutuante com fogo crescente (amarelo -> laranja -> vermelho).
function g.cadeia(n, x, y)
  if MODO_TESTE or not n or n < 2 then return end
  local cor = n >= 4 and VERMELHO or (n >= 3 and LARANJA or OURO)
  novoTexto("CHAIN x" .. tostring(n) .. "!", x, y, cor, 1 + math.min(n, 5) * 0.08)
  -- Fagulhas sobem junto com o texto.
  for i = 1, math.min(12, n * 3) do
    moedas[#moedas + 1] = {
      x = x + (love.math.random() - 0.5) * 90,
      y = y + love.math.random() * 18,
      vy = -(40 + love.math.random() * 70),
      idade = 0, dur = 0.7, cor = cor, fogo = true, tam = 2 + love.math.random() * 3,
    }
  end
end

-- Moedas flutuando quando o saldo sobe.
function g.moedas(x, y, valor)
  if MODO_TESTE then return end
  local n = math.min(14, 4 + math.floor((valor or 100) / 120))
  for _ = 1, n do
    moedas[#moedas + 1] = {
      x = x + (love.math.random() - 0.5) * 70,
      y = y + (love.math.random() - 0.5) * 24,
      vy = -(35 + love.math.random() * 55),
      idade = 0, dur = 1.0 + love.math.random() * 0.5,
      cor = OURO, fogo = false, tam = 4 + love.math.random() * 3,
    }
  end
end

-- Fumaca vermelha quando o jogador esta em perigo (saldo < 500).
function g.perigo(seat, x, y, ativo)
  if MODO_TESTE then return end
  nuvens[seat] = ativo and { x = x, y = y, fase = love.math.random() * 6 } or nil
end

-- Eventos ambientais do Deus Mercado.
function g.evento(nome)
  if MODO_TESTE or not nome then return end
  evento = {
    nome = nome,
    tempo = 0,
    dur = COMPRIMENTO_EVENTO[nome] or 3,
  }
  if nome == "CRISE" and ui._fx then ui._fx.bater(0.55) end
  if nome == "BONANCA" then
    for _ = 1, 40 do
      moedas[#moedas + 1] = {
        x = love.math.random() * VW, y = -love.math.random() * VH * 0.5,
        vy = 90 + love.math.random() * 120, idade = 0,
        dur = 3, cor = OURO, fogo = false, tam = 4 + love.math.random() * 4,
        chuva = true,
      }
    end
  end
end

function g.eventoAtivo()
  return evento and evento.nome or nil
end

-- Momento surpresa: carta de alta chance que falha ou baixa chance que acerta.
function g.surpresa(chance, sucesso, x, y)
  if MODO_TESTE or chance == nil then return false end
  local surpreendente = (chance >= 0.9 and not sucesso)
    or (chance <= 0.3 and sucesso)
  if not surpreendente then return false end
  if ui._fx then
    ui._fx.lento(0.25, 0.3)
    ui._fx.flash(BRANCO, 0.20, 0.72)
  end
  novoTexto("SURPRESA!", x or VW / 2, y or VH * 0.32, BRANCO, 1.35)
  g.vibrar("forte")
  return true
end

-- Haptics: leve (jogada), medio (ataque), forte (falencia/Morte), duplo (chain).
local vibrarDuplo = 0
function g.vibrar(tipo)
  if MODO_TESTE or not love.system or not love.system.vibrate then return end
  local segundos = { leve = 0.06, medio = 0.18, forte = 0.5, duplo = 0.12 }
  local s = segundos[tipo]
  if not s then return end
  pcall(love.system.vibrate, s)
  if tipo == "duplo" then vibrarDuplo = 0.18 end
end

-- Cor da borda da mao conforme o combo: normal -> laranja -> vermelho.
function g.corBordaMao(n)
  if not n or n < 1 then return nil end
  if n >= 4 then return VERMELHO end
  if n >= 2 then return LARANJA end
  return OURO
end

function g.atualizar(dt, emPerigo)
  if MODO_TESTE then return end
  t = t + dt
  -- Momento decisivo: silencio + batimentos quando alguem quase faliu.
  if emPerigo then
    heartT = heartT + dt
    if heartT >= 0.9 then
      heartT = 0
      som.tocar("tensao")
    end
  else
    heartT = 0
  end
  for i = #cadeias, 1, -1 do
    local c = cadeias[i]
    c.idade = c.idade + dt
    if c.idade >= c.dur then table.remove(cadeias, i) end
  end
  for i = #moedas, 1, -1 do
    local m = moedas[i]
    m.idade = m.idade + dt
    m.y = m.y + m.vy * dt
    if m.chuva then m.vy = m.vy + 120 * dt end
    if m.idade >= m.dur then table.remove(moedas, i) end
  end
  if vibrarDuplo > 0 then
    vibrarDuplo = vibrarDuplo - dt
    if vibrarDuplo <= 0 then
      vibrarDuplo = 0
      pcall(love.system.vibrate, 0.12)
    end
  end
  if evento then
    evento.tempo = evento.tempo + dt
    if evento.tempo >= evento.dur then evento = nil end
    if evento and evento.nome == "CRISE" and ui._fx and math.random() < 0.04 then
      ui._fx.bater(0.18)
    end
  end
end

-- Desenha O QUE FICA ATRAS das cartas (mesa/particulas/ambiente).
function g.desenharFundo()
  if MODO_TESTE then return end
  if evento and evento.nome == "VOLATILIDADE" then
    local k = 0.10 + 0.06 * math.sin(t * 3.5)
    love.graphics.setColor(0.9, 0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 2.1)),
      0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * 1.7 + 1)), k)
    love.graphics.rectangle("fill", 0, 0, VW, VH)
    love.graphics.setColor(1, 1, 1, 1)
  end
  if evento and evento.nome == "CRISE" then
    love.graphics.setColor(0.35, 0.34, 0.38, 0.24)
    love.graphics.rectangle("fill", 0, 0, VW, VH)
    love.graphics.setColor(1, 1, 1, 1)
  end
  -- Fumaca dos jogadores em perigo.
  for _, n in pairs(nuvens) do
    for i = 1, 3 do
      local a = 0.10 + 0.06 * math.sin(t * 2 + n.fase + i)
      local x = n.x + math.sin(t * 1.3 + i * 2) * 16
      local y = n.y - ((t * 18 + i * 22) % 70)
      love.graphics.setColor(0.85, 0.12, 0.12, a)
      love.graphics.circle("fill", x, y, 14 + i * 5)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Brilho dourado pulsando na Area Segura quando tem carta guardada.
function g.brilhoArea(x, y, w, h)
  if MODO_TESTE then return end
  local a = 0.16 + 0.12 * math.sin(t * 4)
  love.graphics.setColor(OURO[1], OURO[2], OURO[3], a)
  love.graphics.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 8, 8)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Desenha O QUE FICA POR CIMA das cartas (textos, fogo, chuva de moedas).
function g.desenharFrente()
  if MODO_TESTE then return end
  for _, m in ipairs(moedas) do
    local a = math.max(0, 1 - m.idade / m.dur)
    if m.fogo then
      love.graphics.setColor(m.cor[1], m.cor[2], m.cor[3], a * 0.8)
      love.graphics.rectangle("fill", m.x, m.y, m.tam, m.tam)
    else
      love.graphics.setColor(m.cor[1], m.cor[2], m.cor[3], a)
      love.graphics.circle("fill", m.x, m.y, m.tam)
      love.graphics.setColor(0.25, 0.15, 0, a)
      love.graphics.circle("line", m.x, m.y, m.tam)
    end
  end
  for _, c in ipairs(cadeias) do
    local k = c.idade / c.dur
    local a = 1 - k
    local escala = c.escala * (1 + k * 0.18)
    local cor = c.cor
    ui.txt(c.texto, c.x - 90, c.y - k * 52, math.floor(20 * escala),
      { cor[1], cor[2], cor[3], a }, "center", 180)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Limpa tudo (nova partida / saida da tela).
function g.limpar()
  cadeias, moedas, nuvens, evento = {}, {}, {}, nil
  vibrarDuplo = 0
end

return g
