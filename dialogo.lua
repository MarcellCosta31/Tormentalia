-- dialogo.lua — Conversa de abertura com o ADAM SMITH antes do duelo do
-- chefe do Ciclo I (no idx 7 do mapa). Cena por cima do mapa, cobrindo a
-- roda com o cenario proprio (cenario_dialogo.png): dialog box embaixo,
-- sprite do jogador em cima da caixa do lado ESQUERDO e a do
-- Adam do lado DIREITO — o falante ativo fica aceso e o nome fica na
-- placa da propria sprite. Clique/espaço avança: o 1o clique completa a
-- linha, o proximo passa adiante; a ultima linha encerra e chama o
-- aoFim recebido no iniciar() (o main abre o duelo).
-- Botao PULAR no canto inferior esquerdo da caixa (e a tecla P) leva
-- direto para a batalha pulando o resto da conversa.
-- Texto ASCII puro: a fonte VCR do jogo nao tem acento (igual ao resto
-- da interface).
local ui = require "ui"
local arte = require "arte"
local som = require "som"

local D = {}

local VW, VH = 1280, 720
local TAMB = ui.E(19)        -- corpo da fala
local TAMS = ui.E(22)        -- fala de sistema (quem = "s"; sem no roteiro)
local TAMN = ui.E(13)        -- nome na placa da sprite
local TAMH = ui.E(12)        -- dicas / botao PULAR
local VEL = 45               -- caracteres por segundo do datilografo
local PAUSA_NOVA = 0.12      -- respiro antes de comecar a digitar
local POP_DUR = 0.18         -- "pop" da sprite quando a fala muda
local FADE = 0.28            -- fade da cena inteira

-- Animacao do ADAM: boca em loop (neutro -> boca leve -> boca aberta ->
-- boca media -> retorno) enquanto o datilografo digita a fala dele; fora
-- disso ele fica parado so piscando (neutro por um tempo, piscada rapida,
-- repete).
local BOCAS = { "neutro", "bocaLeve", "bocaAberta", "bocaMedia",
  "retorno" }
local DUR_BOCO = 0.11        -- segundos por quadro da boca falando
local DUR_NEUTRO = 2.1       -- parado: tempo entre piscadas
local DUR_PISCA = 0.14       -- duracao do quadro de piscar

-- { quem = "p" (protagonista) | "a" (Adam) | "s" (sistema, sem retrato
-- aceso), fala = "..." }.
local FALAS = {
  { quem = "p", fala = "Entao voce e quem esta no comando deste lugar?" },
  { quem = "a", fala = "No comando?" },
  { quem = "a", fala = "Nao." },
  { quem = "a", fala = "Eu apenas observo." },
  { quem = "p", fala = "Observa o que?" },
  { quem = "a", fala = "Homens lutando por aquilo que desejam." },
  { quem = "a", fala = "Dinheiro. Poder. Seguranca. Reconhecimento..." },
  { quem = "a", fala = "Cada um tentando conseguir o melhor para si." },
  { quem = "p", fala = "E voce chama isso de que?" },
  { quem = "a", fala = "Mercado." },
  { quem = "p", fala = "Isso aqui nao parece um mercado." },
  { quem = "a", fala = "Porque voce ainda nao entendeu." },
  { quem = "a", fala = "Um mercado nao precisa de alguem dizendo a cada individuo o que fazer." },
  { quem = "a", fala = "Cada um busca seu proprio interesse." },
  { quem = "a", fala = "E, mesmo assim..." },
  { quem = "a", fala = "...uma mao invisivel organiza o caos." },
  { quem = "p", fala = "Entao e voce que controla essa mao?" },
  { quem = "a", fala = "[risada]" },
  { quem = "a", fala = "Voce realmente nao entendeu nada." },
  { quem = "a", fala = "Eu nao controlo a mao." },
  { quem = "a", fala = "Eu sou apenas mais um homem tentando sobreviver a ela." },
  { quem = "p", fala = "Entao por que eu estou aqui?" },
  { quem = "a", fala = "Porque voce acreditava que sabia administrar." },
  { quem = "p", fala = "..." },
  { quem = "a", fala = "Voce abriu uma empresa." },
  { quem = "a", fala = "Contratou pessoas." },
  { quem = "a", fala = "Tomou decisoes." },
  { quem = "a", fala = "E acreditou que poderia controlar tudo." },
  { quem = "p", fala = "Eu tentei." },
  { quem = "a", fala = "Todos tentam." },
  { quem = "a", fala = "Mas o mercado nao se importa com suas tentativas." },
  { quem = "a", fala = "Voce quer sair daqui?" },
  { quem = "p", fala = "Quero." },
  { quem = "a", fala = "Entao tera que provar que merece." },
  { quem = "p", fala = "Como?" },
  { quem = "a", fala = "Do jeito que todos aprendem neste lugar." },
  { quem = "a", fala = "Competindo." },
  { quem = "a", fala = "Bem-vindo ao Reino Esquecido, e aqui eu sou o Soberano." },
  { quem = "a", fala = "Vamos descobrir quanto vale voce." },
}

