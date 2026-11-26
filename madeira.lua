local M = {}

local CORES_PLACAS = {
  { 0x6B, 0x45, 0x26 },
  { 0x73, 0x49, 0x2B },
  { 0x64, 0x40, 0x1F },
  { 0x78, 0x50, 0x31 },
  { 0x5E, 0x3B, 0x1E },
  { 0x6F, 0x48, 0x28 },
}

local VINHETA = { 0.05, 0.055, 0.06, 0.065, 0.07, 0.075 }

local canvas = nil

local function variarCor(base, delta)
  local function c(v)
    return math.max(0, math.min(255, v + delta)) / 255
  end
  return { c(base[1]), c(base[2]), c(base[3]) }
end

local function segsDePlaca(rand, larguraTotal)
  local sorteio = rand()
  local qtd = sorteio < 0.45 and 1 or (sorteio < 0.80 and 2 or 3)
  if qtd == 1 then return { { left = 0, largura = larguraTotal } } end

  local fronteiras = { 0 }
  local acumulado = 0
  for _ = 1, qtd - 1 do
    acumulado = acumulado + larguraTotal / qtd + (rand() - 0.5) * (larguraTotal / qtd) * 0.4
    table.insert(fronteiras, math.floor(acumulado + 0.5))
  end
  table.insert(fronteiras, larguraTotal)

  local segmentos = {}
  for i = 1, #fronteiras - 1 do
    table.insert(segmentos, {
      left = fronteiras[i],
      largura = fronteiras[i + 1] - fronteiras[i],
    })
  end
  return segmentos
end

local function desenharVeios(rand, x, y, segLargura, segAltura)
  local qtd = 7 + math.floor(rand() * 7)
  for _ = 1, qtd do
    local claro = rand() < 0.35
    local ehDuplo = rand() < 0.22
    local rotacao = (rand() - 0.5) * 3
    local largura = segLargura * (0.35 + rand() * 0.7)
    local top = 5 + rand() * math.max(1, segAltura - 10)
    local left = rand() * segLargura * 0.55
    local altura = rand() < 0.25 and 2 or 1

    local cor
    if claro then
      cor = { 1, 0.878, 0.717, 0.05 + rand() * 0.07 }
    else
      cor = { 0.157, 0.086, 0.035, 0.10 + rand() * 0.22 }
    end

    love.graphics.setColor(cor)
    love.graphics.push()
    love.graphics.translate(x + left, y + top)
    love.graphics.rotate(math.rad(rotacao))
    love.graphics.rectangle("fill", 0, 0, largura, altura)
    love.graphics.pop()

    if ehDuplo then
      love.graphics.push()
      love.graphics.translate(x + left + (rand() * 12), y + top + (rand() < 0.5 and 3 or -3))
      love.graphics.rotate(math.rad(rotacao + (rand() - 0.5) * 1.2))
      love.graphics.rectangle("fill", 0, 0, largura * (0.6 + rand() * 0.3), 1)
      love.graphics.pop()
    end
  end
end

local function desenharNo(rand, x, y, segLargura, segAltura)
  local noX = x + segLargura * (0.15 + rand() * 0.65)
  local noY = y + segAltura * (0.25 + rand() * 0.45)
  local raio = 11 + rand() * 9

  love.graphics.setColor(0.204, 0.110, 0.047, 0.42)
  love.graphics.setLineWidth(2)
  love.graphics.ellipse("line", noX, noY, raio, raio * 0.85)

  love.graphics.setColor(0.165, 0.086, 0.035, 0.55)
  love.graphics.setLineWidth(1.5)
  love.graphics.ellipse("line", noX, noY, raio * 0.68, raio * 0.58)

  love.graphics.setColor(0.102, 0.051, 0.020, 0.65)
  love.graphics.ellipse("fill", noX, noY, raio * 0.33, raio * 0.28)
  love.graphics.setLineWidth(1)
end

function M.gerar(largura, altura)
  if canvas then return canvas end

  canvas = love.graphics.newCanvas(largura, altura)
  canvas:setFilter("linear", "linear")

  local anterior = love.graphics.getCanvas()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.369, 0.231, 0.118, 1)

  local gen = love.math.newRandomGenerator(1994)
  local function rand(...) return gen:random(...) end

  local y = -30
  while y < altura + 60 do
    local alt = math.max(40, math.floor(altura / 6) + math.floor(rand() * 30) - 15)
    local base = CORES_PLACAS[rand(#CORES_PLACAS)]
    local segmentos = segsDePlaca(rand, largura)

    -- costura horizontal superior da taboa
    love.graphics.setColor(0.102, 0.055, 0.020, 0.85)
    love.graphics.rectangle("fill", 0, y, largura, 3)
    love.graphics.setColor(1, 0.902, 0.745, 0.18)
    love.graphics.rectangle("fill", 0, y + 3, largura, 1)

    for si, seg in ipairs(segmentos) do
      local cor = variarCor(base, math.floor((rand() - 0.5) * 14))
      love.graphics.setColor(cor[1], cor[2], cor[3], 1)
      love.graphics.rectangle("fill", seg.left, y, seg.largura, alt)

      love.graphics.setColor(1, 0.882, 0.725, 0.05)
      love.graphics.rectangle("fill", seg.left, y + 3, seg.largura, alt * 0.30)
      love.graphics.setColor(0, 0, 0, 0.10)
      love.graphics.rectangle("fill", seg.left, y + alt - alt * 0.35, seg.largura, alt * 0.35)

      desenharVeios(rand, seg.left, y, seg.largura, alt)

      if rand() < 0.4 then
        desenharNo(rand, seg.left, y, seg.largura, alt)
      end

      if si > 1 then
        love.graphics.setColor(0.078, 0.039, 0.016, 0.55)
        love.graphics.rectangle("fill", seg.left, y, 2, alt)
      end
    end

    y = y + alt
  end

  -- luz central quente (mesa sob lampada)
  love.graphics.setColor(1, 0.910, 0.725, 0.06)
  love.graphics.ellipse("fill", largura * 0.5, altura * 0.5, largura * 0.4, altura * 0.32)

  -- verniz: faixas diagonais
  love.graphics.push()
  love.graphics.translate(largura * 0.5, altura * 0.13)
  love.graphics.rotate(math.rad(-8))
  love.graphics.setColor(1, 0.941, 0.824, 0.035)
  love.graphics.rectangle("fill", -largura, -45, largura * 2, 90)
  love.graphics.pop()

  love.graphics.push()
  love.graphics.translate(largura * 0.5, altura * 0.58)
  love.graphics.rotate(math.rad(-8))
  love.graphics.setColor(1, 0.941, 0.824, 0.025)
  love.graphics.rectangle("fill", -largura, -30, largura * 2, 60)
  love.graphics.pop()

  -- spotlight do topo (ArenaCombate)
  love.graphics.setColor(1, 0.922, 0.686, 0.08)
  love.graphics.ellipse("fill", largura * 0.5, altura * 0.475, largura * 0.30, altura * 0.225)

  -- vinheta: bordas escurecidas em 6 aneis
  for i, opacidade in ipairs(VINHETA) do
    local b = i * 26
    love.graphics.setColor(0.055, 0.027, 0.012, opacidade)
    love.graphics.rectangle("fill", 0, 0, largura, b)
    love.graphics.rectangle("fill", 0, altura - b, largura, b)
    love.graphics.rectangle("fill", 0, 0, b, altura)
    love.graphics.rectangle("fill", largura - b, 0, b, altura)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setCanvas()
  if anterior then love.graphics.setCanvas(anterior) end

  return canvas
end

function M.limpar()
  canvas = nil
end

return M
