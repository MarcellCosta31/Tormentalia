-- anim.lua — Biblioteca de tween e timers para animacoes do jogo.
-- Easings: linear, saidaQuad, saidaCubica, entradaCubica, meio, atraso,
-- elastico, quicar, saidaExcesso (back-out com overshoot).
-- anim.tween(alvo, para, dur, ease, fim) — substitui tweens conflitantes
-- no mesmo alvo/chave. Suporta atraso opcional (5o parametro posicional
-- era 'fim'; agora 'atraso' vai como campo nomeado ou posicional depois de
-- 'ease': anim.tween(alvo, para, dur, ease, fim, atraso)).
-- anim.depois(seg, fn) — timer disparado apos `seg` segundos.
-- anim.update(dt) avanca tweens e timers. anim.ativo() / anim.limpar().

local anim = {}

local lista = {}
local timers = {}

function anim.linear(k) return k end
function anim.saidaQuad(k) return 1 - (1 - k) * (1 - k) end
function anim.saidaCubica(k) return 1 - (1 - k) ^ 3 end
function anim.entradaCubica(k) return k * k * k end
function anim.meio(k) return k < 0.5 and 4 * k * k * k or 1 - (-2 * k + 2) ^ 3 / 2 end
function anim.atraso(k) return k * k * (3 - 2 * k) end
function anim.elastico(k)
  if k == 0 or k == 1 then return k end
  return 2 ^ (-10 * k) * math.sin((k * 10 - 0.75) * (2 * math.pi / 3)) + 1
end
function anim.quicar(k)
  local n1, d1 = 7.5625, 2.75
  if k < 1 / d1 then return n1 * k * k end
  if k < 2 / d1 then k = k - 1.5 / d1 return n1 * k * k + 0.75 end
  if k < 2.5 / d1 then k = k - 2.25 / d1 return n1 * k * k + 0.9375 end
  k = k - 2.625 / d1
  return n1 * k * k + 0.984375
end

-- Back-out com overshoot (spring do Reanimated). c = quantidade de excesso.
-- Ex.: saidaExcesso(k) com c=1.1 ultrapassa o alvo e volta.
function anim.saidaExcesso(k, c)
  c = c or 1.1
  local s = k - 1
  return 1 + (c + 1) * s * s * s + c * s * s
end

local function copiarValores(alvo, chaves)
  local de = {}
  for k in pairs(chaves) do de[k] = alvo[k] end
  return de
end

-- Cria (ou substitui) um tween no alvo. Se ja existe um tween no mesmo alvo
-- que anima alguma das chaves de `para`, o antigo e cancelado.
-- Parametros:
--   alvo  tabela cujos campos serao interpolados (de -> para)
--   para  tabela { chave = valorDestino, ... }
--   dur   duracao em segundos
--   ease  funcao de easing (default saidaCubica)
--   fim   callback ao terminar
--   atraso segundos para esperar antes de iniciar (opcional)
function anim.tween(alvo, para, dur, ease, fim, atraso)
  for i = #lista, 1, -1 do
    local tw = lista[i]
    if tw.alvo == alvo then
      for k in pairs(para) do
        if tw.para[k] ~= nil then
          table.remove(lista, i)
          break
        end
      end
    end
  end

  table.insert(lista, {
    alvo = alvo,
    de = copiarValores(alvo, para),
    para = para,
    t = 0,
    dur = math.max(dur, 0.0001),
    ease = ease or anim.saidaCubica,
    fim = fim,
    atraso = atraso or 0,
  })
end

function anim.depois(seg, fn)
  table.insert(timers, { t = math.max(seg, 0.0001), fn = fn })
end

function anim.ativo()
  return #lista > 0 or #timers > 0
end

function anim.limpar()
  lista = {}
  timers = {}
end

function anim.update(dt)
  -- Timers
  for i = #timers, 1, -1 do
    local tm = timers[i]
    tm.t = tm.t - dt
    if tm.t <= 0 then
      table.remove(timers, i)
      if tm.fn then tm.fn() end
    end
  end

  -- Tweens
  for i = #lista, 1, -1 do
    local tw = lista[i]
    -- Consome o atraso; o tempo restante do frame avanca o tween no mesmo
    -- update (com atraso=0 isso equivale ao passoTween original).
    local avanca = dt
    if tw.atraso > 0 then
      if tw.atraso >= avanca then
        tw.atraso = tw.atraso - avanca
        avanca = 0
      else
        avanca = avanca - tw.atraso
        tw.atraso = 0
      end
    end
    tw.t = tw.t + avanca

    local k = math.min(1, tw.t / tw.dur)
    local e = tw.ease(k)
    for chave, destino in pairs(tw.para) do
      tw.alvo[chave] = tw.de[chave] + (destino - tw.de[chave]) * e
    end
    if k >= 1 then
      table.remove(lista, i)
      if tw.fim then tw.fim() end
    end
  end
end

return anim