local st = nil

-- Fecha a cena e descarta os quadros do Adam (cena transitoria: ~90 MB
-- que nao valem a pena depois que a conversa acaba).
local function encerrar()
  st = nil
  arte.liberarAdamDialogo()
end

-- Quadro atual da animacao do Adam: boca so enquanto a fala dele ainda
-- esta sendo digitada; linha pronta ou fala de outro = parado piscando.
local function nomeAdam()
  if not st then return nil end
  if st.adamFalando then
    return BOCAS[math.floor(st.tAdam / DUR_BOCO) % #BOCAS + 1]
  end
  local t = st.tAdam % (DUR_NEUTRO + DUR_PISCA)
  return t < DUR_NEUTRO and "neutro" or "piscando"
end

-- Mesmo quadro acima em nome ("neutro"/"piscando"/boca), exposto para o
-- teste conferir a troca parado <-> falando sem depender da imagem.
function D.quadroAdam()
  return nomeAdam()
end

local ROT_PULAR = "PULAR >>"

-- Retangulo do botao PULAR (canto inferior esquerdo da caixa), na mesma
-- posicao do desenho e do clique — inclui o deslocamento do fade de entrada.
local function retPular()
  if not st then return nil end
  local bx = ui.E(48)
  local bw = VW - ui.E(96)
  local bh = ui.E(150)
  local p = math.min(1, st.t / FADE)
  local a = 1 - (1 - p) * (1 - p)
  local by = VH - ui.E(40) - bh + (1 - a) * ui.E(30)
  local alt = ui.alturaTexto(TAMH)
  local larg = ui.larguraTexto(ROT_PULAR, TAMH) + ui.E(24)
  return bx + ui.E(26), by + bh - ui.E(30) - ui.E(8), larg, alt + ui.E(16)
end

function D.retPular()
  return retPular()
end

-- opcoes: { nome = nome do jogador, aoFim = funcao chamada ao terminar }
function D.iniciar(opcoes)
  opcoes = opcoes or {}
  -- Quadros do Adam e o cenario carregados ja no fade de entrada (evita
  -- tranco na primeira fala); limpos por encerrar() quando a conversa
  -- termina.
  arte.carregarAdamDialogo()
  st = {
    idx = 1,
    chars = 0,
    espera = PAUSA_NOVA,
    pop = POP_DUR,
    t = 0,
    aviso = 0,
    tAdam = 0,
    adamFalando = false,
    nomeP = opcoes.nome or "JOGADOR",
    aoFim = opcoes.aoFim,
  }
end

function D.ativo()
  return st ~= nil
end

function D.total()
  return #FALAS
end

function D.idxAtual()
  return st and st.idx or nil
end

function D.atualizar(dt)
  if not st then return end
  st.t = st.t + dt
  st.aviso = st.aviso + dt
  if st.pop > 0 then st.pop = math.max(0, st.pop - dt) end
  -- Animacao do Adam: so a fala dele em digitacao mexe a boca; trocar de
  -- modo zera o relogio para a nova sequencia comecar do neutro.
  local atual = FALAS[st.idx]
  local falando = atual.quem == "a" and st.chars < #atual.fala
  if falando ~= st.adamFalando then
    st.adamFalando = falando
    st.tAdam = 0
  end
  st.tAdam = st.tAdam + dt
  if st.espera > 0 then
    st.espera = st.espera - dt
    return
  end
  local fala = FALAS[st.idx].fala
  if st.chars < #fala then
    st.chars = math.min(#fala, st.chars + VEL * dt)
  end
end

-- Pula a conversa inteira e vai direto para a batalha (botao PULAR /
-- tecla P). Mesmo caminho do fim natural: limpa a cena e dispara o aoFim.
function D.pular()
  if not st then return false end
  local fn = st.aoFim
  encerrar()
  som.tocar("jogar", 0.5)
  if fn then fn() end
  return true
end

-- Um clique: dentro do botao PULAR pula para a batalha; fora dele completa
-- a linha atual, e se ja esta completa passa adiante; na ultima linha
-- encerra (limpa o estado e dispara o aoFim). Devolve true quando o clique
-- foi consumido pela cena.
function D.clique(mx, my)
  if not st then return false end
  if mx and my then
    local rx, ry, rw, rh = retPular()
    if rx and mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh then
      return D.pular()
    end
  end
  local fala = FALAS[st.idx].fala
  if st.chars < #fala then
    st.chars = #fala
    st.espera = 0
    return true
  end
  if st.idx < #FALAS then
    st.idx = st.idx + 1
    st.chars = 0
    st.espera = PAUSA_NOVA
    st.pop = POP_DUR
    som.tocar("clique", 0.4)
    return true
  end
  local fn = st.aoFim
  encerrar()
  som.tocar("jogar", 0.5)
  if fn then fn() end
  return true
end

local function sprite(img, nome, x, y, w, h, ativa, alfa, escala)
  love.graphics.push()
  local cx, cy = x + w / 2, y + h / 2
  love.graphics.translate(cx, cy)
  love.graphics.scale(escala, escala)
  love.graphics.translate(-cx, -cy)

  -- moldura + miolo
  ui.caixa(x, y, w, h, 6, ui.C.AVATAR_BOX, ativa and ui.C.OURO or ui.C.TEXTO3,
    ativa and 2.5 or 1.5, 0.98 * alfa, (ativa and 1 or 0.45) * alfa)
  if img then
    ui.imagemCover(img, x + 3, y + 3, w - 6, h - 6,
      (ativa and 1 or 0.5) * alfa)
  end

  -- placa de nome na base da sprite (em cima da borda da caixa)
  local altPlaca = ui.alturaTexto(TAMN) + ui.E(7) * 2
  local py = y + h - altPlaca
  love.graphics.setColor(0, 0, 0, 0.66 * alfa)
  love.graphics.rectangle("fill", x, py, w, altPlaca)
  local corNome = ativa and ui.C.OURO or ui.C.TEXTO2
  ui.txt(nome, x, py + ui.E(7), TAMN, corNome, "center", w, alfa)
  love.graphics.pop()
end

function D.desenhar()
  if not st then return end
  local p = math.min(1, st.t / FADE)
  local a = 1 - (1 - p) * (1 - p)
  local sobe = (1 - a) * ui.E(30)

  -- Fundo: cenario proprio da conversa, entrando com o mesmo fade. O
  -- escuro opaco embaixo esconde a roda na hora (sem tranco da troca);
  -- sem imagem, fica so o escuro.
  love.graphics.setColor(0.03, 0.03, 0.07, 1)
  ui.preencherTela(VW, VH)
  local cenario = arte.cenarioDialogo()
  if cenario then
    ui.imagemCover(cenario, 0, 0, VW, VH, a)
  end

  local fala = FALAS[st.idx]
  local ehSistema = fala.quem == "s"
  local completa = st.chars >= #fala.fala

  -- Caixa de dialogo.
  local bx = ui.E(48)
  local bw = VW - ui.E(96)
  local bh = ui.E(150)
  local by = VH - ui.E(40) - bh + sobe
  ui.caixa(bx, by, bw, bh, 10, ui.C.PAINEL, ui.C.OURO, 2, 0.97 * a, 0.9 * a)

  -- Sprites em cima da caixa: jogador (esquerda) e Adam (direita).
  local sw, sh = ui.E(130), ui.E(152)
  local sy = by + ui.E(14) - sh
  local pop = 1 + 0.035 * (st.pop / POP_DUR)
  sprite(arte.avatar("voce"), st.nomeP, bx + ui.E(18), sy, sw, sh,
    fala.quem == "p", a, fala.quem == "p" and pop or 1)
  -- Quadro animado do Adam (boca falando / piscando parado); se os PNGs
  -- nao carregarem, cai na foto estatica antiga (arte.avatar("ia")).
  sprite(arte.adamDialogo(nomeAdam()) or arte.avatar("ia"), "ADAM SMITH",
    bx + bw - ui.E(18) - sw, sy, sw, sh,
    fala.quem == "a", a, fala.quem == "a" and pop or 1)

  -- Fala (datilografo; quebrada em linhas pelo ui.quebrar). O texto e
  -- ASCII entao o corte por byte do sub() e seguro.
  local tam = ehSistema and TAMS or TAMB
  local tx = bx + ui.E(26)
  local tw = bw - ui.E(52)
  local ty = by + ui.E(30)
  local cor = ehSistema and ui.C.OURO or ui.C.CREME
  local linhas = ui.quebrar(fala.fala, tam, tw)
  local resta = math.floor(st.chars)
  love.graphics.setFont(arte.fonte(tam))
  local alt = love.graphics.getFont():getHeight()
  local ultX, ultY = tx, ty
  for i, linha in ipairs(linhas) do
    local y = ty + (i - 1) * alt
    if resta <= #linha then
      local parte = resta < #linha and linha:sub(1, math.max(0, resta))
        or linha
      ui.txt(parte, tx, y, tam, cor, nil, nil, a)
      ultX = tx + ui.larguraTexto(parte, tam)
      ultY = y
      break
    end
    ui.txt(linha, tx, y, tam, cor, nil, nil, a)
    resta = resta - #linha - 1
    ultX = tx + ui.larguraTexto(linha, tam)
    ultY = y
  end

  -- Dica de avanco (pisca) no canto inferior direito da caixa; enquanto a
  -- linha ainda esta sendo digitada, um cursor pisca no fim do texto.
  if completa then
    local pisca = 0.55 + 0.45 * math.sin(st.aviso * 4)
    local dica = ehSistema and "CLIQUE PARA INICIAR A BATALHA"
      or "CLIQUE PARA CONTINUAR >>"
    local corDica = ehSistema and ui.C.OURO or ui.C.TEXTO2
    ui.txt(dica, bx + bw - ui.E(26) - ui.larguraTexto(dica, TAMH),
      by + bh - ui.E(30), TAMH, corDica, nil, nil, a * pisca)
  elseif math.sin(st.aviso * 6) > 0 then
    ui.txt("_", ultX + ui.E(3), ultY, tam, cor, nil, nil, a * 0.9)
  end

  -- Botao PULAR (leva direto para a batalha), espelhando a dica do outro
  -- lado: caixa com borda dourada e rotulo em TEXTO2.
  local rx, ry, rw, rh = retPular()
  if rx then
    ui.caixa(rx, ry, rw, rh, 6, { 0, 0, 0 }, ui.C.OURO, 1.5,
      0.6 * a, 0.75 * a)
    ui.txt(ROT_PULAR, rx, ry + (rh - ui.alturaTexto(TAMH)) / 2, TAMH,
      ui.C.TEXTO2, "center", rw, a)
  end
end

function D.limpar()
  encerrar()
end

return D
