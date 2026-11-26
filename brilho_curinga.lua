-- brilho_curinga.lua
-- Brilho que percorre a borda da carta Curinga (efeito de carta rara).
-- Desenha em coordenadas LOCAIS da carta: chame dentro do mesmo
-- push/translate/rotate/scale que você já usa para desenhar a carta,
-- logo DEPOIS de desenhar a moldura. Assim ele acompanha o leque da mão.

local M = {}

M.padrao = {
    espessura   = 4,                    -- espessura do brilho (px da carta)
    margem      = 2,                    -- distância da borda externa da carta
    passo       = 3,                    -- tamanho de cada "pixel" do brilho (pixel art)
    velocidade  = 0.30,                 -- voltas por segundo
    comprimento = 0.22,                 -- tamanho do rastro (fração do perímetro)
    cor         = {1.0, 0.92, 0.62},    -- dourado claro (troque por branco p/ visual sobrenatural)
    pulso       = 0.10,                 -- intensidade do pulsar suave (0 desliga)
    pulso_vel   = 2.2,                  -- velocidade do pulsar
}

-- Converte uma distância ao longo do perímetro em x, y (sentido horário,
-- começando no canto superior esquerdo).
local function pontoNoPerimetro(s, w, h)
    if s < w then return s, 0 end
    s = s - w
    if s < h then return w, s end
    s = s - h
    if s < w then return w - s, h end
    s = s - w
    return 0, h - s
end

-- x, y: canto superior esquerdo da carta (use 0, 0 se já estiver transladado)
-- w, h: tamanho da carta
-- t:    tempo em segundos (ex.: love.timer.getTime() ou um acumulador do update)
-- opt:  tabela opcional que sobrescreve M.padrao
-- fase: deslocamento opcional, para cada carta brilhar em momentos diferentes
function M.desenhar(x, y, w, h, t, opt, fase)
    local o = {}
    for k, v in pairs(M.padrao) do o[k] = v end
    if opt then for k, v in pairs(opt) do o[k] = v end end

    local mw, mh = w - o.margem * 2, h - o.margem * 2
    local P = 2 * (mw + mh)
    local cabeca = (((t or 0) * o.velocidade + (fase or 0)) % 1) * P
    local rastro = o.comprimento * P
    local pulso = 1 + o.pulso * math.sin((t or 0) * o.pulso_vel)

    local r0, g0, b0, a0 = love.graphics.getColor()
    local modo0, alfa0 = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")

    local e = o.espessura
    for pos = 0, P, o.passo do
        local d = (cabeca - pos) % P          -- distância atrás da "cabeça"
        if d < rastro then
            local a = (1 - d / rastro)
            a = a * a * pulso                 -- cai suave até sumir
            love.graphics.setColor(o.cor[1], o.cor[2], o.cor[3], math.min(a, 1))
            local px, py = pontoNoPerimetro(pos, mw, mh)
            -- centraliza o bloco na linha da borda
            love.graphics.rectangle("fill",
                x + o.margem + px - e / 2,
                y + o.margem + py - e / 2,
                o.passo, e)
        end
    end

    love.graphics.setBlendMode(modo0, alfa0)
    love.graphics.setColor(r0, g0, b0, a0)
end

-- Opcional: multiplicador de escala para um "respirar" da carta na mão.
-- Ex.: love.graphics.scale(M.respirar(t))
function M.respirar(t, intensidade)
    return 1 + (intensidade or 0.012) * math.sin((t or 0) * 2.2)
end

return M

--[[ EXEMPLO DE USO

local brilho = require("brilho_curinga")

-- dentro do seu desenho da carta:
love.graphics.push()
love.graphics.translate(cx, cy)              -- centro da carta
love.graphics.rotate(angulo)                 -- ângulo do leque
love.graphics.translate(-LARGURA/2, -ALTURA/2)

    love.graphics.draw(imgMoldura, 0, 0)     -- sua moldura/arte
    -- ... textos ...

    if carta.tipo == "CORINGA" then
        brilho.desenhar(0, 0, LARGURA, ALTURA, love.timer.getTime(), nil, carta.fase)
    end

love.graphics.pop()

-- dica: guarde carta.fase = love.math.random() ao criar a carta,
-- para os brilhos das cartas na mão não ficarem sincronizados.

--]]
