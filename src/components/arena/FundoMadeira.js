import React from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';

const { width: LARGURA_TELA, height: ALTURA_TELA } = Dimensions.get('window');

const CORES_PLACAS = [
  '#6B4526',
  '#73492B',
  '#64401F',
  '#785031',
  '#5E3B1E',
  '#6F4828',
];

const VINHETA = [0.05, 0.055, 0.06, 0.065, 0.07, 0.075];

// PRNG deterministico (mulberry32) — a textura nao "pula" entre renders
function criarRandom(semente) {
  let s = semente >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Clareia/escurece uma cor hex em uma quantidade (-255 a 255)
function ajustarCor(hex, delta) {
  const num = parseInt(hex.replace('#', ''), 16);
  const r = Math.min(255, Math.max(0, (num >> 16) + delta));
  const g = Math.min(255, Math.max(0, ((num >> 8) & 0xff) + delta));
  const b = Math.min(255, Math.max(0, (num & 0xff) + delta));
  return `rgb(${r},${g},${b})`;
}

function gerarSegmentos(rand, larguraTotal) {
  // 1 a 3 pedacos de taboa lado a lado, como uma mesa remontada de verdade
  const pesos = [0.45, 0.35, 0.2]; // chance de 1, 2 ou 3 segmentos
  const sorteio = rand();
  const qtd = sorteio < pesos[0] ? 1 : sorteio < pesos[0] + pesos[1] ? 2 : 3;

  if (qtd === 1) return [{ left: 0, largura: larguraTotal }];

  const fronteiras = [0];
  let acumulado = 0;
  for (let i = 0; i < qtd - 1; i++) {
    acumulado += larguraTotal / qtd + (rand() - 0.5) * (larguraTotal / qtd) * 0.4;
    fronteiras.push(Math.round(acumulado));
  }
  fronteiras.push(larguraTotal);

  const segmentos = [];
  for (let i = 0; i < fronteiras.length - 1; i++) {
    segmentos.push({ left: fronteiras[i], largura: fronteiras[i + 1] - fronteiras[i] });
  }
  return segmentos;
}

function gerarVeiosParaSegmento(rand, idx, segLargura, segAltura, corBase) {
  const veios = [];
  const qtdVeios = 7 + Math.floor(rand() * 7);

  for (let i = 0; i < qtdVeios; i++) {
    const claro = rand() < 0.35;
    const ehDuplo = rand() < 0.22;
    const rotacaoLeve = (rand() - 0.5) * 3; // graus, da a sensacao de veio "fluindo"
    const largura = Math.round(segLargura * (0.35 + rand() * 0.7));
    const top = Math.round(5 + rand() * Math.max(1, segAltura - 10));
    const left = Math.round(rand() * segLargura * 0.55);
    const cor = claro
      ? `rgba(255,224,183,${(0.05 + rand() * 0.07).toFixed(3)})`
      : `rgba(40,22,9,${(0.10 + rand() * 0.22).toFixed(3)})`;

    veios.push({
      key: `v${idx}_${i}`,
      top,
      left,
      largura,
      altura: rand() < 0.25 ? 2 : 1,
      cor,
      rotacao: rotacaoLeve,
    });

    if (ehDuplo) {
      veios.push({
        key: `v${idx}_${i}_par`,
        top: top + (rand() < 0.5 ? 3 : -3),
        left: left + Math.round(rand() * 12),
        largura: Math.round(largura * (0.6 + rand() * 0.3)),
        altura: 1,
        cor,
        rotacao: rotacaoLeve + (rand() - 0.5) * 1.2,
      });
    }
  }

  return veios;
}

function gerarPlacas() {
  const rand = criarRandom(1994);
  const placas = [];
  let y = -30;
  let idx = 0;

  while (y < ALTURA_TELA + 60) {
    const altura = Math.max(
      40,
      Math.round(ALTURA_TELA / 6) + Math.round(rand() * 30) - 15
    );

    const corBaseIdx = Math.floor(rand() * CORES_PLACAS.length);
    const corBase = CORES_PLACAS[corBaseIdx];

    const segmentosRaw = gerarSegmentos(rand, LARGURA_TELA);
    const segmentos = segmentosRaw.map((seg, segIdx) => {
      const variacao = Math.round((rand() - 0.5) * 14); // pequena diferenca de tom entre taboas vizinhas
      const corSegmento = ajustarCor(corBase, variacao);
      const veios = gerarVeiosParaSegmento(rand, `${idx}_${segIdx}`, seg.largura, altura, corSegmento);

      const temNo = rand() < 0.4;
      const no = temNo
        ? {
            left: Math.round(seg.largura * (0.15 + rand() * 0.65)),
            top: Math.round(altura * (0.25 + rand() * 0.45)),
            raio: Math.round(11 + rand() * 9),
          }
        : null;

      return {
        key: `s${idx}_${segIdx}`,
        left: seg.left,
        largura: seg.largura,
        cor: corSegmento,
        veios,
        no,
        temCostura: segIdx > 0,
      };
    });

    placas.push({
      key: `p${idx}`,
      top: y,
      altura,
      segmentos,
    });

    y += altura;
    idx += 1;
  }

  return placas;
}

const PLACAS = gerarPlacas();

// Fundo procedural: mesa de madeira (taboas com segmentos verticais + veios
// levemente ondulados + nos com aneis + verniz diagonal + vinheta).
export default function FundoMadeira() {
  return (
    <View style={styles.raiz} pointerEvents="none">
      {PLACAS.map((placa) => (
        <View key={placa.key} style={[styles.placa, { top: placa.top, height: placa.altura }]}>
          <View style={styles.costuraHorizontal} />
          <View style={styles.brilhoHorizontal} />

          {placa.segmentos.map((seg) => (
            <View
              key={seg.key}
              style={{
                position: 'absolute',
                left: seg.left,
                width: seg.largura,
                top: 0,
                bottom: 0,
                backgroundColor: seg.cor,
                overflow: 'hidden',
              }}
            >
              <View style={styles.brilhoTopo} />
              <View style={styles.sombraBase} />

              {seg.veios.map((veio) => (
                <View
                  key={veio.key}
                  style={{
                    position: 'absolute',
                    top: veio.top,
                    left: veio.left,
                    width: veio.largura,
                    height: veio.altura,
                    backgroundColor: veio.cor,
                    transform: [{ rotate: `${veio.rotacao}deg` }],
                  }}
                />
              ))}

              {seg.no && (
                <View
                  style={[
                    styles.noAnelExterno,
                    {
                      top: seg.no.top - seg.no.raio,
                      left: seg.no.left - seg.no.raio,
                      width: seg.no.raio * 2,
                      height: seg.no.raio * 1.7,
                      borderRadius: seg.no.raio,
                    },
                  ]}
                >
                  <View
                    style={[
                      styles.noAnelMeio,
                      {
                        width: '68%',
                        height: '68%',
                        borderRadius: seg.no.raio,
                      },
                    ]}
                  >
                    <View style={styles.noCentro} />
                  </View>
                </View>
              )}

              {seg.temCostura && <View style={styles.costuraVertical} />}
            </View>
          ))}
        </View>
      ))}

      {/* luz central quente — mesa sob lampada */}
      <View style={styles.luzCentral} />

      {/* verniz: faixa diagonal suave simulando reflexo de laca na madeira */}
      <View style={styles.vernizFaixa1} />
      <View style={styles.vernizFaixa2} />

      {/* vinheta: bordas escurecidas gradualmente */}
      {VINHETA.map((opacidade, i) => (
        <View
          key={`vinheta_${i}`}
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            borderWidth: (i + 1) * 26,
            borderColor: `rgba(14,7,3,${opacidade})`,
          }}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  raiz: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#5E3B1E',
    overflow: 'hidden',
  },
  placa: {
    position: 'absolute',
    left: 0,
    right: 0,
    overflow: 'hidden',
  },
  costuraHorizontal: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 3,
    backgroundColor: 'rgba(26,14,5,0.85)',
    zIndex: 5,
  },
  brilhoHorizontal: {
    position: 'absolute',
    top: 3,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,230,190,0.18)',
    zIndex: 5,
  },
  costuraVertical: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    width: 2,
    backgroundColor: 'rgba(20,10,4,0.55)',
  },
  brilhoTopo: {
    position: 'absolute',
    top: 3,
    left: 0,
    right: 0,
    height: '30%',
    backgroundColor: 'rgba(255,225,185,0.05)',
  },
  sombraBase: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: '35%',
    backgroundColor: 'rgba(0,0,0,0.10)',
  },
  noAnelExterno: {
    position: 'absolute',
    backgroundColor: 'rgba(52,28,12,0.42)',
    borderWidth: 2,
    borderColor: 'rgba(38,19,7,0.4)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  noAnelMeio: {
    backgroundColor: 'rgba(42,22,9,0.55)',
    borderWidth: 1.5,
    borderColor: 'rgba(30,15,6,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  noCentro: {
    width: '48%',
    height: '48%',
    borderRadius: 999,
    backgroundColor: 'rgba(26,13,5,0.65)',
  },
  luzCentral: {
    position: 'absolute',
    left: '10%',
    right: '10%',
    top: '18%',
    bottom: '18%',
    borderRadius: 300,
    backgroundColor: 'rgba(255,232,185,0.06)',
  },
  vernizFaixa1: {
    position: 'absolute',
    left: '-20%',
    right: '-20%',
    top: '8%',
    height: 90,
    backgroundColor: 'rgba(255,240,210,0.035)',
    transform: [{ rotate: '-8deg' }],
  },
  vernizFaixa2: {
    position: 'absolute',
    left: '-20%',
    right: '-20%',
    top: '55%',
    height: 60,
    backgroundColor: 'rgba(255,240,210,0.025)',
    transform: [{ rotate: '-8deg' }],
  },
});