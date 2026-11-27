-- fx.lua — Game feel central (hit-stop, trauma/shake, flash de tela, slow-motion).
-- API: fx.ativo, fx.hitstop(seg), fx.atualizar(dt), fx.bater(forca),
-- fx.offset(), fx.flash(cor,dur,alfa), fx.desenharFlash(), fx.lento(fator,seg).
-- Todos os deslocamentos devolvidos por fx.offset() sao inteiros para nao
-- borrar pixel art. Em MODO_TESTE nada late (sem hit-stop visivel; dt passa
-- reto para nao travar a suite de testes).

local fx = {}

-- Flag mestre: desliga tudo (testes / acessibilidade).
fx.ativo = true

local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"

-- Estado interno
local hitstopT = 0      -- segundos restantes de congelamento logico
local trauma = 0        -- 0..1; soma ao bater, decai com o tempo
local lentoT = 0        -- segundos restantes de slow-motion
local lentoFator = 1    -- fator de escala do dt durante slow-motion

local flashCor = {1, 1, 1}
local flashT = 0
local flashDur = 0.15
local flashAlfa = 1

-- Decaimento do trauma por segundo (depois do pico, cai rapidamente).
local TRAUMA_DECAI = 6

-- Direcao do shake: (0,0) = aleatorio; quando definido, o tremor vai
-- principalmente para la (ex.: carta voando para cima -> shake vertical).
local dirX, dirY = 0, 0
function fx.direcao(dx, dy)
  dx, dy = dx or 0, dy or 0
  local tam = math.sqrt(dx * dx + dy * dy)
  if tam > 0 then dx, dy = dx / tam, dy / tam end
  dirX, dirY = dx, dy
end

-- Congela a logica por `seg` segundos (impacto, falha, protecao, etc.).
-- Em MODO_TESTE ignora (nao trava a suite).
function fx.hitstop(seg)
  if MODO_TESTE or not fx.ativo then return end
  seg = seg or 0.05
  if seg > hitstopT then hitstopT = seg end
end

-- Soma trauma (0..1) ao impacto. `forca` em 0..1.
function fx.bater(forca)
  if MODO_TESTE or not fx.ativo then return end
  forca = math.max(0, math.min(1, forca or 0))
  if forca > trauma then trauma = forca end
end

-- Slow-motion temporario: escala o dt por `fator` durante `seg` segundos.
function fx.lento(fator, seg)
  if MODO_TESTE or not fx.ativo then return end
  lentoFator = math.max(0.05, fator or 0.3)
  lentoT = math.max(0.01, seg or 0.3)
end

-- Flash de tela: cor {r,g,b}, duracao em segundos, alfa maximo.
function fx.flash(cor, duracao, alfa)
  if MODO_TESTE or not fx.ativo then return end
  flashCor[1], flashCor[2], flashCor[3] = cor[1] or 1, cor[2] or 1, cor[3] or 1
  flashDur = math.max(0.01, duracao or 0.15)
  flashT = flashDur
  flashAlfa = math.max(0, math.min(1, alfa or 0.6))
end

-- Devolve dt efetivo (0 durante hit-stop; escalado durante slow-motion).
-- Deve ser chamado no topo de love.update, antes de qualquer return de tela.
function fx.atualizar(dt)
  if MODO_TESTE or not fx.ativo then return dt end

  -- Hit-stop congela tudo.
  if hitstopT > 0 then
    hitstopT = hitstopT - dt
    if hitstopT < 0 then hitstopT = 0 end
    return 0
  end

  -- Slow-motion escala o dt.
  if lentoT > 0 then
    lentoT = lentoT - dt
    if lentoT < 0 then
      lentoT = 0
      lentoFator = 1
    end
    return dt * lentoFator
  end

  return dt
end

-- Decai o trauma e devolve deslocamento inteiro (dx, dy) em pixels.
-- Chamado em love.draw para aplicar tremor de camera no frame inteiro.
function fx.offset()
  if MODO_TESTE or not fx.ativo then return 0, 0 end
  if trauma <= 0 then return 0, 0 end

  local intensidade = trauma * trauma   -- trauma^2 (suave no inicio, forte no pico)
  trauma = math.max(0, trauma - TRAUMA_DECAI * (1 / 60)) -- decaimento por frame aprox.
  if trauma < 0.01 then trauma = 0 end

  -- 75% do deslocamento segue a direcao, 25% e jitter para nao ficar rigido.
  local baseX = dirX * intensidade * 12 * 0.75
  local baseY = dirY * intensidade * 9 * 0.75
  local dx = math.floor(baseX + (love.math.random() * 2 - 1) * intensidade * 12 * 0.25 + 0.5)
  local dy = math.floor(baseY + (love.math.random() * 2 - 1) * intensidade * 9 * 0.25 + 0.5)
  return dx, dy
end

-- Desenha o flash de tela por cima de tudo (chamado em love.draw).
-- `dt` opcional: usa o delta real quando vier do main; senao 1/60.
function fx.desenharFlash(dt)
  if MODO_TESTE or not fx.ativo then return end
  if flashT <= 0 then return end
  flashT = flashT - (dt or (1 / 60))
  if flashT < 0 then flashT = 0 end

  local a = flashAlfa * (flashT / math.max(0.01, flashDur))
  if a <= 0 then return end

  love.graphics.push()
  love.graphics.setColor(flashCor[1], flashCor[2], flashCor[3], a)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.pop()
end

return fx
