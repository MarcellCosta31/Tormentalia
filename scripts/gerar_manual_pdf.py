"""Gera impor/Manual_Tormentalia.pdf em A4, no estilo dark fantasy do jogo."""
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

R = Path(__file__).resolve().parent.parent
OUT = R / 'impor' / 'Manual_Tormentalia.pdf'
W, H = 1240, 1754          # A4 a 150 DPI

FONTE_PIXEL = R / 'fonts' / 'VCR_OSD_MONO_1.001.ttf'
FONTE_TEXTO = Path('C:/Windows/Fonts/arial.ttf')
FONTE_TEXTO_B = Path('C:/Windows/Fonts/arialbd.ttf')


def fonte(caminho, tamanho):
    try:
        return ImageFont.truetype(str(caminho), tamanho)
    except OSError:
        return ImageFont.load_default()


PX = lambda n: fonte(FONTE_PIXEL, n)
TX = lambda n: fonte(FONTE_TEXTO, n)
Txb = lambda n: fonte(FONTE_TEXTO_B, n)

FUNDO = (9, 7, 18)
PAINEL = (18, 16, 38)
DOURADO = (246, 196, 83)
ROSA = (255, 95, 210)
ROXO = (139, 92, 246)
CIANO = (69, 214, 255)
TEXTO = (214, 218, 236)
SUAVE = (150, 156, 185)

PAGINAS = []


def nova_pagina():
    img = Image.new('RGB', (W, H), FUNDO)
    d = ImageDraw.Draw(img)
    for y in range(H):
        k = max(0, 1 - y / (H * 0.6))
        d.line((0, y, W, y), fill=(int(9 + 16 * k), int(7 + 6 * k), int(18 + 30 * k)))
    for x in range(-H, W + H, 100):
        d.line((x, H, x + H, 0), fill=(20, 15, 38), width=1)
    PAGINAS.append(img)
    return img, d


def cabecalho(d, numero, titulo, subtitulo=None):
    d.rounded_rectangle((60, 50, W - 60, 158), radius=10,
                        fill=(14, 11, 28), outline=DOURADO, width=2)
    d.text((84, 66), titulo, font=PX(29), fill=DOURADO)
    if subtitulo:
        d.text((86, 116), subtitulo, font=TX(17), fill=SUAVE)
    d.text((W - 130, 72), f'{numero:02d}', font=PX(25), fill=ROSA)
    d.line((80, 178, W - 80, 178), fill=(90, 66, 40), width=2)


def rodape(d, numero):
    d.line((80, H - 98, W - 80, H - 98), fill=(90, 66, 40), width=2)
    d.text((80, H - 80), 'TORMENTALIA / MANUAL DE COMO JOGAR / VERSAO 1.0 BETA',
           font=PX(11), fill=SUAVE)
    d.text((W - 110, H - 80), str(numero), font=PX(14), fill=DOURADO)


def quebrar(texto, font, largura, d):
    linhas, atual = [], ''
    for palavra in texto.split():
        candidata = (atual + ' ' + palavra).strip()
        if d.textlength(candidata, font=font) <= largura or not atual:
            atual = candidata
        else:
            linhas.append(atual)
            atual = palavra
    if atual:
        linhas.append(atual)
    return linhas


def texto(d, conteudo, x, y, largura, tamanho=19, cor=TEXTO, negrito=False, espaco=1.28):
    f = Txb(tamanho) if negrito else TX(tamanho)
    alt = int(tamanho * espaco)
    for linha in quebrar(conteudo, f, largura, d):
        d.text((x, y), linha, font=f, fill=cor)
        y += alt
    return y


def titulo_secao(d, titulo_, y, cor=ROSA):
    d.text((82, y), titulo_, font=PX(21), fill=cor)
    largura = min(560, d.textlength(titulo_, font=PX(21)))
    d.line((82, y + 34, 82 + largura, y + 34), fill=cor, width=2)
    return y + 54


