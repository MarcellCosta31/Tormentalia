local A = {}

-- Avatares basicos em 64x64, gerados a partir de arte/perfil/*.png (os
-- originais ficam guardados). Centraliza a variante: "limpo/" = media +
-- 32 cores + alfa duro (padrao); "" = nearest (pixels crus) e
-- "preenchido/" = nearest esticado no quadrado.
local AV64 = "arte/perfil/64/limpo/"

local IMAGENS = {
  verso = "arte/cards/traseira_cartas.png",
  arte_faltando = "arte/cards/arte_faltando.png",
  -- Mao do Deus Mercado usada na roleta do Curinga global. A imagem aponta
  -- para cima; o meta gira em torno do punho ate a carta sorteada.
  deus_mao = "arte/deus_mercado/escolha_curinga.png",
  -- Mao do Deus Mercado interferindo no bonus (fundo transparente).
  deus_interfere = "arte/deus_mercado/deusmercado_interfereindo.png",
  pause = "arte/menu/pause.jpg",
  menu_fundo = "arte/menu/menu_back.png",
  logo = "arte/menu/Logo.png",
  logo_menu = "arte/menu/LOGO-TORMENTALIA.png",
  btn_um_jogador = "arte/menu/um_jogador_btn.png",
  -- A arte nova (jogar_btn.png) veio 24bpp SEM alfa (fundo preto solido);
  -- "*_recortada" e a mesma arte com o fundo aberto por preenchimento a
  -- partir das bordas (luminancia <= 30, rampa de alfa 10..30).
  btn_multi = "arte/menu/jogar_btn_recortada.png",
  btn_config = "arte/menu/configura_btn.png",
  btn_sobre = "arte/menu/sobre_btn.png",
  btn_sair = "arte/menu/sair_btn.png",
  btn_loja = "arte/menu/loja.png",
  moeda = "arte/menu/moeda.png",
  avatar_voce = AV64 .. "azul_marinho_64.png",
  -- Adam Smith: avatar do Ciclo I (a arte 64px de arte/64/ciclo1; o 1920
  -- original de "1 ciclo" ficou guardado).
  avatar_ia = "arte/64/ciclo1/Adam_Smith_64.png",
  -- Tela PERFIL (TelaPerfil.js): grade na mesma ordem de avatar.js, agora
  -- com a arte 64x64 (ver AV64 acima).
  avatar_1 = AV64 .. "azul_marinho_64.png",
  avatar_2 = AV64 .. "vermelho_64.png",
  avatar_3 = AV64 .. "verde_64.png",
  avatar_4 = AV64 .. "roxo_64.png",
  avatar_5 = AV64 .. "marrom_64.png",
  avatar_6 = AV64 .. "amarelo_64.png",
  avatar_7 = AV64 .. "cinza_64.png",
  avatar_8 = AV64 .. "ciano_64.png",
  -- Avatares compraveis na loja: entram na grade do perfil quando posse.
  -- Arte 64px de arte/64/especiais (os 1920 de "avatares/" ficam guardados).
  avatar_taylor = "arte/64/especiais/Frederick_Taylor_64.png",
  avatar_marx = "arte/64/especiais/Karl_Marx_64.png",
  avatar_mayo = "arte/64/especiais/Elton_Mayo_64.png",
  perfil_fundo = "arte/perfil/background.png",
  -- Botoes da NAV BAR do perfil (arte pronta: moldura + icone + rotulo ja
  -- embutidos). A versao "_sel" e a aba ativa, com a moldura verde.
  -- (Pasta sem acento: o LOVE/PhysFS nao abre caminho com "õ" no Windows.)
  btn_perfil_resumo = "arte/perfil/botoes_perfil/botao_resumo_aba_avatares.png",
  btn_perfil_resumo_sel = "arte/perfil/botoes_perfil/botao_resumo_selecionado.png",
  btn_perfil_avatares = "arte/perfil/botoes_perfil/botao_avatares.png",
  btn_perfil_avatares_sel =
    "arte/perfil/botoes_perfil/botao_avatares_selecionado.png",
  btn_perfil_emotes = "arte/perfil/botoes_perfil/botao_emotes.png",
  btn_perfil_emotes_sel = "arte/perfil/botoes_perfil/botao_emotes_selecionado.png",
  btn_perfil_cartas = "arte/perfil/botoes_perfil/botao_cartas.png",
  btn_perfil_cartas_sel = "arte/perfil/botoes_perfil/botao_cartas_selecionado.png",
  -- Tela MODO UM JOGADOR (TelaUmJogador.js)
  sel_fundo = "arte/um_jogador/background.jpg",
  sel_adam = "arte/um_jogador/adam_smith.jpg",
  sel_lock = "arte/um_jogador/perso_bloqueado.png",
  sel_voltar = "arte/um_jogador/voltar_btn.png",
  -- No do chefe no mapa do Ciclo I (retrato ate ser enfrentado).
  inimigo_bloqueado = "arte/um_jogador/inimigo_bloqueado.png",
  -- Tela OS 9 CICLOS (modo um jogador): papel de parede + artes dos
  -- ciclos (I desbloqueado, II..IX bloqueados; ~127 MB decodificadas).
  ciclos_fundo = "arte/um_jogador/fundo.png",
  -- Selecao de ciclos: placa do titulo (texto ja embutido), as ilhas (a
  -- placa com o nome do ciclo vem na arte: "CICLO I - O REINO ESQUECIDO" e
  -- "CICLO 2 - A EFICIENCIA"; o arquivo da segunda veio com "I" no nome,
  -- mas a placa pintada diz CICLO 2) e as setas de folhear.
  -- A arte do Ciclo 2 chegou em 24bpp, SEM canal alfa (fundo preto solido):
  -- "*_recortada" e a mesma arte com o fundo aberto por preenchimento a
  -- partir das bordas (luminancia <= 60, rampa de alfa 26..60), para a ilha
  -- flutuar no deserto como a do Ciclo I. Se o designer mandar a versao com
  -- transparencia, basta trocar o caminho de sel_ilha_2.
  sel_placa = "arte/um_jogador/placa_selecao_de_ciclos_cortada.png",
  sel_ilha_1 = "arte/um_jogador/ilha_ciclo_I_o_reino_esquecido.png",
  sel_ilha_2 = "arte/um_jogador/ilha_ciclo_I_efiencia_recortada.png",
  sel_seta_esq = "arte/um_jogador/seta_mudar_ciclo_esquerda.png",
  sel_seta_dir = "arte/um_jogador/seta_mudar_ciclo_direita.png",
  -- Artes das cartas do baralho padrao (regras/baralho atual.txt). A
  -- associacao e por id: cartas fora do baralho nao tem arte propria e caem
  -- na face textual do placeholder.
  -- Acao (4)
  carta_5 = "arte/cards/cartas de acao/presente_noel.png",
  carta_11 = "arte/cards/cartas de acao/emprestimo.png",
  carta_20 = "arte/cards/cartas de acao/cada_um_no_seu_quadrado.png",
  carta_23 = "arte/cards/cartas de acao/overclock_produtivo.png",
  -- Defesa (5)
  carta_8 = "arte/cards/cartas de defesa/1-removebg-preview.png",
  carta_10 = "arte/cards/cartas de defesa/2-removebg-preview.png",
  carta_12 = "arte/cards/cartas de defesa/3-removebg-preview.png",
  carta_13 = "arte/cards/cartas de defesa/4-removebg-preview.png",
  carta_22 = "arte/cards/cartas de defesa/5.png",
  -- Efeito (17)
  carta_9 = "arte/cards/cartas de efeito/1-removebg-preview.png",
  carta_2 = "arte/cards/cartas de efeito/2-removebg-preview.png",
  carta_24 = "arte/cards/cartas de efeito/4-removebg-preview.png",
  carta_29 = "arte/cards/cartas de efeito/5-removebg-preview.png",
  carta_31 = "arte/cards/cartas de efeito/6-removebg-preview.png",
  carta_32 = "arte/cards/cartas de efeito/7-removebg-preview.png",
  carta_49 = "arte/cards/cartas de efeito/8-removebg-preview.png",
  carta_25 = "arte/cards/cartas de efeito/9-removebg-preview.png",
  carta_27 = "arte/cards/cartas de efeito/10-removebg-preview.png",
  carta_4 = "arte/cards/cartas de efeito/11-removebg-preview.png",
  carta_41 = "arte/cards/cartas de efeito/12-removebg-preview.png",
  carta_39 = "arte/cards/cartas de efeito/13-removebg-preview.png",
  carta_40 = "arte/cards/cartas de efeito/14-removebg-preview.png",
  carta_42 = "arte/cards/cartas de efeito/15-removebg-preview.png",
  carta_45 = "arte/cards/cartas de efeito/16-removebg-preview.png",
  carta_44 = "arte/cards/cartas de efeito/17-removebg-preview.png",
  carta_35 = "arte/cards/cartas de efeito/18-removebg-preview.png",
  -- Curinga (6)
  carta_18 = "arte/cards/curinga/1-removebg-preview.png",
  carta_19 = "arte/cards/curinga/2-removebg-preview.png",
  carta_6 = "arte/cards/curinga/3-removebg-preview.png",
  carta_26 = "arte/cards/curinga/4-removebg-preview.png",
  carta_51 = "arte/cards/curinga/5-removebg-preview.png",
  carta_50 = "arte/cards/curinga/6-removebg-preview.png",
}

local FONTE = "fonts/VCR_OSD_MONO_1.001.ttf"

-- Logo mostrada na tela "logo" (depois da intro de caminhada).
IMAGENS.intro_logo = "arte/menu/tormentalia.png"
-- Logo da Gears Studio (equipe que esta fazendo o jogo): entra na propria
-- intro, entre o simbolo da paz e a logo do Tormentalia.
IMAGENS.intro_gears = "arte/logoTela/gears_studio.jpeg"
for i = 1, 8 do
  IMAGENS["intro_and_" .. i] = "arte/logoTela/andando/" .. i .. ".png"
  IMAGENS["intro_sim_" .. i] = "arte/logoTela/simbolo/" .. i .. ".png"
end

-- Artes dos 9 ciclos, na ordem da grade: so o ciclo I vem desbloqueado
-- (ciclos_desbloqueados); II..IX usam a versao bloqueada (P&B com cadeado).
IMAGENS.ciclo_1 = "arte/um_jogador/ciclos_desbloqueados/"
  .. "ciclo_I_abismo_mao_invisivel_revisado.png"
-- Arenas dos ciclos (fundo da mesa no duelo do Ciclo I e na partida em
-- rede): PNGs grandes (~5-7 MB no disco, ~15 MB decodificados cada).
-- Fora do IMAGENS de proposito: o carregar() eager decodificaria as 9 de
-- uma vez (~135 MB) e estouraria a RAM do celular. Carregadas sob demanda
-- por A.arena(n), mantendo so UMA viva (trocar descarrega a anterior).
local ARENAS_CICLOS = {
  "arena_ciclo_I_abismo_mao_invisivel_topdown.png",
  "arena_ciclo_II_forja_eficiencia_eterna_topdown.png",
  "arena_ciclo_III_fortaleza_mil_hierarquias_topdown.png",
  "arena_ciclo_IV_labirinto_protocolo_eterno_topdown.png",
  "arena_ciclo_V_jardim_sorrisos_mortos_topdown.png",
  "arena_ciclo_VI_torre_necessidades_infinitas_topdown.png",
  "arena_ciclo_VII_organismo_nunca_morre_topdown.png",
  "arena_ciclo_VIII_reino_caos_infinito_topdown.png",
  "arena_ciclo_IX_trono_deus_mercado_topdown.png",
}
local ARENA_ROMANOS = {
  "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
}
local CICLOS_BLOQUEADOS = {
  "ciclo_II_forja_eficiencia_eterna",
  "ciclo_III_fortaleza_mil_hierarquias",
  "ciclo_IV_labirinto_protocolo_eterno",
  "ciclo_V_jardim_sorrisos_mortos",
  "ciclo_VI_torre_necessidades_infinitas",
  "ciclo_VII_organismo_nunca_morre",
  "ciclo_VIII_reino_caos_infinito",
  "ciclo_IX_trono_deus_mercado",
}
for i, base in ipairs(CICLOS_BLOQUEADOS) do
  IMAGENS["ciclo_" .. (i + 1)] = "arte/um_jogador/ciclos_bloqueados/"
    .. base .. "_bloqueado.png"
end

-- Inimigos do Ciclo I: 6 avatares simples + Adam Smith como chefe. A arte
-- agora vem em 64x64 de arte/64/ciclo1 (os 1920 originais de "1 ciclo"
-- ficam guardados, sem uso no jogo). "inimigo_1..7" alimenta o mapa, a
-- intro e o painel da mesa.
local DIR64_CICLO1 = "arte/64/ciclo1/"
local INIMIGOS_CICLO1 = {
  "avatar_funcionario_condenado_simples",
  "avatar_criatura_papeis_simples",
  "avatar_trabalhador_sem_rosto_simples",
  "avatar_fiscal_simples",
  "avatar_consumidor_desesperado_simples",
  "avatar_subordinado_corrompido_simples",
  "Adam_Smith",
}
for i, base in ipairs(INIMIGOS_CICLO1) do
  IMAGENS["avatar_inimigo_" .. i] = DIR64_CICLO1 .. base .. "_64.png"
end

-- Inimigos do Ciclo 2: 5 capatazes + Frederick Taylor como soberano, em
-- 64x64 de arte/64/ciclo2. Os cinco primeiros vieram em 24bpp (fundo preto
-- solido) e o Taylor em 32bpp opaco: no jogo eles entram recortados no disco
-- da roda (stencil) e emoldurados na VS, entao o fundo preto nao aparece.
local DIR64_CICLO2 = "arte/64/ciclo2/"
local INIMIGOS_CICLO2 = {
  "avatar_ciclo2_operario_desgastado",
  "avatar_ciclo2_fiscal_produtividade",
  "avatar_ciclo2_esteira_faminta",
  "avatar_ciclo2_relogio_fiscal",
  "avatar_ciclo2_capataz_meta",
  "Frederick_Taylor",
}
for i, base in ipairs(INIMIGOS_CICLO2) do
  IMAGENS["avatar_inimigo2_" .. i] = DIR64_CICLO2 .. base .. "_64.png"
end

local imagens = {}
local fontes = {}
local temFonte = false

local function carregarImagem(chave, caminho)
  local ok, img = pcall(love.graphics.newImage, caminho)
  if ok and img then
    -- Avatares (jogador, especiais e inimigos dos ciclos), as poses da VS e
    -- os quadros do Adam na conversa vem das artes 64: nearest mantem o
    -- pixel duro quando o jogo amplia (grade do perfil, roda, mesa, VS,
    -- dialogo). O resto segue suave.
    if chave:match("^avatar_") or chave:match("^vs_")
        or chave:match("^adam_dlg_") then
      img:setFilter("nearest", "nearest")
    else
      img:setFilter("linear", "linear")
    end
    imagens[chave] = img
    return true
  end
  print("[arte] imagem ignorada: " .. caminho .. " (" .. tostring(img) .. ")")
  return false
end

function A.carregar()
  for chave, caminho in pairs(IMAGENS) do
    carregarImagem(chave, caminho)
  end
  temFonte = love.filesystem.getInfo(FONTE) ~= nil
  if not temFonte then
    print("[arte] fonte VCR nao encontrada, usando fonte padrao")
  end
end

function A.img(chave)
  return imagens[chave]
end

-- Barras de Satisfacao/Produtividade: arte pixel-art 640x1280, com um quadro
-- para cada faixa de 10% (0, 10, ... 100). Ficam fora do IMAGENS de proposito:
-- sao grandes (~3,3 MB decodificados cada) e o jogo mostra no maximo um quadro
-- de cada tipo por vez. Carregamos sob demanda e mantemos so 4 vivos por tipo
-- (o suficiente para a animacao passar pelos quadros vizinhos).
local BARRA_DIR = {
  sat = "arte/barra_sastifacao/",
  prod = "arte/barra_produtividade/",
}
local barraCache = { sat = {}, prod = {} }
local barraOrdem = { sat = {}, prod = {} }
local BARRA_MAX = 4

-- A.barra("sat"|"prod", 0..100) -> Image do quadro mais proximo (passo 10).
function A.barra(tipo, pct)
  local dir = BARRA_DIR[tipo]
  if not dir then return nil end
  local faixa = math.floor((tonumber(pct) or 0) / 10 + 0.5) * 10
  if faixa < 0 then faixa = 0 elseif faixa > 100 then faixa = 100 end

  local cache, ordem = barraCache[tipo], barraOrdem[tipo]
  if cache[faixa] then return cache[faixa] end

  local ok, img = pcall(love.graphics.newImage, dir .. faixa .. ".png",
    { mipmaps = true })
  if not ok or not img then return nil end
  -- A arte e reduzida para ~21x58 na tela: mipmap + filtro linear evitam o
  -- serrilhado do nearest num downscale tao grande.
  img:setFilter("linear", "linear")
  pcall(function() img:setMipmapFilter("linear") end)

  cache[faixa] = img
  ordem[#ordem + 1] = faixa
  while #ordem > BARRA_MAX do
    local velho = table.remove(ordem, 1)
    local antiga = cache[velho]
    if antiga then
      pcall(function() antiga:release() end)
      cache[velho] = nil
    end
  end
  return img
end

local function soltarImagem(chave)
  local img = imagens[chave]
  if not img then return end
  pcall(function() img:release() end)
  imagens[chave] = nil
end

-- Quantidade de arenas dos ciclos (1..9) para o ciclo do host na sala.
function A.totalArenas()
  return #ARENAS_CICLOS
end

-- Nome curto da arena para a sala: sem escolha = madeira padrao.
function A.nomeArena(n)
  n = tonumber(n)
  if not n or n < 1 or n > #ARENAS_CICLOS then return "MADEIRA" end
  return "CICLO " .. (ARENA_ROMANOS[n] or tostring(n))
end

-- Arena do ciclo `n` (1..9) carregada sob demanda; nil/0/fora de faixa =
-- nil (o chamador cai na madeira padrao). Mantem so UMA arena viva: cada
-- PNG decificado ocupa ~15 MB, peso que o celular nao aguenta em dobro.
function A.arena(n)
  n = tonumber(n)
  if not n or n < 1 or n > #ARENAS_CICLOS then return nil end
  local chave = "arena_ciclo_" .. n
  if not imagens[chave] then
    local soltar = {}
    for k in pairs(imagens) do
      if tostring(k):match("^arena_ciclo_%d+$") and k ~= chave then
        soltar[#soltar + 1] = k
      end
    end
    for _, k in ipairs(soltar) do soltarImagem(k) end
    carregarImagem(chave,
      "arte/um_jogador/arenas_ciclos/" .. ARENAS_CICLOS[n])
  end
  return imagens[chave]
end

-- Quadros da animacao do ADAM na conversa com o chefe do Ciclo I. Arte
-- 64x64 de arte/64/dialogo (os 1920 de "Adam Smith/" ficam guardados): a
-- cena e transitoria mas com 64 px nao ha mais o pico de ~105 MB que os
-- quadros grandes seguravam. O cenario da cena continua em 2560 (e fundo,
-- nao sprite). Sem corte por quadro de proposito: recortar cada um pela
-- caixa do conteudo faria a cara pular entre os quadros da animacao.
local ADAM_DIALOGO = {
  neutro = "adam_smith_07",
  bocaLeve = "adam_smith_02",
  bocaAberta = "adam_smith_03",
  bocaMedia = "adam_smith_04",
  piscando = "adam_smith_05",
  retorno = "adam_smith_06",
}
local ADAM_DIALOGO_DIR = "arte/64/dialogo/"
-- Cenario proprio da conversa (2560x1440): mesmo tempo de vida dos
-- quadros do Adam - carrega com a cena e sai no fim dela.
local CENARIO_DLG = "arte/um_jogador/1 ciclo/cenario_dialogo.png"

function A.carregarAdamDialogo()
  for nome, arquivo in pairs(ADAM_DIALOGO) do
    local chave = "adam_dlg_" .. nome
    if not imagens[chave] then
      carregarImagem(chave, ADAM_DIALOGO_DIR .. arquivo .. "_64.png")
    end
  end
  if not imagens.cenario_dlg then
    carregarImagem("cenario_dlg", CENARIO_DLG)
  end
end

function A.adamDialogo(nome)
  return imagens["adam_dlg_" .. tostring(nome)]
end

function A.cenarioDialogo()
  return imagens.cenario_dlg
end

function A.liberarAdamDialogo()
  for nome in pairs(ADAM_DIALOGO) do
    soltarImagem("adam_dlg_" .. nome)
  end
  soltarImagem("cenario_dlg")
end

-- Emojis de SPRITE (animacao PNG -> canvas): cada emoji tem uma pasta em
-- arte/64/emojis/<id>/ com quadros 64x64. Trocados pela arte 64: o canvas
-- de 256 e um upscale inteiro de 4x, entao o pixel fica duro se a imagem e
-- o canvas carregarem com nearest (feito na carga, abaixo). A pasta antiga
-- arte/emojis/<id>/ (quadros 1920) fica guardada, sem uso no jogo.
local EMOJI_SPRITES = {
  karl_marx = {
    dir = "arte/64/emojis/karl_marx/",
    quadros = {
      "frame_01_neutral.png",
      "frame_02_reach.png",
      "frame_03_lowering.png",
      "frame_04_glasses_down.png",
      "frame_05_wink.png",
      "frame_06_wink_release.png",
      "frame_07_raising.png",
      "frame_08_return.png",
    },
  },
  adam_smith = {
    dir = "arte/64/emojis/adam_smith/",
    quadros = {
      "frame_01_neutral_sem_texto.png",
      "frame_02_hand_rising_sem_texto.png",
      "frame_03_hand_to_forehead_sem_texto.png",
      "frame_04_facepalm_sem_texto.png",
      "frame_05_hold_facepalm_sem_texto.png",
      "frame_06_hand_sliding_sem_texto.png",
      "frame_07_hand_lowering_sem_texto.png",
      "frame_08_return_sem_texto.png",
    },
  },
}
local EMOJI_SPRITE_TAM = 256
-- Duracao TOTAL da animacao (todos os quadros) em segundos: 1,5s, igual
-- para todos os sprites. Tanto o balao da partida quanto o preview da loja
-- derivam o passo daqui (quadro = floor(t / dur * total)).
local EMOJI_SPRITE_DUR = 1.5
local emojiQuadros = {}  -- id -> { canvas ... }

function A.emojiSpriteTotal(id)
  local def = EMOJI_SPRITES[id]
  return def and #def.quadros or 0
end

function A.emojiSpriteDur()
  return EMOJI_SPRITE_DUR
end

-- Carrega os quadros de um id uma vez; devolve false se a arte faltar
-- (pcall isola caminho quebrado/ausente sem derrubar a partida).
function A.carregarEmojiSprite(id)
  if emojiQuadros[id] then return true end
  local def = EMOJI_SPRITES[id]
  if not def then return false end
  local quads = {}
  for i, arquivo in ipairs(def.quadros) do
    local ok, img = pcall(love.graphics.newImage, def.dir .. arquivo)
    if not ok or not img then
      for _, q in ipairs(quads) do pcall(function() q:release() end) end
      return false
    end
    local cv = love.graphics.newCanvas(EMOJI_SPRITE_TAM, EMOJI_SPRITE_TAM)
    -- Arte 64 -> canvas 256: nearest nos dois lados para o quadro virar
    -- 4x4 blocos duros (com linear o upscale borraria o pixel).
    img:setFilter("nearest", "nearest")
    cv:setFilter("nearest", "nearest")
    -- Cover centrado (sprites quadrados); identity pra nao herdar a
    -- escala/letterbox ativa da tela.
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, 0, 0, 0,
      EMOJI_SPRITE_TAM / img:getWidth(), EMOJI_SPRITE_TAM / img:getHeight())
    love.graphics.setCanvas()
    love.graphics.pop()
    pcall(function() img:release() end)
    quads[i] = cv
  end
  emojiQuadros[id] = quads
  return true
end

-- Quadro de um emoji-sprite (carrega sob demanda; nil se a arte faltar).
function A.emojiSprite(id, n)
  if not emojiQuadros[id] then A.carregarEmojiSprite(id) end
  local quads = emojiQuadros[id]
  if not quads then return nil end
  return quads[math.max(1, math.min(#quads, n or 1))]
end

-- Sprites da tela de VS antes de cada duelo: pose de cintura de cada
-- inimigo do Ciclo I + a pose do jogador de gravata cinza. Arte 64 px de
-- arte/64/vs (os 1920 de "1 ciclo" ficam guardados): cortada na caixa do
-- conteudo, porque os originais tem ~42% de vazio embaixo. Por isso a
-- fracao de corte em vs.lua virou 1.0. Mesmo criterio do dialogo: carrega
-- tudo na abertura da cena e descarta no fim (e transitoria). O fundo da
-- cena e o perfil_fundo eager, entao nao vem para ca.
local VS_SPRITES = {
  vs_jogador_cinza = "arte/64/especiais/cinza_desafiando_64.png",
  vs_inimigo_1 = "arte/64/vs/sprite_vs_funcionario_condenado_cintura_64.png",
  vs_inimigo_2 = "arte/64/vs/sprite_vs_criatura_papeis_cintura_64.png",
  vs_inimigo_3 = "arte/64/vs/sprite_vs_trabalhador_sem_rosto_cintura_64.png",
  vs_inimigo_4 = "arte/64/vs/sprite_vs_fiscal_cintura_64.png",
  vs_inimigo_5 = "arte/64/vs/sprite_vs_consumidor_desesperado_cintura_64.png",
  vs_inimigo_6 = "arte/64/vs/sprite_vs_subordinado_corrompido_cintura_64.png",
  vs_inimigo_7 = "arte/64/vs/sprite_vs_adam_smith_cintura_esquerda_64.png",
}

function A.carregarVS()
  for chave, caminho in pairs(VS_SPRITES) do
    if not imagens[chave] then
      carregarImagem(chave, caminho)
    end
  end
end

function A.vs(chave)
  return imagens[chave]
end

function A.liberarVS()
  for chave in pairs(VS_SPRITES) do
    soltarImagem(chave)
  end
end

function A.verso()
  return imagens.verso
end

function A.arte(carta)
  if not carta then return nil end
  -- Cartas sem arte propria usam o placeholder (igual ao React).
  return imagens["carta_" .. tostring(carta.id)] or imagens.arte_faltando
end

function A.temArte(carta)
  if not carta then return false end
  return imagens["carta_" .. tostring(carta.id)] ~= nil
end

-- Avatar escolhido na tela de perfil (id 1..8, igual a getAvatarById do RN).
local avatarPerfilId = "1"

function A.definirAvatar(id)
  id = tostring(id)
  if imagens["avatar_" .. id] then avatarPerfilId = id end
end

-- quem: "ia" (Adam Smith), id de avatar "1".."8" (ARENA N jogadores) ou
-- qualquer outra coisa = avatar do perfil ("voce").
function A.avatar(quem)
  if quem == "ia" then return imagens.avatar_ia end
  if quem and quem ~= "voce" and imagens["avatar_" .. tostring(quem)] then
    return imagens["avatar_" .. tostring(quem)]
  end
  return imagens["avatar_" .. avatarPerfilId] or imagens.avatar_voce
end

function A.fonte(tamanho)
  local f = fontes[tamanho]
  if f then return f end
  if temFonte then
    local ok, nova = pcall(love.graphics.newFont, FONTE, tamanho)
    if ok and nova then
      fontes[tamanho] = nova
      return nova
    end
    temFonte = false
  end
  local padrao = love.graphics.newFont(tamanho)
  fontes[tamanho] = padrao
  return padrao
end

return A
