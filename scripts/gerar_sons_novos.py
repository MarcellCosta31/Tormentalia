"""Gera efeitos sonoros curtos (16-bit/44100Hz/mono) para as melhorias de game feel."""
import math
import random
import struct
import wave
from pathlib import Path

R = Path(__file__).resolve().parent.parent
OUT = R / 'sons'
OUT.mkdir(exist_ok=True)
TAXA = 44100


def salvar(nome, amostras):
    dados = b''.join(struct.pack('<h', max(-32768, min(32767, int(v * 32767))))
                     for v in amostras)
    with wave.open(str(OUT / (nome + '.wav')), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(dados)
    print(nome, len(amostras) / TAXA, 's')


def envelope(i, n, ataque=0.02):
    if i < TAXA * ataque:
        return i / (TAXA * ataque)
    return max(0.0, 1 - (i - TAXA * ataque) / (n - TAXA * ataque))


def tom(freq, dur, tipo='square'):
    n = int(TAXA * dur)
    out = []
    for i in range(n):
        fase = 2 * math.pi * freq * i / TAXA
        if tipo == 'square':
            v = 1 if math.sin(fase) >= 0 else -1
        elif tipo == 'triangle':
            v = 2 / math.pi * math.asin(math.sin(fase))
        else:
            v = math.sin(fase)
        out.append(v * envelope(i, n) * 0.45)
    return out


# Caixa registradora: dois beeps agudos em sequencia.
caixa = tom(1320, 0.07, 'square') + [0.0] * int(TAXA * 0.04) + tom(1760, 0.10, 'square')
salvar('caixa', caixa)

# Escudo metalico: triangulo descendente com vibrato.
escudo = []
n = int(TAXA * 0.32)
for i in range(n):
    k = i / n
    freq = 900 - 480 * k + 40 * math.sin(2 * math.pi * 18 * i / TAXA)
    escudo.append(math.sin(2 * math.pi * freq * i / TAXA) * envelope(i, n) * 0.5)
salvar('escudo', escudo)

# Impacto/soco: ruido com envelope curto + Frequencia grave.
impacto = []
n = int(TAXA * 0.22)
for i in range(n):
    k = i / n
    ruido = random.uniform(-1, 1)
    grave = math.sin(2 * math.pi * (120 - 60 * k) * i / TAXA)
    impacto.append((ruido * 0.55 + grave * 0.6) * (1 - k) ** 2 * 0.7)
salvar('impacto', impacto)

# Versus: duas notas fortes em conflito.
versus = []
for freq, dur in ((330, 0.22), (440, 0.30)):
    n = int(TAXA * dur)
    for i in range(n):
        versus.append(math.sin(2 * math.pi * freq * i / TAXA) * envelope(i, n) * 0.5)
salvar('versus', versus)