def painel(d, x, y, w, titulo_, corpo, cor=DOURADO, tamanho=17):
    """Painel com altura automatica: nunca corta texto nem cobre o seguinte."""
    linhas = quebrar(corpo, TX(tamanho), w - 44, d)
    h = 44 + len(linhas) * int(tamanho * 1.28) + 24
    d.rounded_rectangle((x, y, x + w, y + h), radius=12, fill=PAINEL, outline=cor, width=2)
    d.text((x + 22, y + 16), titulo_, font=PX(15), fill=cor)
    yy = y + 46
    for linha in linhas:
        d.text((x + 22, yy), linha, font=TX(tamanho), fill=TEXTO)
        yy += int(tamanho * 1.28)
    return y + h + 20


def arte(caminho, caixa, capa=False):
    img = Image.open(R / caminho).convert('RGBA')
    x0, y0, x1, y1 = caixa
    bw, bh = x1 - x0, y1 - y0
    escala = max(bw / img.width, bh / img.height) if capa else min(bw / img.width, bh / img.height)
    img = img.resize((max(1, int(img.width * escala)), max(1, int(img.height * escala))), Image.LANCZOS)
    return img, (x0 + (bw - img.width) // 2, y0 + (bh - img.height) // 2)


def colar(pagina, img, pos):
    pagina.paste(img, pos, img)


def legenda(d, x, y, largura, texto_):
    return texto(d, texto_, x, y, largura, 15, SUAVE)


# --------------------------------------------------------------- 1 CAPA
img, d = nova_pagina()
logo, pos = arte('arte/deus_mercado/LOGO-TORMENTALIA.png', (170, 110, 1070, 620))
colar(img, logo, pos)
d.text((W // 2, 700), 'TORMENTALIA', font=PX(52), fill=DOURADO, anchor='mm')
d.text((W // 2, 760), 'MANUAL DE COMO JOGAR', font=PX(23), fill=ROSA, anchor='mm')
d.line((250, 820, W - 250, 820), fill=DOURADO, width=3)
texto(d, 'Um card game de estrategia, blefe e sobrevivencia para 2 a 8 jogadores.',
      200, 880, W - 400, 21)
texto(d, 'Aprenda as regras, as cartas e os rituais do Deus Mercado.',
      200, 940, W - 400, 21)
mao, pos = arte('arte/deus_mercado/escolha_curinga.png', (450, 1030, 790, 1370))
colar(img, mao, pos)
d.text((W // 2, 1480), 'VERSAO 1.0 / JOGANDO EM BETA', font=PX(18), fill=CIANO, anchor='mm')
rodape(d, 1)

# --------------------------------------------------------------- 2 OBJETIVO / TURNO
img, d = nova_pagina()
cabecalho(d, 2, '1. O OBJETIVO', 'Vence quem sai com mais dinheiro')
y = titulo_secao(d, 'A MESA', 200)
y = texto(d, 'Cada jogador e uma empresa com saldo em reais. Comeca com R$ 2.000 e 7 cartas. '
             'Jogue cartas para ganhar dinheiro, derrubar os oponentes ou interferir nas maos alheias.',
          82, y, W - 164, 19)
y = painel(d, 80, y + 12, W - 160, 'COMO VENCER',
           'Eliminacao: todos os rivais falem (R$ 0). Tempo: maior saldo apos 10 turnos. '
           'Saldos iguais no topo = empate.', DOURADO)
y = painel(d, 80, y, W - 160, 'FALENCIA',
           'Ao chegar a R$ 0 o jogador e eliminado na hora. O saldo nunca fica negativo.', ROSA)
y = titulo_secao(d, '2. O TURNO', y + 10)
y = painel(d, 80, y, W - 160, 'QUOTA E TEMPO',
           'Jogue ate 2 cartas por turno. Cartas da Area Segura nao gastam quota. '
           'Passe quando quiser. Tempo base: 25 segundos.', CIANO)
y = painel(d, 80, y, W - 160, 'CADEIA (CHAIN)',
           'Cartas da mesma classe em sequencia dao ate 2 jogadas extras (4 cartas no turno). '
           'A cadeia zera no inicio do seu turno.', DOURADO)
# Captura em area propria, sem sobrepor textos
if y < 1230:
    cap, pos = arte('impor/mesa_manual.png', (100, y + 10, W - 100, min(y + 400, 1600)))
    colar(img, cap, pos)
    legenda(d, 100, min(y + 410, 1610), W - 200, 'A mesa emacao: saldos, barras e slots secretos.')
rodape(d, 2)

# --------------------------------------------------------------- 3 CARTAS
img, d = nova_pagina()
cabecalho(d, 3, '3. AS CARTAS', '32 cartas / quatro classes')
classes = [
    ('ACAO', 'arte/cards/cartas de acao/overclock_produtivo.png',
     'Dinheiro e ataques diretos. 4 cartas.', DOURADO),
    ('EFEITO', 'arte/cards/cartas de efeito/2-removebg-preview.png',
     'Maos, chances e turnos. 17 cartas.', ROSA),
    ('DEFESA', 'arte/cards/cartas de defesa/1-removebg-preview.png',
     'Protecao no slot. 5 cartas.', CIANO),
    ('CURINGA', 'arte/cards/curinga/5-removebg-preview.png',
     'Efeitos globais. 6 cartas.', ROXO),
]
y = 210
for i, (nome, caminho, desc, cor) in enumerate(classes):
    x = 80 + (i % 2) * 570
    yy = y + (i // 2) * 660
    d.rounded_rectangle((x, yy, x + 530, yy + 610), radius=14, fill=PAINEL, outline=cor, width=2)
    d.text((x + 22, yy + 18), nome, font=PX(22), fill=cor)
    arte_img, pos = arte(caminho, (x + 150, yy + 60, x + 380, yy + 500))
    colar(img, arte_img, pos)
    legenda(d, x + 30, yy + 520, 470, desc)
rodape(d, 3)

# --------------------------------------------------------------- 4 CHANCE / COMBOS
img, d = nova_pagina()
cabecalho(d, 4, '4. SUCESSO E COMBOS', 'Cada carta tem sua chance')
y = titulo_secao(d, 'CHANCE DE SUCESSO', 200)
y = texto(d, 'Cada carta tem chance propria (55% a 100%). Se falhar, o efeito especial nao aplica, '
             'mas o dinheiro de falha e cobrado. A partir da segunda carta com o mesmo id no turno, '
             'a chance e multiplicada por 1,3 (Carta Dobrada).', 82, y, W - 164, 19)
y = titulo_secao(d, 'COMBINACOES DE MERCADO', y + 30)
y = legenda(d, 82, y, W - 164, 'Verificadas no fim da rodada, depois da renda.')
combos = [
    ('5S COMPLETO', 'Seiri, Seiton, Seiso, Seiketsu, Shitsuke', '+R$ 300'),
    ('TRIADE FINANCEIRA', 'Emprestimo, Nosso, Cris e Greg Agiotas', '+R$ 250'),
    ('MARKETING E PRODUCAO', 'Toyotinho, Presente do Noel, Queima de Estoque', '+R$ 200'),
    ('CONTROLE E DEFESA', 'Psicologia Industrial, Mao Visivel, Tempos e Movimentos', '+R$ 150'),
]
y += 20
for nome, cartas, premio in combos:
    h = 132
    d.rounded_rectangle((80, y, W - 80, y + h), radius=10, fill=PAINEL, outline=(80, 66, 110), width=2)
    d.text((102, y + 14), nome, font=PX(17), fill=DOURADO)
    legenda(d, 102, y + 56, 620, cartas)
    d.text((W - 310, y + 22), premio, font=PX(22), fill=ROSA)
    y += h + 16
rodape(d, 4)

# --------------------------------------------------------------- 5 AREA / DEFESA
img, d = nova_pagina()
cabecalho(d, 5, '5. AREA E DEFESA', 'Os dois espacos que decidem')
y = titulo_secao(d, 'AREA SEGURA / 1 SLOT', 200)
y = painel(d, 80, y, W - 160, 'GUARDAR',
           'Guardar nao gasta quota. Cabe uma carta; um novo guarda substitui a anterior.', DOURADO)
y = painel(d, 80, y, W - 160, 'REACAO',
           'Uma carta guardada pode ser jogada fora do seu turno; o adversario so ve o verso.', ROSA)
y = titulo_secao(d, 'SLOT DE DEFESA', y + 10)
y = painel(d, 80, y, W - 160, 'UMA SO PROTECAO',
           'Slot unico: uma nova defesa substitui a anterior. Dura 2 turnos e e consumida ao bloquear. '
           'O adversario nunca ve a face.', CIANO)
defimg, pos = arte('arte/cards/cartas de defesa/2-removebg-preview.png', (430, y + 10, 810, y + 360))
colar(img, defimg, pos)
legenda(d, 390, y + 370, 460, 'Carta de defesa / so o dono ve a face')
rodape(d, 5)

# --------------------------------------------------------------- 6 SAT / PROD
img, d = nova_pagina()
cabecalho(d, 6, '6. OS DOIS MEDIDORES', 'Satisfacao e produtividade')
y = titulo_secao(d, 'SATISFACAO (0 A 200)', 200)
y = painel(d, 80, y, W - 160, '0 = GREVE',
           'A barra comeca em 100. Em 0, a empresa entra em greve e perde o proximo turno. '
           'Ao sair, volta a 100.', ROSA)
y = painel(d, 80, y, W - 160, '200 = EFEITOS DOBRADOS',
           'As proximas 2 cartas tem efeito de sucesso dobrado. A penalidade de falha continua normal.', DOURADO)
y = titulo_secao(d, 'PRODUTIVIDADE', y + 10)
y = painel(d, 80, y, W - 160, 'RENDA DE RODADA',
           '(R$ 1.000 + (rodada - 1) x R$ 100) x (1 + produtividade), no fim da rodada. '
           'Acumulativa, sem teto, piso em -100%.', CIANO)
# Artes reais das barras do HUD (mesmas sprites usadas no jogo)
by = min(y + 30, 900)
d.text((390, by), 'SATISFACAO', font=PX(16), fill=ROSA, anchor='mm')
d.text((1050, by), 'PRODUTIVIDADE', font=PX(16), fill=CIANO, anchor='mm')
sat_img, sat_pos = arte('arte/barra_sastifacao/100.png', (220, by + 40, 560, by + 700))
colar(img, sat_img, sat_pos)
prod_img, prod_pos = arte('arte/barra_produtividade/50.png', (880, by + 40, 1220, by + 700))
colar(img, prod_img, prod_pos)
legenda(d, 210, by + 710, 360, 'Barra cheia: efeitos dobrados')
legenda(d, 870, by + 710, 360, 'Meio da barra: produtividade 0%')
rodape(d, 6)

# --------------------------------------------------------------- 7 EVENTO
img, d = nova_pagina()
cabecalho(d, 7, '7. O DEUS MERCADO', 'Rodadas pares: 2, 4, 6 e 8')
y = titulo_secao(d, 'QUATRO PASSOS', 200)
passos = [
    ('1. LEILAO', 'Um produto, um lance por jogador em passos de R$ 100. 15 segundos.'),
    ('2. LOJINHA', 'Ate 3 cartas por R$ 100 a R$ 400. 15 segundos.'),
    ('3. FUSAO', 'De 2 a 5 cartas viram uma Super Carta sorteada.'),
    ('4. FECHAR', 'Fim do evento. Nunca ha evento apos a rodada 10.'),
]
for titulo_, corpo in passos:
    y = painel(d, 80, y, W - 160, titulo_, corpo, DOURADO)
mao, pos = arte('arte/deus_mercado/escolha_curinga.png', (440, y + 10, 800, y + 330))
colar(img, mao, pos)
legenda(d, 300, y + 340, 640, 'Antes do leilao, um Curinga Global vale para todos.')
rodape(d, 7)

# --------------------------------------------------------------- 8 AVATARES
img, d = nova_pagina()
cabecalho(d, 8, '8. AVATARES', 'Escolha seu teórico')
avatares = [
    ('FREDERICK TAYLOR', 'arte/64/especiais/Frederick_Taylor_64.png',
     '+10% de chance em cartas de Acao e Efeito.', DOURADO),
    ('KARL MARX', 'arte/64/especiais/Karl_Marx_64.png',
     'No seu turno, o mais rico doa R$ 100 ao mais pobre.', ROSA),
    ('ELTON MAYO', 'arte/64/especiais/Elton_Mayo_64.png',
     '30% de neutralizar carta negativa, 1x por rodada.', CIANO),
]
y = 200
for nome, caminho, desc, cor in avatares:
    h = 400
    d.rounded_rectangle((80, y, W - 80, y + h), radius=14, fill=PAINEL, outline=cor, width=2)
    retrato, pos = arte(caminho, (110, y + 24, 330, y + 244))
    colar(img, retrato, pos)
    d.text((380, y + 50), nome, font=PX(24), fill=cor)
    legenda(d, 380, y + 120, 720, desc)
    d.text((380, y + 300), '100 MOEDAS', font=PX(15), fill=DOURADO)
    y += h + 22
legenda(d, 82, y + 10, W - 164, 'Cada vitoria concede +10 moedas.')
rodape(d, 8)

# --------------------------------------------------------------- 9 MULTIPLAYER
img, d = nova_pagina()
cabecalho(d, 9, '9. MULTIPLAYER', 'A mesa e sempre compartilhada')
y = titulo_secao(d, 'ARENA', 200)
y = painel(d, 80, y, W - 160, '2 A 8 JOGADORES',
           'Duelo (2), Batalha (3-4), Guerra (5-6), Caos Total (7-8). Mesmas regras para todos.', DOURADO)
y = painel(d, 80, y, W - 160, 'PERSONALIDADES DE IA',
           'Agressiva, defensiva, oportunista ou caotica. Vagas vazias podem ser bots.', ROSA)
y = titulo_secao(d, 'PARTIDA EM REDE', y + 10)
y = painel(d, 80, y, W - 160, 'HOST E CONVIDADOS',
           'O host cria a sala com IP/porta e roda o motor. Os outros conectam na mesma rede. '
           'Tempo real e quem desconecta sai da rotacao.', CIANO)
y = titulo_secao(d, 'TUTORIAL', y + 10)
y = painel(d, 80, y, W - 160, 'PRIMEIRO ACESSO',
           'A mao do Deus Mercado ensina cartas, Area Segura, Defesa, SAT e PROD, '
           'e acompanha um duelo ate a vitoria.', DOURADO)
rodape(d, 9)

# --------------------------------------------------------------- 10 DICAS
img, d = nova_pagina()
cabecalho(d, 10, '10. DICAS E GLOSSARIO', 'Do primeiro turno a ultima rodada')
y = 200
dicas = [
    'Jogue cartas da mesma classe em sequencia para ganhar cadeia.',
    'Guardar na Area Segura e gratis e permite reagir fora do turno.',
    'Uma defesa bloqueia um ataque e some.',
    'Satisfacao em 0 custa um turno; em 200 dobra efeitos.',
    'Produtividade multiplica a renda: some cedo.',
    'Rodadas pares mudam a mesa inteira.',
]
for dica in dicas:
    d.ellipse((86, y + 8, 106, y + 28), fill=DOURADO)
    y = texto(d, dica, 130, y, W - 220, 19)
    y += 26
y += 20
y = titulo_secao(d, 'GLOSSARIO', y)
termos = [
    ('QUOTA', 'Cartas possiveis no turno (2 + cadeia).'),
    ('CADEIA', 'Sequencia da mesma classe com jogadas extras.'),
    ('DORSO', 'O que o oponente ve na Area e Defesa.'),
    ('CARTA DOBRADA', 'Mesmo id no turno: chance x1,3.'),
    ('GREVE', 'SAT 0: perde o proximo turno.'),
    ('SUPER CARTA', 'Carta da fusao de 2 a 5 cartas.'),
    ('FALENCIA', 'Saldo R$ 0: eliminacao.'),
]
for nome, def_ in termos:
    d.text((86, y), nome, font=PX(14), fill=ROSA)
    legenda(d, 380, y, 760, def_)
    y += 52
rodape(d, 10)

# --------------------------------------------------------------- 11 GALERIA CARTAS
img, d = nova_pagina()
cabecalho(d, 11, '11. GALERIA DE CARTAS', 'Arte do baralho')
galeria = [
    ('arte/cards/cartas de acao/presente_noel.png', 'PRESENTE DO NOEL'),
    ('arte/cards/cartas de acao/emprestimo.png', 'EMPRESTIMO'),
    ('arte/cards/cartas de efeito/4-removebg-preview.png', 'EFEITO'),
    ('arte/cards/cartas de efeito/8-removebg-preview.png', 'EFEITO'),
    ('arte/cards/curinga/3-removebg-preview.png', 'CURINGA'),
    ('arte/cards/cartas de defesa/3-removebg-preview.png', 'DEFESA'),
]
y = 200
for i, (caminho, nome) in enumerate(galeria):
    x = 80 + (i % 3) * 380
    yy = y + (i // 3) * 730
    d.rounded_rectangle((x, yy, x + 350, yy + 680), radius=10, fill=PAINEL, outline=(80, 66, 110), width=2)
    arte_img, pos = arte(caminho, (x + 60, yy + 30, x + 290, yy + 580))
    colar(img, arte_img, pos)
    d.text((x + 24, yy + 610), nome, font=PX(13), fill=DOURADO)
rodape(d, 11)

# --------------------------------------------------------------- 12 GALERIA MESA
img, d = nova_pagina()
cabecalho(d, 12, '12. A MESA EM ACAO', 'Capturas do jogo')
capturas = [
    ('impor/mesa_manual.png', 'ARENA / MESA EM REDE', False),
    ('impor/mesa_area_manual.png', 'AREA SEGURA COM CARTA GUARDADA', False),
    ('arte/deus_mercado/deusmercado_interfereindo.png', 'O DEUS MERCADO INTERFERE', True),
]
y = 210
for caminho, legenda_texto, emoldurado in capturas:
    # capa=False (contain): a captura cabe inteira na caixa e nunca sobe
    # sobre o cabecalho nem invade a legenda da captura anterior.
    if emoldurado:
        d.rounded_rectangle((80, y, W - 80, y + 400), radius=10,
                            fill=PAINEL, outline=(80, 66, 110), width=2)
        caixa = (340, y + 30, 900, y + 360)
    else:
        caixa = (80, y, W - 80, y + 400)
    cap, pos = arte(caminho, caixa)
    colar(img, cap, pos)
    d.text((84, y + 410), legenda_texto, font=PX(14), fill=DOURADO)
    y += 460
rodape(d, 12)

# --------------------------------------------------------------- PDF
OUT.parent.mkdir(parents=True, exist_ok=True)
PAGINAS[0].save(OUT, 'PDF', save_all=True, append_images=PAGINAS[1:], resolution=150.0)
print(f'PDF A4 gerado: {OUT} ({len(PAGINAS)} paginas)')

if os.getenv('MANUAL_PNG_DIR'):
    destino = Path(os.getenv('MANUAL_PNG_DIR'))
    destino.mkdir(parents=True, exist_ok=True)
    for i, pagina in enumerate(PAGINAS, 1):
        pagina.save(destino / f'a4_{i:02d}.png')
    print('PNG de conferencia:', destino)
